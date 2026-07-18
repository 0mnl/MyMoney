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
import kotlinx.datetime.Clock
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.AccountDto
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.BudgetDto
import mymoney.delivery.http.dto.BudgetProgressDto
import mymoney.delivery.http.dto.CategoryDto
import mymoney.delivery.http.dto.CreateAccountRequest
import mymoney.delivery.http.dto.CreateBudgetRequest
import mymoney.delivery.http.dto.CreateTransactionRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.UpdateBudgetRequest
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class BudgetRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private data class TestUser(val familyId: String, val userId: String, val accessToken: String)

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend fun ApplicationTestBuilder.registerUser(): TestUser {
        val email = "budget-${UUID.randomUUID()}@example.com"
        val resp = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }
        val s = json.decodeFromString<AuthSessionResponse>(resp.bodyAsText())
        return TestUser(s.familyId, s.userId, s.accessToken)
    }

    private suspend fun ApplicationTestBuilder.createAccount(user: TestUser): AccountDto {
        val id = UUID.randomUUID()
        val res = client.post("/v1/accounts") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<CreateAccountRequest>(CreateAccountRequest(id.toString(), "Wallet", "cash", "RUB", 0L)))
        }
        return json.decodeFromString(res.bodyAsText())
    }

    private suspend fun ApplicationTestBuilder.firstExpenseCategory(user: TestUser): CategoryDto {
        val res = client.get("/v1/categories?type=EXPENSE") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        return json.decodeFromString<List<CategoryDto>>(res.bodyAsText()).first { it.type == "EXPENSE" }
    }

    private suspend fun ApplicationTestBuilder.firstIncomeCategory(user: TestUser): CategoryDto {
        val res = client.get("/v1/categories?type=INCOME") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        return json.decodeFromString<List<CategoryDto>>(res.bodyAsText()).first { it.type == "INCOME" }
    }

    private suspend fun ApplicationTestBuilder.createBudget(
        user: TestUser,
        categoryId: String,
        periodType: String = "MONTH",
        periodStart: String = "2026-07-01T00:00:00Z",
        planned: Long = 10_000_00L,
    ) = client.post("/v1/budgets") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        contentType(ContentType.Application.Json)
        setBody(
            json.encodeToString<CreateBudgetRequest>(CreateBudgetRequest(
                    id = UUID.randomUUID().toString(),
                    categoryId = categoryId,
                    periodType = periodType,
                    periodStart = kotlinx.datetime.Instant.parse(periodStart),
                    plannedAmount = planned,
                ),
            ),
        )
    }

    @Test
    fun `create budget for EXPENSE category succeeds`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstExpenseCategory(user)
        val res = createBudget(user, cat.id, planned = 15_000_00L)
        assertEquals(HttpStatusCode.Created, res.status)
        val dto = json.decodeFromString<BudgetDto>(res.bodyAsText())
        assertEquals(cat.id, dto.categoryId)
        assertEquals("MONTH", dto.periodType)
        assertEquals(15_000_00L, dto.plannedAmount)
    }

    @Test
    fun `budget for INCOME category is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstIncomeCategory(user)
        val res = createBudget(user, cat.id)
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `duplicate budget for same period is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstExpenseCategory(user)
        assertEquals(HttpStatusCode.Created, createBudget(user, cat.id).status)
        val second = createBudget(user, cat.id)
        assertEquals(HttpStatusCode.Conflict, second.status)
    }

    @Test
    fun `list returns own budgets only`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()
        val aliceCat = firstExpenseCategory(alice)
        val bobCat = firstExpenseCategory(bob)
        assertEquals(HttpStatusCode.Created, createBudget(alice, aliceCat.id, planned = 100_00L).status)
        assertEquals(HttpStatusCode.Created, createBudget(bob, bobCat.id, planned = 200_00L).status)

        val list = client.get("/v1/budgets") {
            header(HttpHeaders.Authorization, "Bearer ${alice.accessToken}")
        }
        val items = json.decodeFromString<List<BudgetDto>>(list.bodyAsText())
        assertEquals(1, items.size)
        assertEquals(100_00L, items.first().plannedAmount)
    }

    @Test
    fun `update budget changes planned amount`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstExpenseCategory(user)
        val created = json.decodeFromString<BudgetDto>(createBudget(user, cat.id, planned = 100_00L).bodyAsText())

        val res = client.put("/v1/budgets/${created.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<UpdateBudgetRequest>(UpdateBudgetRequest(plannedAmount = 250_00L)))
        }
        assertEquals(HttpStatusCode.OK, res.status)
        assertEquals(250_00L, json.decodeFromString<BudgetDto>(res.bodyAsText()).plannedAmount)
    }

    @Test
    fun `soft delete hides budget from list`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstExpenseCategory(user)
        val created = json.decodeFromString<BudgetDto>(createBudget(user, cat.id).bodyAsText())
        assertEquals(
            HttpStatusCode.NoContent,
            client.delete("/v1/budgets/${created.id}") {
                header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            }.status,
        )
        val list = client.get("/v1/budgets") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertTrue(json.decodeFromString<List<BudgetDto>>(list.bodyAsText()).isEmpty())
    }

    @Test
    fun `progress reflects EXPENSE transactions in the period window`() = testApplication {
        setup()
        val user = registerUser()
        val cat = firstExpenseCategory(user)
        val account = createAccount(user)
        val budget = json.decodeFromString<BudgetDto>(
            createBudget(user, cat.id, periodStart = "2026-07-01T00:00:00Z", planned = 1_000_00L).bodyAsText(),
        )

        // in-window expense
        client.post("/v1/transactions") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<CreateTransactionRequest>(CreateTransactionRequest(
                        id = UUID.randomUUID().toString(),
                        accountId = account.id,
                        type = "EXPENSE",
                        amount = 400_00L,
                        occurredAt = kotlinx.datetime.Instant.parse("2026-07-15T12:00:00Z"),
                        currency = "RUB",
                        categoryId = cat.id,
                    ),
                ),
            )
        }
        // out-of-window expense — should NOT count
        client.post("/v1/transactions") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<CreateTransactionRequest>(CreateTransactionRequest(
                        id = UUID.randomUUID().toString(),
                        accountId = account.id,
                        type = "EXPENSE",
                        amount = 900_00L,
                        occurredAt = kotlinx.datetime.Instant.parse("2026-08-05T12:00:00Z"),
                        currency = "RUB",
                        categoryId = cat.id,
                    ),
                ),
            )
        }

        val res = client.get("/v1/budgets/${budget.id}/progress") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.OK, res.status)
        val progress = json.decodeFromString<BudgetProgressDto>(res.bodyAsText())
        assertEquals(400_00L, progress.spentAmount)
        assertEquals(600_00L, progress.remainingAmount)
        assertEquals(false, progress.isOverspent)
        assertEquals(40, progress.progressPercent)
    }

    @Test
    fun `cross-family access is forbidden`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()
        val cat = firstExpenseCategory(alice)
        val budget = json.decodeFromString<BudgetDto>(createBudget(alice, cat.id).bodyAsText())

        val res = client.get("/v1/budgets/${budget.id}") {
            header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}")
        }
        assertEquals(HttpStatusCode.Forbidden, res.status)
    }

    @Test
    fun `unauthenticated is rejected`() = testApplication {
        setup()
        assertEquals(HttpStatusCode.Unauthorized, client.get("/v1/budgets").status)
    }
}
