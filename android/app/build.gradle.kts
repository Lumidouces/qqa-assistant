import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// One ABI per build. The Rust core must exist as a .so for whatever ABI is
// shipped: Gradle will happily merge plugin AARs for ABIs we have no
// libapp.so / libflutter.so for, producing an APK that installs and then
// crashes on load. Override with `-PtargetAbi=x86_64` for emulator runs.
//
// `flutter build apk --target-platform android-x64` does NOT set targetAbi; it
// only passes -Ptarget-platform, which Gradle otherwise ignores here. Map it so
// the requested ABI is the one actually packaged.
val resolvedAbi: String = run {
    val explicit = project.findProperty("targetAbi") as String?
    if (explicit != null) return@run explicit
    val platform = project.findProperty("target-platform") as String?
    when {
        platform == null -> "arm64-v8a"
        platform.contains("android-x64") -> "x86_64"
        platform.contains("android-arm64") -> "arm64-v8a"
        platform.contains("android-arm") -> "armeabi-v7a"
        else -> "arm64-v8a"
    }
}

// Release signing is read from android/key.properties, which is git-ignored.
// Copy android/key.properties.example and fill in your own keystore. When the
// file (or the keystore it points at) is missing, release builds fall back to
// the debug key so `flutter build apk --release` still works for local testing.
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val releaseKeystore = keystoreProps.getProperty("storeFile")?.let { rootProject.file(it) }
val hasReleaseSigning = releaseKeystore != null && releaseKeystore.exists()

android {
    namespace = "cn.local.qqa.qqa_assistant"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "cn.local.qqa.qqa_assistant"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // `flutter build apk --target-platform android-x64` passes
        // -Ptarget-platform=android-x64; resolvedAbi maps it to a real ABI so the
        // APK actually contains libflutter.so for the ABI we asked for.
        val targetAbi = resolvedAbi
        ndk {
            abiFilters += listOf(targetAbi)
        }
    }

    // Drop every ABI the build did not target, for the same reason as above.
    packaging {
        jniLibs {
            val all = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64", "mips", "mips64")
            val keep = resolvedAbi
            excludes += all.filter { it != keep }.map { "lib/$it/**" }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseKeystore
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
