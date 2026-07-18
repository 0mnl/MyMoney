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
import mymoney.delivery.http.routes.healthRoutes
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
        }
    }
}
