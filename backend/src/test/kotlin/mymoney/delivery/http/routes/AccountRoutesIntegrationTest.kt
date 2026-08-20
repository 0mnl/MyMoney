package mymoney.delivery.http.routes

import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.AccountDto
import mymoney.delivery.http.dto.ArchiveAccountRequest
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.CreateAccountRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.UpdateAccountRequest
import mymoney.configureApplication
import mymoney.test.CapturingVerificationCodeSender
import mymoney.test.TestPostgres
import mymoney.test.registerAndVerify
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class AccountRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private data class TestUser(
        val familyId: String,
        val userId: String,
        val accessToken: String,
    )

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { configureApplication(CapturingVerificationCodeSender) }
    }

    private suspend fun ApplicationTestBuilder.registerUser(): TestUser {
        val email = "acc-${UUID.randomUUID()}@example.com"
        val session = registerAndVerify(email)
        return TestUser(session.familyId, session.userId, session.accessToken)
    }

    private suspend fun ApplicationTestBuilder.createAccount(
        user: TestUser,
        id: UUID = UUID.randomUUID(),
        name: String = "Cash",
        type: String = "cash",
        initialBalance: Long = 0L,
    ): HttpResponse = client.post("/v1/accounts") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        contentType(ContentType.Application.Json)
        setBody(
            json.encodeToString<CreateAccountRequest>(CreateAccountRequest(
                    id = id.toString(),
                    name = name,
                    type = type,
                    currency = "RUB",
                    initialBalance = initialBalance,
                ),
            ),
        )
    }

    @Test
    fun `unauthenticated requests are rejected`() = testApplication {
        setup()
        val res = client.get("/v1/accounts")
        assertEquals(HttpStatusCode.Unauthorized, res.status)
    }

    @Test
    fun `create then list then update then archive then unarchive`() = testApplication {
        setup()
        val user = registerUser()
        val accountId = UUID.randomUUID()

        val created = createAccount(user, id = accountId, name = "Wallet", initialBalance = 500_00L)
        assertEquals(HttpStatusCode.Created, created.status)
        val createdDto = json.decodeFromString<AccountDto>(created.bodyAsText())
        assertEquals(accountId.toString(), createdDto.id)
        assertEquals(user.familyId, createdDto.familyId)
        assertEquals(500_00L, createdDto.initialBalance)

        val list = client.get("/v1/accounts") { header(HttpHeaders.Authorization, "Bearer ${user.accessToken}") }
        val items = json.decodeFromString<List<AccountDto>>(list.bodyAsText())
        assertEquals(1, items.size)
        assertEquals(accountId.toString(), items.first().id)

        val updated = client.put("/v1/accounts/$accountId") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<UpdateAccountRequest>(UpdateAccountRequest(name = "Wallet+", type = "cash", currency = "RUB", initialBalance = 1_000_00L),
                ),
            )
        }
        assertEquals(HttpStatusCode.OK, updated.status)
        val updatedDto = json.decodeFromString<AccountDto>(updated.bodyAsText())
        assertEquals("Wallet+", updatedDto.name)
        assertEquals(1_000_00L, updatedDto.initialBalance)

        val archived = client.post("/v1/accounts/$accountId/archive") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<ArchiveAccountRequest>(ArchiveAccountRequest(archived = true)))
        }
        assertEquals(HttpStatusCode.OK, archived.status)
        assertTrue(json.decodeFromString<AccountDto>(archived.bodyAsText()).isArchived)

        val listAfterArchive = client.get("/v1/accounts") { header(HttpHeaders.Authorization, "Bearer ${user.accessToken}") }
        assertTrue(json.decodeFromString<List<AccountDto>>(listAfterArchive.bodyAsText()).isEmpty())

        val listWithArchived = client.get("/v1/accounts?includeArchived=true") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(1, json.decodeFromString<List<AccountDto>>(listWithArchived.bodyAsText()).size)

        val unarchived = client.post("/v1/accounts/$accountId/archive") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<ArchiveAccountRequest>(ArchiveAccountRequest(archived = false)))
        }
        assertEquals(HttpStatusCode.OK, unarchived.status)
        assertTrue(!json.decodeFromString<AccountDto>(unarchived.bodyAsText()).isArchived)
    }

    @Test
    fun `user cannot access another family's account`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()

        val aliceAccountId = UUID.randomUUID()
        assertEquals(HttpStatusCode.Created, createAccount(alice, id = aliceAccountId).status)

        val bobFetchesAlice = client.get("/v1/accounts/$aliceAccountId") {
            header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}")
        }
        assertEquals(HttpStatusCode.Forbidden, bobFetchesAlice.status)

        val bobUpdatesAlice = client.put("/v1/accounts/$aliceAccountId") {
            header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<UpdateAccountRequest>(UpdateAccountRequest("hacked", "cash", "RUB", 0L),
                ),
            )
        }
        assertEquals(HttpStatusCode.Forbidden, bobUpdatesAlice.status)

        val bobList = client.get("/v1/accounts") { header(HttpHeaders.Authorization, "Bearer ${bob.accessToken}") }
        assertTrue(json.decodeFromString<List<AccountDto>>(bobList.bodyAsText()).isEmpty())
    }

    @Test
    fun `create rejects non-RUB currency`() = testApplication {
        setup()
        val user = registerUser()
        val bad = client.post("/v1/accounts") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<CreateAccountRequest>(CreateAccountRequest(UUID.randomUUID().toString(), "N", "cash", "USD", 0L),
                ),
            )
        }
        assertEquals(HttpStatusCode.BadRequest, bad.status)
        assertTrue(bad.bodyAsText().contains("VALIDATION_FAILED"))
    }

    @Test
    fun `create with duplicate id returns 409`() = testApplication {
        setup()
        val user = registerUser()
        val id = UUID.randomUUID()

        assertEquals(HttpStatusCode.Created, createAccount(user, id = id).status)
        val dup = createAccount(user, id = id)
        assertEquals(HttpStatusCode.Conflict, dup.status)
        assertTrue(dup.bodyAsText().contains("ACCOUNT_ID_TAKEN"))
    }

    @Test
    fun `delete removes account from list and from get`() = testApplication {
        setup()
        val user = registerUser()
        val id = UUID.randomUUID()
        assertEquals(HttpStatusCode.Created, createAccount(user, id = id).status)

        val deleted = client.delete("/v1/accounts/$id") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.NoContent, deleted.status)

        val getDeleted = client.get("/v1/accounts/$id") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.NotFound, getDeleted.status)

        val list = client.get("/v1/accounts") { header(HttpHeaders.Authorization, "Bearer ${user.accessToken}") }
        assertTrue(json.decodeFromString<List<AccountDto>>(list.bodyAsText()).isEmpty())
    }

    @Test
    fun `get with invalid uuid returns 400`() = testApplication {
        setup()
        val user = registerUser()
        val res = client.get("/v1/accounts/not-a-uuid") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `list is empty for freshly-registered user`() = testApplication {
        setup()
        val user = registerUser()
        val res = client.get("/v1/accounts") { header(HttpHeaders.Authorization, "Bearer ${user.accessToken}") }
        assertEquals(HttpStatusCode.OK, res.status)
        val list = json.decodeFromString<List<AccountDto>>(res.bodyAsText())
        assertNotNull(list)
        assertTrue(list.isEmpty())
    }
}
