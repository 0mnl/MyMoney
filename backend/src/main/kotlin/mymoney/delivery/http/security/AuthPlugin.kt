package mymoney.delivery.http.security

import com.auth0.jwt.JWT
import com.auth0.jwt.algorithms.Algorithm
import io.ktor.http.HttpStatusCode
import io.ktor.server.application.Application
import io.ktor.server.application.ApplicationCall
import io.ktor.server.application.install
import io.ktor.server.auth.Authentication
import io.ktor.server.auth.jwt.JWTPrincipal
import io.ktor.server.auth.jwt.jwt
import io.ktor.server.auth.principal
import io.ktor.server.response.respond
import mymoney.config.JwtConfig
import mymoney.delivery.http.plugins.ErrorBody
import mymoney.delivery.http.plugins.ErrorResponse
import mymoney.domain.errors.UnauthorizedException
import mymoney.domain.model.UserContext
import java.util.UUID

const val AUTH_ACCESS = "access"

fun Application.configureAuth(config: JwtConfig) {
    install(Authentication) {
        jwt(AUTH_ACCESS) {
            realm = config.realm
            verifier(
                JWT.require(Algorithm.HMAC256(config.secret))
                    .withIssuer(config.issuer)
                    .withAudience(config.audience)
                    .build(),
            )
            validate { credential ->
                val sub = credential.payload.subject
                val familyId = credential.payload.getClaim("family_id").asString()
                if (!sub.isNullOrBlank() && !familyId.isNullOrBlank()) {
                    JWTPrincipal(credential.payload)
                } else {
                    null
                }
            }
            challenge { _, _ ->
                call.respond(
                    HttpStatusCode.Unauthorized,
                    ErrorResponse(ErrorBody("UNAUTHORIZED", "Missing or invalid access token")),
                )
            }
        }
    }
}

fun ApplicationCall.userContext(): UserContext {
    val principal = principal<JWTPrincipal>() ?: throw UnauthorizedException()
    val sub = principal.subject ?: throw UnauthorizedException("Malformed access token")
    val fam = principal.payload.getClaim("family_id").asString()
        ?: throw UnauthorizedException("Malformed access token")
    return UserContext(userId = UUID.fromString(sub), familyId = UUID.fromString(fam))
}
