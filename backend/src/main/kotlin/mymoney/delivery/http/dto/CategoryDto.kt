package mymoney.delivery.http.dto

import kotlinx.datetime.Instant
import kotlinx.serialization.Serializable
import mymoney.domain.model.Category
import mymoney.domain.model.CategoryType

@Serializable
data class CategoryDto(
    val id: String,
    val familyId: String,
    val parentCategoryId: String?,
    val name: String,
    val type: String,               // INCOME | EXPENSE
    val isMandatory: Boolean,
    val isSystem: Boolean,
    val icon: String?,
    val color: String?,
    val isArchived: Boolean,
    val isDeleted: Boolean,
    val createdAt: Instant,
    val updatedAt: Instant,
)

@Serializable
data class CreateCategoryRequest(
    val id: String,                 // client-generated UUID (ADR-0005)
    val name: String,
    val type: String,               // INCOME | EXPENSE
    val parentCategoryId: String? = null,
    val isMandatory: Boolean = false,
    val icon: String? = null,
    val color: String? = null,
)

@Serializable
data class UpdateCategoryRequest(
    val name: String,
    val isMandatory: Boolean,
    val icon: String? = null,
    val color: String? = null,
)

@Serializable
data class ArchiveCategoryRequest(
    val archived: Boolean,
)

fun Category.toDto() = CategoryDto(
    id = id.toString(),
    familyId = familyId.toString(),
    parentCategoryId = parentCategoryId?.toString(),
    name = name,
    type = type.name,
    isMandatory = isMandatory,
    isSystem = isSystem,
    icon = icon,
    color = color,
    isArchived = isArchived,
    isDeleted = isDeleted,
    createdAt = createdAt,
    updatedAt = updatedAt,
)

fun parseCategoryType(raw: String): CategoryType = try {
    CategoryType.valueOf(raw.uppercase())
} catch (_: IllegalArgumentException) {
    throw mymoney.domain.errors.ValidationException(
        "invalid category type: expected INCOME or EXPENSE",
        mapOf("field" to "type", "value" to raw),
    )
}
