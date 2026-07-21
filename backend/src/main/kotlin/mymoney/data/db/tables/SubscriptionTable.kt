package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object SubscriptionTable : Table("subscription") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val name = text("name")
    val amount = long("amount")                            // kopecks
    val billingPeriod = text("billing_period")             // 'WEEKLY' | 'MONTHLY' | 'YEARLY'
    val nextChargeDate = timestamp("next_charge_date")
    val categoryId = uuid("category_id").references(CategoryTable.id).nullable()
    val isDeleted = bool("is_deleted")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}
