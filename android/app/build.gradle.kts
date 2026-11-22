plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningVariables = listOf(
    "MOTOPASS_KEYSTORE", "MOTOPASS_STORE_PASSWORD", "MOTOPASS_KEY_ALIAS", "MOTOPASS_KEY_PASSWORD"
)
val releaseSigning = releaseSigningVariables.associateWith { providers.environmentVariable(it).orNull }
val pilotApplicationId = providers.environmentVariable("MOTOPASS_APPLICATION_ID").orNull

android {
    namespace = "com.example.parsu_motopass"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = pilotApplicationId ?: "com.example.parsu_motopass"
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

    signingConfigs {
        create("pilotRelease") {
            storeFile = releaseSigning["MOTOPASS_KEYSTORE"]?.let { file(it) }
            storePassword = releaseSigning["MOTOPASS_STORE_PASSWORD"]
            keyAlias = releaseSigning["MOTOPASS_KEY_ALIAS"]
            keyPassword = releaseSigning["MOTOPASS_KEY_PASSWORD"]
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("pilotRelease")
        }
    }
}

val requireReleaseSigning by tasks.registering {
    doLast {
        val missing = releaseSigning.filterValues { it.isNullOrBlank() }.keys
        check(missing.isEmpty()) { "Missing Android release signing inputs: ${missing.joinToString()}" }
        val applicationId = pilotApplicationId.orEmpty()
        check(
            !applicationId.startsWith("com.example.") &&
                Regex("[A-Za-z][A-Za-z0-9_]*(\\.[A-Za-z][A-Za-z0-9_]*)+").matches(applicationId)
        ) { "Set MOTOPASS_APPLICATION_ID to the approved Android package ID." }
    }
}

tasks.configureEach {
    when (name) {
        "validateSigningRelease", "packageRelease", "packageReleaseBundle",
        "signReleaseBundle", "assembleRelease", "bundleRelease" -> dependsOn(requireReleaseSigning)
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
