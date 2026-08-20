package mymoney.data.notification

import kotlinx.datetime.Instant
import mymoney.domain.usecase.auth.VerificationCodeSender
import org.slf4j.LoggerFactory

/**
 * Development transport: writes the code to the application log instead of
 * sending mail, so the onboarding flow is testable without SMTP credentials.
 *
 * Refuses to be used in production — `AppModule` picks [SmtpVerificationCodeSender]
 * whenever `mail.host` is configured, and `loadAppConfig` requires that in prod.
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
