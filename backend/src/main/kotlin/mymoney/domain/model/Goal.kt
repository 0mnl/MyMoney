package mymoney.domain.model

import kotlinx.datetime.Instant
import java.util.UUID

/**
 * Goal — накопительная цель. currentAmountKopecks меняется отдельными
 * usecase'ами deposit/withdraw, чтобы не путать с прямым редактированием.
 */
data class Goal(
    val id: UUID,
    val familyId: UUID,
    val name: String,
    val targetAmountKopecks: Long,
    val currentAmountKopecks: Long,
    val targetDate: Instant?,
    val createdAt: Instant,
    val updatedAt: Instant,
    val isDeleted: Boolean = false,
) {
    val isCompleted: Boolean get() = currentAmountKopecks >= targetAmountKopecks
    val progressPercent: Int
        get() {
            if (targetAmountKopecks <= 0L) return 0
            val raw = (currentAmountKopecks * 100 / targetAmountKopecks).toInt()
            return raw.coerceIn(0, 100)
        }
}
