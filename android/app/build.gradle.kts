import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// One ABI per build. Gradle will happily merge plugin AARs for ABIs we have no
// libapp.so / libflutter.so for, producing an APK that installs and then crashes
// on load. Override with `-PtargetAbi=x86_64` for emulator runs.
//
// 规则内核已从 Rust 换成 Kotlin（android/.../QqaCore.kt），所以这里不再需要
// 任何自带的 .so —— APK 里的 native 库只剩 Flutter 自己的那几个。
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
        // Order matters: `flutter build apk --release` with no --target-platform
        // passes `-Ptarget-platform=android-arm,android-arm64,android-x64` (all
        // three). Checking android-x64 first won on that fat string and shipped
        // an x86_64-only APK, which real phones reject as "incompatible with
        // 64-bit system". Prefer arm64 whenever it is among the requested ABIs.
        platform.contains("android-arm64") -> "arm64-v8a"
        platform.contains("android-x64") -> "x86_64"
        platform.contains("android-arm") -> "armeabi-v7a"
        else -> "arm64-v8a"
    }
}

// 只有显式要求 Rust 内核（`--dart-define=QQA_KERNEL_RUST=true`）时才把
// libqqa_core.so 打进包。Kotlin 版的 APK 必须干净：否则两份产物里躺着同一个
// .so，用户装哪份都分不清自己跑的是哪个内核。
//
// Flutter 把 --dart-define 编成 base64 塞进 -Pdart-defines，这里解回来判断。
val rustKernelRequested: Boolean = run {
    val raw = project.findProperty("dart-defines") as String? ?: return@run false
    raw.split(",").mapNotNull { part ->
        runCatching {
            String(Base64.getMimeDecoder().decode(part), Charsets.UTF_8)
        }.getOrNull()
    }.any { it == "QQA_KERNEL_RUST=true" }
}

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
            // kotlin 版不带自家 .so：tools/build-rust.sh 把 libqqa_core.so 放在
            // 默认 jniLibs 目录里，这里在打包阶段剔掉，只有 --dart-define=
            // QQA_KERNEL_RUST=true 的那次构建才保留。
            if (!rustKernelRequested) excludes += "lib/**/libqqa_core.so"
        }
    }

    // Declared before buildTypes: `signingConfigs.getByName("release")` below is
    // resolved at configuration time and would fail if created afterwards.
    signingConfigs {
        create("release") {
            storeFile = file("qqa-release.jks")
            storePassword = "qqa-assistant"
            keyAlias = "qqa"
            keyPassword = "qqa-assistant"
        }
    }

    buildTypes {
        release {
            // Signed with the project keystore so the APK is installable
            // outside of `flutter run`.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // JVM 单测：QqaCoreTest 的断言与 rust/src/rules.rs 的 #[test] 一一对应，
    // 用来证明 Kotlin 移植和 Rust 原版逐字符相同（`cd android && ./gradlew test`）。
    testImplementation("junit:junit:4.13.2")
    // GoldenParityTest 读 src/test/resources/golden.json（由 `cargo run --bin golden`
    // 从 Rust 参考实现导出）。android.jar 里的 org.json 在 JVM 单测中是空壳实现，
    // 因此引入真实实现。
    testImplementation("org.json:json:20240303")
}
