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
import mymoney.delivery.http.dto.PendingRegistrationResponse
import mymoney.delivery.http.dto.RefreshRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.ResendCodeRequest
import mymoney.delivery.http.dto.VerifyEmailRequest
import mymoney.configureApplication
import mymoney.test.CapturingVerificationCodeSender
import mymoney.test.TestPostgres
import mymoney.test.registerAndVerify
import mymoney.test.testAppConfig
import java.util.UUID
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

/**
 * End-to-end auth flow against a real Postgres via Testcontainers. Covers the
 * happy path (register → confirm → login → refresh → logout-all) plus the
 * failure modes the onboarding screens branch on: unconfirmed login, wrong
 * code, duplicate email, revoked refresh.
 */
class AuthRoutesIntegrationTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun ApplicationTestBuilder.setup() {
        environment { config = testAppConfig(TestPostgres.container) }
        application { configureApplication(CapturingVerificationCodeSender) }
    }

    private suspend inline fun <reified T> HttpResponse.decode(): T =
        json.decodeFromString<T>(this.bodyAsText())

    private suspend fun ApplicationTestBuilder.register(email: String, password: String = "password123") =
        client.post("/v1/auth/register") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(RegisterRequest(email, password)))
        }

    private suspend fun ApplicationTestBuilder.verify(email: String, code: String) =
        client.post("/v1/auth/verify-email") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(VerifyEmailRequest(email, code)))
        }

    @Test
    fun `register issues no tokens and confirmation exchanges the code for a session`() = testApplication {
        setup()
        val email = "reg-${UUID.randomUUID()}@example.com"

        val pending = register(email)
        assertEquals(HttpStatusCode.Accepted, pending.status)
        val body = pending.decode<PendingRegistrationResponse>()
        assertEquals(email, body.email)
        assertTrue(
            body.codeExpiresAt > body.resendAvailableAt,
            "code must outlive the resend cooldown",
        )
        assertFalse(
            pending.bodyAsText().contains("accessToken"),
            "registration must not hand out tokens before confirmation",
        )

        val confirmed = verify(email, CapturingVerificationCodeSender.codeFor(email))
        assertEquals(HttpStatusCode.OK, confirmed.status)
        val session = confirmed.decode<AuthSessionResponse>()
        assertTrue(session.accessToken.isNotBlank())
        assertTrue(session.refreshToken.isNotBlank())
        assertNotEquals(session.userId, session.familyId)
    }

    @Test
    fun `a wrong code is rejected and the right one still works`() = testApplication {
        setup()
        val email = "code-${UUID.randomUUID()}@example.com"
        register(email)

        val wrong = verify(email, "000000")
        // Guard against the 1-in-a-million collision with the real code.
        if (CapturingVerificationCodeSender.codeFor(email) != "000000") {
            assertEquals(HttpStatusCode.BadRequest, wrong.status)
            assertTrue(wrong.bodyAsText().contains("INVALID_CODE"))
        }

        val right = verify(email, CapturingVerificationCodeSender.codeFor(email))
        assertEquals(HttpStatusCode.OK, right.status)
    }

    @Test
    fun `a code cannot be reused once confirmed`() = testApplication {
        setup()
        val email = "reuse-${UUID.randomUUID()}@example.com"
        register(email)
        val code = CapturingVerificationCodeSender.codeFor(email)

        assertEquals(HttpStatusCode.OK, verify(email, code).status)

        val replay = verify(email, code)
        assertEquals(HttpStatusCode.Conflict, replay.status)
        assertTrue(replay.bodyAsText().contains("EMAIL_ALREADY_VERIFIED"))
    }

    @Test
    fun `resend is refused during the cooldown and leaves the code intact`() = testApplication {
        setup()
        val email = "resend-${UUID.randomUUID()}@example.com"
        register(email)
        val first = CapturingVerificationCodeSender.codeFor(email)

        // The cooldown has not elapsed, so the server refuses a second send.
        val tooSoon = client.post("/v1/auth/resend-code") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(ResendCodeRequest(email)))
        }
        assertEquals(HttpStatusCode.TooManyRequests, tooSoon.status)
        assertTrue(tooSoon.bodyAsText().contains("RESEND_COOLDOWN"))

        // The original code is untouched by the rejected resend.
        assertEquals(first, CapturingVerificationCodeSender.codeFor(email))
        assertEquals(HttpStatusCode.OK, verify(email, first).status)
    }

    @Test
    fun `register on an unconfirmed address does not conflict and does not re-send`() = testApplication {
        setup()
        val email = "again-${UUID.randomUUID()}@example.com"

        assertEquals(HttpStatusCode.Accepted, register(email).status)
        val first = CapturingVerificationCodeSender.codeFor(email)

        // Retrying registration must not be a way around the resend cooldown,
        // or it becomes a mail-flooding tool aimed at someone else's inbox.
        assertEquals(HttpStatusCode.Accepted, register(email).status)
        assertEquals(first, CapturingVerificationCodeSender.codeFor(email))

        assertEquals(HttpStatusCode.OK, verify(email, first).status)
    }

    @Test
    fun `register rejects a duplicate once the address is confirmed`() = testApplication {
        setup()
        val email = "dup-${UUID.randomUUID()}@example.com"
        registerAndVerify(email)

        val dup = register(email)
        assertEquals(HttpStatusCode.Conflict, dup.status)
        assertTrue(dup.bodyAsText().contains("EMAIL_TAKEN"))
    }

    @Test
    fun `login is refused until the email is confirmed`() = testApplication {
        setup()
        val email = "unconfirmed-${UUID.randomUUID()}@example.com"
        val password = "password123"
        register(email, password)

        val blocked = client.post("/v1/auth/login") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(LoginRequest(email, password)))
        }
        assertEquals(HttpStatusCode.Forbidden, blocked.status)
        assertTrue(blocked.bodyAsText().contains("EMAIL_NOT_VERIFIED"))

        verify(email, CapturingVerificationCodeSender.codeFor(email))

        val allowed = client.post("/v1/auth/login") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString(LoginRequest(email, password)))
        }
        assertEquals(HttpStatusCode.OK, allowed.status)
    }

    @Test
    fun `login succeeds with correct password and rejects wrong password`() = testApplication {
        setup()
        val email = "login-${UUID.randomUUID()}@example.com"
        val password = "password123"
        registerAndVerify(email, password)

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
        val session = registerAndVerify(email)

        val rotated = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RefreshRequest>(RefreshRequest(session.refreshToken)))
        }
        assertEquals(HttpStatusCode.OK, rotated.status)
        val pair = rotated.decode<AuthTokensResponse>()
        assertNotEquals(session.refreshToken, pair.refreshToken)
        assertNotEquals(session.accessToken, pair.accessToken)

        // Reusing the original refresh must fail — it has been revoked.
        val replay = client.post("/v1/auth/refresh") {
            contentType(ContentType.Application.Json)
            setBody(json.encodeToString<RefreshRequest>(RefreshRequest(session.refreshToken)))
        }
        assertEquals(HttpStatusCode.Unauthorized, replay.status)
    }

    @Test
    fun `logout-all invalidates every refresh token for the user`() = testApplication {
        setup()
        val email = "logout-${UUID.randomUUID()}@example.com"
        val session = registerAndVerify(email)

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
