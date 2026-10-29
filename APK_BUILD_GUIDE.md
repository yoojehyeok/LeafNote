# LeafNote Android APK build

This archive is source code, not an APK. It includes a GitHub Actions workflow
to build the APK on a remote Ubuntu runner, without Flutter installed on your PC.

1. Create a GitHub repository.
2. Upload the *contents* of the leafnote folder to the repository root,
   including .github/workflows/build-apk.yml.
3. Open Actions -> Build LeafNote Android APK -> Run workflow.
4. When the build succeeds, download the LeafNote-Android-APK artifact.
5. Extract it and install app-release.apk on Android.

This is an untested prototype; CI may expose source/plugin compatibility issues.
The workflow does not sign the APK with a persistent release key, so this
is for personal testing, not Play Store distribution.
