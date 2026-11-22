import base64
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from io import BytesIO
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from urllib.parse import urlsplit
from wsgiref.util import setup_testing_defaults

from backend.recovery import copy_database
from backend.retention import synthetic_evidence_cleanup
from backend.server import FIELDS, REQUIRED, create_app, provision


class StudentApiTest(unittest.TestCase):
    def setUp(self):
        folder = TemporaryDirectory()
        self.addCleanup(folder.cleanup)
        self.path = Path(folder.name) / "test.sqlite3"
        self.app = create_app(self.path)
        self.password = "test-only-passphrase"
        provision(self.path, "123", "one@parsu.edu.ph", "Student One", self.password)
        provision(self.path, "456", "two@parsu.edu.ph", "Student Two", self.password)

    def request(self, method, path, body=None, token=None):
        route = urlsplit(path)
        request = {}
        setup_testing_defaults(request)
        request.update(REQUEST_METHOD=method, PATH_INFO=route.path, QUERY_STRING=route.query)
        if body is not None:
            data = json.dumps(body).encode()
            request.update(CONTENT_LENGTH=str(len(data)), CONTENT_TYPE="application/json")
            request["wsgi.input"] = BytesIO(data)
        if token:
            request["HTTP_AUTHORIZATION"] = f"Bearer {token}"
        response = {}

        def start(status, headers):
            response.update(status=int(status.split()[0]), headers=dict(headers))

        content = b"".join(self.app(request, start))
        if response["headers"]["Content-Type"] == "application/json":
            content = json.loads(content)
        return response["status"], content

    def sign_in(self, login):
        status, data = self.request("POST", "/sessions", {
            "login": login, "password": self.password,
        })
        self.assertEqual(status, 200)
        return data

    def test_private_atomic_submission_survives_restart_and_retry(self):
        self.assertEqual(self.request("GET", "/application")[0], 401)
        self.assertEqual(self.request("POST", "/sessions", {
            "login": "123", "password": "wrong",
        })[0], 401)
        first = self.sign_in("123")["token"]
        second = self.sign_in("TWO@parsu.edu.ph")["token"]
        payload = {
            "student_id": "456",
            "details": {**dict.fromkeys(FIELDS, "example"), "ownership": "owned"},
            "documents": {},
        }
        self.assertEqual(self.request("POST", "/application", payload, first)[0], 400)
        self.assertEqual(self.request("GET", "/application", token=first)[1],
                         {"application": None})
        pdf = b"%PDF-1.7 test"
        payload["documents"] = {
            slot: {"filename": "document.pdf", "content": base64.b64encode(pdf).decode()}
            for slot in REQUIRED
        }
        payload["details"]["ownership"] = "notOwned"
        self.assertEqual(self.request("POST", "/application", payload, first)[0], 400)
        payload["details"]["ownership"] = "owned"

        def submit():
            status, result = self.request("POST", "/application", payload, first)
            self.assertEqual(status, 200)
            return result["application"]["reference"]

        with ThreadPoolExecutor(max_workers=2) as pool:
            attempts = [pool.submit(submit) for _ in range(2)]
            reference, retried = [attempt.result() for attempt in attempts]
        self.assertEqual(reference, retried)
        self.assertRegex(reference, r"^MS-\d{4}-[A-F0-9]{24}$")
        self.app = create_app(self.path)
        restored = self.sign_in("one@parsu.edu.ph")["application"]
        self.assertEqual(restored["reference"], reference)
        self.assertEqual(self.request("GET", "/application", token=second)[1],
                         {"application": None})
        document = "/document?slot=Student+ID&student_id=123"
        self.assertEqual(self.request("GET", document, token=second)[0], 404)
        self.assertEqual(self.request("GET", document, token=first), (200, pdf))
        other = self.request("POST", "/application", payload, second)[1]
        self.assertNotEqual(other["application"]["reference"], reference)
        self.assertEqual(self.request("DELETE", "/sessions/current", token=first)[0], 200)
        self.assertEqual(self.request("GET", document, token=first)[0], 401)

    def test_pilot_restores_documents_and_discards_old_sessions(self):
        original = self.app
        token = self.sign_in("123")["token"]
        document = b"%PDF-1.7 recovery fixture"
        payload = {
            "details": {**dict.fromkeys(FIELDS, "fixture"), "ownership": "owned"},
            "documents": {
                slot: {"filename": "fixture.pdf", "content": base64.b64encode(document).decode()}
                for slot in REQUIRED
            },
        }
        status, result = self.request("POST", "/application", payload, token)
        self.assertEqual(status, 200)
        reference = result["application"]["reference"]
        snapshot = self.path.with_name("snapshot.sqlite3")
        restored = self.path.with_name("restored.sqlite3")
        copy_database(self.path, snapshot)
        copy_database(snapshot, restored, restore=True)
        with self.assertRaises(FileExistsError):
            copy_database(snapshot, self.path, restore=True)

        self.app = create_app(restored)
        self.assertEqual(self.request("GET", "/healthz"), (200, {"status": "ready"}))
        self.assertEqual(self.request("GET", "/application", token=token)[0], 401)
        learner = self.sign_in("123")
        self.assertEqual(learner["application"]["reference"], reference)
        query = "/document?slot=Student+ID&credential=synthetic-secret"
        with self.assertLogs("motopass.requests", "INFO") as logs:
            self.assertEqual(self.request("GET", query, token=learner["token"]), (200, document))
        self.assertRegex(logs.output[0], r"category=document status=200 duration_ms=")
        self.assertNotIn("synthetic-secret", logs.output[0])
        self.assertNotIn(learner["token"], logs.output[0])
        stranger = self.sign_in("456")
        self.assertEqual(self.request("GET", query, token=stranger["token"])[0], 404)

        # Switch back to the original intact database in this isolated drill.
        self.app = original
        self.assertEqual(self.request("GET", query, token=token), (200, document))
        self.app = create_app(restored.with_name("readiness.sqlite3"))
        restored.with_name("readiness.sqlite3").unlink()
        with self.assertLogs("motopass.requests", "ERROR") as logs:
            self.assertEqual(self.request("GET", "/healthz")[0], 503)
        self.assertIn("category=readiness status=503", logs.output[0])

    def test_requirement_change_preserves_submitted_revision(self):
        provision(self.path, "manager", "manager@parsu.edu.ph", "Sample Manager",
                  self.password, grants=["manage"])
        first = self.sign_in("123")["token"]
        second = self.sign_in("456")["token"]
        manager = self.sign_in("manager")["token"]
        payload = {
            "details": {**dict.fromkeys(FIELDS, "example"), "ownership": "owned"},
            "documents": {
                slot: {"filename": "document.pdf",
                       "content": base64.b64encode(b"%PDF-1.7 synthetic").decode()}
                for slot in REQUIRED
            },
        }
        expected = self.request("POST", "/application", payload, first)[1]["application"]
        self.assertEqual(expected["requirementRevision"], 1)
        endpoint = "/staff/requirements"
        self.assertEqual(self.request("POST", endpoint, {"photoRequired": True}, first)[0], 403)
        self.assertEqual(self.request("POST", endpoint, {"photoRequired": True}, manager),
                         (200, {"revision": 2, "photoRequired": True}))
        self.assertEqual(self.request("POST", "/application", payload, second)[0], 400)
        payload["documents"]["Motorcycle photo"] = {
            "filename": "photo.png",
            "content": base64.b64encode(b"\x89PNG\r\n\x1a\nsynthetic").decode(),
        }
        result = self.request("POST", "/application", payload, second)[1]["application"]
        self.assertEqual(result["requirementRevision"], 2)
        self.assertIn("Motorcycle photo", result["requiredDocuments"])
        original = self.request("GET", "/application", token=first)[1]["application"]
        self.assertEqual(original["requiredDocuments"], expected["requiredDocuments"])

    def test_staff_grants_review_and_single_pickup(self):
        for account, grants in (("reviewer", ["review"]), ("decider", ["decide"]),
                                ("releaser", ["release"]), ("manager", ["manage"])):
            provision(self.path, account, f"{account}@parsu.edu.ph", account,
                      self.password, grants=grants)
        student = self.sign_in("123")["token"]
        reviewer = self.sign_in("reviewer")["token"]
        decider = self.sign_in("decider")["token"]
        releaser = self.sign_in("releaser")["token"]
        manager = self.sign_in("manager")["token"]
        pdf = b"%PDF-1.7 synthetic"
        payload = {
            "details": {**dict.fromkeys(FIELDS, "example"), "ownership": "owned"},
            "documents": {
                slot: {"filename": "document.pdf", "content": base64.b64encode(pdf).decode()}
                for slot in REQUIRED
            },
        }
        _, result = self.request("POST", "/application", payload, student)
        path = f"/staff/applications/{result['application']['reference']}"

        def transition(token, revision, status, **extra):
            return self.request("POST", f"{path}/transition",
                                {"revision": revision, "status": status, **extra}, token)[0]

        self.assertEqual(transition(student, 0, "documentsReceived"), 403)
        self.assertEqual(self.request("GET", f"{path}/document?slot=Student+ID", token=reviewer), (200, pdf))
        self.assertEqual(self.request("GET", f"{path}/document?slot=Student+ID", token=releaser)[0], 403)
        self.assertEqual(transition(reviewer, 0, "documentsReceived"), 200)
        self.assertEqual(transition(reviewer, 1, "underReview"), 200)
        self.assertEqual(transition(decider, 2, "approved"), 409)
        self.assertEqual(transition(decider, 2, "rejected", reason=" "), 400)
        self.assertEqual(transition(reviewer, 2, "needsCorrection", reason="Retake ID"), 200)
        self.assertEqual(self.request("GET", "/application", token=student)[1]
                         ["application"]["history"][0]["reason"], "Retake ID")
        self.assertEqual(self.request("POST", "/application", payload, student)[0], 409)
        payload["correctionRevision"] = 3
        status, corrected = self.request("POST", "/application", payload, student)
        self.assertEqual(status, 200)
        self.assertEqual(corrected["application"]["reference"], result["application"]["reference"])
        for slot in REQUIRED:
            self.assertEqual(self.request("POST", f"{path}/verify",
                                          {"revision": 4, "slot": slot}, reviewer)[0], 200)
        self.assertEqual(transition(reviewer, 4, "approved"), 403)
        self.assertEqual(transition(decider, 4, "approved"), 200)
        self.assertEqual(transition(decider, 4, "rejected", reason="Synthetic"), 409)
        self.assertEqual(transition(releaser, 5, "readyForRelease"), 409)
        settings = {"location": "Synthetic desk", "hours": "Monday 08:00–12:00"}
        self.assertEqual(self.request("POST", "/staff/pickup", settings, reviewer)[0], 403)
        self.assertEqual(self.request("POST", "/staff/pickup", settings, manager), (200, settings))
        self.assertEqual(transition(releaser, 5, "readyForRelease"), 200)
        self.assertEqual(self.request("GET", "/application", token=student)[1]
                         ["application"]["pickup"], settings)
        self.assertEqual(transition(releaser, 6, "released"), 400)
        updated_settings = {**settings, "location": "New desk"}
        self.assertEqual(self.request("POST", "/staff/pickup", updated_settings, manager)[0], 200)
        with ThreadPoolExecutor(max_workers=2) as pool:
            pickups = list(pool.map(
                lambda _: transition(releaser, 6, "released", identityConfirmed=True),
                range(2),
            ))
        self.assertEqual(sorted(pickups), [200, 409])
        self.app = create_app(self.path)
        code, staff_record = self.request("GET", path, token=releaser)
        self.assertEqual(code, 200)
        self.assertEqual(staff_record["application"]["history"][0]["actor"], "releaser")
        self.assertNotIn("documents", staff_record["application"])
        _, result = self.request("GET", "/application", token=student)
        current = result["application"]
        self.assertEqual(current["status"], "released")
        self.assertEqual(current["pickup"], settings)
        self.assertEqual(current["history"][0]["status"], "released")
        self.assertTrue(current["history"][0]["recorded_at"])
        self.assertEqual(len(current["history"]), 8)
        self.assertNotIn("actor", current["history"][0])
        payload.pop("correctionRevision")
        payload["newApplication"] = True
        payload["submissionKey"] = "a" * 32
        payload["details"]["plateNo"] = "DEMO 123"
        status, retry_application = self.request("POST", "/application", payload, student)
        self.assertEqual(status, 200)
        new_reference = retry_application["application"]["reference"]
        self.assertNotEqual(new_reference, current["reference"])
        payload["details"]["plateNo"] = "demo-123"
        payload["submissionKey"] = "b" * 32
        self.assertEqual(self.request("POST", "/application", payload, student)[1]
                         ["application"]["reference"], new_reference)
        previous = self.request("GET", "/applications", token=student)[1]["applications"]
        self.assertEqual([row["status"] for row in previous], ["submitted", "released"])
        other = self.sign_in("456")["token"]
        self.assertEqual(self.request("GET", "/applications", token=other)[1]["applications"], [])
        self.assertEqual(self.request("POST", "/application", payload, other)[0], 200)
        queue = self.request("GET", "/staff/applications", token=reviewer)[1]["applications"]
        self.assertEqual(sum(item["possibleDuplicate"] for item in queue), 2)
        policy = {"age": timedelta(days=1), "now": datetime.now(timezone.utc) + timedelta(days=2)}
        closed = current["reference"]
        snapshot = self.path.with_name("before-retention.sqlite3")
        restored = self.path.with_name("restored-retention.sqlite3")
        copy_database(self.path, snapshot)
        self.assertEqual(synthetic_evidence_cleanup(self.path, **policy), [closed])
        self.assertEqual(synthetic_evidence_cleanup(
            self.path, **policy, held_references=[closed], apply=True), [])
        self.assertEqual(self.request("GET", f"/staff/applications/{closed}/document?slot=Student+ID",
                                      token=reviewer)[0], 200)
        self.assertEqual(synthetic_evidence_cleanup(self.path, **policy, apply=True), [closed])
        self.assertEqual(self.request("GET", f"/staff/applications/{closed}/document?slot=Student+ID",
                                      token=reviewer)[0], 404)
        self.assertEqual(synthetic_evidence_cleanup(self.path, **policy), [])
        copy_database(snapshot, restored, restore=True)
        self.assertEqual(synthetic_evidence_cleanup(restored, **policy, apply=True), [closed])
        self.assertEqual(synthetic_evidence_cleanup(restored, **policy), [])
        path = f"/staff/applications/{new_reference}"
        self.assertEqual(transition(reviewer, 0, "documentsReceived"), 200)
        self.assertEqual(transition(reviewer, 1, "underReview"), 200)
        self.assertEqual(transition(decider, 2, "rejected", reason="Invalid synthetic registration"), 200)
        self.assertEqual(self.request("POST", "/application", payload, student)[1]
                         ["application"]["status"], "rejected")
        self.assertEqual(self.request("GET", "/application", token=student)[1]
                         ["application"]["history"][0]["reason"], "Invalid synthetic registration")
        revoke = {"account": "releaser", "grant": "release", "enabled": False}
        self.assertEqual(self.request("POST", "/staff/accounts", revoke, reviewer)[0], 403)
        self.assertEqual(self.request("POST", "/staff/accounts", revoke, manager)[0], 200)
        self.assertEqual(self.request("GET", "/staff/applications", token=releaser)[0], 403)
        self.assertEqual(self.request("GET", "/application", token=releaser)[0], 403)


if __name__ == "__main__":
    unittest.main()
