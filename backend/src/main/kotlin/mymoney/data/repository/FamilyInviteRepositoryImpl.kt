package mymoney.data.repository

import kotlinx.datetime.Instant
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.FamilyInviteTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.FamilyInvite
import mymoney.domain.repository.FamilyInviteRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class FamilyInviteRepositoryImpl(private val db: Database) : FamilyInviteRepository {

    override suspend fun create(invite: FamilyInvite): FamilyInvite = dbQuery(db) {
        FamilyInviteTable.insert {
            it[id] = invite.id
            it[familyId] = invite.familyId
            it[invitedBy] = invite.invitedBy
            it[invitedEmail] = invite.invitedEmail
            it[inviteToken] = invite.inviteToken
            it[expiresAt] = invite.expiresAt
            it[acceptedAt] = invite.acceptedAt
            it[acceptedBy] = invite.acceptedBy
            it[createdAt] = invite.createdAt
        }
        invite
    }

    override suspend fun findByToken(token: String): FamilyInvite? = dbQuery(db) {
        FamilyInviteTable.selectAll()
            .where { FamilyInviteTable.inviteToken eq token }
            .singleOrNull()
            ?.toInvite()
    }

    override suspend fun listPendingByFamily(familyId: UUID): List<FamilyInvite> = dbQuery(db) {
        FamilyInviteTable.selectAll()
            .where {
                (FamilyInviteTable.familyId eq familyId) and
                    (FamilyInviteTable.acceptedAt.isNull())
            }
            .map { it.toInvite() }
    }

    override suspend fun markAccepted(id: UUID, acceptedBy: UUID, acceptedAt: Instant): FamilyInvite = dbQuery(db) {
        val updated = FamilyInviteTable.update({
            (FamilyInviteTable.id eq id) and (FamilyInviteTable.acceptedAt.isNull())
        }) {
            it[FamilyInviteTable.acceptedAt] = acceptedAt
            it[FamilyInviteTable.acceptedBy] = acceptedBy
        }
        if (updated == 0) throw NotFoundException("family_invite", id.toString())
        FamilyInviteTable.selectAll()
            .where { FamilyInviteTable.id eq id }
            .single()
            .toInvite()
    }

    private fun ResultRow.toInvite() = FamilyInvite(
        id = this[FamilyInviteTable.id],
        familyId = this[FamilyInviteTable.familyId],
        invitedBy = this[FamilyInviteTable.invitedBy],
        invitedEmail = this[FamilyInviteTable.invitedEmail],
        inviteToken = this[FamilyInviteTable.inviteToken],
        expiresAt = this[FamilyInviteTable.expiresAt],
        acceptedAt = this[FamilyInviteTable.acceptedAt],
        acceptedBy = this[FamilyInviteTable.acceptedBy],
        createdAt = this[FamilyInviteTable.createdAt],
    )
}
