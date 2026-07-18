package mymoney.domain.usecase.category

import kotlinx.datetime.Clock
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType
import mymoney.domain.model.UserContext
import mymoney.domain.repository.CategoryRepository
import java.util.UUID

class CreateCategoryUseCase(
    private val categories: CategoryRepository,
    private val clock: Clock = Clock.System,
) {
    /**
     * Creates a user category. System categories are seeded once at family
     * creation by SeedSystemCategoriesUseCase and cannot be created via
     * this path — `isSystem` is always `false`.
     *
     * If [parentCategoryId] is supplied, the parent must belong to the same
     * family, match [type], and itself have no parent (Bible § 6.3: strictly
     * two levels).
     */
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        name: String,
        type: CategoryType,
        parentCategoryId: UUID? = null,
        isMandatory: Boolean = false,
        icon: String? = null,
        color: String? = null,
    ): Category {
        if (name.isBlank()) {
            throw ValidationException("name must not be blank", mapOf("field" to "name"))
        }

        categories.findById(id)?.let {
            throw ConflictException("CATEGORY_ID_TAKEN", "Category with this id already exists")
        }

        if (parentCategoryId != null) {
            val parent = categories.findById(parentCategoryId)
                ?: throw ValidationException(
                    "parent category not found",
                    mapOf("field" to "parentCategoryId"),
                )
            if (parent.familyId != ctx.familyId) {
                throw ForbiddenException("parent category belongs to another family")
            }
            if (parent.isDeleted) {
                throw ValidationException(
                    "parent category is deleted",
                    mapOf("field" to "parentCategoryId"),
                )
            }
            if (parent.type != type) {
                throw ValidationException(
                    "parent category has different type",
                    mapOf("field" to "type", "parentType" to parent.type.name),
                )
            }
            if (parent.parentCategoryId != null) {
                throw ValidationException(
                    "categories can be nested only two levels deep",
                    mapOf("field" to "parentCategoryId"),
                )
            }
        }

        val now = clock.now()
        return categories.create(
            Category(
                id = id,
                familyId = ctx.familyId,
                parentCategoryId = parentCategoryId,
                name = name.trim(),
                type = type,
                isMandatory = isMandatory,
                isSystem = false,
                icon = icon,
                color = color,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}
