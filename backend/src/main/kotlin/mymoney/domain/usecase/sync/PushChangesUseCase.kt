package mymoney.domain.usecase.sync

import kotlinx.datetime.Clock
import mymoney.domain.model.SyncBundle
import mymoney.domain.model.SyncPushOutcome
import mymoney.domain.repository.SyncRepository
import java.util.UUID

class PushChangesUseCase(
    private val sync: SyncRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(familyId: UUID, bundle: SyncBundle): SyncPushOutcome {
        val result = sync.pushLww(familyId, bundle)
        return SyncPushOutcome(
            serverTime = clock.now(),
            accepted = result.accepted,
            conflicts = result.conflicts,
        )
    }
}
