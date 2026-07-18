package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object BudgetTable : Table("budget") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val periodType = text("period_type")            // 'WEEK' | 'MONTH' | 'YEAR'
    val periodStart = timestamp("period_start")
    val categoryId = uuid("category_id").references(CategoryTable.id)
    val plannedAmount = long("planned_amount")      // kopecks
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
