package mymoney.domain.usecase.category

import kotlinx.datetime.Clock
import mymoney.domain.model.Category
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

/**
 * Archives or unarchives a category. Archiving is the recommended way to
 * retire a system category (per Bible § 25.1 — system rows cannot be
 * physically deleted).
 */
class ArchiveCategoryUseCase(
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(ctx: UserContext, id: UUID, archived: Boolean): Category {
        val existing = categories.getOwned(ctx, id)
        if (existing.isArchived == archived) return existing
        return categories.update(existing.copy(isArchived = archived, updatedAt = clock.now()))
    }
}
