# Campus operating rules for ParSU MotoPass

**Status: Proposed for campus approval.** Record the responsible office and decision for each row below before implementing policy-dependent behavior or collecting real student documents. This draft implements roadmap task P2-T01's decision record. It uses the [project design](MIDPROJ_Cleofe-Surname2_BSCS3A.md) as its baseline.

| ID | Confirm with | Decision to record | Status |
| --- | --- | --- | --- |
| C01 | Registrar and campus IT | Eligible enrollment, approved identity source, account recovery and enrollment rechecks | Pending |
| C02 | Permit office, campus IT and security | Campus/office scope, who grants each staff role, who makes decisions and whether security lookup is needed | Pending |
| C03 | Permit office and campus privacy lead | Exact evidence by ownership scenario, whether a second student ID copy is necessary, and allowed file formats/sizes | Pending |
| C04 | Permit office | Application limits, corrections, transition authority, rejection and resubmission | Pending |
| C05 | Permit office | Pickup location, hours, proof of identity, proxy policy and record kept at handoff | Pending |
| C06 | Records owner and campus privacy lead | Collection purpose, retention periods, deletion, holds and backup expiry | Pending |
| C07 | Campus IT and permit office | Hosting, responsible operators, pilot audience, anticipated traffic and recovery targets | Pending |

## C01 — Student identity

Use school-managed sign-in if available and verify that the account belongs to an eligible student through a registrar-approved source. Link an application to the verified school account. A typed student number or email address alone does not prove identity. If school sign-in is unavailable, have the registrar approve an enrollment-verification and recovery process before enabling self-registration. Record when eligibility is checked, how mismatches are handled, and how access is revoked after an account is disabled.

## C02 — Role permissions

| Role | Proposed access |
| --- | --- |
| Student | Create, edit and submit own applications, upload own evidence, and view own decisions and pickup information. |
| Reviewer | View assigned or office-scoped applications and evidence, record verification, and make decisions only with an explicit decision grant. |
| Releasing staff | View ready applications within scope, verify the claimant, and record pickup. |
| Administrator | Manage approved roles, requirement versions, pickup settings and scoped records. Evidence access requires its own grant. |
| Security | If approved, look up a released sticker by exact plate. Return only the verification result and approved sticker fields. |

Use institutional staff accounts and approve role grants through a named campus owner. Revoke access when duties change and record role changes and sensitive actions. Confirm whether one employee may hold both reviewer and releasing roles.

## C03 — Required documents

| Evidence | Student-owned motorcycle | Borrowed motorcycle |
| --- | --- | --- |
| Student ID evidence | Required in the design. Confirm whether one capture can satisfy both ID and photocopy entries. | Same |
| Motorcycle registration (OR/CR) | Required | Required |
| Owner ID evidence | Inapplicable | Required in the design. Confirm acceptable proof and allowable redactions. |
| Owner authorization or consent letter | Inapplicable | Required. Confirm the accepted template and signature method. |
| Motorcycle photo | Conditional. Confirm when the rule applies. | Same |

Approve file types and size limits, evidence quality criteria and any alternate proof as explicit policy. Confirm whether course, year/section, phone and home address are all necessary. Give students a way to replace evidence before submission and whenever staff request a correction. A requirement change should affect new applications according to the campus-approved effective date. Existing submissions retain the version applied when submitted.

## C04 — Review and decision

Proposed normal flow is **Submitted → Documents received → Under review → Approved → Ready for pickup → Released**. Submitted means the system accepted the form. Documents received means staff acknowledged the evidence. Approved requires a human decision and verified required evidence. Only releasing staff may record the handoff.

Give authorized reviewers a correction path for fixable omissions. A **Needs correction** result should specify what to replace and return to review after resubmission. Use **Rejected** for a final decision on that submission, with a student-visible reason. Confirm who can reopen a case, whether students may submit a fresh application after rejection, and whether the application limit is per student, vehicle or academic period. Record the actor, time and reason for staff decisions. Keep internal notes separate from student notices.

## C05 — Pickup

The permit office supplies the approved pickup location, office hours, required proof and any collection deadline. The proposed in-person check uses student ID and reference number together. A reference number identifies an application and does not establish identity. Confirm whether a proxy may collect and what authorization they must present. Record the handoff once, with the staff actor, timestamp and sticker identifier if one is assigned. Campus staff remain responsible for physical issuance.

## C06 — Data collection and retention

The following periods require campus approval. Confirm a deletion trigger for every category before enabling real submissions.

| Data class | Proposed retention trigger | Duration to approve |
| --- | --- | --- |
| Abandoned drafts and incomplete uploads | Last activity or abandoned upload | Pending |
| Identity and vehicle evidence | Final decision or sticker handoff, with a defined period for corrections or disputes | Pending |
| Application and sticker records | End of permit validity or final case closure, as applicable | Pending |
| Access and decision audit records | Date of event, with access limited to designated personnel | Pending |
| Backup copies | Backup creation date, using the approved expiry schedule | Pending |

Keep attachments private, scope access to assigned duties, and omit document contents and private links from routine logs and notifications. Define who can authorize a records hold and how held records are released. Ensure deletion covers attachment objects and metadata, and verify that restored backups reapply applicable deletions. Publish a notice that explains the purpose, who can see each category and where students can request a correction.

## C07 — Pilot operations

Name the service owner, hosting and support operators, and the office responsible for release decisions. Agree on pilot eligibility, expected student and staff traffic, recovery time and acceptable data loss. Record these decisions before sizing or provisioning a production environment.

## Recommended pilot baseline

Use these defaults for implementation planning and synthetic-data testing. Confirm them with the assigned campus offices before enabling real accounts or collecting evidence.

| Decision | Recommended default |
| --- | --- |
| Student identity | Use campus sign-in plus an enrollment check. Start with campus-provisioned test accounts if the identity provider is undecided. |
| Staff permissions | Start with one permit office and separate reviewer, decision, release and role-management grants. A staff member may hold multiple approved grants. Keep security lookup disabled until its scope is approved. |
| Required evidence | Use one student ID capture and OR/CR for both ownership paths. Add owner ID and a consent letter for borrowed motorcycles. Request a motorcycle photo only when a configured campus rule requires it. Keep home address out of the proposed minimum unless the office confirms a need. |
| Duplicate applications | Allow one active request per student and normalized plate within the same permit cycle. Treat submitted through ready-for-pickup and needs-correction as active. Flag potential duplicates across students for staff review. |
| Decisions and corrections | Start at Submitted. Require a staff decision after required evidence has been verified. Give students a correction path for fixable problems and show a plain-language reason for corrections or rejection. Keep rejected records intact and allow a new request for an otherwise eligible student. |
| Pickup | Start with in-person collection by the student, using student ID and reference number. Keep proxy pickup off until approved. Configure location and hours through the permit office and record pickup once. |
| Retention | Use separate retention schedules for drafts, attachments, permit records, audit records and backups. Use short synthetic expiry values to verify cleanup in tests. Production durations, holds and backup expiry require records-owner approval. |
| Pilot operations | Keep the first pilot Android-only and invitation-based. Use a single permit office and in-app updates. Assign hosting, support and recovery ownership before admitting real users. |

### Checks to carry into the service design

- One student cannot view another student's request or attachments. Removing a staff grant blocks subsequent actions that depended on it.
- Owned and borrowed applications enforce different evidence requirements. A submitted record keeps the requirement version active when it was submitted.
- Retrying a submission produces one durable reference. A concurrent reviewer action cannot overwrite an already-recorded decision.
- Missing evidence can be corrected and resubmitted. A reviewer cannot approve an application with unresolved required checks.
- Only staff with the release grant can record pickup. A repeated pickup action cannot create a second handoff.
- Synthetic retention tests cover abandoned uploads, expired evidence, held records and deletion after a backup restore.

## Approval record

For each decision, record the approving office and owner, approved wording or exception, date and supporting reference. Keep the latest approved decisions here and mark P2-T01 complete in the [progress tracker](PROJECT_PROGRESS_TRACKER.md) after all release-critical decisions have owners and sign-off.
