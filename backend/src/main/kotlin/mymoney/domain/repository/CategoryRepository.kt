package mymoney.domain.repository

import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import java.util.UUID

interface CategoryRepository {
    suspend fun create(category: Category): Category
    suspend fun findById(id: UUID): Category?
    suspend fun listByFamily(
        familyId: UUID,
        type: CategoryType? = null,
        includeArchived: Boolean = false,
    ): List<Category>
    suspend fun update(category: Category): Category

    /**
     * Soft-deletes a category. Callers must ensure the category is not a
     * system category — system categories can only be archived
     * (см. § 25.1 Bible, open question № 5). The repository does not enforce
     * this rule; the use case does.
     */
    suspend fun softDelete(id: UUID)
}
