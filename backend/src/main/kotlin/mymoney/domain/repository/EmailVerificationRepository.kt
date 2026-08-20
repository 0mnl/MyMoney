package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.EmailVerificationCode
import java.util.UUID

interface EmailVerificationRepository {
    suspend fun create(
        id: UUID,
        userId: UUID,
        codeHash: String,
        expiresAt: Instant,
        createdAt: Instant,
    ): EmailVerificationCode

    /** Newest code for the user that has not been consumed yet, or null. */
    suspend fun findActiveByUser(userId: UUID): EmailVerificationCode?

    /** Bumps the failed-attempt counter and returns the new value. */
    suspend fun incrementAttempts(id: UUID): Int

    suspend fun markConsumed(id: UUID, at: Instant)

    /** Burns every outstanding code for the user — called before issuing a new one. */
    suspend fun consumeAllForUser(userId: UUID, at: Instant)
}
