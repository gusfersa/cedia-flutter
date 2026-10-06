plugins {
    id("com.android.application")
    // El plugin de Flutter se aplica después del plugin de Android.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.bto.exploraec"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Identidad de la práctica, igual al identificador de las teselas OSM.
        applicationId = "com.bto.exploraec"
        // Versiones mínimas y objetivo configuradas por el SDK de Flutter.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // El código y nombre de versión provienen de pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Firma de depuración para el laboratorio; no es una firma de tienda.
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
