package mymoney.delivery.http.routes

import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.CreateGoalRequest
import mymoney.delivery.http.dto.GoalContributionRequest
import mymoney.delivery.http.dto.GoalDto
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.UpdateGoalRequest
import mymoney.configureApplication
import mymoney.test.CapturingVerificationCodeSender
import mymoney.test.TestPostgres
import mymoney.test.registerAndVerify
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GoalRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private data class TestUser(val familyId: String, val userId: String, val accessToken: String)

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { configureApplication(CapturingVerificationCodeSender) }
    }

    private suspend fun ApplicationTestBuilder.registerUser(): TestUser {
        val email = "goal-${UUID.randomUUID()}@example.com"
        val s = registerAndVerify(email)
        return TestUser(s.familyId, s.userId, s.accessToken)
    }

    private suspend fun ApplicationTestBuilder.createGoal(
        user: TestUser,
        name: String = "New laptop",
        target: Long = 100_000_00L,
        current: Long = 0L,
    ) = client.post("/v1/goals") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        contentType(ContentType.Application.Json)
        setBody(
            json.encodeToString<CreateGoalRequest>(CreateGoalRequest(
                    id = UUID.randomUUID().toString(),
                    name = name,
                    targetAmount = target,
                    currentAmount = current,
                ),
            ),
        )
    }

    @Test
    fun `create goal happy path`() = testApplication {
        setup()
        val user = registerUser()
        val res = createGoal(user, name = "New bike", target = 40_000_00L)
        assertEquals(HttpStatusCode.Created, res.status)
        val goal = json.decodeFromString<GoalDto>(res.bodyAsText())
        assertEquals("New bike", goal.name)
        assertEquals(40_000_00L, goal.targetAmount)
        assertEquals(0L, goal.currentAmount)
        assertEquals(false, goal.isCompleted)
    }

    @Test
    fun `deposit adds to current amount and updates progress`() = testApplication {
        setup()
        val user = registerUser()
        val created = json.decodeFromString<GoalDto>(createGoal(user, target = 1_000_00L).bodyAsText())

        val deposited = client.post("/v1/goals/${created.id}/deposit") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<GoalContributionRequest>(GoalContributionRequest(amount = 400_00L)))
        }
        assertEquals(HttpStatusCode.OK, deposited.status)
        val depGoal = json.decodeFromString<GoalDto>(deposited.bodyAsText())
        assertEquals(400_00L, depGoal.currentAmount)
        assertEquals(40, depGoal.progressPercent)
        assertEquals(false, depGoal.isCompleted)
    }

    @Test
    fun `withdraw more than current is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val created = json.decodeFromString<GoalDto>(createGoal(user, target = 1_000_00L, current = 100_00L).bodyAsText())
        val res = client.post("/v1/goals/${created.id}/withdraw") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<GoalContributionRequest>(GoalContributionRequest(amount = 500_00L)))
        }
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `reaching target marks goal as completed`() = testApplication {
        setup()
        val user = registerUser()
        val created = json.decodeFromString<GoalDto>(createGoal(user, target = 500_00L).bodyAsText())
        val res = client.post("/v1/goals/${created.id}/deposit") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<GoalContributionRequest>(GoalContributionRequest(amount = 500_00L)))
        }
        val updated = json.decodeFromString<GoalDto>(res.bodyAsText())
        assertEquals(true, updated.isCompleted)
        assertEquals(100, updated.progressPercent)
    }

    @Test
    fun `update goal changes name and target but not current`() = testApplication {
        setup()
        val user = registerUser()
        val created = json.decodeFromString<GoalDto>(
            createGoal(user, name = "Old", target = 500_00L, current = 100_00L).bodyAsText(),
        )

        val res = client.put("/v1/goals/${created.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<UpdateGoalRequest>(UpdateGoalRequest(name = "New", targetAmount = 800_00L, targetDate = null),
                ),
            )
        }
        assertEquals(HttpStatusCode.OK, res.status)
        val updated = json.decodeFromString<GoalDto>(res.bodyAsText())
        assertEquals("New", updated.name)
        assertEquals(800_00L, updated.targetAmount)
        assertEquals(100_00L, updated.currentAmount)
    }

    @Test
    fun `soft delete hides goal from list`() = testApplication {
        setup()
        val user = registerUser()
        val created = json.decodeFromString<GoalDto>(createGoal(user).bodyAsText())
        assertEquals(
            HttpStatusCode.NoContent,
            client.delete("/v1/goals/${created.id}") {
                header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            }.status,
        )
        val list = client.get("/v1/goals") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertTrue(json.decodeFromString<List<GoalDto>>(list.bodyAsText()).isEmpty())
    }

    @Test
    fun `cross-family access is forbidden`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()
        val goal = json.decodeFromString<GoalDto>(createGoal(alice).bodyAsText())
        val res = client.get("/v1/goals/${goal.id}") {
            header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}")
        }
        assertEquals(HttpStatusCode.Forbidden, res.status)
    }

    @Test
    fun `blank name is rejected`() = testApplication {
        setup()
        val user = registerUser()
        assertEquals(HttpStatusCode.BadRequest, createGoal(user, name = " ").status)
    }

    @Test
    fun `negative target is rejected`() = testApplication {
        setup()
        val user = registerUser()
        assertEquals(HttpStatusCode.BadRequest, createGoal(user, target = -100L).status)
    }

    @Test
    fun `unauthenticated is rejected`() = testApplication {
        setup()
        assertEquals(HttpStatusCode.Unauthorized, client.get("/v1/goals").status)
    }
}
