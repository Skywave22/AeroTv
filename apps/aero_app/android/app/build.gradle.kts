import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release signing.
 *
 * CI writes android/key.properties from GitHub secrets. Locally, copy
 * key.properties.example and point it at your own keystore. When the file is
 * absent we fall back to debug signing so `flutter run --release` still works.
 */
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    // Neutral namespace/applicationId: it cannot be changed after publishing,
    // so it deliberately avoids the product's working title.
    namespace = "app.orbit.media"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "app.orbit.media"
        // media_kit/libmpv and the TV focus system need a modern baseline.
        // 24 covers essentially all Android TV / Fire TV devices in use.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("en")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            applicationIdSuffix = ".debug"
            isMinifyEnabled = false
        }
    }

    // NOTE: deliberately NO `splits { abi { ... } }` block.
    //
    // Flutter's `--split-per-abi` flag enables ABI splits itself. Declaring the
    // block here as well sets isEnable=false during evaluation and can win over
    // the plugin's own configuration, so Gradle emits a single
    // `app-release.apk` while the Flutter tool looks for
    // `app-arm64-v8a-release.apk` — producing the misleading
    // "Gradle build failed to produce an .apk file" even though Gradle
    // succeeded. Let the CLI own this entirely.

    packaging {
        resources {
            excludes += setOf(
                "META-INF/AL2.0",
                "META-INF/LGPL2.1",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
            )
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
