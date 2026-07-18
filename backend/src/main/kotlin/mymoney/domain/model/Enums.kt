package mymoney.domain.model

enum class TransactionType { INCOME, EXPENSE, TRANSFER }

enum class CategoryType { INCOME, EXPENSE }

enum class FamilyRole { OWNER, MEMBER }

enum class BudgetPeriodType { WEEK, MONTH, YEAR }

enum class DebtDirection { I_OWE, OWED_TO_ME }

enum class DebtStatus { OPEN, CLOSED }
