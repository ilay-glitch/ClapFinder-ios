pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "GuardDog"

// Pure Kotlin/JVM: guard state machines, ad policies, catalog. No Android imports,
// injected clocks — every debounce and grace rule is unit-testable without sleeping.
include(":core")

// Compose app and everything platform-bound (sensors, audio, torch, service, ads).
include(":app")
