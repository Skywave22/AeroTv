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

// ---------------------------------------------------------------------------
// JVM target alignment
//
// Flutter plugins do not agree on a JVM target: flutter_js compiles Kotlin to
// 1.8, android_file_picker compiles Java to 17, the app uses 11. Kotlin 2.x
// turns any Java/Kotlin mismatch inside a module into a hard error:
//   "Inconsistent JVM-target compatibility detected for tasks
//    'compileDebugJavaWithJavac' (17) and 'compileDebugKotlin' (11)"
//
// Forcing one global target just moves the failure to the next plugin, so
// instead derive each module's Kotlin target from *its own* Java target.
//
// The value is read inside a lazy `provider` so it resolves at execution time,
// when the sibling JavaCompile task exists and is fully configured. This needs
// no AGP types and works no matter which DSL version a plugin uses.
// ---------------------------------------------------------------------------
subprojects {
    tasks.withType(org.jetbrains.kotlin.gradle.tasks.KotlinCompile::class.java)
        .configureEach {
            val kotlinTaskName = name
            compilerOptions.jvmTarget.set(
                project.provider {
                    // compileDebugKotlin -> compileDebugJavaWithJavac
                    val javaTaskName =
                        kotlinTaskName.replace("Kotlin", "JavaWithJavac")
                    val javaTask =
                        project.tasks.findByName(javaTaskName) as? JavaCompile
                    org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(
                        javaTask?.targetCompatibility ?: "11",
                    )
                },
            )
        }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
