package mymoney.delivery.http.routes

import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import io.ktor.server.testing.testApplication
import kotlinx.datetime.Instant
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.SyncAccountDto
import mymoney.delivery.http.dto.SyncBundleDto
import mymoney.delivery.http.dto.SyncPullResponse
import mymoney.delivery.http.dto.SyncPushRequest
import mymoney.delivery.http.dto.SyncPushResponse
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class SyncRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend inline fun <reified T> HttpResponse.decode(): T =
        json.decodeFromString<T>(bodyAsText())

    private suspend fun ApplicationTestBuilder.register(email: String) =
        client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(RegisterRequest(email, "password123")))
        }.decode<AuthSessionResponse>()

    private fun newEmail(prefix: String) = "$prefix-${UUID.randomUUID()}@example.com"

    private fun makeAccount(familyId: String, id: String = UUID.randomUUID().toString(), updated: Instant): SyncAccountDto =
        SyncAccountDto(
            id = id,
            familyId = familyId,
            name = "Wallet",
            type = "cash",
            currency = "RUB",
            initialBalanceKopecks = 100_000L,
            isArchived = false,
            isDeleted = false,
            createdAt = updated,
            updatedAt = updated,
        )

    @Test
    fun `initial pull returns seeded categories and self family`() = testApplication {
        setup()
        val user = register(newEmail("pull-init"))

        val resp = client.get("/v1/sync/pull") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }
        assertEquals(HttpStatusCode.OK, resp.status)
        val body = resp.decode<SyncPullResponse>()
        assertEquals(1, body.bundle.families.size)
        assertEquals(user.familyId, body.bundle.families.first().id)
        assertEquals(1, body.bundle.familyMembers.size)
        // seed_data.dart mirror on server: SeedSystemCategoriesUseCase creates
        // a non-empty default set.
        assertTrue(body.bundle.categories.isNotEmpty(), "system categories must be seeded")
    }

    @Test
    fun `push then pull round-trips an account`() = testApplication {
        setup()
        val user = register(newEmail("push-account"))
        val accountId = UUID.randomUUID().toString()
        val ts = Instant.parse("2026-07-21T12:00:00Z")

        val push = client.post("/v1/sync/push") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString(
                    SyncPushRequest(
                        bundle = SyncBundleDto(
                            accounts = listOf(makeAccount(user.familyId, accountId, ts)),
                        ),
                    ),
                ),
            )
        }
        assertEquals(HttpStatusCode.OK, push.status)
        val pushBody = push.decode<SyncPushResponse>()
        assertTrue(pushBody.conflicts.isEmpty())
        assertEquals(1, pushBody.accepted.size)
        assertEquals(accountId, pushBody.accepted.first().id)

        val pull = client.get("/v1/sync/pull") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }.decode<SyncPullResponse>()
        val fetched = pull.bundle.accounts.singleOrNull { it.id == accountId }
        assertTrue(fetched != null, "account must appear in pull")
        assertEquals(100_000L, fetched!!.initialBalanceKopecks)
    }

    @Test
    fun `LWW rejects older client version when server is newer`() = testApplication {
        setup()
        val user = register(newEmail("lww"))
        val accountId = UUID.randomUUID().toString()
        val early = Instant.parse("2026-07-01T00:00:00Z")
        val late = Instant.parse("2026-07-21T00:00:00Z")

        // Server first sees the "late" version.
        val serverPush = client.post("/v1/sync/push") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString(
                    SyncPushRequest(
                        bundle = SyncBundleDto(
                            accounts = listOf(makeAccount(user.familyId, accountId, late).copy(name = "Server")),
                        ),
                    ),
                ),
            )
        }
        assertEquals(HttpStatusCode.OK, serverPush.status)

        // Now client attempts to push an older version → must land in conflicts.
        val clientPush = client.post("/v1/sync/push") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString(
                    SyncPushRequest(
                        bundle = SyncBundleDto(
                            accounts = listOf(makeAccount(user.familyId, accountId, early).copy(name = "Client")),
                        ),
                    ),
                ),
            )
        }.decode<SyncPushResponse>()
        assertTrue(clientPush.accepted.isEmpty(), "old client version must not be accepted")
        assertEquals(1, clientPush.conflicts.size)
        val serverVersion = clientPush.conflicts.first().serverBundle.accounts.single()
        assertEquals("Server", serverVersion.name)
        assertEquals(late, serverVersion.updatedAt)
    }

    @Test
    fun `push into a foreign family is rejected`() = testApplication {
        setup()
        val attacker = register(newEmail("attacker"))
        val victim = register(newEmail("victim"))

        val response = client.post("/v1/sync/push") {
            header(HttpHeaders.Authorization, "Bearer ${attacker.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString(
                    SyncPushRequest(
                        bundle = SyncBundleDto(
                            accounts = listOf(makeAccount(victim.familyId, updated = Instant.parse("2026-07-21T00:00:00Z"))),
                        ),
                    ),
                ),
            )
        }
        assertEquals(HttpStatusCode.Forbidden, response.status)
    }

    @Test
    fun `pull with since returns only newer rows`() = testApplication {
        setup()
        val user = register(newEmail("since"))

        val firstPull = client.get("/v1/sync/pull") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }.decode<SyncPullResponse>()
        val cursor = firstPull.serverTime

        // Push a fresh account after the cursor.
        val ts = Instant.parse("2027-01-01T00:00:00Z")
        client.post("/v1/sync/push") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
            contentType(ContentType.Application.Json)
            setBody(
                json.encodeToString(
                    SyncPushRequest(
                        bundle = SyncBundleDto(
                            accounts = listOf(makeAccount(user.familyId, updated = ts)),
                        ),
                    ),
                ),
            )
        }

        val incremental = client.get("/v1/sync/pull?since=$cursor") {
            header(HttpHeaders.Authorization, "Bearer ${user.accessToken}")
        }.decode<SyncPullResponse>()
        assertEquals(1, incremental.bundle.accounts.size)
        assertTrue(incremental.bundle.categories.isEmpty(), "seed categories must be behind cursor")
    }
}
