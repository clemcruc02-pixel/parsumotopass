"""ParSU MotoPass student API and account provisioning."""

import argparse
import base64
import binascii
from contextlib import closing, contextmanager
from datetime import datetime, timedelta, timezone
import getpass
import hashlib
import hmac
import json
import logging
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time
from urllib.parse import parse_qs
from wsgiref.simple_server import make_server
from wsgiref.simple_server import WSGIRequestHandler


MAX_FILE = 5 * 1024 * 1024
REQUEST_LOG = logging.getLogger("motopass.requests")
MAX_REQUEST = 41 * 1024 * 1024
SESSION_SECONDS = 8 * 60 * 60
REQUIRED = {"Student ID", "Registration (OR/CR)"}
OWNER_DOCUMENTS = {"Owner's ID", "Consent letter"}
FIELDS = ("course", "yearSection", "contact", "address", "plateNo",
          "color", "brandModel", "orCrNo")
STAFF_PERMISSIONS = ("review", "decide", "release", "manage")
PILOT_CYCLE = "synthetic-pilot"
SURROGATE = re.compile(r"[\ud800-\udfff]")


class ApiError(Exception):
    def __init__(self, status, message):
        self.status = status
        self.message = message


@contextmanager
def database(path):
    connection = sqlite3.connect(path, timeout=15)
    connection.row_factory = sqlite3.Row
    connection.execute("PRAGMA foreign_keys = ON")
    try:
        with connection:
            yield connection
    finally:
        connection.close()


def initialize(path):
    with database(path) as db:
        db.executescript("""
            CREATE TABLE IF NOT EXISTS students (
                id TEXT PRIMARY KEY NOT NULL,
                email TEXT UNIQUE NOT NULL,
                name TEXT NOT NULL,
                salt BLOB NOT NULL,
                password_hash BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sessions (
                digest BLOB PRIMARY KEY NOT NULL,
                student_id TEXT NOT NULL REFERENCES students(id),
                expires INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS applications (
                id INTEGER PRIMARY KEY,
                student_id TEXT UNIQUE NOT NULL REFERENCES students(id),
                reference TEXT UNIQUE NOT NULL,
                submitted_at TEXT NOT NULL,
                details TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS documents (
                application_id INTEGER NOT NULL REFERENCES applications(id),
                slot TEXT NOT NULL,
                filename TEXT NOT NULL,
                content BLOB NOT NULL,
                PRIMARY KEY (application_id, slot)
            );
            CREATE TABLE IF NOT EXISTS staff_grants (
                account_id TEXT NOT NULL REFERENCES students(id),
                permission TEXT NOT NULL CHECK(permission IN ('review', 'decide', 'release', 'manage')),
                PRIMARY KEY (account_id, permission)
            );
            CREATE TABLE IF NOT EXISTS staff_accounts (
                account_id TEXT PRIMARY KEY REFERENCES students(id)
            );
            INSERT OR IGNORE INTO staff_accounts SELECT account_id FROM staff_grants;
            CREATE TABLE IF NOT EXISTS application_events (
                application_id INTEGER NOT NULL REFERENCES applications(id),
                revision INTEGER NOT NULL,
                status TEXT NOT NULL,
                actor TEXT NOT NULL REFERENCES students(id),
                recorded_at TEXT NOT NULL,
                reason TEXT,
                PRIMARY KEY (application_id, revision)
            );
            CREATE TABLE IF NOT EXISTS document_checks (
                application_id INTEGER NOT NULL,
                slot TEXT NOT NULL,
                reviewer TEXT NOT NULL REFERENCES students(id),
                PRIMARY KEY (application_id, slot),
                FOREIGN KEY (application_id, slot) REFERENCES documents(application_id, slot)
            );
            CREATE TABLE IF NOT EXISTS pickup_settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                location TEXT NOT NULL,
                hours TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS submission_keys (
                student_id TEXT NOT NULL REFERENCES students(id),
                request_key TEXT NOT NULL,
                application_id INTEGER NOT NULL REFERENCES applications(id),
                PRIMARY KEY (student_id, request_key)
            );
            CREATE TABLE IF NOT EXISTS requirement_policies (
                revision INTEGER PRIMARY KEY,
                photo_required INTEGER NOT NULL CHECK(photo_required IN (0, 1))
            );
            INSERT OR IGNORE INTO requirement_policies VALUES (1, 0);
            CREATE TABLE IF NOT EXISTS application_policies (
                application_id INTEGER PRIMARY KEY REFERENCES applications(id),
                policy_revision INTEGER NOT NULL REFERENCES requirement_policies(revision)
            );
            INSERT OR IGNORE INTO application_policies SELECT id, 1 FROM applications;
            DELETE FROM pickup_settings WHERE location = 'Synthetic campus permit desk';
            CREATE TABLE IF NOT EXISTS pickup_instructions (
                application_id INTEGER PRIMARY KEY REFERENCES applications(id),
                location TEXT NOT NULL,
                hours TEXT NOT NULL
            );
            DELETE FROM pickup_instructions WHERE location = 'Synthetic campus permit desk';
            INSERT OR IGNORE INTO application_events
                SELECT id, 0, 'submitted', student_id, submitted_at, NULL FROM applications;
        """)
        if "normalized_plate" not in {column["name"] for column in db.execute(
            "PRAGMA table_info(applications)"
        )}:
            migrate_applications(db)


def normalize_plate(value):
    return re.sub(r"[^A-Z0-9]", "", value.upper())


def migrate_applications(db):
    db.execute("PRAGMA foreign_keys = OFF")
    db.execute("BEGIN IMMEDIATE")
    try:
        db.execute("""
            CREATE TABLE applications_next (
                id INTEGER PRIMARY KEY,
                student_id TEXT NOT NULL REFERENCES students(id),
                reference TEXT UNIQUE NOT NULL,
                submitted_at TEXT NOT NULL,
                details TEXT NOT NULL,
                cycle TEXT NOT NULL,
                normalized_plate TEXT NOT NULL,
                active INTEGER NOT NULL CHECK (active IN (0, 1))
            )
        """)
        rows = db.execute("""
            SELECT a.*, (SELECT status FROM application_events WHERE application_id = a.id
                         ORDER BY revision DESC LIMIT 1) AS status FROM applications a
        """).fetchall()
        db.executemany("INSERT INTO applications_next VALUES (?, ?, ?, ?, ?, ?, ?, ?)", (
            (row["id"], row["student_id"], row["reference"], row["submitted_at"],
             row["details"], PILOT_CYCLE, normalize_plate(json.loads(row["details"])["plateNo"]),
             int(row["status"] not in {"rejected", "released"}))
            for row in rows
        ))
        db.execute("DROP TABLE applications")
        db.execute("ALTER TABLE applications_next RENAME TO applications")
        db.execute("""
            CREATE UNIQUE INDEX one_active_plate
            ON applications (student_id, cycle, normalized_plate) WHERE active = 1
        """)
        db.execute("CREATE INDEX application_student ON applications (student_id, id DESC)")
        if db.execute("PRAGMA foreign_key_check").fetchone() is not None:
            raise RuntimeError("Application migration violated a foreign key.")
        db.commit()
    except BaseException:
        db.rollback()
        raise
    finally:
        db.execute("PRAGMA foreign_keys = ON")


def password_hash(password, salt):
    return hashlib.scrypt(password.encode("utf-8"), salt=salt, n=2**15,
                          r=8, p=1, maxmem=64 * 1024 * 1024)


def provision(path, student_id, email, name, password, *, grants=None):
    student_id, email, name = student_id.strip(), email.strip().lower(), name.strip()
    if not re.fullmatch(r"[0-9A-Za-z-]{1,40}", student_id):
        raise ValueError("Enter a valid student ID.")
    if not re.fullmatch(r"[^@\s]{1,100}@parsu\.edu\.ph", email):
        raise ValueError("Enter the student's @parsu.edu.ph email.")
    if not 1 <= len(name) <= 200 or not 12 <= len(password) <= 256:
        raise ValueError("A name and a password of 12 to 256 characters are required.")
    salt = secrets.token_bytes(16)
    with database(path) as db:
        db.execute("INSERT INTO students VALUES (?, ?, ?, ?, ?)",
                   (student_id, email, name, salt, password_hash(password, salt)))
        if grants is not None:
            db.execute("INSERT INTO staff_accounts VALUES (?)", (student_id,))
            db.executemany("INSERT INTO staff_grants VALUES (?, ?)",
                           ((student_id, grant) for grant in sorted(set(grants))))


def read_json(request, limit):
    try:
        length = int(request.get("CONTENT_LENGTH") or "0")
        if length > limit:
            raise ApiError("413 Payload Too Large", "The request is too large.")
        if length <= 0 or request.get("CONTENT_TYPE", "").split(";")[0] != "application/json":
            raise ValueError()
        data = json.loads(request["wsgi.input"].read(length))
        if not isinstance(data, dict):
            raise ValueError()
        return data
    except (ValueError, RecursionError):
        raise ApiError("400 Bad Request", "Invalid JSON request.") from None


def application(db, student_id):
    row = db.execute("SELECT * FROM applications WHERE student_id = ? ORDER BY id DESC LIMIT 1",
                     (student_id,)).fetchone()
    if row is None:
        return None
    return application_result(db, row)


def application_result(db, row, *, staff=False):
    policy = requirement_policy(db, row["id"])
    details = json.loads(row["details"])
    documents = db.execute(
        "SELECT slot, filename FROM documents WHERE application_id = ?", (row["id"],))
    history = db.execute("""
        SELECT revision, status, actor, recorded_at, reason FROM application_events
        WHERE application_id = ? ORDER BY revision DESC
    """, (row["id"],)).fetchall()
    result = {
        "reference": row["reference"],
        "submittedAt": row["submitted_at"],
        "status": history[0]["status"] if history else "submitted",
        "revision": history[0]["revision"] if history else 0,
        "history": [
            {key: event[key] for key in event.keys() if staff or key != "actor"}
            for event in history
        ],
        "details": details,
        "requirementRevision": policy["revision"],
        "requiredDocuments": sorted(required_documents(details["ownership"], policy)),
        "documents": {doc["slot"]: doc["filename"] for doc in documents},
    }
    if staff:
        result["studentId"] = row["student_id"]
        result["verifiedDocuments"] = [
            item["slot"] for item in db.execute(
                "SELECT slot FROM document_checks WHERE application_id = ?", (row["id"],))
        ]
        result["possibleDuplicate"] = db.execute("""
            SELECT 1 FROM applications WHERE normalized_plate = ? AND cycle = ?
            AND active = 1 AND student_id <> ? LIMIT 1
        """, (row["normalized_plate"], row["cycle"], row["student_id"])).fetchone() is not None
    if result["status"] in {"readyForRelease", "released"}:
        pickup = db.execute(
            "SELECT location, hours FROM pickup_instructions WHERE application_id = ?",
            (row["id"],),
        ).fetchone()
        if pickup:
            result["pickup"] = dict(pickup)
    return result


def requirement_policy(db, application_id=None):
    if application_id is not None:
        return db.execute("""
            SELECT revision, photo_required FROM requirement_policies p
            JOIN application_policies a ON a.policy_revision = p.revision
            WHERE a.application_id = ?
        """, (application_id,)).fetchone()
    return db.execute("SELECT * FROM requirement_policies ORDER BY revision DESC LIMIT 1").fetchone()


def required_documents(ownership, policy):
    required = REQUIRED | OWNER_DOCUMENTS if ownership == "notOwned" else REQUIRED
    return required | {"Motorcycle photo"} if policy["photo_required"] else required


TRANSITIONS = {
    ("submitted", "documentsReceived"): "review",
    ("documentsReceived", "underReview"): "review",
    ("underReview", "approved"): "decide",
    ("underReview", "rejected"): "decide",
    ("underReview", "needsCorrection"): "review",
    ("approved", "readyForRelease"): "release",
    ("readyForRelease", "released"): "release",
}


def permissions(db, account):
    return {row["permission"] for row in db.execute(
        "SELECT permission FROM staff_grants WHERE account_id = ?", (account,))}


def require_grant(grants, *allowed):
    if not grants.intersection(allowed):
        raise ApiError("403 Forbidden", "Your account cannot perform this action.")


def staff_application(db, row, grants):
    item = application_result(db, row, staff=True)
    if "review" not in grants:
        item.pop("documents")
    if grants.isdisjoint({"review", "decide"}):
        fields = {"reference", "studentId", "status", "revision", "submittedAt"}
        if "release" in grants:
            fields.update({"pickup", "history"})
            item["history"] = [
                event for event in item["history"]
                if event["status"] in {"readyForRelease", "released"}
            ]
        item = {key: value for key, value in item.items() if key in fields}
    return item


def staff_request(db, request, account, route):
    method, path = route
    if method == "POST":
        db.execute("BEGIN IMMEDIATE")
    grants = permissions(db, account)
    require_grant(grants, "review", "decide", "release", "manage")
    if route in (("GET", "/staff/requirements"), ("POST", "/staff/requirements")):
        require_grant(grants, "manage")
        policy = requirement_policy(db)
        if method == "POST":
            value = read_json(request, 4096).get("photoRequired")
            if type(value) is not bool:
                raise ApiError("400 Bad Request", "Specify whether a motorcycle photo is required.")
            if value != bool(policy["photo_required"]):
                db.execute("INSERT INTO requirement_policies VALUES (?, ?)",
                           (policy["revision"] + 1, int(value)))
                policy = requirement_policy(db)
        return {"revision": policy["revision"], "photoRequired": bool(policy["photo_required"])}
    if route in (("GET", "/staff/pickup"), ("POST", "/staff/pickup")):
        require_grant(grants, "manage")
        if method == "POST":
            payload = read_json(request, 4096)
            values = [payload.get(key) for key in ("location", "hours")]
            if any(not isinstance(value, str) or not 1 <= len(value.strip()) <= 200
                   or SURROGATE.search(value) for value in values):
                raise ApiError("400 Bad Request", "Enter a pickup location and office hours.")
            db.execute("INSERT INTO pickup_settings VALUES (1, ?, ?) ON CONFLICT(id) DO UPDATE SET location = excluded.location, hours = excluded.hours",
                       tuple(value.strip() for value in values))
        settings = db.execute("SELECT location, hours FROM pickup_settings WHERE id = 1").fetchone()
        return dict(settings) if settings else {}
    if route in (("GET", "/staff/accounts"), ("POST", "/staff/accounts")):
        require_grant(grants, "manage")
        if method == "POST":
            payload = read_json(request, 4096)
            target = payload.get("account")
            grant = payload.get("grant")
            enabled = payload.get("enabled")
            if (not isinstance(target, str) or grant not in STAFF_PERMISSIONS
                    or type(enabled) is not bool or target == account or grant == "manage"):
                raise ApiError("400 Bad Request", "Select a different staff account and an operational grant.")
            if not db.execute("SELECT 1 FROM staff_accounts WHERE account_id = ?", (target,)).fetchone():
                raise ApiError("404 Not Found", "Staff account not found.")
            if enabled:
                db.execute("INSERT OR IGNORE INTO staff_grants VALUES (?, ?)", (target, grant))
            else:
                db.execute("DELETE FROM staff_grants WHERE account_id = ? AND permission = ?",
                           (target, grant))
        accounts = db.execute("""
            SELECT students.id, students.name FROM staff_accounts JOIN students
            ON staff_accounts.account_id = students.id ORDER BY students.id
        """).fetchall()
        return {"accounts": [{**dict(row), "permissions": sorted(permissions(db, row["id"]))}
                             for row in accounts]}
    if route == ("GET", "/staff/applications"):
        if "release" in grants and grants.isdisjoint({"review", "decide"}):
            rows = db.execute("""
                SELECT a.* FROM applications a JOIN application_events e ON e.application_id = a.id
                WHERE e.revision = (SELECT MAX(revision) FROM application_events WHERE application_id = a.id)
                AND e.status IN ('approved', 'readyForRelease', 'released') ORDER BY a.id DESC
            """)
        else:
            rows = db.execute("SELECT * FROM applications ORDER BY id DESC")
        return {"applications": [staff_application(db, row, grants) for row in rows]}
    match = re.fullmatch(r"/staff/applications/([A-Z0-9-]+)(?:/(verify|transition|document))?", path)
    if match is None:
        raise ApiError("404 Not Found", "Resource not found.")
    reference, action = match.groups()
    if action in {"document", "verify"}:
        require_grant(grants, "review")
    if action == "transition":
        require_grant(grants, "review", "decide", "release")
    row = db.execute("SELECT * FROM applications WHERE reference = ?", (reference,)).fetchone()
    if row is None:
        raise ApiError("404 Not Found", "Application not found.")
    current = application_result(db, row, staff=True)
    if "release" in grants and grants.isdisjoint({"review", "decide"}) and current["status"] not in {
        "approved", "readyForRelease", "released"
    }:
        raise ApiError("404 Not Found", "Application not found.")
    if action is None and method == "GET":
        return {"application": staff_application(db, row, grants)}
    if action == "document" and method == "GET":
        slot = document_slot(request)
        document = db.execute("SELECT content FROM documents WHERE application_id = ? AND slot = ?",
                              (row["id"], slot)).fetchone()
        if document is not None:
            return document["content"]
        raise ApiError("404 Not Found", "Document not found.")
    if method != "POST" or action not in {"verify", "transition"}:
        raise ApiError("404 Not Found", "Resource not found.")
    payload = read_json(request, 4096)
    if type(payload.get("revision")) is not int or payload["revision"] != current["revision"]:
        raise ApiError("409 Conflict", "The application changed. Refresh and try again.")
    if action == "verify":
        slot = payload.get("slot")
        if current["status"] != "underReview" or not isinstance(slot, str) or slot not in current["documents"]:
            raise ApiError("400 Bad Request", "Select a document on an application under review.")
        db.execute("INSERT OR IGNORE INTO document_checks VALUES (?, ?, ?)",
                   (row["id"], slot, account))
    else:
        target = payload.get("status")
        grant = TRANSITIONS.get((current["status"], target)) if isinstance(target, str) else None
        if grant is None:
            raise ApiError("409 Conflict", "This status change is not allowed.")
        require_grant(grants, grant)
        reason = payload.get("reason")
        if target in {"rejected", "needsCorrection"}:
            if not isinstance(reason, str) or not 1 <= len(reason.strip()) <= 500 or SURROGATE.search(reason):
                raise ApiError("400 Bad Request", "Provide a student-visible reason.")
            reason = reason.strip()
        else:
            reason = None
        if target == "approved":
            if not set(current["requiredDocuments"]) <= set(current["verifiedDocuments"]):
                raise ApiError("409 Conflict", "Verify the required documents before approval.")
        if target == "readyForRelease":
            pickup = db.execute("SELECT location, hours FROM pickup_settings WHERE id = 1").fetchone()
            if pickup is None:
                raise ApiError("409 Conflict", "Ask a permit office administrator to configure pickup first.")
            db.execute("INSERT INTO pickup_instructions VALUES (?, ?, ?)",
                       (row["id"], pickup["location"], pickup["hours"]))
        if target == "released" and payload.get("identityConfirmed") is not True:
            raise ApiError("400 Bad Request", "Confirm the student's identity before recording pickup.")
        db.execute("INSERT INTO application_events VALUES (?, ?, ?, ?, ?, ?)", (
            row["id"], current["revision"] + 1, target, account,
            datetime.now(timezone.utc).isoformat(), reason,
        ))
        if target in {"rejected", "released"}:
            db.execute("UPDATE applications SET active = 0 WHERE id = ?", (row["id"],))
    return {"application": staff_application(db, row, grants)}


def valid_document(filename, content):
    if filename.lower().endswith(".pdf"):
        return content.startswith(b"%PDF-")
    if filename.lower().endswith((".jpg", ".jpeg")):
        return content.startswith(b"\xff\xd8\xff")
    if filename.lower().endswith(".png"):
        return content.startswith(b"\x89PNG\r\n\x1a\n")
    return False


def document_slot(request):
    try:
        return parse_qs(request.get("QUERY_STRING", ""), max_num_fields=8).get("slot", [""])[0]
    except ValueError:
        raise ApiError("400 Bad Request", "Invalid document request.") from None


def submit(db, student_id, request, cycle):
    existing = application(db, student_id)
    payload = read_json(request, MAX_REQUEST)
    new_application = payload.get("newApplication") is True
    request_key = payload.get("submissionKey")
    if request_key is not None and (
        not isinstance(request_key, str) or not re.fullmatch(r"[a-f0-9]{32}", request_key)
    ):
        raise ApiError("400 Bad Request", "Invalid submission key.")
    if new_application and request_key is None:
        raise ApiError("400 Bad Request", "A submission key is required for a new application.")
    if request_key and (retained := submission_for_key(db, student_id, request_key)):
        return application_result(db, retained)
    if existing is not None and existing["status"] != "needsCorrection" and not new_application:
        return existing
    correction_revision = payload.get("correctionRevision")
    if existing is not None and existing["status"] == "needsCorrection" and (
        type(correction_revision) is not int or correction_revision != existing["revision"]
    ):
        raise ApiError("409 Conflict", "Refresh the correction request before submitting.")
    details = payload.get("details")
    documents = payload.get("documents")
    if not isinstance(details, dict) or not isinstance(documents, dict):
        raise ApiError("400 Bad Request", "Application details and documents are required.")
    ownership = details.get("ownership")
    if ownership not in ("owned", "notOwned"):
        raise ApiError("400 Bad Request", "Select motorcycle ownership.")
    fields = FIELDS + ("ownerName",) if ownership == "notOwned" else FIELDS
    policy = requirement_policy(db)
    if existing is not None and existing["status"] == "needsCorrection":
        policy_id = db.execute("SELECT id FROM applications WHERE reference = ?",
                               (existing["reference"],)).fetchone()["id"]
        policy = requirement_policy(db, policy_id)
    required = required_documents(ownership, policy)
    if not required <= documents.keys() <= required | {"Motorcycle photo", "ID photocopy"}:
        raise ApiError("400 Bad Request", "Provide the required documents for this ownership.")
    values = {"ownership": ownership}
    for field in fields:
        value = details.get(field)
        if field == "address" and value in ("", None):
            continue
        if not isinstance(value, str) or not 1 <= len(value.strip()) <= 500 or SURROGATE.search(value):
            raise ApiError("400 Bad Request", f"Enter a valid value for {field}.")
        values[field] = value.strip()
    plate = normalize_plate(values["plateNo"])
    if not 1 <= len(plate) <= 24:
        raise ApiError("400 Bad Request", "Enter a valid motorcycle plate number.")

    files = []
    for slot, document in documents.items():
        try:
            filename = document["filename"]
            if not isinstance(filename, str) or not re.fullmatch(
                r"[^/\\\x00-\x1f\x7f\ud800-\udfff]{1,200}", filename
            ):
                raise ValueError()
            content = base64.b64decode(document["content"], validate=True)
            if not 0 < len(content) <= MAX_FILE or not valid_document(filename, content):
                raise ValueError()
        except (KeyError, TypeError, ValueError, binascii.Error):
            raise ApiError("400 Bad Request", f"{slot} must be a PDF, PNG or JPEG up to 5 MB.") from None
        files.append((slot, filename, content))

    db.execute("BEGIN IMMEDIATE")
    if request_key and (retained := submission_for_key(db, student_id, request_key)):
        return application_result(db, retained)
    existing = application(db, student_id)
    if existing is not None and existing["status"] == "needsCorrection":
        cycle = db.execute("SELECT cycle FROM applications WHERE reference = ?",
                           (existing["reference"],)).fetchone()["cycle"]
    duplicate = db.execute("""
        SELECT * FROM applications WHERE student_id = ? AND normalized_plate = ?
        AND cycle = ? AND active = 1
    """, (student_id, plate, cycle)).fetchone()
    if existing is not None and (
        not new_application or correction_revision is not None or existing["status"] == "needsCorrection"
    ):
        if existing["status"] != "needsCorrection":
            return existing
        if correction_revision != existing["revision"]:
            raise ApiError("409 Conflict", "Refresh the correction request before submitting.")
        row = db.execute("SELECT id FROM applications WHERE reference = ?",
                         (existing["reference"],)).fetchone()
        application_id = row["id"]
        db.execute("DELETE FROM document_checks WHERE application_id = ?", (application_id,))
        db.execute("DELETE FROM documents WHERE application_id = ?", (application_id,))
        db.executemany("INSERT INTO documents VALUES (?, ?, ?, ?)",
                       ((application_id, *file) for file in files))
        if duplicate is not None and duplicate["id"] != application_id:
            raise ApiError("409 Conflict", "An active request already exists for this plate.")
        db.execute("UPDATE applications SET details = ?, normalized_plate = ? WHERE id = ?",
                   (json.dumps(values), plate, application_id))
        db.execute("INSERT INTO application_events VALUES (?, ?, 'underReview', ?, ?, NULL)",
                   (application_id, correction_revision + 1, student_id,
                    datetime.now(timezone.utc).isoformat()))
        return application(db, student_id)
    if duplicate is not None:
        if request_key is not None:
            db.execute("INSERT INTO submission_keys VALUES (?, ?, ?)",
                       (student_id, request_key, duplicate["id"]))
        return application_result(db, duplicate)
    if policy["revision"] != requirement_policy(db)["revision"]:
        raise ApiError("409 Conflict", "Document requirements changed. Sign in again before submitting.")
    now = datetime.now(timezone(timedelta(hours=8)))
    reference = f"MS-{now.year}-{secrets.token_hex(12).upper()}"
    cursor = db.execute(
        """INSERT INTO applications
           (student_id, reference, submitted_at, details, cycle, normalized_plate, active)
           VALUES (?, ?, ?, ?, ?, ?, 1)""",
        (student_id, reference, now.isoformat(), json.dumps(values), cycle, plate))
    db.executemany("INSERT INTO documents VALUES (?, ?, ?, ?)",
                   ((cursor.lastrowid, *file) for file in files))
    db.execute("INSERT INTO application_events VALUES (?, 0, 'submitted', ?, ?, NULL)",
               (cursor.lastrowid, student_id, now.isoformat()))
    db.execute("INSERT INTO application_policies VALUES (?, ?)",
               (cursor.lastrowid, policy["revision"]))
    if request_key is not None:
        db.execute("INSERT INTO submission_keys VALUES (?, ?, ?)",
                   (student_id, request_key, cursor.lastrowid))
    return application(db, student_id)


def submission_for_key(db, student_id, request_key):
    return db.execute("""
        SELECT a.* FROM applications a JOIN submission_keys k ON k.application_id = a.id
        WHERE k.student_id = ? AND k.request_key = ?
    """, (student_id, request_key)).fetchone()


def handle(db, request, cycle=PILOT_CYCLE):
    route = (request["REQUEST_METHOD"], request["PATH_INFO"])
    if route == ("POST", "/sessions"):
        credentials = read_json(request, 4096)
        login, password = credentials.get("login"), credentials.get("password")
        if not isinstance(login, str) or not isinstance(password, str) or len(password) > 256:
            raise ApiError("400 Bad Request", "Enter your student ID or school email and password.")
        login = login.strip()
        if SURROGATE.search(login):
            raise ApiError("400 Bad Request", "Enter a valid student ID or email.")
        student = db.execute(
            "SELECT * FROM students WHERE id = ? OR email = ?", (login, login.lower())).fetchone()
        expected = student["password_hash"] if student else bytes(64)
        salt = student["salt"] if student else bytes(16)
        try:
            matches = hmac.compare_digest(password_hash(password, salt), expected)
        except UnicodeEncodeError:
            matches = False
        if not matches or student is None:
            raise ApiError("401 Unauthorized", "The student ID, email or password is incorrect.")
        token = secrets.token_urlsafe(32)
        now = int(time.time())
        db.execute("DELETE FROM sessions WHERE expires <= ?", (now,))
        db.execute("INSERT INTO sessions VALUES (?, ?, ?)",
                   (hashlib.sha256(token.encode()).digest(), student["id"], now + SESSION_SECONDS))
        return {
            "token": token,
            "student": {"id": student["id"], "name": student["name"]},
            "permissions": sorted(permissions(db, student["id"])),
            "photoRequired": bool(requirement_policy(db)["photo_required"]),
            "staff": db.execute("SELECT 1 FROM staff_accounts WHERE account_id = ?",
                                (student["id"],)).fetchone() is not None,
            "application": application(db, student["id"]),
        }

    auth = request.get("HTTP_AUTHORIZATION", "")
    if not re.fullmatch(r"Bearer [A-Za-z0-9_-]{43}", auth):
        raise ApiError("401 Unauthorized", "Sign in to continue.")
    digest = hashlib.sha256(auth.removeprefix("Bearer ").encode()).digest()
    session = db.execute("SELECT student_id FROM sessions WHERE digest = ? AND expires > ?",
                         (digest, int(time.time()))).fetchone()
    if session is None:
        raise ApiError("401 Unauthorized", "Your session has expired. Sign in again.")
    student_id = session["student_id"]
    if route == ("DELETE", "/sessions/current"):
        db.execute("DELETE FROM sessions WHERE digest = ?", (digest,))
        return {}
    if route[1].startswith("/staff/"):
        return staff_request(db, request, student_id, route)
    if db.execute("SELECT 1 FROM staff_accounts WHERE account_id = ?", (student_id,)).fetchone():
        raise ApiError("403 Forbidden", "Sign in with a student account.")
    if route == ("GET", "/application"):
        return {"application": application(db, student_id)}
    if route == ("GET", "/applications"):
        rows = db.execute("""
            SELECT a.reference, a.submitted_at AS submittedAt, e.status
            FROM applications a JOIN application_events e ON e.application_id = a.id
            WHERE a.student_id = ? AND e.revision = (
                SELECT MAX(revision) FROM application_events WHERE application_id = a.id
            ) ORDER BY a.id DESC
        """, (student_id,))
        return {"applications": [dict(row) for row in rows]}
    if route == ("POST", "/application"):
        return {"application": submit(db, student_id, request, cycle)}
    if route == ("GET", "/document"):
        slot = document_slot(request)
        file = db.execute("""
            SELECT documents.content FROM documents JOIN applications
            ON applications.id = documents.application_id
            WHERE applications.id = (
                SELECT id FROM applications WHERE student_id = ? ORDER BY id DESC LIMIT 1
            ) AND documents.slot = ?
        """, (student_id, slot)).fetchone()
        if file is not None:
            return file["content"]
    raise ApiError("404 Not Found", "Resource not found.")


def create_app(path, allowed_origin=None, *, cycle=PILOT_CYCLE):
    if not re.fullmatch(r"[a-zA-Z0-9_-]{1,48}", cycle):
        raise ValueError("Enter a valid synthetic permit cycle identifier.")
    initialize(path)

    def app(request, start_response):
        started = time.perf_counter()
        method = request["REQUEST_METHOD"]
        route = request["PATH_INFO"]
        category = {
            ("GET", "/healthz"): "readiness",
            ("POST", "/sessions"): "authentication",
            ("POST", "/application"): "submission",
            ("GET", "/application"): "tracking",
            ("GET", "/document"): "document",
        }.get((method, route), "staff" if route.startswith("/staff/") else "other")
        headers = [("Cache-Control", "no-store"), ("X-Content-Type-Options", "nosniff")]
        origin = request.get("HTTP_ORIGIN")
        if origin is not None and origin == allowed_origin:
            headers += [
                ("Access-Control-Allow-Origin", origin),
                ("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS"),
                ("Access-Control-Allow-Headers", "Authorization, Content-Type"),
                ("Vary", "Origin"),
            ]
        status = "200 OK"
        try:
            if (method, route) == ("GET", "/healthz"):
                with closing(sqlite3.connect(
                    Path(path).resolve().as_uri() + "?mode=ro", uri=True, timeout=2,
                )) as db:
                    db.execute("SELECT id FROM applications LIMIT 1").fetchone()
                result = {"status": "ready"}
            elif method == "OPTIONS" and origin and origin == allowed_origin:
                result = {}
            else:
                with database(path) as db:
                    result = handle(db, request, cycle)
        except ApiError as error:
            status, result = error.status, {"error": error.message}
        except sqlite3.Error:
            status, result = "503 Service Unavailable", {"error": "Storage is unavailable."}
        if isinstance(result, bytes):
            body = result
            headers += [("Content-Type", "application/octet-stream"),
                        ("Content-Disposition", "attachment")]
        else:
            body = json.dumps(result).encode()
            headers.append(("Content-Type", "application/json"))
        headers.append(("Content-Length", str(len(body))))
        REQUEST_LOG.log(
            logging.ERROR if status.startswith("5") else logging.INFO,
            "request category=%s status=%s duration_ms=%.1f",
            category, status[:3], (time.perf_counter() - started) * 1000,
        )
        start_response(status, headers)
        return [body]

    return app


class RedactedRequestHandler(WSGIRequestHandler):
    def log_request(self, code="-", size="-"):
        # The app emits aggregate-safe request fields.
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--db", default=os.environ.get("MOTOPASS_DB", "backend/local/motopass.sqlite3"))
    commands = parser.add_subparsers(dest="command", required=True)
    serve = commands.add_parser("serve")
    serve.add_argument("--port", type=int, default=8080)
    serve.add_argument("--origin")
    serve.add_argument("--cycle", default=PILOT_CYCLE)
    account = commands.add_parser("add-student")
    account.add_argument("student_id")
    account.add_argument("email")
    account.add_argument("name")
    staff = commands.add_parser("add-staff")
    staff.add_argument("student_id", metavar="account_id")
    staff.add_argument("email")
    staff.add_argument("name")
    staff.add_argument("grants", nargs="+", choices=STAFF_PERMISSIONS)
    args = parser.parse_args()
    os.umask(0o077)
    os.makedirs(os.path.dirname(os.path.abspath(args.db)), exist_ok=True)
    if args.command in ("add-student", "add-staff"):
        initialize(args.db)
        password = getpass.getpass("Password: ")
        if password != getpass.getpass("Confirm password: "):
            parser.error("Passwords do not match.")
        try:
            provision(args.db, args.student_id, args.email, args.name, password,
                      grants=getattr(args, "grants", None))
        except (ValueError, sqlite3.IntegrityError) as error:
            parser.error(str(error))
    else:
        logging.basicConfig(level=logging.INFO)
        with make_server(
            "127.0.0.1", args.port, create_app(args.db, args.origin, cycle=args.cycle),
            handler_class=RedactedRequestHandler,
        ) as server:
            print(f"MotoPass API listening on http://127.0.0.1:{args.port}", flush=True)
            server.serve_forever()


if __name__ == "__main__":
    main()
