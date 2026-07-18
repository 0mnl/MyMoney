package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object AccountTable : Table("account") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val name = text("name")
    val type = text("type")
    val currency = text("currency")
    val initialBalance = long("initial_balance")            // kopecks
    val isArchived = bool("is_archived")
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
