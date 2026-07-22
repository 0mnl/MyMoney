# syntax=docker/dockerfile:1.7

# --------- Builder ---------
FROM gradle:8.10-jdk17-alpine AS builder
WORKDIR /app

# Copy only what's needed to leverage layer caching.
COPY settings.gradle.kts build.gradle.kts gradle.properties* ./
COPY gradle ./gradle
COPY src ./src

# Ktor plugin -> "mymoney-backend.jar" (see build.gradle.kts).
RUN gradle --no-daemon buildFatJar

# --------- Runtime ---------
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# curl for the healthcheck (also handy for debugging inside the container).
RUN apk add --no-cache curl

# Non-root user — уменьшает риск при exploit'е.
RUN addgroup -S app && adduser -S app -G app

COPY --from=builder /app/build/libs/mymoney-backend.jar /app/app.jar
RUN chown -R app:app /app
USER app

EXPOSE 8080

# Sensible JVM defaults for a small container. Override with -e JAVA_OPTS.
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar /app/app.jar"]
