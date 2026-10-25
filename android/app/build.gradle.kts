import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by android/key.properties (git-ignored). When the file
// is absent (e.g. a developer running `flutter run --release` without the upload
// keystore), the release build falls back to debug keys so local builds still work.
// CI / publish builds MUST have key.properties present — a debug-signed artifact
// cannot be uploaded to Play Store.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "io.sheikhy.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.sheikhy.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the real upload keystore when key.properties is present; otherwise
            // fall back to debug keys so `flutter run --release` still works locally.
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    buildFeatures {
        resValues = true
    }

    // White-label clients. One flavor per sheikh. Each sets its own applicationId,
    // launcher name (resValue app_name → referenced as @string/app_name in the
    // manifest) and deep-link scheme (manifestPlaceholder consumed by the VIEW
    // intent-filter). `ahmed` is the live client — its values MUST stay identical
    // to the pre-flavor build so existing installs update in place.
    flavorDimensions += "client"
    productFlavors {
        create("ahmed") {
            dimension = "client"
            applicationId = "io.sheikhy.app"
            resValue("string", "app_name", "الشيخ أحمد بن عبد التواب")
            manifestPlaceholders["deepLinkScheme"] = "io.sheikhy.app"
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
