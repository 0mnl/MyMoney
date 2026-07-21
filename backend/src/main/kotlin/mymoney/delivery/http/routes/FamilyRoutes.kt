package mymoney.delivery.http.routes

import io.ktor.http.HttpStatusCode
import io.ktor.server.auth.authenticate
import io.ktor.server.request.receive
import io.ktor.server.response.respond
import io.ktor.server.routing.Route
import io.ktor.server.routing.get
import io.ktor.server.routing.post
import io.ktor.server.routing.route
import mymoney.delivery.http.dto.AcceptInviteRequest
import mymoney.delivery.http.dto.AcceptInviteResponse
import mymoney.delivery.http.dto.FamilyMembersResponse
import mymoney.delivery.http.dto.InviteRequest
import mymoney.delivery.http.dto.InviteResponse
import mymoney.delivery.http.dto.toDto
import mymoney.delivery.http.security.AUTH_ACCESS
import mymoney.delivery.http.security.userContext
import mymoney.domain.usecase.family.AcceptFamilyInviteUseCase
import mymoney.domain.usecase.family.InviteFamilyMemberUseCase
import mymoney.domain.usecase.family.ListFamilyMembersUseCase

fun Route.familyRoutes(
    invite: InviteFamilyMemberUseCase,
    accept: AcceptFamilyInviteUseCase,
    listMembers: ListFamilyMembersUseCase,
) {
    authenticate(AUTH_ACCESS) {
        route("/family") {
            post("/invite") {
                val ctx = call.userContext()
                val body = call.receive<InviteRequest>()
                val result = invite.execute(ctx.userId, ctx.familyId, body.email)
                call.respond(
                    HttpStatusCode.OK,
                    InviteResponse(inviteToken = result.inviteToken, expiresAt = result.expiresAt),
                )
            }

            post("/accept") {
                val ctx = call.userContext()
                val body = call.receive<AcceptInviteRequest>()
                val result = accept.execute(ctx.userId, body.inviteToken)
                call.respond(
                    HttpStatusCode.OK,
                    AcceptInviteResponse(familyId = result.familyId.toString()),
                )
            }

            get("/members") {
                val ctx = call.userContext()
                val members = listMembers.execute(ctx.familyId)
                call.respond(
                    HttpStatusCode.OK,
                    FamilyMembersResponse(members = members.map { it.toDto() }),
                )
            }
        }
    }
}
