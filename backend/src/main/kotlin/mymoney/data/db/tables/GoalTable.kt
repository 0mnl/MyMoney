package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object GoalTable : Table("goal") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val name = text("name")
    val targetAmount = long("target_amount")
    val currentAmount = long("current_amount")
    val targetDate = timestamp("target_date").nullable()
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
