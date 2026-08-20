package mymoney.domain.usecase.auth

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.TooManyRequestsException
import mymoney.domain.repository.UserRepository

/**
 * Re-issues a confirmation code for an address that is registered but not yet
 * confirmed.
 *
 * Unknown addresses return a normal [PendingRegistration] rather than an error:
 * this endpoint is unauthenticated, so a distinguishable response would turn it
 * into an account-enumeration oracle. Nothing is sent in that case.
 */
class ResendVerificationCodeUseCase(
    private val users: UserRepository,
    private val issuer: VerificationCodeIssuer,
    private val clock: Clock = Clock.System,
) {

    suspend fun execute(rawEmail: String): PendingRegistration {
        val email = normalizeEmail(rawEmail)
        val now = clock.now()
        val user = users.findByEmail(email)
            ?: return PendingRegistration(
                email = email,
                codeExpiresAt = now.plus(VerificationCodeIssuer.CODE_TTL),
                resendAvailableAt = now.plus(VerificationCodeIssuer.RESEND_COOLDOWN),
            )

        if (users.isEmailVerified(user.id)) {
            throw ConflictException(
                code = "EMAIL_ALREADY_VERIFIED",
                msg = "Email is already confirmed",
                details = mapOf("email" to email),
            )
        }

        val result = issuer.issue(user.id, email)
        if (!result.sent) {
            // Unlike registration, an explicit "send it again" that quietly
            // sends nothing would be a lie — report the wait instead.
            val retryAfter = (result.resendAvailableAt - now).inWholeSeconds.coerceAtLeast(1)
            throw TooManyRequestsException(
                msg = "Confirmation code was just sent — wait before requesting another",
                code = "RESEND_COOLDOWN",
                details = mapOf("retryAfterSeconds" to retryAfter.toString()),
            )
        }
        return result.toPending(email)
    }
}
