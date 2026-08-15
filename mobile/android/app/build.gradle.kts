import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
val hasReleaseKeys = if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
    rootProject.file(keyProperties.getProperty("storeFile", "")).exists()
} else {
    false
}

android {
    namespace = "com.pondyconnect.pondyconnect"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseKeys) {
            create("consumer") {
                keyAlias = keyProperties.getProperty("keyAliasConsumer", keyProperties.getProperty("keyAlias", ""))
                keyPassword = keyProperties.getProperty("keyPassword", "")
                storeFile = rootProject.file(keyProperties.getProperty("storeFile", ""))
                storePassword = keyProperties.getProperty("storePassword", "")
            }
            create("driver") {
                keyAlias = keyProperties.getProperty("keyAliasDriver", keyProperties.getProperty("keyAlias", ""))
                keyPassword = keyProperties.getProperty("keyPassword", "")
                storeFile = rootProject.file(keyProperties.getProperty("storeFile", ""))
                storePassword = keyProperties.getProperty("storePassword", "")
            }
            create("partner") {
                keyAlias = keyProperties.getProperty("keyAliasPartner", keyProperties.getProperty("keyAlias", ""))
                keyPassword = keyProperties.getProperty("keyPassword", "")
                storeFile = rootProject.file(keyProperties.getProperty("storeFile", ""))
                storePassword = keyProperties.getProperty("storePassword", "")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pondyconnect.pondyconnect"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Google Play 2026 mandate: target Android 16 (API 36) by Aug 31, 2026.
        // compileSdk stays at 37 (>= 36, compliant); targetSdk pinned to 36.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    flavorDimensions += "app"
    productFlavors {
        create("consumer") {
            dimension = "app"
            applicationId = "com.pondyconnect.app"
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("consumer")
        }
        create("driver") {
            dimension = "app"
            applicationId = "com.pondyconnect.driver"
            // Driver app needs higher minSdk for foreground service features
            minSdk = 24
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("driver")
        }
        create("partner") {
            dimension = "app"
            applicationId = "com.pondyconnect.partner"
            if (hasReleaseKeys) signingConfig = signingConfigs.getByName("partner")
        }
    }

    buildTypes {
        release {
            // Falls back to debug signing when no key.properties is present.
            // When key.properties exists, each flavor uses its own signingConfig
            // set in the productFlavors block above.
            signingConfig = if (hasReleaseKeys) null else signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Firebase BOM — manages Firebase dependency versions
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
