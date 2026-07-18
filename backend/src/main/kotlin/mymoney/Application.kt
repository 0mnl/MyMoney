package mymoney

import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.application.log
import io.ktor.server.netty.EngineMain
import io.ktor.server.routing.route
import io.ktor.server.routing.routing
import mymoney.config.loadAppConfig
import mymoney.data.db.DatabaseFactory
import mymoney.delivery.http.plugins.configureHttp
import mymoney.delivery.http.routes.accountRoutes
import mymoney.delivery.http.routes.authRoutes
import mymoney.delivery.http.routes.budgetRoutes
import mymoney.delivery.http.routes.categoryRoutes
import mymoney.delivery.http.routes.goalRoutes
import mymoney.delivery.http.routes.healthRoutes
import mymoney.delivery.http.routes.transactionRoutes
import mymoney.delivery.http.security.configureAuth
import mymoney.di.appModule
import mymoney.domain.usecase.account.ArchiveAccountUseCase
import mymoney.domain.usecase.account.CreateAccountUseCase
import mymoney.domain.usecase.account.DeleteAccountUseCase
import mymoney.domain.usecase.account.GetAccountUseCase
import mymoney.domain.usecase.account.ListAccountsUseCase
import mymoney.domain.usecase.account.UpdateAccountUseCase
import mymoney.domain.usecase.auth.LoginUseCase
import mymoney.domain.usecase.auth.LogoutAllUseCase
import mymoney.domain.usecase.auth.RefreshTokenUseCase
import mymoney.domain.usecase.auth.RegisterUserUseCase
import mymoney.domain.usecase.category.ArchiveCategoryUseCase
import mymoney.domain.usecase.category.CreateCategoryUseCase
import mymoney.domain.usecase.category.DeleteCategoryUseCase
import mymoney.domain.usecase.category.GetCategoryUseCase
import mymoney.domain.usecase.category.ListCategoriesUseCase
import mymoney.domain.usecase.category.UpdateCategoryUseCase
import mymoney.domain.usecase.transaction.CreateTransactionUseCase
import mymoney.domain.usecase.transaction.DeleteTransactionUseCase
import mymoney.domain.usecase.transaction.GetTransactionHistoryUseCase
import mymoney.domain.usecase.transaction.GetTransactionUseCase
import mymoney.domain.usecase.transaction.ListTransactionsUseCase
import mymoney.domain.usecase.transaction.UpdateTransactionUseCase
import mymoney.domain.usecase.budget.CreateBudgetUseCase
import mymoney.domain.usecase.budget.DeleteBudgetUseCase
import mymoney.domain.usecase.budget.GetBudgetProgressUseCase
import mymoney.domain.usecase.budget.GetBudgetUseCase
import mymoney.domain.usecase.budget.ListBudgetsUseCase
import mymoney.domain.usecase.budget.UpdateBudgetUseCase
import mymoney.domain.usecase.goal.ContributeGoalUseCase
import mymoney.domain.usecase.goal.CreateGoalUseCase
import mymoney.domain.usecase.goal.DeleteGoalUseCase
import mymoney.domain.usecase.goal.GetGoalUseCase
import mymoney.domain.usecase.goal.ListGoalsUseCase
import mymoney.domain.usecase.goal.UpdateGoalUseCase
import org.koin.ktor.ext.inject
import org.koin.ktor.plugin.Koin
import org.koin.logger.slf4jLogger

fun main(args: Array<String>): Unit = EngineMain.main(args)

fun Application.module() {
    val config = loadAppConfig(environment.config)
    log.info("Starting MyMoney backend, jdbc={}", config.db.url)

    val databaseFactory = DatabaseFactory(config.db).apply { init() }

    install(Koin) {
        slf4jLogger()
        modules(appModule(config, databaseFactory))
    }

    configureHttp()
    configureAuth(config.jwt)

    val register by inject<RegisterUserUseCase>()
    val login by inject<LoginUseCase>()
    val refresh by inject<RefreshTokenUseCase>()
    val logoutAll by inject<LogoutAllUseCase>()

    val createAccount by inject<CreateAccountUseCase>()
    val listAccounts by inject<ListAccountsUseCase>()
    val getAccount by inject<GetAccountUseCase>()
    val updateAccount by inject<UpdateAccountUseCase>()
    val archiveAccount by inject<ArchiveAccountUseCase>()
    val deleteAccount by inject<DeleteAccountUseCase>()

    val createCategory by inject<CreateCategoryUseCase>()
    val listCategories by inject<ListCategoriesUseCase>()
    val getCategory by inject<GetCategoryUseCase>()
    val updateCategory by inject<UpdateCategoryUseCase>()
    val archiveCategory by inject<ArchiveCategoryUseCase>()
    val deleteCategory by inject<DeleteCategoryUseCase>()

    val createTransaction by inject<CreateTransactionUseCase>()
    val listTransactions by inject<ListTransactionsUseCase>()
    val getTransaction by inject<GetTransactionUseCase>()
    val updateTransaction by inject<UpdateTransactionUseCase>()
    val deleteTransaction by inject<DeleteTransactionUseCase>()
    val getTransactionHistory by inject<GetTransactionHistoryUseCase>()

    val createBudget by inject<CreateBudgetUseCase>()
    val listBudgets by inject<ListBudgetsUseCase>()
    val getBudget by inject<GetBudgetUseCase>()
    val updateBudget by inject<UpdateBudgetUseCase>()
    val deleteBudget by inject<DeleteBudgetUseCase>()
    val getBudgetProgress by inject<GetBudgetProgressUseCase>()

    val createGoal by inject<CreateGoalUseCase>()
    val listGoals by inject<ListGoalsUseCase>()
    val getGoal by inject<GetGoalUseCase>()
    val updateGoal by inject<UpdateGoalUseCase>()
    val deleteGoal by inject<DeleteGoalUseCase>()
    val contributeGoal by inject<ContributeGoalUseCase>()

    routing {
        healthRoutes(databaseFactory.database)
        route("/v1") {
            authRoutes(register, login, refresh, logoutAll)
            accountRoutes(
                create = createAccount,
                list = listAccounts,
                get = getAccount,
                update = updateAccount,
                archive = archiveAccount,
                delete = deleteAccount,
            )
            categoryRoutes(
                create = createCategory,
                list = listCategories,
                get = getCategory,
                update = updateCategory,
                archive = archiveCategory,
                delete = deleteCategory,
            )
            transactionRoutes(
                create = createTransaction,
                list = listTransactions,
                get = getTransaction,
                update = updateTransaction,
                delete = deleteTransaction,
                history = getTransactionHistory,
            )
            budgetRoutes(
                create = createBudget,
                list = listBudgets,
                get = getBudget,
                update = updateBudget,
                delete = deleteBudget,
                progress = getBudgetProgress,
            )
            goalRoutes(
                create = createGoal,
                list = listGoals,
                get = getGoal,
                update = updateGoal,
                delete = deleteGoal,
                contribute = contributeGoal,
            )
        }
    }
}
