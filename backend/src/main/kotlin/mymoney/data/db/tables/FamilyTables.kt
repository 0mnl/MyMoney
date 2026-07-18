package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

/**
 * Exposed table objects mirror V1__initial_schema.sql exactly (see ADR-0003:
 * DDL is the source of truth; these objects describe what already exists).
 * Any drift is a bug in the table object, not in the SQL.
 */
object FamilyTable : Table("family") {
    val id = uuid("id")
    val name = text("name")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    val isDeleted = bool("is_deleted")
    override val primaryKey = PrimaryKey(id)
}

object FamilyMemberTable : Table("family_member") {
    val id = uuid("id")
    val familyId = uuid("family_id").references(FamilyTable.id)
    val userId = uuid("user_id").references(AppUserTable.id)
    val role = text("role")            // 'OWNER' | 'MEMBER'
    val joinedAt = timestamp("joined_at")
    val isDeleted = bool("is_deleted")
    override val primaryKey = PrimaryKey(id)
}
