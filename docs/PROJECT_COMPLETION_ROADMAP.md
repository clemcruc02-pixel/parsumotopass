# ParSU MotoPass completion roadmap

Use the [audit](PROJECT_AUDIT.md) for the original evidence baseline, the [tracker](PROJECT_PROGRESS_TRACKER.md) for current status, and the [release checklist](PRODUCTION_READINESS_CHECKLIST.md) for sign-off. Synthetic implementation follows the [recommended pilot baseline](CAMPUS_OPERATING_RULES.md). Campus authorization is pending. Sizes are relative. S is a small change with focused verification, M crosses several components, and L contains multiple integration steps.

## P1 — Recover the Flutter baseline

**Objective.** Establish a reproducible build and preserve the existing screen flows.

**Current state.** The Flutter launcher and widget tests exist. The duplicate incomplete declaration stops compilation. The installed Dart version satisfies the project constraint. Flutter runtime and clean Android builds are unverified.

| ID | Task and implementation order | Depends on | Priority / size |
| --- | --- | --- | --- |
| P1-T01 | Delete the stray unfinished declaration at ../lib/main.dart:27. Preserve the complete MotopassApp and LoginScreen. Work through toolchain startup separately if it prevents confirmation. | Implementation approval | Critical / S |
| P1-T02 | Pin and record the working Flutter and Android toolchain. In a clean checkout verify package resolution, wrapper provisioning, package/activity alignment and Android debug installation. Add CI for analysis, tests and debug builds. Resolve verified clean-build failures with minimal changes. | P1-T01 | High / M |
| P1-T03 | Stabilize ../test/widget_test.dart by isolating state per test and using deterministic viewport/scroll interactions. Retain the two existing journeys and cover both ownership branches, required inputs, edit/back navigation and logout isolation. | P1-T01 | High / M |

**Validation and exit.** Run dart format --output=none lib/main.dart, flutter pub get, flutter analyze, flutter test and flutter build apk --debug. Run the full tests twice in isolation and as a suite. Install the debug build on an Android emulator or device. The app launches, both preserved journeys pass, and a clean checkout can reproduce the baseline. Risk is SDK/Gradle drift and prototype test coupling. Keep signing outside this phase.

## P2 — Confirm policy and establish durable service boundaries

**Objective.** Make identity, application ownership and access policy enforceable before accepting documents.

**Current state.** SQLite-backed sessions and student/staff grants support provisioned synthetic accounts. Campus sign-in, formal migration/version policy and operational approval are pending.

| ID | Task and implementation order | Depends on | Priority / size |
| --- | --- | --- | --- |
| P2-T01 | Record campus approval for identity proof and recovery, reviewer/admin grants and revocation, security access scope, permissions matrix, one-active-request policy, legal status transitions including rejection and required reasons, document rules, pickup workflow, data minimization, retention, Android distribution, load and recovery targets. Confirm hosting and operating owners. | Campus owner availability | Critical / M |
| P2-T02 | Create the approved single application service, with a versioned API contract, disposable local database and migrations. Proposed entities are profile, role assignment, application, attachment, status event and notification. Add ownership foreign keys, unique reference, attachment uniqueness by request and type, required fields, status constraints and indexes for owner/status and paginated staff queue. Snapshot submitted details and requirement revision. Document timezone handling and migration strategy. | P1-T02, P2-T01 | Critical / L |
| P2-T03 | Integrate school-approved identity. Map stable provider subjects to internal student profiles, enforce roles and resource ownership in every service action, provision staff through an approved process, support session expiry, recovery and revocation. Add a Flutter session repository used by auth_screens.dart and guard entry/navigation in main.dart. Replace shared account state, keeping per-session drafts. Clear memory and approved local cache on logout and account switch. | P2-T02 | Critical / L |

**Validation and exit.** In disposable CI, apply migrations to empty and previous schemas with seeded synthetic data. Verify unique ownership and references, safe migration failure and restore. Run service and client integration tests for verified and rejected sign-ins, token expiry, revocation, role matrix and two-student isolation. Require campus sign-off and passing CI contract/auth/migration gates. Identity availability and institutional approvals may block service selection.

## P3 — Connect the student application flow

**Objective.** Persist a valid request and its evidence through app restarts and safe retries.

**Current state.** The service-backed flow accepts synthetic file bytes and uses atomic SQLite submission with per-plate and cycle uniqueness. The original simulated workflow remains available as a debug demo. Evidence cleanup is exercised in disposable databases. Campus retention policy, evidence scanning and device qualification remain open.

| ID | Task and implementation order | Depends on | Priority / size |
| --- | --- | --- | --- |
| P3-T01 | Implement canonical requirements by ownership and version. Connect apply_screens.dart and app_state.dart to typed draft/review data. Validate allowed fields, lengths and required inputs on both boundaries. Keep relevant state on back/edit; clear obsolete owner data when ownership changes. Show file-level review and recoverable errors. | P2-T02, P2-T03 | High / M |
| P3-T02 | Replace the fake picker with Android-tested camera/gallery/document handling. Use limited authenticated uploads to private storage, verify file type and size, quarantine until checked, permit authorized expiring reads, and clean up expired/orphaned uploads. Handle cancel, bad files, slow networks, denial, replacement and retries. | P3-T01 | Critical / L |
| P3-T03 | Implement atomic submit with server-issued unique reference, ownership and readiness validation, idempotency key and concurrency guard. Commit submission and initial history/notification event together. Show pending, error and confirmed states; resume persisted results on relaunch. Remove the production dependency on fake reference/status. | P3-T02 | Critical / L |

**Validation and exit.** Run unit tests for required documents and form normalization; contract and database integration tests for limits, duplicate/concurrent submission, persistence and failed-file finalization; device E2E for both ownership types, edit, reconnect and restart. Test private document access across roles and students. Verify two identical retries yield one committed record/reference, while a different request gets a distinct reference. Risk is inconsistent file metadata and object state when work fails partway.

## P4 — Enable staff decisions and student tracking

**Objective.** Carry each submitted request through authorized review, decision and pickup with a durable history.

**Current state.** Signed-in staff can record evidence checks, correction requests, decisions and pickup against persistent records. Students can refresh event history and pickup instructions. Campus operating approval and full device verification are pending.

| ID | Task and implementation order | Depends on | Priority / size |
| --- | --- | --- | --- |
| P4-T01 | Build the minimal authorized staff queue, filters, detail and evidence access using the approved client surface. Apply server-enforced transition matrix, reason requirements, optimistic concurrency, actor/timestamp audit and transactionally persisted events. Support necessary admin user/requirement/record operations. Add narrowly scoped security access only if approved. | P2-T03, P3-T03 | Critical / L |
| P4-T02 | Bind status_screens.dart, main_shell.dart and alerts to persisted events and approved pickup data. Display rejection with approved reason visibility, clear loading/error/empty states and update in-app notifications. Remove demo status controls from production surfaces. Apply staff-controlled ready/release policy and student visibility rules. | P4-T01 | Critical / M |

**Validation and exit.** Run role/ownership matrix, allowed and rejected transition, stale update and parallel reviewer tests. Run student-to-staff-to-student E2E for rejection and approved pickup. Every authorized transition has exactly one actor-stamped event visible to the appropriate audience, and student actions cannot change review outcomes. Risk is policy mismatch or disclosure of documents through staff views.

## P5 — Qualify and operate an Android-first pilot

**Objective.** Demonstrate operational readiness with synthetic data before approved pilot release.

**Current state.** Android scaffold uses debug release signing and an example application ID. There is no CI/CD, monitored service or proven recovery process.

| ID | Task and implementation order | Depends on | Priority / size |
| --- | --- | --- | --- |
| P5-T01 | In CI and isolated staging, run the complete test matrix in the readiness checklist. Lock dependencies and SDK, scan advisories and build artifacts, verify permission boundaries and redact logs. On representative Android hardware profile startup/forms/tracking and test TalkBack, large text, contrast, slow networks and upload memory/latency. Benchmark staff queue with approved peak fixtures and record thresholds and results. | P4-T02 | High / L |
| P5-T02 | Configure user-approved staging and release deployment with protected approvals, managed runtime secrets, private storage, health checks, redacted telemetry, alert routing and least-privilege runtime identities. Agree package ID before distribution, supply protected release signing manually, verify upgrade/install and build a signed AAB. Document setup, release and incident procedures. | P1-T02, P2-T01, P4-T02 | Critical / L |
| P5-T03 | Restore database and objects into isolated staging, verify referential consistency and meet agreed RPO/RTO. Drill service rollback and forward recovery of schema, keep prior clients compatible, run campus student/staff UAT and record sign-off, evidence, owners and go/no-go. | P5-T01, P5-T02 | Critical / M |

**Validation and exit.** Run flutter analyze, flutter test, the approved integration suite and flutter build appbundle --release with protected signing in release CI. Verify the installed artifact and staged endpoint health. Exercise queue failure, stalled uploads, restore and rollback. The release checklist is evidenced, campus and operations owners approve, and the team can stop or roll back pilot distribution. Risk is permission, signing, infrastructure and recovery coordination.

## Execution strategy

Likely critical path is P1-T01 → P1-T02 → P2-T02 → P2-T03 → P3-T01 → P3-T02 → P3-T03 → P4-T01 → P4-T02 → P5-T02 → P5-T03. Policy approval P2-T01 gates P2-T02 and may dominate calendar time. P1-T03 can proceed alongside tooling recovery after P1-T01. Draft policy, accessibility cases and synthetic fixtures can be prepared in parallel. P5-T01 and P5-T02 can run concurrently once workflows are ready. Measure the critical path again after service selection.

Keep the Flutter screens, shared widgets, ownership flow and existing behavior wherever compatible with the approved contract. Change demo behavior only through explicit production wiring and regression tests. Support deployed clients during API and schema changes using additive contracts and expand/migrate/contract steps where applicable. Use a checkpoint at each phase exit and log results by task ID.

## Optional follow-up

iOS or web student distribution, push/email delivery, campus security lookup beyond approved pilot scope, and advanced reporting can be assessed after pilot needs are confirmed. Any selected item must get its own scope, task IDs and release tests. Keep QR workflows and automated decisions outside the baseline.
