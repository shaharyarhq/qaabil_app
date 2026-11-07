# Member login integration

Implemented locally on 2026-11-01. Not deployed to qaabil.io.

## Backend

Use the existing PHP 8.4 DDEV runtime in `~/Projects/Laravel/qaabil`; the host
PHP 8.3 does not satisfy the project's already-locked dependencies.

Sanctum adds the `personal_access_tokens` table. Only its new migration was
applied to the local DDEV database; no existing user records were changed.

| Endpoint | Request | Response |
|---|---|---|
| POST /api/v1/member/login | email, password, device_name | token, expires_at, user |
| GET /api/v1/member/me | Authorization: Bearer token | user |
| POST /api/v1/member/logout | Authorization: Bearer token | message |
| GET /api/v1/member/courses?page=1 | Authorization: Bearer token | data, pagination meta |
| GET /api/v1/member/courses/{id} | Authorization: Bearer token | data: course content and own progress |

Tokens have the `member` ability and expire after 30 days. Login is limited to
five requests per minute per IP; authenticated routes use a 60/minute limit.
The current device token is deleted on logout; other device tokens are retained.
Only users with the existing student/member role can sign in. Confirmed web
2FA accounts are explicitly rejected until mobile 2FA is implemented.

The profile response allowlists id, name, email, full_name and school. It does
not grant premium access. Existing video rules and verification behavior were
not changed. Member registration and password reset are not implemented in the app.
The read-only courses/learning API was added on 2026-11-02.

## Flutter

- `lib/services/member_api.dart`: HTTP requests and safe user-facing errors.
- `lib/auth/member_session.dart`: shared session and secure token storage.
- `lib/auth/member.dart`: profile data model.
- `lib/screens/login_screen.dart`: validated email/password form.
- `lib/screens/profile_screen.dart`: server profile fields and sign-out.

Passwords are not stored. Tokens are stored using flutter_secure_storage and
namespaced by API server. A saved token is validated with /me on app startup.
Expired/unauthorized tokens are removed. Network failures do not delete a saved
token. A failed remote logout keeps the session so revocation can be retried.

API_BASE_URL must include /api/v1. An unconfigured build shows a service configuration error for public courses
and explicitly says member sign-in is unavailable. It does not
silently send credentials to a production server. Release builds require HTTPS.

## Local Android / Waydroid testing

DDEV's mapped web port can change. Find it with:

```bash
docker port ddev-qaabil-web 80
```

If it prints `127.0.0.1:32776`, forward that host port through adb:

```bash
adb connect 192.168.240.112:5555
adb -s 192.168.240.112:5555 reverse tcp:8080 tcp:32776
flutter run -d 192.168.240.112:5555 --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1
```

Use an existing **local** member account. Production-only accounts will not work
unless they also exist in the local database. No demo member was created.
Local HTTP is allowed only for loopback/emulator addresses in the debug Android
network policy; never disable TLS verification for a production server.

After backend deployment, build with its real HTTPS API URL instead. Do not
point at qaabil.io until these endpoints and their migration are deployed.

## Verification

```bash
flutter analyze
flutter test
```

Backend tests use fake settings and SQLite :memory:, not the local member DB:

```bash
docker exec -w /var/www/html ddev-qaabil-web vendor/bin/phpunit tests/Feature/MemberApiTest.php tests/Feature/MemberLearningApiTest.php --do-not-cache-result
```

The tests cover token issuance/expiry/scope, membership, invalid credentials,
rate limiting, device-specific logout, 2FA refusal, profile allowlisting, app
login/profile/logout, saved-session restoration and retry after logout failure.
The local /me endpoint was checked to return 401 without credentials.

The debug Android APK was built and launched on Waydroid with the local API
port forwarded. A real member login on Android and an iOS device build still need manual
verification. No real member credentials were used during implementation.

## My Learning — 2026-11-02

- My Learning loads actual local backend courses with a progress record belonging
  to the signed-in member. It is not an enrolment list. The API paginates at 25.
- Started = Behind + Practice + Mastery. Missing progress and explicit Not Started
  do not increase coverage. Mastery percentage is separate. No progress data was
  modified; the website member course summaries use the same calculation.
- The course content endpoint returns actual section/chapter/objective IDs and names,
  plus only the requesting member's statuses. Disabled courses return 404.
- Responses are explicitly allowlisted and do not include video URLs, attachments,
  answer keys or other members' progress. Playback/download access is separate.
- Flutter handles loading, empty data, retry, pull-to-refresh, more pages, expired
  sessions, and stale responses after logout. Course detail is read-only.
- At this stage the public Courses tab was still a mock catalogue; the public
  catalogue connection described below supersedes that. Neither tab now silently
  substitutes mock courses when a request fails.
- Resources, quiz taking and progress editing are not connected in this slice.
- Checks: analyzer clean, 20 Flutter tests and 13 backend tests (78 assertions)
  passing, including member isolation, disabled courses and pagination.
- Main files: member_course.dart, my_learning_screen.dart, member_course_screen.dart,
  learning_progress.dart; backend MemberLearningController, EnsureMemberToken and
  CourseProgressService. No new dependencies or database migrations for this slice.

## Objective videos and notes — 2026-11-02

Member flow: My Learning → Open course → expand chapter → Videos & notes.

| Endpoint | Purpose |
|---|---|
| GET /api/v1/member/objectives/{id}/resources | Approved video metadata and supported objective-note metadata |
| GET /api/v1/member/videos/{id} | Recheck publication and return playback state/YouTube ID |
| GET /api/v1/member/objectives/{id}/notes/{index} | Authenticated document download |

All endpoints require a scoped member token. Disabled curriculum, unapproved
videos and mismatched video hierarchy references are rejected. Response metadata
excludes raw storage paths and unpublished source URLs. Missing resources return
404. An unavailable/unsupported playback state uses 200 with allowed=false,
not 403, so it does not wrongly invalidate the account session.

Confirmed product decision: approved YouTube videos play for signed-in members,
without payment or contribution requirements for those embeds. The website's
member YouTube playback follows the same rule. config/member.php has a playback
switch; private hosting/subscriptions remain separate future work. This does not
certify every aspect of YouTube/store compliance.

Member edits to approved video content now reset it to pending and clear the
approval actor; privileged moderation edits remain distinct. Website objective
listings filter approved videos, and direct public course/objective/video paths
now reject disabled/unpublished resources. Guest legacy allowance behavior and
future non-YouTube contribution entitlements were not redesigned.

Notes supported: PDF, PPT/PPTX, DOC/DOCX and TXT, at most 20 MiB. Server resolves
only files under its configured disk root, rejects traversal/external paths,
filters unsupported/missing files, and downloads with nosniff/no-store headers.
Original website files are still on public storage: this endpoint does NOT
retroactively make those existing files private or revoke existing public URLs.
Private-storage migration remains tracked under B20.

Flutter downloads with an Authorization header, never a token query string,
then opens a generated temporary filename using the device document viewer.
Temp copies are cleared on logout/session invalidation and app startup where
possible. A viewer may keep its own copy; this is not DRM or offline entitlement
control. No compatible viewer produces a clear message. iOS device behavior has
not been manually verified.

Added open_filex and declared path_provider directly. Removed the opener's
unneeded storage/media permissions from the Android merge; aapt confirmed the
built debug APK has only Internet and an app-internal receiver permission.

Main app files: objective_resources.dart, objective_resources_screen.dart,
lesson_video_screen.dart and note_files.dart. MemberApi/MemberSession connect
these to the existing login. Backend: MemberResourceController and
PublishedLearningResources, plus publication checks/VideoObserver changes.

Verification: analyzer clean; 26 Flutter tests; 20 backend tests, 125 assertions;
debug Android APK builds and was installed on Waydroid. Tests exercise metadata,
empty/error/retry states, playback decisions, authenticated notes, path safety,
file cleanup, disabled courses, publication and re-review. Actual playback and
opening each real document format need device verification with your account.
No new database migration or production deployment in this step.


## Public catalogue connection (2026-11-02)

The public Courses tab now fetches Laravel data, with no sample-data fallback.
Both guests and members use GET /api/v1/courses without a bearer token. Query
parameters: search (up to 200 characters), qualification (database ID), sort
(newest/oldest), page (25 per page). The response includes course metadata,
counts, pagination and qualifications from the database. Only enabled courses
are returned; video counts include approved videos with a nonempty source URL.

GET /api/v1/courses/{id} returns existing sections, chapters and objectives;
it never returns member progress, objective statuses, resource URLs or files.
Both public routes are throttled at 60 requests/minute. The shared
CourseContentService also serves the authenticated detail endpoint with only
the requesting member's progress. Disabled or missing course IDs return 404.

The app opens the same course-content screen from Courses and My Learning.
Guests can browse the hierarchy and are prompted to log in for videos/notes.
Members see their saved progress and use the existing protected resource APIs.
Search is debounced and stale responses are ignored; errors support retry,
pull-to-refresh and pagination without silently showing mock courses.

Waydroid still uses API_BASE_URL=http://127.0.0.1:8080/api/v1, forwarded to local
DDEV. Its database currently contains three enabled courses: Data Analysis with
Excel, Web Design Fundamentals and Python Programming. This differs from the
production qaabil.io database. No production deployment or database copy was
performed. Showing production courses requires deploying these endpoints to the
production backend and building against its HTTPS API URL.

Verification: 25 backend tests (173 assertions), 21 Flutter tests. Legacy mock
course/detail source files remain unused by the public navigation.

Device verification: rebuilt and launched on Waydroid; captured the public
Courses screen showing all three local backend courses. Flutter launch cleared
the manual reverse tunnel; restoring it after launch and hot restarting fixed
the connection. For this local setup, run `adb -s 192.168.240.112:5555 reverse
tcp:8080 tcp:32776` after launch if the catalogue reports a connection error.

## Self-test results — 2026-11-03

- Analyzer: clean. Flutter tests: 21 passed. Backend tests: 25 passed,
  173 assertions, in the isolated SQLite test database.
- Real local HTTP checks using a disposable member passed: login/profile,
  My Learning, the seeded practice status, public-response privacy, approved
  resources, playback authorization, logout and rejection of the revoked token.
- Added `integration_test/member_journey_test.dart`, using the Flutter SDK
  integration_test dev dependency. On Waydroid with real HTTP and secure storage,
  the core smoke test passed: public course loading/initial search, guest course
  content and login gate, form login, saved progress, approved resources,
  My Learning, persisted session restoration and logout.
- **Playback failed:** the actual iframe for the selected published local video
  (video record 8, YouTube ID URJuE4nlc7U) reported `invalidParam` (error 2), stayed
  unStarted and never reached playing. Root cause is not established. The smoke
  test records this as a diagnostic; its green result covers the core journey,
  not successful video streaming. Do not claim playback is working from this run.
- The selected objective has no attached notes. Its empty state passed; real
  document download/opening on Android remains unverified in this run. Existing
  isolated backend/file-opener tests still pass.
- Repeated text entry/search in device automation did not pass reliably: after
  entering a second query, the earlier Python result remained. Widget search/
  stale-response tests and backend filtering tests pass. This needs a focused
  reproduction to distinguish input automation/IME behavior from an app defect.
  The retained core smoke test checks only the initial course search.
- Progress editing is not implemented; only existing saved progress was tested.
  Production endpoints and iOS device behavior were not tested.
- The temporary member used a separate secure-storage key. Its account, seeded
  progress, role assignment and tokens were removed after testing; its temporary
  credentials file was deleted. No existing member progress was edited.

To rerun the device test, prepare a disposable local `device-smoke-…@example.invalid`
member and an untracked JSON define file containing API_BASE_URL, TEST_EMAIL,
TEST_PASSWORD, TEST_COURSE_NAME, TEST_CHAPTER_NAME, TEST_OBJECTIVE_NAME,
TEST_OBJECTIVE_ID and TEST_VIDEO_ID. The objective must have a saved practice
status for that member and an approved video. Run:

```bash
flutter test integration_test/member_journey_test.dart -d DEVICE_ID --dart-define-from-file=/tmp/qaabil-device-member.json
```

Keep the local API reverse tunnel present after device launch, and remove the
fixture account/data afterward. Never commit the credential file. The test uses
only its own namespaced secure-storage key, not the app's normal saved session.

## Playback follow-up — 2026-11-07

The earlier error-2 result was not a reliable playback failure: the smoke test
called playVideo as soon as the iframe existed, before the initial cue completed.
A focused Waydroid test of the same published source (URJuE4nlc7U) reached cued,
played and advanced its timeline using the original player code. The suspected
null timing parameters were therefore not established as the cause and were not
patched or worked around with custom JavaScript.

The member smoke test now waits for cued before playing and asserts a playing
result instead of treating failed playback as a passing diagnostic. A focused
native test, integration_test/youtube_playback_test.dart, checks actual timeline
advancement, pause, error/retry controls and recovery when the source changes.

The app now handles the cue Future explicitly, catches initialization failures,
shows a playback error with Retry video, and creates a fresh controller when the
lesson changes or is retried. Inline sizing follows the existing 640px content
width, with a minimum 200px player height for phone controls. The test exposed an
inline overflow on the wide Waydroid screen; the width constraint corrected it.

Local environment: started Waydroid and the DDEV web/database containers. The
old auto-selected database port 32775 was occupied by Netbill's Mailpit service,
so an ignored .ddev/config.mobile.local.yaml pins Qaabil's database port to
32790. Existing services were left running. DDEV reported a missing router
container, but the app's direct local endpoint at 127.0.0.1:32776 responds normally.
No production deployment, source-video replacement or member-data mutation.

Verification: analyzer clean, 21 existing Flutter tests passed, and the focused
Waydroid playback test passed with timeline advancement, pause and recovery from
an invalid source. The normal app is built with the local API_BASE_URL. This
follow-up did not repeat iOS testing or real document opening. Repeated-search
input automation remains a separate unresolved finding from the earlier run.

## Member video-page functionality — 2026-11-07

Implemented locally before the UI overhaul:

- Overview: existing course/section/chapter/objective context, plain-text
  description, creator, publication status, language, submission date and
  approver display name. Approver email/internal account fields are not exposed.
- Reviews: website-backed star ratings and optional comments, summary average/
  counts, pagination, own-review state, submit and confirmed owner-only delete.
  Reviews load independently and preserve the composer when switching tabs.
- Related submissions: only approved videos in the same consistent objective
  hierarchy. The first 12 are shown, with a link to all objective resources.
- Materials: video learning_materials, video notes (legacy quiz_attachments field)
  and objective notes remain distinguishable. The tab appears only with usable
  files or a configured HTTPS quiz link. Downloads require the scoped token;
  metadata never contains storage paths. Quiz links open in the device browser
  without app tokens; web sign-in may be required. Native quiz taking is not added.
- Supported files: PDF, PPT/PPTX, DOC/DOCX, TXT and PNG/JPG/JPEG/WebP, max 20 MiB.
  Existing path traversal, symlink, format and disk-root guards apply. Opening a
  file uses the device's installed viewer; this is not private storage migration.

New endpoints, all under /api/v1/member and the existing member middleware:

| Method and path | Purpose |
|---|---|
| GET videos/{id}/details | Overview, context, related metadata and safe material metadata |
| GET videos/{id}/reviews?page=1 | Paginated reviews, own review and whole-video summary |
| POST videos/{id}/reviews | rating 1–5, optional review up to 1,000 characters |
| DELETE videos/{id}/reviews/{review} | Confirmed own-review deletion, scoped to this video |
| GET videos/{id}/materials/{kind}/{index} | Authenticated local-file download |

Review writes share VideoReviewService with both website review components.
Creation/deletion lock the video row, reject duplicate membership reviews and
scope deletions to both video and owner. The existing five-point review reward
now uses VideoReviewed, with one reward per member/video even after deleting and
resubmitting. Previous reward history is not migrated or recalculated. No new
schema migration was required. API write requests have a separate 10/minute
budget; public reads, login and general member requests now also have distinct
rate-limit prefixes so browsing does not consume the write/login budget.

Visibility deliberately matches the website's existing getReviews(false)
cohort. In the installed review package, false means approved=false, not "all
reviews". The requesting member's own review is returned separately across
cohorts to prevent duplicate submissions and allow owner deletion. This existing
web visibility rule needs a separate moderation-policy review before release.
Reporting/blocking and a full native UGC moderation flow are not included here.

Details failures are caught immediately while the player loads independently,
then displayed by their own retry UI. Sign-out removes the private page; stale
review responses cannot repopulate it. Navigating to another lesson/course from
this page replaces the route, disposing the old player.

Validation: 32 backend tests (277 assertions), 28 Flutter tests and analyzer clean.
A real Waydroid run using a disposable local member/lesson passed guest browsing,
login, saved progress, resources, session restoration, YouTube playback, overview,
related metadata, authenticated material bytes, rating/comment submission,
cancelling deletion, confirming deletion and logout. The temporary account,
lesson, material, review/rating records, points, badges, progress and tokens were
removed. Existing member content and progress were not edited.

Device file downloading was checked with a temporary TXT material. Opening every
file format in an external viewer, external quiz sign-in and iOS behavior remain
unverified. No production deployment was performed.

## Course, section and chapter notes — 2026-11-07

- Signed-in course details now include safe `notes` metadata at course, section
  and chapter level. Public course responses omit these fields. No storage paths
  or raw download URLs are returned.
- `GET /api/v1/member/learning-notes/{kind}/{resource}/{note}` downloads a note;
  kind is course, section or chapter. The member-token guard applies. Each request
  resolves the resource through its enabled parent course and checks the file
  again using the shared disk-root, traversal, type and 20 MiB limits.
- Legacy single-filename attachment values and current attachment lists both
  work. Supported missing/unsafe files are filtered rather than linked blindly.
- The app shows real filenames, file types and sizes under Course notes,
  Section notes and expanded Chapter notes. Tapping downloads with a bearer header
  and uses the existing private temporary-file/document-viewer flow. Loading,
  retryable errors and session changes use the existing member protections.
- Course details now render their backend description. Catalogue cards and
  course sections/chapters use additional violet, teal and coral accents alongside
  Qaabil navy/amber. Decorative accents do not change progress-status meanings.
- Verification: analyzer clean; all 31 Flutter tests passed; 35 API tests passed
  with 349 assertions in isolated SQLite/fake-storage tests. Download tests cover
  all three levels, guest/wrong-scope denial, disabled/missing resources, unsafe
  files, legacy scalar values, path privacy and app retry/opening behavior.
  Phone-size renders were visually inspected, and the running Waydroid app was
  hot-restarted. Opening real notes in external Android/iOS viewers was not
  repeated in this step.
- Read-only local-data checks found two available course files, one section file
  and one chapter file. No existing member or curriculum records were changed;
  no test accounts were created. No schema migration or production deployment.
