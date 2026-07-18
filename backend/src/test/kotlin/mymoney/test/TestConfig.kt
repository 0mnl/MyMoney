package mymoney.test

import io.ktor.server.config.MapApplicationConfig
import org.testcontainers.containers.PostgreSQLContainer

fun testAppConfig(postgres: PostgreSQLContainer<*>): MapApplicationConfig =
    MapApplicationConfig(
        "db.url" to postgres.jdbcUrl,
        "db.user" to postgres.username,
        "db.password" to postgres.password,
        "db.poolSize" to "3",
        "jwt.issuer" to "mymoney-test",
        "jwt.audience" to "mymoney-mobile",
        "jwt.realm" to "mymoney",
        "jwt.secret" to "test-secret-please-do-not-use-in-production-please",
        "jwt.accessTokenTtlMinutes" to "15",
        "jwt.refreshTokenTtlDays" to "30",
    )
