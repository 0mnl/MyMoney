package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Domain view of an application user. The password hash lives only in the
 * data layer and never leaves the repository — see UserRepository.
 */
data class User(
    val id: UUID,
    val email: String,
    val createdAt: Instant,
    val updatedAt: Instant,
)
