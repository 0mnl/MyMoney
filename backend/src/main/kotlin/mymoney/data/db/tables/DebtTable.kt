package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object DebtTable : Table("debt") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val counterpartyName = text("counterparty_name")
    val direction = text("direction")            // 'I_OWE' | 'OWED_TO_ME'
    val amount = long("amount")                  // kopecks
    val dueDate = timestamp("due_date").nullable()
    val status = text("status")                  // 'OPEN' | 'CLOSED'
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
