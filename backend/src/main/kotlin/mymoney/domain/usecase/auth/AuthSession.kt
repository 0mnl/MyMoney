package mymoney.domain.usecase.auth

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Outcome of /auth/register. Deliberately carries no tokens: the account exists
 * but stays unusable until the emailed code is confirmed, at which point
 * [VerifyEmailUseCase] returns a real [AuthSession].
 */
data class PendingRegistration(
    val email: String,
    val codeExpiresAt: Instant,
    val resendAvailableAt: Instant,
)

/** Successful outcome of login / email confirmation. */
data class AuthSession(
    val userId: UUID,
    val familyId: UUID,
    val tokens: AuthTokens,
)

/** Access + refresh pair returned to the client. */
data class AuthTokens(
    val accessToken: String,
    val refreshToken: String,
    val accessTokenExpiresAt: Instant,
    val refreshTokenExpiresAt: Instant,
)
