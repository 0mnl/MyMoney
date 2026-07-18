package mymoney.domain.usecase.category

import mymoney.domain.model.CategoryType

/**
 * Default set of system categories seeded into every new family on
 * registration. Labels are Russian (target audience — see § 3 Bible).
 * Icons are Material Symbols names — mobile presentation layer decides
 * how to render them.
 *
 * Users can rename, re-icon, archive, or add children under system
 * categories, but system rows cannot be physically deleted
 * (см. § 25.1 Bible, closes open question № 5).
 */
data class SystemCategoryDef(
    val name: String,
    val type: CategoryType,
    val icon: String,
    val isMandatory: Boolean = false,
)

object SystemCategoriesCatalog {
    val defaults: List<SystemCategoryDef> = listOf(
        // Income
        SystemCategoryDef("Зарплата", CategoryType.INCOME, icon = "work"),
        SystemCategoryDef("Подработка", CategoryType.INCOME, icon = "attach_money"),
        SystemCategoryDef("Подарки", CategoryType.INCOME, icon = "redeem"),
        SystemCategoryDef("Прочие поступления", CategoryType.INCOME, icon = "trending_up"),

        // Expense — mandatory (used by the "смета" / mandatory-plan view; see open question № 7)
        SystemCategoryDef("Продукты", CategoryType.EXPENSE, icon = "shopping_cart", isMandatory = true),
        SystemCategoryDef("Жильё", CategoryType.EXPENSE, icon = "home", isMandatory = true),
        SystemCategoryDef("Коммунальные услуги", CategoryType.EXPENSE, icon = "bolt", isMandatory = true),
        SystemCategoryDef("Связь и интернет", CategoryType.EXPENSE, icon = "wifi", isMandatory = true),
        SystemCategoryDef("Транспорт", CategoryType.EXPENSE, icon = "directions_bus", isMandatory = true),

        // Expense — regular
        SystemCategoryDef("Кафе и рестораны", CategoryType.EXPENSE, icon = "restaurant"),
        SystemCategoryDef("Здоровье", CategoryType.EXPENSE, icon = "healing"),
        SystemCategoryDef("Одежда", CategoryType.EXPENSE, icon = "checkroom"),
        SystemCategoryDef("Развлечения", CategoryType.EXPENSE, icon = "sports_esports"),
        SystemCategoryDef("Образование", CategoryType.EXPENSE, icon = "school"),
        SystemCategoryDef("Прочие расходы", CategoryType.EXPENSE, icon = "more_horiz"),
    )
}
