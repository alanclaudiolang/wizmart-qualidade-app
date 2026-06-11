import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Lê assinatura de release de duas fontes (a primeira encontrada vence):
//  1) android/key.properties — desenvolvimento local (NÃO commitado).
//  2) Variáveis de ambiente do CI — UPLOAD_KEYSTORE_PATH, UPLOAD_KEYSTORE_PASSWORD,
//     UPLOAD_KEY_ALIAS, UPLOAD_KEY_PASSWORD. Geradas a partir de GitHub Secrets.
// Sem fonte: cai pra debug keystore (apk só instalável em devices de dev).
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val ciKeystorePath: String? = System.getenv("UPLOAD_KEYSTORE_PATH")
val hasReleaseSigning = keystoreProperties.isNotEmpty() || ciKeystorePath != null

android {
    namespace = "com.wizmart.wizmart_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.wizmart.wizmart_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (ciKeystorePath != null) {
                storeFile = file(ciKeystorePath)
                storePassword = System.getenv("UPLOAD_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("UPLOAD_KEY_ALIAS")
                keyPassword = System.getenv("UPLOAD_KEY_PASSWORD")
            } else if (keystoreProperties.isNotEmpty()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Mesma chave em todos os builds → APKs atualizam por cima
            // sem precisar desinstalar. Em dev sem keystore configurada,
            // cai pra debug (cada build assina diferente — só dev local).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}
