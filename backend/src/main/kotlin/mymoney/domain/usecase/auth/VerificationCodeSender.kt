package mymoney.domain.usecase.auth

import kotlinx.datetime.Instant

/**
 * Delivers a confirmation code to the user. Kept as an interface so the
 * transport (SMTP, a transactional-email provider, a log line in dev) is a
 * deployment concern and never leaks into the auth use cases.
 */
interface VerificationCodeSender {
    suspend fun send(email: String, code: String, expiresAt: Instant)
}
