# Android pilot verification

**Decision on 22 November 2026 — hold distribution.** Local checks used synthetic students and documents. The signed artifact, staging controls, Android device checks, and service rollback remain release gates.

The backend suite passed all four tests. Dart analysis, the nine Flutter tests and release workflow YAML validation passed, and a local debug APK built (re-checked 22 November 2026). Device checks remain blocked because no Android device or emulator is available, and the signing check needs the protected release secrets. No signed artifact was verified.

| Area | Evidence | Remaining gate |
| --- | --- | --- |
| Release signing | Removed the debug-key fallback. The manual release job builds an APK and AAB and gates artifact upload on signature verification and comparison with the approved certificate fingerprint. The APK is also checked against the configured package ID. | Configure the protected `pilot-signing` GitHub environment, run the workflow, and verify installation and upgrade on Android. Supply the approved package ID, certificate fingerprint, and HTTPS staging endpoint through environment variables. |
| Security | Local API tests covered two-student isolation, staff grants, document privacy, sign-out, rejection of old sessions after restore, and duplicate-safe submission. Android app-data backup is disabled. | Scan the release inputs and artifacts for advisories and embedded secrets. Check staging TLS, rate limits, filesystem access, storage encryption, production proxy logging, and sign-in against approved accounts. |
| Accessibility | Shared back and alerts controls have spoken labels. Shared primary actions have a 48 dp minimum height and can grow for larger text. The Flutter test checks labels and Android tap targets at 200% text scaling. | Run the widget suite and verify the full student and staff journeys with TalkBack, large text, focus order, contrast, and error announcements on a representative phone. |
| Performance | Ten serial, in-process samples per route. p95 was **523 ms** for sign-in, **1,737 ms** for a submission with six 5 MiB attachments, and **12 ms** for tracking. All samples succeeded. Submission timings include local JSON encoding and SQLite writes. | Approve targets, then measure startup, frame timing, peak memory, queue load, and upload recovery under representative staging concurrency and network conditions. Local timings exclude network and Android device overhead. |
| Monitoring | `GET /healthz` returned 200 with an available database and 503 after the synthetic database was removed. Tests checked request logs for a fixed category, status, and elapsed time, with credentials and query strings excluded. | Configure synthetic HTTPS probes, collect application logs, and exercise alert delivery to the on-call owner. Cover probe failures, elevated 5xx, slow submissions, and stale backups. Match proxy and WSGI access-log redaction to the API logs. |
| Backup restoration | Took an SQLite snapshot, verified SQLite integrity and foreign keys, restored to a separate file, and confirmed the original reference, exact attachment bytes, ownership, and fresh sign-in. Restore refused to overwrite the source. | Repeat on isolated staging storage using the scheduled encrypted backup, and measure accepted RPO and RTO against campus targets. Validate retention and permissions after recovery. |
| Rollback | The isolated drill switched from the original database to the restored copy and back, with the original copy intact. | Run a service-version rollback against a staging database with post-deploy writes. Verify the earlier artifact, schema compatibility, and installed Android client behavior. The current Git baseline predates the backend and cannot supply a prior compatible deployment. |

## Sign and verify

Configure the protected GitHub environment with required reviewers. Set `MOTOPASS_APPLICATION_ID`, `MOTOPASS_PILOT_API_URL`, and `MOTOPASS_SIGNING_CERT_SHA256` as environment variables. Supply `MOTOPASS_KEYSTORE_BASE64`, `MOTOPASS_STORE_PASSWORD`, `MOTOPASS_KEY_ALIAS`, and `MOTOPASS_KEY_PASSWORD` through its secret manager. Use the campus-approved signing certificate SHA-256 fingerprint. The manual workflow runs from `main` and produces artifacts for review. Record the source commit, version code, package ID, and checksums. If using Play App Signing, also verify the certificate on a Play-delivered APK and test upgrade through the intended internal track. [Flutter Android release documentation](https://docs.flutter.dev/deployment/android)

## Restore and validate

With the synthetic local API configured as in the README, run the following commands from the repository root. Use new filenames on each run.

```sh
python -m unittest backend.test_server -v
python -m backend.recovery backup backend/local/motopass.sqlite3 backend/local/snapshot.sqlite3
python -m backend.recovery restore backend/local/snapshot.sqlite3 backend/local/restored.sqlite3
python backend/server.py --db backend/local/restored.sqlite3 serve --port 8081
```

The snapshot uses SQLite's online backup API and includes attachment bytes. Restore invalidates copied sessions. Keep snapshots on access-controlled, encrypted storage. Before a restored database serves real traffic, reconcile any post-snapshot account or grant revocations, record deletions, and accepted submissions. Measure RPO from the latest recoverable transaction and RTO from detection through a successful application and document smoke test. [SQLite Online Backup API](https://www.sqlite.org/backup.html)

## Stage the rollback

1. Record the previous verified service revision, package version, database schema assumptions, and deployment settings. Preserve both service artifacts.
2. Halt distribution and pause writes if an incompatible release or data-integrity problem is suspected. Take a fresh snapshot and preserve the failed state for reconciliation.
3. Prefer reverting the service artifact while keeping the current database when compatibility has been demonstrated. For an incompatible database, rehearse forward recovery or an isolated restore and reconcile changes before redirecting traffic.
4. Confirm readiness, fresh student sign-in, existing reference and attachment access, staff grants, and a duplicate-safe submission. Confirm the already-installed Android build works against the restored service. For Android recovery, prepare the known-good code as a build signed with the approved key and a higher version code if a replacement update is needed.
5. Record the recovered revision, observed data loss and downtime, alert acknowledgement, and the campus decision to reopen traffic.
