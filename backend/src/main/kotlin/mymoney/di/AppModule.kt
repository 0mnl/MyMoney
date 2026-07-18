package mymoney.di

import mymoney.config.AppConfig
import mymoney.config.DbConfig
import mymoney.config.JwtConfig
import mymoney.data.db.DatabaseFactory
import org.koin.dsl.module

fun appModule(config: AppConfig, databaseFactory: DatabaseFactory) = module {
    single { config }
    single<DbConfig> { config.db }
    single<JwtConfig> { config.jwt }
    single { databaseFactory }
    single { databaseFactory.database }
}
