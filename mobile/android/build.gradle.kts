allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// isar_flutter_libs 3.1.0+1 ships an AndroidManifest.xml with the deprecated
// `package="..."` attribute, which AGP ≥ 8.4 refuses to build. Upstream is
// unmaintained (isar 3 EOL). Until we migrate to a maintained fork, rewrite
// the manifest in the pub cache to remove `package=` and rely on the plugin
// namespace inferred from the module name. This runs at configuration time
// so `processDebugManifest` sees the cleaned file.
run {
    val isarManifest = java.io.File(
        System.getProperty("user.home"),
        "AppData/Local/Pub/Cache/hosted/pub.dev/isar_flutter_libs-3.1.0+1/android/src/main/AndroidManifest.xml",
    )
    if (isarManifest.exists()) {
        val original = isarManifest.readText()
        val cleaned = original.replace(Regex("\\s*package=\"dev\\.isar\\.isar_flutter_libs\""), "")
        if (cleaned != original) {
            isarManifest.writeText(cleaned)
            println("Patched isar_flutter_libs AndroidManifest.xml (removed package= attr)")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
