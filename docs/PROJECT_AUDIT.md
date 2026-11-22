# ParSU MotoPass project audit

## Assessment

ParSU MotoPass is an Android-first Flutter prototype for student motorcycle sticker requests. Its screens model requirements, ownership-specific applications, review, tracking, alerts and pickup. The release objective includes durable records, verified student identity and authorized staff who review documents and approve or reject applications. The campus retains control of approval and sticker issuance.

Evidence baseline is local main at 685076b, matching the local origin/main reference. Two commits are visible, 988a628 and 685076b. No tracked changes were present at audit start. Existing untracked items included .vscode/settings.json and graphify-out/. No remote fetch or live service inspection was performed. Graphify mapped relationships, then the tracked source and configuration were used to validate findings. The requirements baseline is [the existing project design](MIDPROJ_Cleofe-Surname2_BSCS3A.md), especially scope, roles, functional requirements and student flow. The README is still Flutter boilerplate. The repository has no separate tracked PRD, API contract, backend, migrations, CI workflow or operational runbook. Existing platform assets and generated tooling were assessed from tracked configuration and entry points. Restricted workspace paths and secret files were outside inspection scope.

## Architecture and dependencies

| Area | Evidence | Finding |
| --- | --- | --- |
| Entry and composition | ../lib/main.dart:8–27 | MaterialApp starts at LoginScreen and uses the existing theme. Line 27 is a second, unfinished declaration of MotopassApp and prevents parsing. |
| Navigation and presentation | ../lib/screens/main_shell.dart:11,82,260 and ../lib/widgets/common.dart | Imperative routes, home/application tabs, shared form controls and a consistent theme. Preserve the UI and route semantics where security permits. |
| Business state | ../lib/data/app_state.dart:23–115 | Singleton ChangeNotifier mixes account, mutable draft, documents, status and alerts. Several fields are set directly. Introduce session-scoped state and injectable service boundaries incrementally. |
| Data and integration | ../pubspec.yaml and ../lib/data/app_state.dart | No client transport, identity provider, storage or backend dependency. No persisted schema or deployed endpoints evidenced. data and eval contain tracked markers only. |
| Dependencies and toolchain | ../pubspec.yaml, ../pubspec.lock, ../analysis_options.yaml | Flutter and Cupertino Icons are direct runtime dependencies. Flutter Test and Flutter Lints are dev dependencies. Dart constraint is ^3.13.7. Lockfile exists. No dependency advisory scan was performed. |
| Android | ../android/app/build.gradle.kts, ../android/settings.gradle.kts, ../android/gradle/wrapper/gradle-wrapper.properties | JDK target 17, AGP 9.1.0, Kotlin plugin declaration 2.4.0 and Gradle distribution 9.3.1. Example package ID and debug release signing. Two Kotlin MainActivity paths exist. Manifest resolves the namespace-relative activity. Wrapper launchers and JAR are absent from tracked inventory. Prove regeneration and toolchain compatibility in a clean checkout. Verify release network permission when the API is integrated. |
| iOS and web | ../ios/Runner.xcodeproj/project.pbxproj, ../ios/RunnerTests/RunnerTests.swift, ../web/index.html, ../web/manifest.json | Scaffolds exist. iOS has a placeholder XCTest and requires macOS/Xcode verification before any iOS commitment. Web metadata remains largely starter content. Student distribution is Android-first per design. |

## Requirements and status

COMPLETE means implemented and verified for its stated scope. PARTIAL means implemented but incomplete or insufficiently verified. NOT STARTED means required and absent in tracked implementation. BLOCKED means a known prerequisite prevents progress. NEEDS REVIEW means a decision or evidence is outstanding. See the [tracker](PROJECT_PROGRESS_TRACKER.md) for work-item status.

| Capability | Status | Evidence and remaining gap |
| --- | --- | --- |
| Launch and navigation smoke test | BLOCKED | main.dart:27 parser failure prevents runtime verification. |
| Login and signup | PARTIAL | auth_screens.dart:77,135 validates UI and navigates locally. Signup stores only name values. No account creation, session recovery, credential verification, school identity proof or guarded routes. |
| Home, requirements and ownership checklists | PARTIAL | main_shell.dart:82,175,260 and apply_screens.dart:16,76,165 implement views. Verify both branches and ensure school-approved rules match upload and submission validation. |
| Student and vehicle forms | PARTIAL | apply_screens.dart:306,382 uses required-field validation and shared state. Add policy-driven formats, size limits and conditional validation. On ownership changes, preserve still-valid files and clear fields and documents that are no longer applicable. |
| Actual document intake | PARTIAL | apply_screens.dart:455–493 uses camera/gallery selection to fabricate a filename. Optional rules use a display label. No bytes, file validation, scanning, private storage, recovery or ownership verification. |
| Review, submit and reference | PARTIAL | apply_screens.dart:572–779 has edit and confirmation; file review shows a count. app_state.dart:84 emits the same reference every time and jumps to underReview. No transactional durable submission, unique reference or retry semantics. |
| Tracking, alerts and pickup | PARTIAL | status_screens.dart:26,89,203,273 renders local state. Students can advance demo status. No rejection state. Notifications use local text and pickup details are hardcoded. |
| Authorized staff and administration | NOT STARTED | Planning document assigns reviewer and administrator duties. No queue, detailed verification, decision workflow, audit trail or admin UI in tracked code. |
| Persistence, record management and isolation | NOT STARTED | app_state.dart is volatile and logout does not clear all identity/form data. No per-student records, schema, migrations or ownership enforcement. |
| Security-personnel access | NEEDS REVIEW | Design says security personnel may use records. Agree whether access is required and what minimum fields can be exposed. |
| Android deployment and operations | PARTIAL | Platform scaffold exists. Verified release tooling, signing, environment setup, monitoring and recovery remain outstanding. |

## Release risks and decisions

- **Critical:** Remove the parser blocker, then verify the preserved demo. Move status authority to the service before pilot. A student device must never authorize approval or pickup.
- **Critical:** School IDs, contact details and owner documents require scoped server access, minimization, retention/deletion rules and private storage. Clear client session state on logout and account switch. Use synthetic data through QA.
- **High:** Submit and transition operations need database constraints, transaction boundaries, concurrency checks and idempotency. Reference numbers identify requests and must never grant access. Store attachment metadata separately; finalize only verified attachments and reconcile orphaned files.
- **High:** Use one service boundary with a relational store and private object storage as the proposed baseline. Reuse school-approved identity and hosting if available. Provider, staff role granularity, account proof, schema policy and pilot distribution need approval. Confirm requirements, pickup schedule, permitted attachment types, retention, peak volume and recovery targets with campus stakeholders.
- **High:** Use structured, redacted logs and health signals. Monitor upload failure, transition errors, queue delay and storage growth. Require tested rollback, coordinated database/object restore and a staffed incident process.
- **Medium:** No measured capacity or accessibility results. Profile on representative Android hardware and slow networks. Use pagination, timeouts, bounded transfer sizes and caching only where measurements justify it.
- **Optional or approval-dependent:** iOS, student web distribution, push/email delivery, QR verification and advanced analytics. In-app persisted notifications are the proposed baseline, subject to school approval. Maintain administrator record duties in the core as agreed. Automated approval and official document generation are outside existing scope.

## Progress estimate

Unit of estimation is production capability with evidence for UI, real integration and verification. Weights approximate delivery effort and risk. Ranges reflect credited reusable implementation, never test pass rates. A static prototype earns partial credit even while the entry point is broken.

| Module | Weight | Estimated completion | Basis |
| --- | ---: | ---: | --- |
| Student UX and navigation | 25% | 55–70% | Most designed screens present, no runtime baseline and incomplete validation. |
| Student identity and access | 15% | 5–15% | Reusable forms only. |
| Application service, records and uploads | 25% | 5–15% | Draft model and UI only. |
| Staff decisions, status and alerts | 20% | 10–20% | Student status and alerts UI only. |
| QA, deployment and operations | 15% | 5–15% | Existing smoke tests, platform scaffolds and lockfile. |

Weighted range is roughly **20–30%** of production scope, with low confidence in exact effort and high confidence in the prototype classification. No release capability is marked COMPLETE. Re-estimate after a green baseline and approval of operational policy and service boundaries.

## Verification ledger

| Check | Outcome |
| --- | --- |
| Git inventory, status and local history; graph query plus source cross-check | Executed and returned evidence. |
| Standalone Dart version | Executed successfully. Dart 3.13.7 on Windows x64. |
| dart format --output=none lib/main.dart | Executed and failed parsing at line 27, expected a type name and a class body. No source edits. |
| dart analyze lib test; flutter --version; flutter test --no-pub | Standalone Dart analysis executed and failed with seven errors: three at main.dart:27 and four cascading test errors. Flutter version and widget-test commands started but produced no output before interruption. No widget-test assertions ran to a reported result. |
| Existing widget tests | Two expected demo workflows in test/widget_test.dart. Login-to-home and borrowed-vehicle flow through simulated upload and release. No verified passing run. XCTest contains no assertions. |
| Android release build, iOS/web runtime, backend, DB, security, performance and restore | Unverified. Android build deferred behind parser/toolchain baseline; production services and release evidence are absent. |

See the [completion roadmap](PROJECT_COMPLETION_ROADMAP.md), [release checklist](PRODUCTION_READINESS_CHECKLIST.md) and [next steps](NEXT_STEPS.md).
