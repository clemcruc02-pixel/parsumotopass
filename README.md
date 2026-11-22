# ParSU MotoPass

ParSU MotoPass accepts student motorcycle sticker applications. Students sign in with a campus-provisioned account, attach documents for their ownership type and receive a reference number when the server saves their submission.

## Run the synthetic pilot

Run these commands from the repository root with Python 3.11 or later. The account commands prompt for a password of at least 12 characters. Use synthetic accounts and files. Campus identity integration and release approval are pending.

```sh
python backend/server.py add-student 202410654 student@parsu.edu.ph "Test Student"
python backend/server.py add-staff TEST-STAFF staff-demo@parsu.edu.ph "Sample Staff" review decide release manage
python backend/server.py serve --origin http://localhost:5173
```

In a separate terminal, run either the web app or the Android emulator build.

```sh
flutter run -d chrome --web-hostname localhost --web-port 5173 --dart-define=MOTOPASS_API_URL=http://localhost:8080
flutter run -d <emulator-device-id> --dart-define=MOTOPASS_API_URL=http://10.0.2.2:8080
```

Sign in with the provisioned account ID or school email and password. Students can submit synthetic PDF, PNG or JPEG evidence of up to 5 MiB per file and refresh status in **My application**. Corrections return to review under the same reference and require selecting the evidence again. The database enforces one active request per student and normalized plate per synthetic cycle. Students can start another request after rejection or pickup and see previous references under **Past applications**. Staff accounts open the permit office workspace, where grants determine document verification, decisions, pickup and administration. Sessions last eight hours and are held in memory, so relaunch requires signing in again.

The API binds to loopback in development. Set `MOTOPASS_DB` or pass `--db` before the subcommand to choose a persistent SQLite path. The default is the ignored `backend/local/motopass.sqlite3`. The database contains student records and private document bytes. Keep it outside public web roots, restrict filesystem access to the service account and back up the database securely. The API uses bearer sessions for `GET /application` and `GET /document?slot=Student+ID` and derives ownership from the signed-in account. For a hosted deployment, serve `backend.server.create_app(path, allowed_origin)` with a production WSGI server behind HTTPS. Set a 41 MiB request limit and rate-limit sign-in at the reverse proxy. Build Flutter with the HTTPS API URL and use the exact web origin for cross-origin requests.

Run the backend check with `python -m unittest backend.test_server -v`.

## Staff review and pickup

Sign in through the same login screen. The permit office lists submitted applications from the database. The `review` grant opens evidence and records verification or requests corrections. The `decide` grant approves verified applications or rejects them with a student-visible reason. The `manage` grant configures pickup location and hours from the workspace settings. The `release` grant marks approved stickers ready and records pickup once after the staff member confirms the student's ID and reference.

Students receive in-app updates while signed in and can refresh from Tracking or Alerts. Tracking shows recorded decisions and pickup history. Pickup instructions are saved with the application when staff mark it ready.

## Local Android development

The CI workflow pins Flutter 3.47.9, which includes Dart 3.13.7, and uses Java 17. Set up the Android SDK and accept its licenses before building. The local SDK inspected during development included Android platform 36, build-tools 36.0.0 and NDK 28.2.13676358. Run these commands from the repository root.

```sh
flutter doctor -v
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --debug --no-pub
```

If Flutter cannot locate Java or Android on Windows, set `JAVA_HOME` and `ANDROID_HOME` in the current shell to the installed JDK and Android SDK directories. Once the build succeeds, the debug APK is at `build/app/outputs/flutter-apk/app-debug.apk`. Use `flutter devices` to identify an emulator or test device, then `flutter install --debug -d <device-id>` to install and verify the launch.

GitHub Actions runs analysis and tests in **Flutter CI**. **Android debug APK** assembles the APK separately and publishes it as the `app-debug` artifact. Once the workflow is on the default branch, open **Actions → Android debug APK → Run workflow** to build it manually. The current verification status is in the [project tracker](docs/PROJECT_PROGRESS_TRACKER.md).
