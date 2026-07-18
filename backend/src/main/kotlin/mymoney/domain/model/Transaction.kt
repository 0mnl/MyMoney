package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Transaction (операция) — the atomic movement of money.
 *
 * Invariants (see SQL CHECK constraint in V1__initial_schema.sql):
 *   - type == TRANSFER  ⇒ targetAccountId != null AND targetAccountId != accountId
 *   - type != TRANSFER  ⇒ targetAccountId == null
 *
 * Amounts are BIGINT kopecks — see ADR-0002. Editing an existing transaction
 * must produce a TransactionHistory entry — see § 10.4 Bible and ADR-0004.
 */
data class Transaction(
    val id: UUID,
    val familyId: UUID,
    val accountId: UUID,
    val categoryId: UUID? = null,
    val type: TransactionType,
    val targetAccountId: UUID? = null,
    val amountKopecks: Long,
    val currency: String,        // MVP: always "RUB"
    val occurredAt: Instant,
    val comment: String? = null,
    val attachmentPhotoPath: String? = null,
    val createdBy: UUID,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean = false,
)

/**
 * Snapshot of a transaction taken before it was overwritten. Enables
 * conflict recovery under last-write-wins sync (see ADR-0004).
 * The snapshot is stored as raw JSON to survive schema evolution — a v2
 * transaction can still restore a v1 snapshot without a migration.
 */
data class TransactionHistoryEntry(
    val id: UUID,
    val transactionId: UUID,
    val snapshotJson: String,
    val changedBy: UUID,
    val changedAt: Instant,
)
