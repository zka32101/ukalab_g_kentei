import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// リリース署名鍵。ローカルは android/key.properties（gitignore対象）、
// CIは環境変数（GitHub Actions Secrets）から読む。どちらも無ければdebug鍵のまま。
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
fun signingProp(key: String, env: String): String? =
    keystoreProperties.getProperty(key) ?: System.getenv(env)

android {
    namespace = "com.yourwish.ukalab_g_kentei"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications が Java 8 の日時 API を使うため
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yourwish.ukalab_g_kentei"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val storeFilePath = signingProp("storeFile", "UPLOAD_STORE_FILE")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = signingProp("storePassword", "UPLOAD_STORE_PASSWORD")
                keyAlias = signingProp("keyAlias", "UPLOAD_KEY_ALIAS")
                keyPassword = signingProp("keyPassword", "UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // リリース署名鍵が設定されていればそれを使い、無ければdebug鍵のまま
            // （`flutter run --release` がローカルで動くようにするため）。
            signingConfig = if (signingProp("storeFile", "UPLOAD_STORE_FILE") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
