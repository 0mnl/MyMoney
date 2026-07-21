package mymoney.domain.repository

import mymoney.domain.model.Subscription
import java.util.UUID

interface SubscriptionRepository {
    suspend fun create(subscription: Subscription): Subscription
    suspend fun findById(id: UUID): Subscription?
    suspend fun list(familyId: UUID): List<Subscription>
    suspend fun update(subscription: Subscription): Subscription
    suspend fun softDelete(id: UUID)
}
