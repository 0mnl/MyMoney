package mymoney.domain.usecase.category

import mymoney.domain.model.Category
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

class GetCategoryUseCase(private val categories: CategoryRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Category = categories.getOwned(ctx, id)
}
