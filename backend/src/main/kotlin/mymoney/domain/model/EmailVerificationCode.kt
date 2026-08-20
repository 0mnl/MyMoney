package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * A confirmation code issued after registration. [codeHash] is the SHA-256 of
 * the 6-digit code that was emailed — the plaintext is never persisted.
 *
 * A code is usable while `consumedAt == null`, `expiresAt` is in the future and
 * [attempts] is below the brute-force ceiling.
 */
data class EmailVerificationCode(
    val id: UUID,
    val userId: UUID,
    val codeHash: String,
    val expiresAt: Instant,
    val consumedAt: Instant?,
    val attempts: Int,
    val createdAt: Instant,
)
