"""Plain SMTP sending — no third-party email API/account needed, just an
existing Gmail account with an App Password (or any other SMTP provider,
by overriding SMTP_HOST/PORT)."""
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def send_email(to: str, subject: str, html_body: str, text_body: str) -> None:
    if not settings.SMTP_USERNAME or not settings.SMTP_PASSWORD:
        raise RuntimeError(
            "SMTP_USERNAME/SMTP_PASSWORD are not configured — see README for Gmail App Password setup."
        )
    if not to:
        raise RuntimeError("No recipient configured (DIGEST_RECIPIENT_EMAIL).")

    from_email = settings.SMTP_FROM_EMAIL or settings.SMTP_USERNAME

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_email
    msg["To"] = to
    msg.attach(MIMEText(text_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=30) as server:
        server.starttls()
        server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
        server.sendmail(from_email, [to], msg.as_string())
    logger.info("Sent email %r to %s", subject, to)
