package mymoney.domain.usecase.debt

import kotlinx.datetime.Clock
import kotlinx.datetime.Instant
import mymoney.domain.errors.ConflictException
import mymoney.domain.errors.ForbiddenException
import mymoney.domain.errors.NotFoundException
import mymoney.domain.errors.ValidationException
import mymoney.domain.model.Debt
import mymoney.domain.model.DebtDirection
import mymoney.domain.model.DebtStatus
import mymoney.domain.model.UserContext
import mymoney.domain.repository.DebtRepository
import java.util.UUID

class CreateDebtUseCase(private val repo: DebtRepository, private val clock: Clock = Clock.System) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        counterpartyName: String,
        direction: DebtDirection,
        amountKopecks: Long,
        interestRate: Double = 0.0,
        dueDate: Instant?,
    ): Debt {
        if (counterpartyName.isBlank()) throw ValidationException("counterpartyName is required")
        if (amountKopecks <= 0) throw ValidationException("amountKopecks must be > 0")
        if (interestRate < 0.0 || interestRate > 999.99) {
            throw ValidationException("interestRate out of range (0..999.99)")
        }
        repo.findById(id)?.let { throw ConflictException("DEBT_ID_TAKEN", "Debt id already exists") }
        val now = clock.now()
        return repo.create(
            Debt(
                id = id,
                familyId = ctx.familyId,
                counterpartyName = counterpartyName.trim(),
                direction = direction,
                amountKopecks = amountKopecks,
                interestRate = interestRate,
                dueDate = dueDate,
                status = DebtStatus.OPEN,
                createdAt = now,
                updatedAt = now,
            ),
        )
    }
}

class ListDebtsUseCase(private val repo: DebtRepository) {
    suspend fun execute(ctx: UserContext, openOnly: Boolean): List<Debt> =
        repo.list(ctx.familyId, openOnly)
}

class GetDebtUseCase(private val repo: DebtRepository) {
    suspend fun execute(ctx: UserContext, id: UUID): Debt {
        val d = repo.findById(id) ?: throw NotFoundException("debt", id.toString())
        if (d.familyId != ctx.familyId) throw ForbiddenException("Debt belongs to another family")
        return d
    }
}

class UpdateDebtUseCase(private val repo: DebtRepository, private val clock: Clock = Clock.System) {
    suspend fun execute(
        ctx: UserContext,
        id: UUID,
        counterpartyName: String,
        amountKopecks: Long,
        interestRate: Double = 0.0,
        dueDate: Instant?,
        status: DebtStatus,
    ): Debt {
        val existing = repo.findById(id) ?: throw NotFoundException("debt", id.toString())
        if (existing.familyId != ctx.familyId) throw ForbiddenException("Debt belongs to another family")
        if (counterpartyName.isBlank()) throw ValidationException("counterpartyName is required")
        if (amountKopecks <= 0) throw ValidationException("amountKopecks must be > 0")
        if (interestRate < 0.0 || interestRate > 999.99) {
            throw ValidationException("interestRate out of range (0..999.99)")
        }
        return repo.update(
            existing.copy(
                counterpartyName = counterpartyName.trim(),
                amountKopecks = amountKopecks,
                interestRate = interestRate,
                dueDate = dueDate,
                status = status,
                updatedAt = clock.now(),
            ),
        )
    }
}

class DeleteDebtUseCase(private val repo: DebtRepository) {
    suspend fun execute(ctx: UserContext, id: UUID) {
        val existing = repo.findById(id) ?: throw NotFoundException("debt", id.toString())
        if (existing.familyId != ctx.familyId) throw ForbiddenException("Debt belongs to another family")
        repo.softDelete(id)
    }
}
