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

// Inject namespace + force compileSdk for legacy plugins (required by AGP 8+).
// This fixes blue_thermal_printer and other older packages.
gradle.afterProject {
    if (project.plugins.hasPlugin("com.android.library")) {
        val androidExtension = project.extensions.getByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExtension.namespace.isNullOrEmpty()) {
            val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val packageName = javax.xml.parsers.DocumentBuilderFactory.newInstance()
                    .newDocumentBuilder()
                    .parse(manifestFile)
                    .documentElement
                    .getAttribute("package")
                if (packageName.isNotEmpty()) {
                    androidExtension.namespace = packageName
                }
            }
        }
        // Force legacy plugins to compile against SDK 34 (required by androidx deps)
        if (androidExtension.compileSdk == null || androidExtension.compileSdk!! < 34) {
            androidExtension.compileSdk = 34
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
