package mymoney.domain.usecase.category

import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository

class ListCategoriesUseCase(private val categories: CategoryRepository) {
    suspend fun execute(
        ctx: UserContext,
        type: CategoryType? = null,
        includeArchived: Boolean = false,
    ): List<Category> = categories.listByFamily(ctx.familyId, type, includeArchived)
}
