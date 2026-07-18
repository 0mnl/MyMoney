package mymoney.delivery.http.routes

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
import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.AuthTokensResponse
import mymoney.delivery.http.dto.LoginRequest
import mymoney.delivery.http.dto.RefreshRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.module
import mymoney.test.TestPostgres
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

/**
 * End-to-end auth flow against a real Postgres via Testcontainers. Covers the
 * happy path (register → login → refresh → logout-all) plus a few common
 * failure modes (duplicate email, wrong password, revoked refresh).
 */
class AuthRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { module() }
    }

    private suspend inline fun <reified T> HttpResponse.decode(): T =
        json.decodeFromString<T>(this.bodyAsText())

    @Test
    fun `register issues a session and prevents duplicate email`() = testApplication {
        setup()
        val email = "reg-${UUID.randomUUID()}@example.com"

        val ok = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }
        assertEquals(HttpStatusCode.OK, ok.status)
        val session = ok.decode<AuthSessionResponse>()
        assertTrue(session.accessToken.isNotBlank())
        assertTrue(session.refreshToken.isNotBlank())
        assertNotEquals(session.userId, session.familyId)

        val dup = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }
        assertEquals(HttpStatusCode.Conflict, dup.status)
    }

    @Test
    fun `login succeeds with correct password and rejects wrong password`() = testApplication {
        setup()
        val email = "login-${UUID.randomUUID()}@example.com"
        val password = "password123"

        client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, password)))
        }

        val ok = client.post("/v1/auth/login") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<LoginRequest>(LoginRequest(email, password)))
        }
        assertEquals(HttpStatusCode.OK, ok.status)

        val bad = client.post("/v1/auth/login") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<LoginRequest>(LoginRequest(email, "wrong-password")))
        }
        assertEquals(HttpStatusCode.Unauthorized, bad.status)
    }

    @Test
    fun `refresh rotates the token and revokes the old one`() = testApplication {
        setup()
        val email = "refresh-${UUID.randomUUID()}@example.com"
        val register = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }.decode<AuthSessionResponse>()

        val rotated = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RefreshRequest>(RefreshRequest(register.refreshToken)))
        }
        assertEquals(HttpStatusCode.OK, rotated.status)
        val pair = rotated.decode<AuthTokensResponse>()
        assertNotEquals(register.refreshToken, pair.refreshToken)
        assertNotEquals(register.accessToken, pair.accessToken)

        // Reusing the original refresh must fail — it has been revoked.
        val replay = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RefreshRequest>(RefreshRequest(register.refreshToken)))
        }
        assertEquals(HttpStatusCode.Unauthorized, replay.status)
    }

    @Test
    fun `logout-all invalidates every refresh token for the user`() = testApplication {
        setup()
        val email = "logout-${UUID.randomUUID()}@example.com"
        val session = client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RegisterRequest>(RegisterRequest(email, "password123")))
        }.decode<AuthSessionResponse>()

        val logout = client.post("/v1/auth/logout-all") {
            header(HttpHeaders.Authorization, "Bearer ${session.accessToken}")
        }
        assertEquals(HttpStatusCode.NoContent, logout.status)

        val afterLogout = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RefreshRequest>(RefreshRequest(session.refreshToken)))
        }
        assertEquals(HttpStatusCode.Unauthorized, afterLogout.status)
    }

    @Test
    fun `logout-all requires a bearer token`() = testApplication {
        setup()
        val response = client.post("/v1/auth/logout-all")
        assertEquals(HttpStatusCode.Unauthorized, response.status)
        assertFalse(response.bodyAsText().isEmpty(), "error body must not be empty")
    }
}
