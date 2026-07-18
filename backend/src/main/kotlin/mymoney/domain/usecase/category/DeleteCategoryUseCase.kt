package mymoney.domain.usecase.category

import mymoney.domain.errors.ConflictException
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

/**
 * Soft-deletes a user category. Refuses to touch:
 *   - system categories → SYSTEM_CATEGORY_UNDELETABLE (Bible § 25.1, open q. 5)
 *   - categories with active children → CATEGORY_HAS_CHILDREN
 *
 * Transactions that reference the category keep their FK — filtering hides
 * them in category lists but they remain queryable by account/date.
 */
class DeleteCategoryUseCase(
    private val categories: CategoryRepository,
) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        val category = categories.getOwned(ctx, id)
        if (category.isSystem) {
            throw ConflictException(
                code = "SYSTEM_CATEGORY_UNDELETABLE",
                msg = "System categories cannot be deleted, only archived",
            )
        }
        if (categories.hasActiveChildren(id)) {
            throw ConflictException(
                code = "CATEGORY_HAS_CHILDREN",
                msg = "Category has active children — remove them first",
            )
        }
        categories.softDelete(id)
    }
}
