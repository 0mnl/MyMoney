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
import kotlinx.datetime.Clock
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.AccountDto
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.CategoryDto
import mymoney.delivery.http.dto.CreateAccountRequest
import mymoney.delivery.http.dto.CreateTransactionRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.TransactionDto
import mymoney.delivery.http.dto.TransactionHistoryEntryDto
import mymoney.delivery.http.dto.UpdateTransactionRequest
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

class TransactionRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private data class TestUser(
        val familyId: String,
        val userId: String,
        val accessToken: String,
    )

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend fun ApplicationTestBuilder.registerUser(): TestUser {
        val email = "tx-${UUID.randomUUID()}@example.com"
        val resp = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }
        val s = json.decodeFromString<AuthSessionResponse>(resp.bodyAsText())
        return TestUser(s.familyId, s.userId, s.accessToken)
    }

    private suspend fun ApplicationTestBuilder.createAccount(user: TestUser, name: String = "Cash"): AccountDto {
        val id = UUID.randomUUID()
        val res = client.post("/v1/accounts") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<CreateAccountRequest>(CreateAccountRequest(id.toString(), name, "cash", "RUB", 0L)))
        }
        return json.decodeFromString(res.bodyAsText())
    }

    private suspend fun ApplicationTestBuilder.firstExpenseCategory(user: TestUser): CategoryDto {
        val res = client.get("/v1/categories?type=EXPENSE") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        val cats = json.decodeFromString<List<CategoryDto>>(res.bodyAsText())
        return cats.first { it.type == "EXPENSE" }
    }

    private suspend fun ApplicationTestBuilder.createTransaction(
        user: TestUser,
        accountId: String,
        categoryId: String? = null,
        type: String = "EXPENSE",
        amount: Long = 250_00L,
        targetAccountId: String? = null,
    ): HttpResponse = client.post("/v1/transactions") {
        header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        contentType(ContentType.Application.Json)
        setBody(
            json.encodeToString<CreateTransactionRequest>(CreateTransactionRequest(
                    id = UUID.randomUUID().toString(),
                    accountId = accountId,
                    type = type,
                    amount = amount,
                    occurredAt = Clock.System.now(),
                    currency = "RUB",
                    categoryId = categoryId,
                    targetAccountId = targetAccountId,
                    comment = null,
                    attachmentPhotoPath = null,
                ),
            ),
        )
    }

    @Test
    fun `create expense transaction and list contains it`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val category = firstExpenseCategory(user)

        val res = createTransaction(user, accountId = account.id, categoryId = category.id, amount = 1_234_56L)
        assertEquals(HttpStatusCode.Created, res.status)
        val created = json.decodeFromString<TransactionDto>(res.bodyAsText())
        assertEquals(1_234_56L, created.amount)
        assertEquals("EXPENSE", created.type)
        assertEquals(user.familyId, created.familyId)

        val list = client.get("/v1/transactions") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        val items = json.decodeFromString<List<TransactionDto>>(list.bodyAsText())
        assertNotNull(items.firstOrNull { it.id == created.id })
    }

    @Test
    fun `transfer between two accounts of same family works`() = testApplication {
        setup()
        val user = registerUser()
        val a = createAccount(user, "Card")
        val b = createAccount(user, "Wallet")

        val res = createTransaction(
            user = user,
            accountId = a.id,
            categoryId = null,
            type = "TRANSFER",
            amount = 500_00L,
            targetAccountId = b.id,
        )
        assertEquals(HttpStatusCode.Created, res.status)
        val tx = json.decodeFromString<TransactionDto>(res.bodyAsText())
        assertEquals("TRANSFER", tx.type)
        assertEquals(b.id, tx.targetAccountId)
    }

    @Test
    fun `transfer without target is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val res = createTransaction(user = user, accountId = account.id, type = "TRANSFER", targetAccountId = null)
        assertEquals(HttpStatusCode.BadRequest, res.status)
        assertTrue(res.bodyAsText().contains("targetAccountId"))
    }

    @Test
    fun `transfer between the same account is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val res = createTransaction(
            user = user,
            accountId = account.id,
            type = "TRANSFER",
            targetAccountId = account.id,
        )
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `income transaction with expense category is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val expenseCategory = firstExpenseCategory(user)

        val res = createTransaction(
            user = user,
            accountId = account.id,
            categoryId = expenseCategory.id,
            type = "INCOME",
        )
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `zero amount is rejected`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val category = firstExpenseCategory(user)
        val res = createTransaction(user, account.id, categoryId = category.id, amount = 0L)
        assertEquals(HttpStatusCode.BadRequest, res.status)
    }

    @Test
    fun `cross-family create is rejected`() = testApplication {
        setup()
        val alice = registerUser()
        val bob = registerUser()
        val aliceAccount = createAccount(alice)
        val bobCategory = firstExpenseCategory(bob)

        val res = createTransaction(
            user = bob,
            accountId = aliceAccount.id,
            categoryId = bobCategory.id,
        )
        // Bob is trying to post to Alice's account — must be blocked.
        assertEquals(HttpStatusCode.Forbidden, res.status)
    }

    @Test
    fun `update creates a history entry with the previous state`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val category = firstExpenseCategory(user)

        val created = json.decodeFromString<TransactionDto>(
            createTransaction(user, account.id, categoryId = category.id, amount = 100_00L).bodyAsText(),
        )

        val updated = client.put("/v1/transactions/${created.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString<UpdateTransactionRequest>(UpdateTransactionRequest(
                        accountId = account.id,
                        type = "EXPENSE",
                        amount = 250_00L,
                        occurredAt = created.occurredAt,
                        currency = "RUB",
                        categoryId = category.id,
                        targetAccountId = null,
                        comment = "corrected",
                        attachmentPhotoPath = null,
                    ),
                ),
            )
        }
        assertEquals(HttpStatusCode.OK, updated.status)
        val updatedDto = json.decodeFromString<TransactionDto>(updated.bodyAsText())
        assertEquals(250_00L, updatedDto.amount)
        assertEquals("corrected", updatedDto.comment)

        val history = client.get("/v1/transactions/${created.id}/history") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.OK, history.status)
        val entries = json.decodeFromString<List<TransactionHistoryEntryDto>>(history.bodyAsText())
        assertEquals(1, entries.size)
        val snapshotText = entries.first().snapshot.toString()
        assertTrue(snapshotText.contains("10000"), "snapshot missing prior amount: $snapshotText")
    }

    @Test
    fun `soft delete hides transaction and adds a history snapshot`() = testApplication {
        setup()
        val user = registerUser()
        val account = createAccount(user)
        val category = firstExpenseCategory(user)
        val tx = json.decodeFromString<TransactionDto>(
            createTransaction(user, account.id, categoryId = category.id).bodyAsText(),
        )

        val del = client.delete("/v1/transactions/${tx.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.NoContent, del.status)

        val getAfter = client.get("/v1/transactions/${tx.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.NotFound, getAfter.status)

        val history = client.get("/v1/transactions/${tx.id}/history") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.OK, history.status)
        val entries = json.decodeFromString<List<TransactionHistoryEntryDto>>(history.bodyAsText())
        assertEquals(1, entries.size)
    }

    @Test
    fun `unauthenticated is rejected`() = testApplication {
        setup()
        assertEquals(HttpStatusCode.Unauthorized, client.get("/v1/transactions").status)
    }

    @Test
    fun `list can filter by accountId including transfers as target`() = testApplication {
        setup()
        val user = registerUser()
        val a = createAccount(user, "A")
        val b = createAccount(user, "B")
        createTransaction(user, a.id, type = "TRANSFER", targetAccountId = b.id, amount = 300_00L)

        val listByA = client.get("/v1/transactions?accountId=${a.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        val listByB = client.get("/v1/transactions?accountId=${b.id}") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        val fromA = json.decodeFromString<List<TransactionDto>>(listByA.bodyAsText())
        val fromB = json.decodeFromString<List<TransactionDto>>(listByB.bodyAsText())
        assertEquals(1, fromA.size)
        assertEquals(1, fromB.size)
        assertEquals(fromA.first().id, fromB.first().id)
    }
}
