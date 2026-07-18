package mymoney.data.db.tables

import org.jetbrains.exposed.sql.Table
import org.jetbrains.exposed.sql.kotlin.datetime.timestamp

object AppUserTable : Table("app_user") {
    val id = uuid("id")
    val email = text("email")
    val passwordHash = text("password_hash")
    val createdAt = timestamp("created_at")
    val updatedAt = timestamp("updated_at")
    override val primaryKey = PrimaryKey(id)
}

object RefreshTokenTable : Table("refresh_token") {
    val id = uuid("id")
    val userId = uuid("user_id").references(AppUserTable.id)
    val tokenHash = text("token_hash")
    val expiresAt = timestamp("expires_at")
    val revokedAt = timestamp("revoked_at").nullable()
    val createdAt = timestamp("created_at")
    override val primaryKey = PrimaryKey(id)
}
