plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.ktor)
    alias(libs.plugins.flyway)
    application
}

group = "mymoney"
version = "0.1.0"

application {
    mainClass.set("mymoney.ApplicationKt")
}

kotlin {
    jvmToolchain(17)
}

dependencies {
    // Ktor server
    implementation(libs.ktor.server.core)
    implementation(libs.ktor.server.netty)
    implementation(libs.ktor.server.config.yaml)
    implementation(libs.ktor.server.content.neg)
    implementation(libs.ktor.server.auth)
    implementation(libs.ktor.server.auth.jwt)
    implementation(libs.ktor.server.status.pages)
    implementation(libs.ktor.server.cors)
    implementation(libs.ktor.server.call.logging)
    implementation(libs.ktor.server.default.headers)
    implementation(libs.ktor.server.request.valid)
    implementation(libs.ktor.serialization.json)

    // Kotlin core
    implementation(libs.kotlinx.serialization)
    implementation(libs.kotlinx.datetime)
    implementation(libs.kotlinx.coroutines.core)

    // DB
    implementation(libs.exposed.core)
    implementation(libs.exposed.jdbc)
    implementation(libs.exposed.kotlin.datetime)
    implementation(libs.exposed.json)
    implementation(libs.hikaricp)
    implementation(libs.postgres)
    implementation(libs.flyway.core)
    implementation(libs.flyway.postgres)

    // DI
    implementation(libs.koin.core)
    implementation(libs.koin.ktor)
    implementation(libs.koin.slf4j)

    // Security
    implementation(libs.argon2)

    // Logging
    implementation(libs.logback.classic)

    // Test
    testImplementation(libs.ktor.server.test)
    testImplementation(libs.kotlin.test)
    testImplementation(libs.kotlin.test.junit5)
    testImplementation(libs.junit.jupiter)
    testImplementation(libs.testcontainers.postgres)
    testImplementation(libs.testcontainers.junit)
    testImplementation(libs.koin.test)
    testImplementation(libs.koin.test.junit5)
}

tasks.test {
    useJUnitPlatform()
    testLogging {
        events("passed", "skipped", "failed")
    }
}

// Flyway is configured from application.conf at runtime; the Gradle plugin is used only
// for occasional manual maintenance (e.g. `./gradlew flywayInfo`). Credentials come from
// env vars, never committed.
flyway {
    url = System.getenv("DB_URL") ?: "jdbc:postgresql://localhost:5432/mymoney"
    user = System.getenv("DB_USER") ?: "mymoney"
    password = System.getenv("DB_PASSWORD") ?: "mymoney_dev_password"
    locations = arrayOf("classpath:db/migration")
    schemas = arrayOf("public")
}

ktor {
    fatJar {
        archiveFileName.set("mymoney-backend.jar")
    }
}
