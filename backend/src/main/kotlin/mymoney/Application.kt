package mymoney

import io.ktor.server.application.Application
import io.ktor.server.application.install
import io.ktor.server.application.log
import io.ktor.server.netty.EngineMain
import io.ktor.server.routing.routing
import mymoney.config.loadAppConfig
import mymoney.data.db.DatabaseFactory
import mymoney.delivery.http.plugins.configureHttp
import mymoney.delivery.http.routes.healthRoutes
import mymoney.di.appModule
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

    routing {
        healthRoutes(databaseFactory.database)
    }
}
