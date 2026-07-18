package mymoney.domain.security

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Issues and verifies auth tokens.
 *
 * Access tokens are short-lived JWTs (see ADR-0005). They carry `sub` (user id)
 * and `family_id` claims and are validated by Ktor's Authentication plugin.
 *
 * Refresh tokens are opaque bearer secrets — random bytes, never JWTs. They are
 * stored on the server as a hash so a DB dump can't be used to forge sessions.
 */
interface TokenService {
    fun issueAccessToken(userId: UUID, familyId: UUID): IssuedAccessToken

    /** Generates a fresh refresh token pair: the plaintext the client keeps, and the hash we persist. */
    fun issueRefreshToken(): IssuedRefreshToken

    /** Computes the deterministic hash used to look up an incoming refresh token. */
    fun hashRefreshToken(plain: String): String
}

data class IssuedAccessToken(
    val token: String,
    val expiresAt: Instant,
)

data class IssuedRefreshToken(
    val plaintext: String,
    val hash: String,
    val expiresAt: Instant,
)
