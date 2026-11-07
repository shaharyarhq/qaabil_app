# Qaabil mobile handoff

Last updated 2026-11-07. Read this first when resuming in a new chat. Use the current source and working-tree status to verify anything that may have changed.

## Scope and working preferences

- Flutter app in this repo. Laravel backend at `/home/shaharyar/Projects/Laravel/qaabil`.
- The mobile repository contains the Flutter client. Its development API endpoints currently depend on changes in the separate Laravel working tree.
- Build for public browsing and members. Admin, moderator, and Quiz Builder tools stay on the web.
- Work one feature at a time. For web parity, trace the active Laravel route through its views and actions before implementing the mobile flow. Use “Course content” in the UI.
- Keep Qaabil's navy and amber identity with playful cards and supporting accents. Use real backend data and progress.
- Use the existing local demo account when live sign-in is needed. Keep credentials out of files and logs. Use isolated test data for automated tests.

## Current implementation

- Public catalogue, search and filters, and course content down to learning objectives.
- Member login, session restoration, sign-out, and read-only profile and learning progress.
- Approved YouTube playback for signed-in members, video details, related videos, and review submission and deletion. Objective/video materials and course, section, and chapter notes use authenticated downloads and the device viewer.
- Past Papers browsing is wired to the member API. It supports paper name search, course/year/sitting filters, pagination, and available question papers, marking schemes, and examiner reports.
- Past Papers verification on 2026-11-07 included six passing Flutter widget tests, seven passing Laravel API tests, and a successful Waydroid launch. The local database had two visible papers. Signed-in opening in an external device viewer still needs a manual check.
- Next Past Papers slice is saving personal marks and exporting a progress report. Follow the website's active Past Papers actions and validate score ownership and bounds. Native quizzes, profile editing, and submission management are separate later features.

## Where to look

- [Member API and local setup](docs/member-api.md)
- The local `docs/backend-findings.md` contains the detailed backend audit. Consult it when available.
- Past Papers entry point is `lib/screens/past_papers_screen.dart`. Backend endpoint lives in `app/Http/Controllers/Api/MemberPastPaperController.php` in the Laravel repo.
- Pre-overhaul APK and source archive are under `backups/pre-ui-overhaul-2026-11-07/`. These are local ignored files. Keep the meeting build available.

## Local testing

Use the DDEV backend and confirm its mapped HTTP port with `docker port ddev-qaabil-web 80`. On Waydroid, reverse device port 8080 to the mapped host port, then run Flutter with `--dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1`. Check the tunnel again if the catalogue cannot connect. Production deployment and iOS device verification are separate work.

Update this file after each completed slice with the current state, next task, and any unresolved verification. Keep detailed API and backend notes in the linked files.
