package mymoney.domain.usecase.auth

import kotlinx.datetime.Instant
import java.util.UUID

/** Successful outcome of register / login. */
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
