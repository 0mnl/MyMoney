package mymoney.domain.repository

import kotlinx.datetime.Instant
import mymoney.domain.model.AcceptedRef
import mymoney.domain.model.SyncBundle
import mymoney.domain.model.SyncConflict
import java.util.UUID

/**
 * Batch read/write operations for the sync protocol (see ADR-0005). Kept
 * separate from per-entity repositories so single-record CRUD stays trim.
 */
interface SyncRepository {
    /**
     * All entities of the family updated strictly after [since]. When
     * [since] is null the full snapshot is returned (initial pull).
     */
    suspend fun pullChanged(familyId: UUID, since: Instant?): SyncBundle

    /**
     * Applies an incoming bundle with last-write-wins semantics. Returns
     * which rows won and which were rejected because the server had a
     * newer copy (client must fold rejected rows into local history — see
     * ADR-0004).
     */
    suspend fun pushLww(familyId: UUID, bundle: SyncBundle): PushResult

    data class PushResult(val accepted: List<AcceptedRef>, val conflicts: List<SyncConflict>)
}
