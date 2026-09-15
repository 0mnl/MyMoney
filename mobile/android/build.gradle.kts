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
// isar_flutter_libs 3.1.0+1 собран под AGP 7 и под AGP 8 не собирается сам по себе:
//   * не выставляет compileSdk — AAPT валится с «resource android:attr/lStar
//     not found» (атрибут появился в API 31);
//   * не объявляет namespace — с AGP 8 это ошибка конфигурации, а не warning;
//   * держит в манифесте атрибут `package="…"`, который AGP ≥ 8.4 не принимает.
//
// Upstream мёртв (isar 3 EOL), поэтому чиним со стороны приложения.
//
// Манифест правится прямо в pub-cache: другого места у зависимости нет. Путь
// берём от самого подпроекта, поэтому он одинаково работает на macOS, Linux и
// Windows — раньше здесь был захардкожен Windows-путь, и на macOS блок молча
// ничего не делал.
//
// ВАЖНО: блок обязан быть идемпотентным. Он правит файл в общем кэше, то есть
// со второй сборки видит уже исправленный манифест. Поэтому namespace берётся
// из `package=` только пока атрибут на месте, а дальше — из `group`, который
// плагин объявляет у себя в build.gradle ('dev.isar.isar_flutter_libs').
// Первая версия этого обхода читала только манифест и разваливалась на второй
// сборке: атрибут уже вырезан, namespace взять неоткуда, AGP падает.
//
// Регистрируем afterEvaluate ДО evaluationDependsOn(":app"), иначе подпроекты
// уже оценены.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.apply {
            if (compileSdk == null || compileSdk!! < 34) {
                compileSdk = 34
            }

            val manifest = file("src/main/AndroidManifest.xml")
            val content = if (manifest.exists()) manifest.readText() else ""
            val declaredPackage =
                Regex("package\\s*=\\s*\"([^\"]+)\"").find(content)?.groupValues?.get(1)

            if (namespace == null) {
                val fallback = project.group.toString().takeIf { it.contains('.') }
                val resolved = declaredPackage ?: fallback
                if (resolved != null) {
                    namespace = resolved
                    println("Injected namespace '$resolved' into ${project.name}")
                }
            }

            if (declaredPackage != null) {
                manifest.writeText(
                    content.replace(Regex("\\s*package\\s*=\\s*\"[^\"]+\""), ""),
                )
                println("Removed deprecated package= from ${project.name} manifest")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
