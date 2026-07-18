package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.FamilyMemberTable
import mymoney.data.db.tables.FamilyTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Family
import mymoney.domain.model.FamilyMember
import mymoney.domain.model.FamilyRole
import mymoney.domain.repository.FamilyMemberRepository
import mymoney.domain.repository.FamilyRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class FamilyRepositoryImpl(private val db: Database) : FamilyRepository {

    override suspend fun create(family: Family): Family = dbQuery(db) {
        FamilyTable.insert {
            it[id] = family.id
            it[name] = family.name
            it[createdAt] = family.createdAt
            it[updatedAt] = family.updatedAt
            it[isDeleted] = family.isDeleted
        }
        family
    }

    override suspend fun findById(id: UUID): Family? = dbQuery(db) {
        FamilyTable.selectAll()
            .where { (FamilyTable.id eq id) and (FamilyTable.isDeleted eq false) }
            .singleOrNull()
            ?.toFamily()
    }

    override suspend fun rename(id: UUID, newName: String): Family = dbQuery(db) {
        val now = Clock.System.now()
        val updated = FamilyTable.update({ FamilyTable.id eq id }) {
            it[name] = newName
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("family", id.toString())
        FamilyTable.selectAll()
            .where { FamilyTable.id eq id }
            .single()
            .toFamily()
    }

    override suspend fun softDelete(id: UUID): Unit = dbQuery(db) {
        val now = Clock.System.now()
        val updated = FamilyTable.update({ FamilyTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("family", id.toString())
    }

    private fun ResultRow.toFamily() = Family(
        id = this[FamilyTable.id],
        name = this[FamilyTable.name],
        createdAt = this[FamilyTable.createdAt],
        updatedAt = this[FamilyTable.updatedAt],
        isDeleted = this[FamilyTable.isDeleted],
    )
}

class FamilyMemberRepositoryImpl(private val db: Database) : FamilyMemberRepository {

    override suspend fun add(member: FamilyMember): FamilyMember = dbQuery(db) {
        FamilyMemberTable.insert {
            it[id] = member.id
            it[familyId] = member.familyId
            it[userId] = member.userId
            it[role] = member.role.name
            it[joinedAt] = member.joinedAt
            it[isDeleted] = member.isDeleted
        }
        member
    }

    override suspend fun findByUserAndFamily(userId: UUID, familyId: UUID): FamilyMember? = dbQuery(db) {
        FamilyMemberTable.selectAll()
            .where {
                (FamilyMemberTable.userId eq userId) and
                    (FamilyMemberTable.familyId eq familyId) and
                    (FamilyMemberTable.isDeleted eq false)
            }
            .singleOrNull()
            ?.toMember()
    }

    override suspend fun listByUser(userId: UUID): List<FamilyMember> = dbQuery(db) {
        FamilyMemberTable.selectAll()
            .where { (FamilyMemberTable.userId eq userId) and (FamilyMemberTable.isDeleted eq false) }
            .map { it.toMember() }
    }

    override suspend fun listByFamily(familyId: UUID): List<FamilyMember> = dbQuery(db) {
        FamilyMemberTable.selectAll()
            .where { (FamilyMemberTable.familyId eq familyId) and (FamilyMemberTable.isDeleted eq false) }
            .map { it.toMember() }
    }

    override suspend fun updateRole(memberId: UUID, role: FamilyRole): FamilyMember = dbQuery(db) {
        val updated = FamilyMemberTable.update({ FamilyMemberTable.id eq memberId }) {
            it[FamilyMemberTable.role] = role.name
        }
        if (updated == 0) throw NotFoundException("family_member", memberId.toString())
        FamilyMemberTable.selectAll()
            .where { FamilyMemberTable.id eq memberId }
            .single()
            .toMember()
    }

    override suspend fun softDelete(memberId: UUID): Unit = dbQuery(db) {
        val updated = FamilyMemberTable.update({ FamilyMemberTable.id eq memberId }) {
            it[isDeleted] = true
        }
        if (updated == 0) throw NotFoundException("family_member", memberId.toString())
    }

    private fun ResultRow.toMember() = FamilyMember(
        id = this[FamilyMemberTable.id],
        familyId = this[FamilyMemberTable.familyId],
        userId = this[FamilyMemberTable.userId],
        role = FamilyRole.valueOf(this[FamilyMemberTable.role]),
        joinedAt = this[FamilyMemberTable.joinedAt],
        isDeleted = this[FamilyMemberTable.isDeleted],
    )
}
