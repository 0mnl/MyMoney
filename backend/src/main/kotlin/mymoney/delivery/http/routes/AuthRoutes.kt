package mymoney.delivery.http.routes

import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import mymoney.delivery.http.dto.LoginRequest
import mymoney.delivery.http.dto.RefreshRequest
import mymoney.delivery.http.dto.RegisterRequest
import mymoney.delivery.http.dto.toResponse
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.usecase.auth.LoginUseCase
import mymoney.domain.usecase.auth.LogoutAllUseCase
import mymoney.domain.usecase.auth.RefreshTokenUseCase
import mymoney.domain.usecase.auth.RegisterUserUseCase

fun Route.authRoutes(
    register: RegisterUserUseCase,
    login: LoginUseCase,
    refresh: RefreshTokenUseCase,
    logoutAll: LogoutAllUseCase,
) {
    route("/auth") {
        post("/register") {
            val body = call.receive<RegisterRequest>()
            val session = register.execute(body.email, body.password)
            call.respond(HttpStatusCode.OK, session.toResponse())
        }

        post("/login") {
            val body = call.receive<LoginRequest>()
            val session = login.execute(body.email, body.password)
            call.respond(HttpStatusCode.OK, session.toResponse())
        }

        post("/refresh") {
            val body = call.receive<RefreshRequest>()
            val tokens = refresh.execute(body.refreshToken)
            call.respond(HttpStatusCode.OK, tokens.toResponse())
        }

        authenticate(AUTH_ACCESS) {
            post("/logout-all") {
                val ctx = call.userContext()
                logoutAll.execute(ctx.userId)
                call.respond(HttpStatusCode.NoContent)
            }
        }
    }
}
