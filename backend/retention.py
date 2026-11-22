"""Configurable evidence cleanup for disposable synthetic pilot databases."""

from datetime import datetime, timedelta, timezone

from backend.server import database


def synthetic_evidence_cleanup(path, *, age, held_references=(), apply=False, now=None):
    """Report expired evidence or remove it from a synthetic test database.

    Application records and event history are kept. The caller supplies the
    policy, including case holds. There is no automatic production schedule.
    """
    if not isinstance(age, timedelta) or age <= timedelta(0):
        raise ValueError("Supply a positive synthetic evidence lifetime.")
    now = now or datetime.now(timezone.utc)
    if now.utcoffset() is None:
        raise ValueError("Supply a timezone-aware clock.")
    cutoff = now - age
    protected = set(held_references)
    with database(path) as db:
        if apply:
            db.execute("BEGIN IMMEDIATE")
        rows = db.execute("""
            SELECT a.id, a.reference, e.recorded_at
            FROM applications a JOIN application_events e ON e.application_id = a.id
            WHERE a.active = 0 AND e.revision = (
                SELECT MAX(revision) FROM application_events WHERE application_id = a.id
            ) AND EXISTS (SELECT 1 FROM documents WHERE application_id = a.id)
            ORDER BY a.id
        """)
        expired = [
            row for row in rows
            if row["reference"] not in protected
            and datetime.fromisoformat(row["recorded_at"]) <= cutoff
        ]
        if apply:
            identifiers = [(row["id"],) for row in expired]
            db.executemany("DELETE FROM document_checks WHERE application_id = ?", identifiers)
            db.executemany("DELETE FROM documents WHERE application_id = ?", identifiers)
        return [row["reference"] for row in expired]
