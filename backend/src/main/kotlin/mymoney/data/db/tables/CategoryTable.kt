package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object CategoryTable : Table("category") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val parentCategoryId = uuid("parent_category_id").references(id).nullable()
    val name = text("name")
    val type = text("type")               // 'INCOME' | 'EXPENSE'
    val isMandatory = bool("is_mandatory")
    val isSystem = bool("is_system")
    val icon = text("icon").nullable()
    val color = text("color").nullable()
    val isArchived = bool("is_archived")
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
