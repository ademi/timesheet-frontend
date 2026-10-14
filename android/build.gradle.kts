allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// AGP 9 enforces AAR compileSdk metadata. Some pub plugins still declare
// compileSdk 34 while transitive AndroidX needs 36 — bump after the plugin
// android {} block (or immediately if evaluationDependsOn already evaluated it).
fun Project.bumpAndroidLibraryCompileSdk(minSdk: Int = 36) {
    val androidExt = extensions.findByName("android") ?: return
    try {
        val setCompileSdk =
            androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdk" && it.parameterCount == 1
            }
        val setCompileSdkVersion =
            androidExt.javaClass.methods.firstOrNull {
                it.name == "setCompileSdkVersion" && it.parameterCount == 1
            }
        when {
            setCompileSdk != null -> {
                setCompileSdk.isAccessible = true
                setCompileSdk.invoke(androidExt, minSdk)
            }
            setCompileSdkVersion != null -> {
                setCompileSdkVersion.isAccessible = true
                val param = setCompileSdkVersion.parameterTypes[0]
                if (param == Int::class.javaPrimitiveType || param == Integer::class.java) {
                    setCompileSdkVersion.invoke(androidExt, minSdk)
                } else {
                    setCompileSdkVersion.invoke(androidExt, "android-$minSdk")
                }
            }
        }
    } catch (_: Exception) {
        // Non-Android or incompatible extension — ignore.
    }
}

subprojects {
    if (state.executed) {
        bumpAndroidLibraryCompileSdk()
    } else {
        afterEvaluate { bumpAndroidLibraryCompileSdk() }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
