package mymoney.test

import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.server.testing.ApplicationTestBuilder
import kotlinx.datetime.Instant
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import mymoney.delivery.http.dto.AuthSessionResponse
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.VerifyEmailRequest
import mymoney.domain.usecase.auth.VerificationCodeSender
import java.util.concurrent.ConcurrentHashMap

/**
 * Captures confirmation codes instead of mailing them, so integration tests
 * can finish the two-step registration flow. Injected via
 * `application { module(CapturingVerificationCodeSender) }`.
 */
object CapturingVerificationCodeSender : VerificationCodeSender {

    private val codes = ConcurrentHashMap<String, String>()

    override suspend fun send(email: String, code: String, expiresAt: Instant) {
        codes[email.lowercase()] = code
    }

    fun codeFor(email: String): String =
        codes[email.lowercase()] ?: error("No confirmation code was sent to $email")
}

private val authJson = Json { ignoreUnknownKeys = true }

/**
 * Registers a user and immediately confirms the emailed code, returning the
 * session. Registration alone no longer yields tokens — see RegisterUserUseCase.
 */
suspend fun ApplicationTestBuilder.registerAndVerify(
    email: String,
    password: String = "password123",
): AuthSessionResponse {
    client.post("/v1/auth/register") {
        contentType(ContentType.Application.Json)
        setBody(authJson.encodeToString(RegisterRequest(email, password)))
    }

    val verified = client.post("/v1/auth/verify-email") {
        contentType(ContentType.Application.Json)
        setBody(
            authJson.encodeToString(
                VerifyEmailRequest(email, CapturingVerificationCodeSender.codeFor(email)),
            ),
        )
    }
    return authJson.decodeFromString(verified.bodyAsText())
}
