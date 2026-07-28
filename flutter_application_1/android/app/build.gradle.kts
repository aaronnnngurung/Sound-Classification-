plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.flutter_application_1"
    // flutter_wear_os_connectivity requires compileSdk 34+
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    // ── Phone / Watch flavors ────────────────────────────────────
    // Lets one repo build two APKs: the phone app (lib/main.dart) and
    // the Wear OS companion app (lib/main_watch.dart).
    //
    // IMPORTANT: neither flavor sets applicationIdSuffix. The Wear OS
    // Data Layer API requires the phone app and watch app to share the
    // EXACT SAME applicationId to find each other at all — adding a
    // suffix to either flavor silently breaks phone<->watch
    // communication (no error, they just never see each other).
    flavorDimensions += "target"
    productFlavors {
        create("mobile") {
            dimension = "target"
            // Uses src/main/AndroidManifest.xml as-is.
        }
        create("wear") {
            dimension = "target"
            // Gradle merges src/wear/AndroidManifest.xml ON TOP of
            // src/main/AndroidManifest.xml for this flavor only.
        }
    }

    sourceSets {
        getByName("wear") {
            manifest.srcFile("src/wear/AndroidManifest.xml")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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

dependencies {
    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:34.14.1"))

    // Add Firebase dependencies (NO versions needed when using BoM)
    implementation("com.google.firebase:firebase-analytics")

    // Add other Firebase products here as needed, e.g.:
    // implementation("com.google.firebase:firebase-auth")
    // implementation("com.google.firebase:firebase-firestore")
    
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}