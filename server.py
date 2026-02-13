import os
import smtplib
from datetime import datetime
from email.message import EmailMessage
import uuid
import re
import json
from typing import Optional

from flask import Flask, jsonify, request, send_from_directory, url_for

app = Flask(__name__)

# Configuration (set these with environment variables in production)
OWNER_EMAIL = os.getenv("OWNER_EMAIL", "")
SMTP_EMAIL = os.getenv("SMTP_EMAIL", "")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD", "")
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_MODE = os.getenv("SMTP_MODE", "auto").strip().lower()
UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "evidence_vault")
RECIPIENTS_FILE = os.getenv("RECIPIENTS_FILE", "alert_recipients.json")
SMTP_TIMEOUT_SECONDS = int(os.getenv("SMTP_TIMEOUT_SECONDS", "20"))

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

MAX_EVIDENCE_TO_KEEP = int(os.getenv("MAX_EVIDENCE_TO_KEEP", "10"))
EMAIL_PATTERN = re.compile(r"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")


def _looks_placeholder(value: str) -> bool:
    lower = (value or "").strip().lower()
    if not lower:
        return True
    placeholder_tokens = (
        "your_",
        "example.com",
        "changeme",
        "app_password",
        "password_here",
    )
    return any(token in lower for token in placeholder_tokens)


def _owner_email() -> str:
    return OWNER_EMAIL.strip()


def _smtp_email() -> str:
    return SMTP_EMAIL.strip()


def _smtp_password() -> str:
    return SMTP_PASSWORD.strip()


def _smtp_host() -> str:
    value = SMTP_HOST
    return value or "smtp.gmail.com"


def _smtp_port() -> int:
    try:
        return int(SMTP_PORT)
    except Exception:
        return 465


def _smtp_timeout() -> int:
    return SMTP_TIMEOUT_SECONDS if SMTP_TIMEOUT_SECONDS > 0 else 20


def _smtp_mode() -> str:
    if SMTP_MODE in {"ssl", "starttls", "plain", "auto"}:
        return SMTP_MODE
    return "auto"


def _send_message(msg: EmailMessage) -> None:
    host = _smtp_host()
    port = _smtp_port()
    timeout = _smtp_timeout()
    mode = _smtp_mode()

    # Auto mode: prefer SSL on 465, otherwise use STARTTLS.
    use_ssl = mode == "ssl" or (mode == "auto" and port == 465)
    if use_ssl:
        with smtplib.SMTP_SSL(host, port, timeout=timeout) as smtp:
            smtp.login(_smtp_email(), _smtp_password())
            smtp.send_message(msg)
        return

    with smtplib.SMTP(host, port, timeout=timeout) as smtp:
        if mode in {"starttls", "auto"}:
            smtp.ehlo()
            smtp.starttls()
            smtp.ehlo()
        smtp.login(_smtp_email(), _smtp_password())
        smtp.send_message(msg)


def prune_evidence_folder(keep: int = MAX_EVIDENCE_TO_KEEP) -> None:
    if keep <= 0:
        return
    try:
        entries = []
        for name in os.listdir(UPLOAD_FOLDER):
            path = os.path.join(UPLOAD_FOLDER, name)
            if not os.path.isfile(path):
                continue
            lower = name.lower()
            if not (lower.endswith(".jpg") or lower.endswith(".jpeg") or lower.endswith(".png")):
                continue
            entries.append((os.path.getmtime(path), path))
        entries.sort(key=lambda t: t[0], reverse=True)
        for _, path in entries[keep:]:
            try:
                os.remove(path)
            except Exception:
                pass
    except Exception:
        # Best-effort retention; don't break uploads.
        pass


def _is_valid_email(value: str) -> bool:
    return bool(EMAIL_PATTERN.fullmatch((value or "").strip()))


def _load_recipients() -> list[str]:
    try:
        if not os.path.exists(RECIPIENTS_FILE):
            return []
        with open(RECIPIENTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, list):
            return []
        # Keep input order, dedupe by lowercase.
        seen = set()
        out = []
        for raw in data:
            email = str(raw).strip()
            key = email.lower()
            if not _is_valid_email(email) or key in seen:
                continue
            seen.add(key)
            out.append(email)
        return out
    except Exception:
        return []


def _save_recipients(recipients: list[str]) -> None:
    with open(RECIPIENTS_FILE, "w", encoding="utf-8") as f:
        json.dump(recipients, f, indent=2)


def _effective_recipients() -> list[str]:
    recipients = _load_recipients()
    owner = _owner_email()
    if _is_valid_email(owner) and not _looks_placeholder(owner):
        owner_key = owner.strip().lower()
        if owner_key not in {r.lower() for r in recipients}:
            recipients.append(owner.strip())
    return recipients


def _smtp_config_error() -> Optional[str]:
    smtp_email = _smtp_email()
    smtp_password = _smtp_password()
    smtp_port = _smtp_port()
    if _looks_placeholder(smtp_email) or not _is_valid_email(smtp_email):
        return "SMTP_EMAIL is missing or invalid"
    if _looks_placeholder(smtp_password) or not smtp_password.strip():
        return "SMTP_PASSWORD is missing"
    if smtp_port <= 0:
        return "SMTP_PORT is invalid"
    return None


def _latest_evidence_path() -> Optional[str]:
    latest_path = None
    latest_mtime = -1.0
    for name in os.listdir(UPLOAD_FOLDER):
        path = os.path.join(UPLOAD_FOLDER, name)
        if not os.path.isfile(path):
            continue
        lower = name.lower()
        if not (lower.endswith(".jpg") or lower.endswith(".jpeg") or lower.endswith(".png")):
            continue
        mtime = os.path.getmtime(path)
        if mtime > latest_mtime:
            latest_mtime = mtime
            latest_path = path
    return latest_path


def send_image_email(image_path: str, recipients: list[str], subject: str, body: str) -> None:
    config_error = _smtp_config_error()
    if config_error:
        raise ValueError(config_error)
    if not recipients:
        raise ValueError("No recipient email configured")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = _smtp_email()
    msg["To"] = ", ".join(recipients)
    msg.set_content(body)

    with open(image_path, "rb") as file:
        msg.add_attachment(
            file.read(),
            maintype="image",
            subtype="jpeg",
            filename=os.path.basename(image_path),
        )

    _send_message(msg)


def send_alert_email(image_path: str, location: str, device_info: str, recipients: list[str]) -> None:
    body = (
        "WARNING: Failed unlock attempts were detected.\n\n"
        f"Time: {datetime.now().isoformat(timespec='seconds')}\n"
        f"Location: {location}\n"
        f"Device: {device_info}\n\n"
        "See the attached image."
    )
    send_image_email(
        image_path=image_path,
        recipients=recipients,
        subject="Security Alert: Intruder detected",
        body=body,
    )


def send_test_email(recipients: list[str]) -> None:
    config_error = _smtp_config_error()
    if config_error:
        raise ValueError(config_error)
    if not recipients:
        raise ValueError("No recipient email configured")

    msg = EmailMessage()
    msg["Subject"] = "Securax Test Email"
    msg["From"] = _smtp_email()
    msg["To"] = ", ".join(recipients)
    msg.set_content(
        "This is a test email from Securax.\n\n"
        f"Time: {datetime.now().isoformat(timespec='seconds')}\n"
        "If you received this, SMTP and recipient setup are working."
    )

    _send_message(msg)


@app.route("/email_config_status", methods=["GET"])
def email_config_status():
    err = _smtp_config_error()
    smtp_email = _smtp_email()
    smtp_password = _smtp_password()
    return (
        jsonify(
            {
                "status": "ok" if err is None else "invalid",
                "error": err,
                "smtp_email_set": bool(smtp_email.strip()) and not _looks_placeholder(smtp_email),
                "smtp_password_set": bool(smtp_password.strip()) and not _looks_placeholder(smtp_password),
                "smtp_host": _smtp_host(),
                "smtp_port": _smtp_port(),
                "smtp_mode": _smtp_mode(),
                "recipient_count": len(_effective_recipients()),
            }
        ),
        200 if err is None else 503,
    )


@app.route("/healthz", methods=["GET"])
def healthz():
    return jsonify({"status": "ok"}), 200


@app.route("/upload_evidence", methods=["POST"])
def upload_evidence():
    if "photo" not in request.files:
        return jsonify({"error": "No photo uploaded"}), 400

    photo = request.files["photo"]
    location = request.form.get("location", "Unknown Location")
    device = request.form.get("device", "Unknown Device")
    reason = request.form.get("reason", "unknown")

    # Keep reason filesystem-safe for filename embedding.
    safe_reason = re.sub(r"[^a-zA-Z0-9_-]+", "_", str(reason)).strip("_") or "unknown"

    # Use a unique filename to avoid overwriting when multiple attempts occur
    # within the same second, and to avoid client-side image caching issues.
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    filename = f"{timestamp}_{safe_reason}_{uuid.uuid4().hex[:6]}.jpg"
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    photo.save(filepath)
    prune_evidence_folder()
    recipients = _effective_recipients()

    try:
        send_alert_email(filepath, location, device, recipients=recipients)
        return jsonify({"status": "success", "file": filename, "reason": safe_reason, "recipients": recipients}), 200
    except Exception as exc:  # pragma: no cover - operational path
        return jsonify(
            {
                "status": "saved_but_email_failed",
                "file": filename,
                "reason": safe_reason,
                "recipients": recipients,
                "error": str(exc),
            }
        ), 500


@app.route("/test_alert_email", methods=["POST"])
def test_alert_email():
    recipients = _effective_recipients()
    try:
        send_test_email(recipients)
        return jsonify({"status": "sent", "recipients": recipients}), 200
    except Exception as exc:
        code = 503 if "SMTP_" in str(exc) else 500
        return jsonify({"status": "failed", "recipients": recipients, "error": str(exc)}), code


@app.route("/send_latest_evidence", methods=["POST"])
def send_latest_evidence():
    recipients = _effective_recipients()
    latest_path = _latest_evidence_path()
    if latest_path is None:
        return jsonify({"status": "failed", "error": "No evidence image available"}), 404

    body = (
        "Manual send from Securax.\n\n"
        f"Time: {datetime.now().isoformat(timespec='seconds')}\n"
        "Attached: Latest captured evidence image."
    )
    try:
        send_image_email(
            image_path=latest_path,
            recipients=recipients,
            subject="Securax: Latest Evidence",
            body=body,
        )
        return jsonify(
            {
                "status": "sent",
                "file": os.path.basename(latest_path),
                "recipients": recipients,
            }
        ), 200
    except Exception as exc:
        code = 503 if "SMTP_" in str(exc) else 500
        return jsonify(
            {
                "status": "failed",
                "file": os.path.basename(latest_path),
                "recipients": recipients,
                "error": str(exc),
            }
        ), code


@app.route("/alert_recipients", methods=["GET"])
def list_alert_recipients():
    return jsonify({"count": len(_load_recipients()), "items": _load_recipients()}), 200


@app.route("/alert_recipients", methods=["POST"])
def add_alert_recipient():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip()
    if not _is_valid_email(email):
        return jsonify({"error": "Invalid email"}), 400

    recipients = _load_recipients()
    lowered = {r.lower() for r in recipients}
    if email.lower() in lowered:
        return jsonify({"status": "exists", "items": recipients}), 200

    recipients.append(email)
    _save_recipients(recipients)
    return jsonify({"status": "added", "items": recipients}), 201


@app.route("/alert_recipients", methods=["DELETE"])
def remove_alert_recipient():
    data = request.get_json(silent=True) or {}
    email = str(data.get("email", "")).strip()
    if not _is_valid_email(email):
        return jsonify({"error": "Invalid email"}), 400

    recipients = _load_recipients()
    filtered = [r for r in recipients if r.lower() != email.lower()]
    if len(filtered) == len(recipients):
        return jsonify({"status": "not_found", "items": recipients}), 404

    _save_recipients(filtered)
    return jsonify({"status": "removed", "items": filtered}), 200


@app.route("/evidence", methods=["GET"])
def list_evidence():
    files = []
    for name in os.listdir(UPLOAD_FOLDER):
        path = os.path.join(UPLOAD_FOLDER, name)
        if not os.path.isfile(path):
            continue
        lower = name.lower()
        if not (lower.endswith(".jpg") or lower.endswith(".jpeg") or lower.endswith(".png")):
            continue
        # Parse reason from filename: <timestamp>_<reason>_<suffix>.jpg
        reason = "unknown"
        base = os.path.basename(name)
        parts = base.split("_")
        if len(parts) >= 4:
            reason = parts[3] if parts[3] else "unknown"
        files.append(
            {
                "file": name,
                "reason": reason,
                "size": os.path.getsize(path),
                "modified": datetime.fromtimestamp(os.path.getmtime(path)).isoformat(timespec="seconds"),
                "image_url": url_for("get_evidence_file", filename=name, _external=True),
            }
        )
    files.sort(key=lambda item: item["modified"], reverse=True)
    return jsonify({"count": len(files), "items": files}), 200


@app.route("/evidence/<path:filename>", methods=["GET"])
def get_evidence_file(filename: str):
    return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=False)


@app.route("/evidence/<path:filename>", methods=["DELETE"])
def delete_evidence_file(filename: str):
    # Only allow deletes within UPLOAD_FOLDER.
    path = os.path.join(UPLOAD_FOLDER, filename)
    try:
        real_base = os.path.realpath(UPLOAD_FOLDER)
        real_path = os.path.realpath(path)
        if not real_path.startswith(real_base + os.sep):
            return jsonify({"error": "Invalid path"}), 400
        if not os.path.exists(real_path):
            return jsonify({"status": "not_found"}), 404
        os.remove(real_path)
        return jsonify({"status": "deleted", "file": filename}), 200
    except Exception as exc:
        return jsonify({"error": str(exc)}), 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    debug = os.getenv("FLASK_DEBUG", "false").strip().lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)
