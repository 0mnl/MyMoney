package mymoney.domain.usecase.sync

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.model.SyncPullResult
import mymoney.domain.repository.SyncRepository
import java.util.UUID

class PullChangesUseCase(
    private val sync: SyncRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(familyId: UUID, since: Instant?): SyncPullResult {
        val bundle = sync.pullChanged(familyId, since)
        return SyncPullResult(serverTime = clock.now(), bundle = bundle)
    }
}
