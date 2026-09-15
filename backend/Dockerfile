# syntax=docker/dockerfile:1.7

# --------- Builder ---------
# Not the -alpine tag: Temurin/Gradle publish Alpine (musl) images for amd64 only,
# so the build fails with "no match for platform in manifest" on arm64 hosts such
# as Apple Silicon. The Debian-based tags are multi-arch.
FROM gradle:8.10-jdk17 AS builder
WORKDIR /app

# Copy only what's needed to leverage layer caching.
COPY settings.gradle.kts build.gradle.kts gradle.properties* ./
COPY gradle ./gradle
COPY src ./src

# Ktor plugin -> "mymoney-backend.jar" (see build.gradle.kts).
RUN gradle --no-daemon buildFatJar

# --------- Runtime ---------
# Debian-based for the same multi-arch reason as the builder above.
FROM eclipse-temurin:17-jre-jammy
WORKDIR /app

# curl for the healthcheck (also handy for debugging inside the container).
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Non-root user — уменьшает риск при exploit'е.
RUN groupadd --system app && useradd --system --gid app app

COPY --from=builder /app/build/libs/mymoney-backend.jar /app/app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080

# Sensible JVM defaults for a small container. Override with -e JAVA_OPTS.
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
