# ParSU MotoPass production readiness checklist

Use synthetic data until the applicable gates pass and campus approval is recorded. Attach CI run, environment, commit, signed artifact or drill evidence to the linked task in the [tracker](PROJECT_PROGRESS_TRACKER.md). The [roadmap](PROJECT_COMPLETION_ROADMAP.md) defines implementation and phase exits.

## Functionality and regression

- [ ] P1-T01–P1-T03. Analyze and test from a clean checkout; run existing Flutter widget journeys before changing service wiring. Test both ownership branches, required inputs, editing, navigation and logout isolation.
- [ ] P2-T03. On Android, verify enrollment, sign-in, session recovery/expiry, logout and account switching using test identities.
- [ ] P3-T01–P3-T03. Complete both ownership flows from requirements to persisted confirmation and restart. Verify invalid forms, missing evidence, cancel/deny picker, rejected/oversize files, replacement, retry and offline recovery.
- [ ] P4-T01–P4-T02. Exercise staff review, approval, rejection and pickup, plus history and student alerts. Record campus UAT feedback. Verify clear loading, empty and retry states.
- [ ] P5-T01. Test representative Android OS/device sizes, TalkBack, large text and contrast. Run unit, widget, service integration and cross-role E2E suites as release gates.

## Data integrity, privacy and security

- [ ] P2-T01. Approve role matrix, applicant eligibility, evidence requirements, retention/deletion, audit access, pickup and notification content. Record the data owner.
- [ ] P2-T02. Apply schema to an empty and previous-version database; verify uniqueness, required attributes, foreign keys and safe migration failure with disposable databases.
- [ ] P2-T03. Test unauthenticated, expired, revoked and wrong-role requests plus cross-student reads/writes and staff scoping. Verify logout clears private client state.
- [ ] P3-T02. Prove files remain private, rejected files cannot finalize, links expire, abandoned objects are collected and logs contain no document contents or private paths.
- [ ] P3-T03 and P4-T01. Verify idempotent submit, concurrent reviewers, allowed status changes, durable history and scoped notifications.
- [ ] P5-T01–P5-T02. Review dependency advisories, build provenance, TLS, permissions, redaction and least privilege. Run approved secret scanning against designated source and build outputs under the institution's process. Keep credentials in the approved deployment manager and supply them manually. Audit logs must omit student details, document URLs, credentials and session tokens.

## Performance and reliability

- [ ] P2-T01 and P5-T01. Approve startup and interaction latency, upload duration and memory, staff queue concurrency and error targets. Record p95 and failures for representative fixtures and slow networks.
- [ ] P5-T01. Test retry/backoff, request timeout, recovery after process termination, queue load and pagination. Confirm representative devices stay responsive.
- [ ] P5-T02. Alert on authentication and request failures, upload/storage issues, review delays and unavailability. Exercise routing to an acknowledged owner.

## Deployment, recovery and sign-off

- [ ] P5-T02. Pin reproducible toolchains and dependencies. Build signed Android release in protected CI. Verify the final package identifier, artifact, upgrade path, endpoint configuration, stage health and network access on a device.
- [ ] P5-T02. Document setup, local synthetic data, architecture, API/migrations, staff workflow, release and incident handling. Record staging and release ownership.
- [ ] P5-T03. Back up database and private objects with coordinated retention and encryption. Restore into isolated staging and verify application/attachment consistency. Record RPO and RTO results.
- [ ] P5-T03. Drill service rollback and compatible schema forward recovery. Verify deployed clients continue to function, and document distribution halt and recovery criteria.
- [ ] P5-T03. Campus and operational owners approve UAT, evidence, privacy controls and release. Record accountable on-call and go/no-go decision.
