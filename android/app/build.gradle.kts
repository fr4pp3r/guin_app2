import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // FlutterFire: reads android/app/google-services.json at BUILD time. The
    // file is gitignored (each deployment has its own Firebase project). When
    // it is absent the plugin is not applied, so the project still builds and
    // runs — push just stays off (see lib/services/push_service.dart and
    // PUSH_NOTIFICATIONS.md). The `apply false` + `apply(plugin = ...)` form is
    // required because a plugins block has no `file()` accessor.
    id("com.google.gms.google-services") apply false
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Only wire Firebase into the build when a Firebase project has actually been
// configured for this checkout; applied conditionally so an unconfigured
// checkout (and CI) builds normally.
val hasGoogleServices = File(project.projectDir, "google-services.json").exists()
if (hasGoogleServices) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "google-services.json not found in android/app — " +
            "FCM push notifications are disabled for this build. " +
            "See PUSH_NOTIFICATIONS.md."
    )
}

// Release signing credentials (android/keystore.properties + android/app/release-keystore.jks,
// both gitignored). All release builds MUST use this fixed keystore so every distributed APK
// carries the same signature — signing with the per-machine debug keystore caused
// "App not installed" on devices that already had a differently-signed copy.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.citeease"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.citeease"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Fail loudly instead of silently falling back to the debug keystore: a release
                // built with a different key would make every device with the previous version
                // reject the update ("App not installed"). This block runs during the
                // configuration phase of EVERY build (including debug `flutter run`), so only
                // raise the error when a release build is actually being requested.
                val requestedTasks = gradle.startParameter.taskNames.map { it.substringAfterLast(':') }
                val buildingRelease = requestedTasks.any {
                    it.contains("Release", ignoreCase = true) ||
                        it in setOf("build", "assemble", "bundle", "install")
                }
                if (buildingRelease) {
                    throw GradleException("Release signing not configured: android/keystore.properties is missing. Restore it and android/app/release-keystore.jks to build a release.")
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
