package mymoney.domain.usecase.category

import kotlinx.datetime.Clock
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Category
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

/**
 * Updates mutable fields of a category. Immutable via this use case:
 * `type`, `parentCategoryId`, `isSystem`. Reassigning parent or type is
 * excluded because it would invalidate the type-consistency of already
 * recorded transactions; a follow-up ADR will decide when (if) to allow it.
 */
class UpdateCategoryUseCase(
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        isMandatory: Boolean,
        icon: String?,
        color: String?,
    ): Category {
        if (name.isBlank()) {
            throw ValidationException("name must not be blank", mapOf("field" to "name"))
        }
        val existing = categories.getOwned(ctx, id)
        val updated = existing.copy(
            name = name.trim(),
            isMandatory = isMandatory,
            icon = icon,
            color = color,
            updatedAt = clock.now(),
        )
        return categories.update(updated)
    }
}
