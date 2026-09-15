package mymoney.data.notification

import kotlinx.datetime.Instant
import mymoney.domain.usecase.auth.VerificationCodeSender
import org.slf4j.LoggerFactory

/**
 * Development transport: writes the code to the application log instead of
 * sending mail, so the onboarding flow is testable without SMTP credentials.
 *
 * There is no real transport yet — the project has no SMTP dependency, and
 * `AppModule` falls back to this class whenever no [VerificationCodeSender] is
 * injected, in production as well. Until a real sender exists, a production
 * deployment writes confirmation codes into the application log and delivers
 * no mail at all; the extension point is the `VerificationCodeSender` binding
 * in `AppModule`.
 */
class LoggingVerificationCodeSender : VerificationCodeSender {

    private val log = LoggerFactory.getLogger(LoggingVerificationCodeSender::class.java)

    override suspend fun send(email: String, code: String, expiresAt: Instant) {
        log.warn(
            "[DEV] Email confirmation code for {} is {} (valid until {}). " +
                "Configure MAIL_HOST to send real mail.",
            email,
            code,
            expiresAt,
        )
    }
}
