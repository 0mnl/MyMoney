package mymoney.domain.repository

import kotlinx.datetime.Instant
import java.util.UUID

interface RefreshTokenRepository {
    /**
     * Persists a new refresh token, keyed by its hash. Plaintext is never
     * stored (см. ADR-0005).
     */
    suspend fun create(
        id: UUID,
        userId: UUID,
        tokenHash: String,
        expiresAt: Instant,
    ): StoredRefreshToken

    suspend fun findByHash(tokenHash: String): StoredRefreshToken?

    /** Marks a single token as revoked (used during rotation). */
    suspend fun revoke(id: UUID)

    /** Revokes every non-revoked token for a user (logout-all endpoint). */
    suspend fun revokeAllForUser(userId: UUID)
}

data class StoredRefreshToken(
    val id: UUID,
    val userId: UUID,
    val tokenHash: String,
    val expiresAt: Instant,
    val revokedAt: Instant?,
    val createdAt: Instant,
)
