package mymoney.data.repository

import kotlinx.datetime.Clock
import mymoney.data.db.dbQuery
import mymoney.data.db.tables.SubscriptionTable
import mymoney.domain.errors.NotFoundException
import mymoney.domain.model.Subscription
import mymoney.domain.model.SubscriptionPeriod
import mymoney.domain.repository.SubscriptionRepository
import org.jetbrains.exposed.sql.Database
import org.jetbrains.exposed.sql.ResultRow
import org.jetbrains.exposed.sql.SortOrder
import org.jetbrains.exposed.sql.and
import org.jetbrains.exposed.sql.insert
import org.jetbrains.exposed.sql.selectAll
import org.jetbrains.exposed.sql.update
import java.util.UUID

class SubscriptionRepositoryImpl(private val db: Database) : SubscriptionRepository {

    override suspend fun create(subscription: Subscription): Subscription = dbQuery(db) {
        SubscriptionTable.insert {
            it[id] = subscription.id
            it[familyId] = subscription.familyId
            it[name] = subscription.name
            it[amount] = subscription.amountKopecks
            it[billingPeriod] = subscription.billingPeriod.name
            it[nextChargeDate] = subscription.nextChargeDate
            it[categoryId] = subscription.categoryId
            it[isDeleted] = subscription.isDeleted
            it[createdAt] = subscription.createdAt
            it[updatedAt] = subscription.updatedAt
        }
        subscription
    }

    override suspend fun findById(id: UUID): Subscription? = dbQuery(db) {
        SubscriptionTable.selectAll().where { SubscriptionTable.id eq id }.singleOrNull()?.toSubscription()
    }

    override suspend fun list(familyId: UUID): List<Subscription> = dbQuery(db) {
        SubscriptionTable.selectAll()
            .where { (SubscriptionTable.familyId eq familyId) and (SubscriptionTable.isDeleted eq false) }
            .orderBy(SubscriptionTable.nextChargeDate to SortOrder.ASC)
            .map { it.toSubscription() }
    }

    override suspend fun update(subscription: Subscription): Subscription = dbQuery(db) {
        val updated = SubscriptionTable.update({ SubscriptionTable.id eq subscription.id }) {
            it[name] = subscription.name
            it[amount] = subscription.amountKopecks
            it[billingPeriod] = subscription.billingPeriod.name
            it[nextChargeDate] = subscription.nextChargeDate
            it[categoryId] = subscription.categoryId
            it[isDeleted] = subscription.isDeleted
            it[updatedAt] = subscription.updatedAt
        }
        if (updated == 0) throw NotFoundException("subscription", subscription.id.toString())
        subscription
    }

    override suspend fun softDelete(id: UUID): Unit = dbQuery(db) {
        val now = Clock.System.now()
        val updated = SubscriptionTable.update({ SubscriptionTable.id eq id }) {
            it[isDeleted] = true
            it[updatedAt] = now
        }
        if (updated == 0) throw NotFoundException("subscription", id.toString())
    }

    private fun ResultRow.toSubscription() = Subscription(
        id = this[SubscriptionTable.id],
        familyId = this[SubscriptionTable.familyId],
        name = this[SubscriptionTable.name],
        amountKopecks = this[SubscriptionTable.amount],
        billingPeriod = SubscriptionPeriod.valueOf(this[SubscriptionTable.billingPeriod]),
        nextChargeDate = this[SubscriptionTable.nextChargeDate],
        categoryId = this[SubscriptionTable.categoryId],
        isDeleted = this[SubscriptionTable.isDeleted],
        createdAt = this[SubscriptionTable.createdAt],
        updatedAt = this[SubscriptionTable.updatedAt],
    )
}
