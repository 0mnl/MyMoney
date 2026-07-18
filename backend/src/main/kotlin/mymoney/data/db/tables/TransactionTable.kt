package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.json.jsonb
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement

/**
 * NB: SQL table is named `transaction`. The Kotlin object is `TransactionTable`
 * (not `Transaction`) to avoid clashing with the Exposed DSL `transaction { }`
 * function that we call very often in repository code.
 */
object TransactionTable : Table("transaction") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val accountId = uuid("account_id").references(AccountTable.id)
    val categoryId = uuid("category_id").references(CategoryTable.id).nullable()
    val type = text("type")               // 'INCOME' | 'EXPENSE' | 'TRANSFER'
    val targetAccountId = uuid("target_account_id").references(AccountTable.id).nullable()
    val amount = long("amount")           // kopecks
    val currency = text("currency")
    val occurredAt = timestamp("occurred_at")
    val comment = text("comment").nullable()
    val attachmentPhotoPath = text("attachment_photo_path").nullable()
    val createdBy = uuid("created_by").references(AppUserTable.id)
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    val isDeleted = bool("is_deleted")
    override val primaryKey = PrimaryKey(id)
}

object TransactionHistoryTable : Table("transaction_history") {
    val id = uuid("id")
    val transactionId = uuid("transaction_id").references(TransactionTable.id)
    // Stored as JSONB; kept schema-agnostic (JsonElement) so v1 snapshots can be
    // read after the Transaction model evolves. Serialization happens in the repo.
    val snapshotJson = jsonb<JsonElement>("snapshot_json", Json)
    val changedBy = uuid("changed_by").references(AppUserTable.id)
    val changedAt = timestamp("changed_at")
    override val primaryKey = PrimaryKey(id)
}
