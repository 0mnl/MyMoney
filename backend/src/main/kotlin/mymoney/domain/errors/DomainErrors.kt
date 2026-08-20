package mymoney.domain.errors

/**
 * Base type for expected, non-bug failures produced by domain code. StatusPages
 * maps subclasses to HTTP responses (see HttpPlugins.kt). Anything else that
 * escapes the domain is treated as an internal error.
 */
sealed class DomainException(
    val code: String,
    message: String,
    val details: Map<String, String> = emptyMap(),
) : RuntimeException(message)

class NotFoundException(entity: String, id: String) :
    DomainException(
        code = "NOT_FOUND",
        message = "$entity not found: $id",
        details = mapOf("entity" to entity, "id" to id),
    )

/**
 * [code] defaults to VALIDATION_FAILED but can be overridden when the client
 * needs to branch on the specific failure (e.g. INVALID_CODE vs CODE_EXPIRED
 * on the email-confirmation screen).
 */
class ValidationException(
    msg: String,
    details: Map<String, String> = emptyMap(),
    code: String = "VALIDATION_FAILED",
) : DomainException(code, msg, details)

class ConflictException(code: String, msg: String, details: Map<String, String> = emptyMap()) :
    DomainException(code, msg, details)

class UnauthorizedException(msg: String = "Unauthorized") :
    DomainException("UNAUTHORIZED", msg)

class ForbiddenException(
    msg: String = "Forbidden",
    code: String = "FORBIDDEN",
    details: Map<String, String> = emptyMap(),
) : DomainException(code, msg, details)

/** Throttling — resend-code cooldown, brute-force protection on codes. */
class TooManyRequestsException(
    msg: String,
    code: String = "TOO_MANY_REQUESTS",
    details: Map<String, String> = emptyMap(),
) : DomainException(code, msg, details)
