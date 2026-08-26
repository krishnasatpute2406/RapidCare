# Fix Build Failures and "Unsupported Modules" Errors

The build is failing due to two main reasons:
1. **File Locks**: A process (likely the Flutter daemon or Java) is holding onto the `build` directory, preventing `flutter clean` and Gradle from working.
2. **Module Mismatch**: The IDE thinks the root module `rapidcare` is a Java module that should be compiled, but it isn't part of the Gradle build. This causes the "Unsupported Modules Detected" error.

## User Review Required

> [!CAUTION]
> We need to terminate all running Java and Flutter processes to release the file locks. This will stop any running apps or debuggers.

## Proposed Changes

### Build Environment Fix
We will provide instructions to force-kill the locking processes and perform a deep clean.

### IDE Configuration Fix

#### [MODIFY] [.idea/modules.xml](file:///C:/Users/Krishna/OneDrive/Documents/final year project/RapidCare/rapidcare_app/.idea/modules.xml)
Remove incorrect module references and ensure only the valid project structure is defined.

#### [MODIFY] [rapidcare.iml](file:///C:/Users/Krishna/OneDrive/Documents/final year project/RapidCare/rapidcare_app/rapidcare.iml)
Ensure the root module is correctly identified as a Flutter/Dart module, not a Java compilation target.

#### [MODIFY] [.idea/gradle.xml](file:///C:/Users/Krishna/OneDrive/Documents/final year project/RapidCare/rapidcare_app/.idea/gradle.xml)
Cleanup the `compositeBuild` settings which currently point to fragile relative paths for the Flutter Gradle tools.

## Verification Plan

### Manual Verification
1. Kill processes using `taskkill /F /IM java.exe` and `taskkill /F /IM dart.exe`.
2. Run `flutter clean`.
3. Perform a Gradle Sync in Android Studio.
4. Run `flutter run` to verify the build works.
