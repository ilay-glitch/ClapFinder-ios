plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// AdMob IDs. These are Google's public TEST IDs — Android needs its OWN AdMob app and
// ad units before release (ANDROID_HANDOFF §3). Never reuse IDs from the iOS repo.
val admobAppId = "ca-app-pub-3940256099942544~3347511713"
val admobAppOpenUnit = "ca-app-pub-3940256099942544/9257395921"
val admobInterstitialUnit = "ca-app-pub-3940256099942544/1033173712"

android {
    namespace = "com.appcentral.guarddog"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "com.appcentral.guarddog"
        minSdk = libs.versions.minSdk.get().toInt()
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = 1
        versionName = "1.0.0"

        manifestPlaceholders["admobAppId"] = admobAppId
        buildConfigField("String", "ADMOB_APP_OPEN_UNIT", "\"$admobAppOpenUnit\"")
        buildConfigField("String", "ADMOB_INTERSTITIAL_UNIT", "\"$admobInterstitialUnit\"")
    }

    androidResources {
        localeFilters += listOf("en")
        // MediaPlayer reads sounds via openRawResourceFd, which needs them stored uncompressed.
        noCompress += "flac"
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" }
    }

    kotlin { jvmToolchain(17) }
}

dependencies {
    implementation(project(":core"))

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.coroutines.android)

    implementation(libs.play.services.ads)
    implementation(libs.ump)

    testImplementation(libs.junit)
}
