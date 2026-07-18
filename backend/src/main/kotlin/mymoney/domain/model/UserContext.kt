package mymoney.domain.model

import java.util.UUID

/**
 * The identity carried through a use case call. Populated by the delivery
 * layer from the verified JWT — the domain layer never touches HTTP.
 * Every family-scoped use case takes this to enforce authorization.
 */
data class UserContext(
    val userId: UUID,
    val familyId: UUID,
)
