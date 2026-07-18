package mymoney.data.db

import com.zaxxer.hikari.HikariConfig
import com.zaxxer.hikari.HikariDataSource
import mymoney.config.DbConfig
import org.flywaydb.core.Flyway
import org.jetbrains.exposed.sql.Database
import javax.sql.DataSource

class DatabaseFactory(private val cfg: DbConfig) {

    lateinit var dataSource: DataSource
        private set

    lateinit var database: Database
        private set

    fun init() {
        dataSource = HikariDataSource(HikariConfig().apply {
            jdbcUrl = cfg.url
            username = cfg.user
            password = cfg.password
            driverClassName = "org.postgresql.Driver"
            maximumPoolSize = cfg.poolSize
            isAutoCommit = false
            transactionIsolation = "TRANSACTION_REPEATABLE_READ"
            validate()
        })

        Flyway.configure()
            .dataSource(dataSource)
            .locations("classpath:db/migration")
            .load()
            .migrate()

        database = Database.connect(dataSource)
    }

    fun close() {
        (dataSource as? HikariDataSource)?.close()
    }
}
