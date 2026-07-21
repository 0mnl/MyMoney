package mymoney.domain.model

import kotlinx.datetime.Instant

/**
 * A snapshot of everything the sync protocol can transfer between the client
 * and the server. All fields default to empty lists so callers can construct
 * partial pushes without ceremony.
 *
 * Formal wire contract lives in ADR-0005; see docs/api/openapi.yaml (WIP).
 */
data class SyncBundle(
    val accounts: List<Account> = emptyList(),
    val categories: List<Category> = emptyList(),
    val transactions: List<Transaction> = emptyList(),
    val budgets: List<Budget> = emptyList(),
    val goals: List<Goal> = emptyList(),
    val families: List<Family> = emptyList(),
    val familyMembers: List<FamilyMember> = emptyList(),
)

/**
 * Server response to a pull request: the changed rows plus the server's
 * "now" that the client stores as the next since-cursor.
 */
data class SyncPullResult(
    val serverTime: Instant,
    val bundle: SyncBundle,
)

data class SyncPushOutcome(
    val serverTime: Instant,
    val accepted: List<AcceptedRef>,
    val conflicts: List<SyncConflict>,
)

data class AcceptedRef(val table: String, val id: String)

/**
 * A push conflict: server's row is newer than the incoming one (LWW by
 * updated_at). The client is expected to store `serverVersion` in its history
 * before overwriting the local row (ADR-0004).
 */
data class SyncConflict(
    val table: String,
    val id: String,
    val serverBundle: SyncBundle,
)
