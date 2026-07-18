package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Category (категория) — two-level hierarchy: parent categories and their
 * children. Categories are typed as income or expense. System categories are
 * pre-seeded per family; user categories are created by the user.
 *
 * System categories cannot be physically deleted, only archived
 * (см. § 25.1 Bible, closing open question № 5).
 */
data class Category(
    val id: UUID,
    val familyId: UUID,
    val parentCategoryId: UUID? = null,
    val name: String,
    val type: CategoryType,
    val isMandatory: Boolean = false,
    val isSystem: Boolean = false,
    val icon: String? = null,
    val color: String? = null,
    val isArchived: Boolean = false,
    val isDeleted: Boolean = false,
    val createdAt: Instant,
    val updatedAt: Instant,
)
