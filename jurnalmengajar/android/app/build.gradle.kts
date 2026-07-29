import java.io.File
import java.util.Properties

val pubspecFile = file("../../pubspec.yaml")
val localPropertiesFile = file("../local.properties")

fun bumpVersionIfNeeded() {
    val taskNames = gradle.startParameter.taskNames
    val isReleaseBuild = taskNames.any { it.contains("Release", ignoreCase = true) || it.contains("assemble", ignoreCase = true) && !it.contains("Debug", ignoreCase = true) }
    
    val hasBumpedProperty = "hasBumpedVersionInThisBuild"
    if (isReleaseBuild && !rootProject.extra.has(hasBumpedProperty)) {
        rootProject.extra.set(hasBumpedProperty, true)
        
        if (pubspecFile.exists()) {
            val content = pubspecFile.readText()
            val regex = Regex("""^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)""", RegexOption.MULTILINE)
            val match = regex.find(content)
            if (match != null) {
                val major = match.groupValues[1].toInt()
                val minor = match.groupValues[2].toInt()
                val oldPatch = match.groupValues[3].toInt()
                val oldBuild = match.groupValues[4].toInt()
                
                val newPatch = oldPatch + 1
                val newBuild = oldBuild + 1
                val newVersionName = "$major.$minor.$newPatch"
                val newFullVersion = "$newVersionName+$newBuild"
                
                val newContent = content.replaceFirst(match.value, "version: $newFullVersion")
                pubspecFile.writeText(newContent)
                
                println("🚀 [Gradle Auto-Version Bumper] Bumped version in pubspec.yaml to $newFullVersion")
                
                if (localPropertiesFile.exists()) {
                    val props = Properties()
                    localPropertiesFile.inputStream().use { props.load(it) }
                    props.setProperty("flutter.versionName", newVersionName)
                    props.setProperty("flutter.versionCode", newBuild.toString())
                    localPropertiesFile.outputStream().use { props.store(it, "Updated by Gradle Auto-Version Bumper") }
                }
            }
        }
    }
}

bumpVersionIfNeeded()

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.jurnalmengajar"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.jurnalmengajar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
