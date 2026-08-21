plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "au.com.zenithpayments.zenpay_example_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        // AGP 8+ generates BuildConfig only when opted in — needed for the
        // BuildConfig.DEBUG check gating Firebase App Distribution below.
        buildConfig = true
    }

    defaultConfig {
        applicationId = "au.com.zenithpayments.zenpay_example_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        missingDimensionStrategy("default", "production")
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

dependencies {
    // Official Firebase App Distribution SDK — replaces the third-party
    // firebase_app_distribution pub package. API-only lib is safe for every
    // variant; the full implementation only goes in the release variant,
    // matching what `cli.dart --distribute` actually builds and uploads.
    implementation("com.google.firebase:firebase-appdistribution-api:16.0.0-beta20")
    releaseImplementation("com.google.firebase:firebase-appdistribution:16.0.0-beta20")
}

flutter {
    source = "../.."
}
