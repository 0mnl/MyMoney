package mymoney.data.notification

import jakarta.mail.Authenticator
import jakarta.mail.Message
import jakarta.mail.PasswordAuthentication
import jakarta.mail.Session
import jakarta.mail.Transport
import jakarta.mail.internet.InternetAddress
import jakarta.mail.internet.MimeBodyPart
import jakarta.mail.internet.MimeMessage
import jakarta.mail.internet.MimeMultipart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.datetime.Instant
import mymoney.config.MailConfig
import mymoney.domain.usecase.auth.VerificationCodeSender
import org.slf4j.LoggerFactory
import java.util.Properties

/**
 * Реальная отправка кодов подтверждения по SMTP.
 *
 * Подключается вместо [LoggingVerificationCodeSender], когда задан
 * `MAIL_HOST` (см. `AppModule`). В production конфигурация обязательна —
 * `loadAppConfig` не даст стартовать без неё.
 *
 * Письмо уходит в двух частях, `text/plain` и `text/html`: почтовые клиенты
 * без HTML показывают первую, остальные — вторую. Один только HTML часть
 * клиентов и спам-фильтров воспринимают хуже.
 */
class SmtpVerificationCodeSender(
    private val config: MailConfig,
) : VerificationCodeSender {

    private val log = LoggerFactory.getLogger(SmtpVerificationCodeSender::class.java)

    private val session: Session by lazy { buildSession() }

    override suspend fun send(email: String, code: String, expiresAt: Instant) {
        // Jakarta Mail блокирующая, а вызывают её из корутины обработчика
        // запроса. Без переключения на IO-диспетчер медленный SMTP занимал
        // бы поток пула Ktor и тормозил обработку других запросов.
        withContext(Dispatchers.IO) {
            runCatching { deliver(email, code) }
                .onSuccess { log.info("Confirmation code sent to {}", email) }
                .onFailure { e ->
                    // Код в лог не пишем: письмо не ушло, но сам код —
                    // секрет, и логи обычно доступны шире, чем почта.
                    log.error("Failed to send confirmation code to {}: {}", email, e.message, e)
                    throw e
                }
        }
    }

    private fun deliver(email: String, code: String) {
        val message = MimeMessage(session).apply {
            setFrom(InternetAddress(config.from, config.fromName, Charsets.UTF_8.name()))
            setRecipients(Message.RecipientType.TO, InternetAddress.parse(email))
            setSubject("Код подтверждения MyMoney: $code", Charsets.UTF_8.name())
            sentDate = java.util.Date()

            setContent(
                MimeMultipart("alternative").apply {
                    addBodyPart(
                        MimeBodyPart().apply {
                            setText(plainBody(code), Charsets.UTF_8.name())
                        },
                    )
                    addBodyPart(
                        MimeBodyPart().apply {
                            setContent(htmlBody(code), "text/html; charset=UTF-8")
                        },
                    )
                },
            )
        }

        Transport.send(message)
    }

    private fun buildSession(): Session {
        val props = Properties().apply {
            put("mail.smtp.host", config.host)
            put("mail.smtp.port", config.port.toString())
            put("mail.smtp.auth", config.username.isNotBlank().toString())
            put("mail.smtp.starttls.enable", config.startTls.toString())
            // Требуем именно шифрованный канал, а не «попробуем, если выйдет»:
            // при starttls.required=false MITM может убрать предложение TLS,
            // и пароль с кодом уйдут открытым текстом.
            put("mail.smtp.starttls.required", config.startTls.toString())
            if (config.ssl) {
                put("mail.smtp.ssl.enable", "true")
                put("mail.smtp.socketFactory.port", config.port.toString())
            }
            // Без таймаутов зависший SMTP держал бы корутину бесконечно.
            put("mail.smtp.connectiontimeout", "10000")
            put("mail.smtp.timeout", "10000")
            put("mail.smtp.writetimeout", "10000")
        }

        return if (config.username.isBlank()) {
            Session.getInstance(props)
        } else {
            Session.getInstance(
                props,
                object : Authenticator() {
                    override fun getPasswordAuthentication() =
                        PasswordAuthentication(config.username, config.password)
                },
            )
        }
    }

    private fun plainBody(code: String) = """
        Код подтверждения MyMoney: $code

        Введите его в приложении, чтобы завершить регистрацию.
        Код действует ограниченное время и используется один раз.

        Если вы не регистрировались в MyMoney — просто проигнорируйте это письмо.
    """.trimIndent()

    private fun htmlBody(code: String) = """
        <!doctype html>
        <html lang="ru">
          <body style="font-family: -apple-system, Segoe UI, Roboto, sans-serif; color: #1a1a1a;">
            <p>Код подтверждения MyMoney:</p>
            <p style="font-size: 32px; font-weight: 700; letter-spacing: 4px;">$code</p>
            <p>Введите его в приложении, чтобы завершить регистрацию.<br>
               Код действует ограниченное время и используется один раз.</p>
            <p style="color: #6b7280; font-size: 13px;">
              Если вы не регистрировались в MyMoney — просто проигнорируйте это письмо.
            </p>
          </body>
        </html>
    """.trimIndent()
}
