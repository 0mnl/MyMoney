package mymoney.domain.usecase.category

import kotlinx.datetime.Clock
import mymoney.domain.model.Category
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

/**
 * Populates a freshly created family with the default catalog of system
 * categories. Invoked from RegisterUserUseCase after the family is persisted.
 */
class SeedSystemCategoriesUseCase(
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    suspend fun execute(familyId: UUID) {
        val now = clock.now()
        SystemCategoriesCatalog.defaults.forEach { def ->
            categories.create(
                Category(
                    id = UUID.randomUUID(),
                    familyId = familyId,
                    parentCategoryId = null,
                    name = def.name,
                    type = def.type,
                    isMandatory = def.isMandatory,
                    isSystem = true,
                    icon = def.icon,
                    color = null,
                    createdAt = now,
                    updatedAt = now,
                ),
            )
        }
    }
}
