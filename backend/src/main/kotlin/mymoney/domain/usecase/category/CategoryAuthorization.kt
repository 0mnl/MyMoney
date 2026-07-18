package mymoney.domain.usecase.category

import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Category
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

internal suspend fun CategoryRepository.getOwned(ctx: UserContext, id: UUID): Category {
    val category = findById(id) ?: throw NotFoundException("category", id.toString())
    if (category.familyId != ctx.familyId) throw ForbiddenException("category belongs to another family")
    if (category.isDeleted) throw NotFoundException("category", id.toString())
    return category
}
