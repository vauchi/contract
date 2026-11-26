// SPDX-FileCopyrightText: 2026 Mattia Egloff <mattia.egloff@pm.me>
// SPDX-License-Identifier: AGPL-3.0-or-later

plugins {
    kotlin("jvm") version "2.2.10"
    `maven-publish`
}

group = "app.vauchi"
version = Regex("""(?m)^version\s*=\s*"([^"]+)"""")
    .find(file("../Cargo.toml").readText())?.groupValues?.get(1)
    ?: error("Contract Cargo.toml has no package version")

repositories {
    mavenCentral()
}

kotlin {
    jvmToolchain(17)
}

dependencyLocking {
    lockAllConfigurations()
}

val ktlint by configurations.creating

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testImplementation("junit:junit:4.13.2")
    testImplementation("io.kotest:kotest-property:5.9.1")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    ktlint("com.pinterest.ktlint:ktlint-cli:1.8.0")
}

tasks.register<JavaExec>("formatGenerated") {
    classpath = ktlint
    mainClass = "com.pinterest.ktlint.Main"
    doFirst {
        workingDir(providers.gradleProperty("generatedRoot").get())
        args("-F", "*.kt")
    }
}

tasks.register<JavaExec>("lintKotlin") {
    classpath = ktlint
    mainClass = "com.pinterest.ktlint.Main"
    args("src/**/*.kt")
}

val rustOracleDirectory = providers.environmentVariable("VAUCHI_ORACLE_DIR")
    .filter { it.isNotEmpty() }
    .orElse(projectDir.parentFile.resolve("cache/oracle").absolutePath)

tasks.test {
    systemProperty("vauchi.contractCheckout", projectDir.parentFile.absolutePath)
    inputs.files(rustOracleDirectory.map { fileTree(it) { include("*.jsonl") } })
        .withPropertyName("rustOracle")
        .withPathSensitivity(PathSensitivity.RELATIVE)
    exclude("**/LargePayloadTest.class")
}

val boundedMemoryTest by tasks.registering(Test::class) {
    testClassesDirs = sourceSets["test"].output.classesDirs
    classpath = sourceSets["test"].runtimeClasspath
    maxHeapSize = "96m"
    filter { includeTestsMatching("app.vauchi.contract.LargePayloadTest") }
}

tasks.check { dependsOn(boundedMemoryTest) }

tasks.processResources {
    from("../fixtures/protocol_conformance_v1.json") {
        into("app/vauchi/contract")
    }
}

java {
    withSourcesJar()
}

tasks.jar {
    manifest.attributes["Implementation-Version"] = project.version
}

val verifyReleaseVersion by tasks.registering {
    doLast {
        val tag = providers.environmentVariable("CI_COMMIT_TAG").orNull
        if (!tag.isNullOrEmpty()) {
            check(tag == "v${project.version}") { "Release tag and contract version disagree" }
        }
    }
}

publishing {
    publications {
        create<MavenPublication>("contract") {
            from(components["java"])
            artifactId = "contract"
            pom {
                name = "Vauchi Contract"
                description = "Typed Kotlin shell commands, events and strict JSON codecs"
                url = "https://gitlab.com/vauchi/contract"
                licenses {
                    license {
                        name = "GNU Affero General Public License v3.0 or later"
                        url = "https://www.gnu.org/licenses/agpl-3.0.html"
                    }
                }
                scm {
                    url = "https://gitlab.com/vauchi/contract"
                    connection = "scm:git:https://gitlab.com/vauchi/contract.git"
                }
            }
        }
    }
    repositories {
        providers.gradleProperty("vauchiPublishRepository").orNull?.let { destination ->
            maven {
                name = "LocalCheck"
                url = uri(destination)
            }
        }
        providers.environmentVariable("CI_PROJECT_ID").orNull?.let { projectId ->
            maven {
                name = "GitLab"
                val api = providers.environmentVariable("CI_API_V4_URL").get()
                url = uri("$api/projects/$projectId/packages/maven")
                credentials(HttpHeaderCredentials::class) {
                    name = "Job-Token"
                    value = providers.environmentVariable("CI_JOB_TOKEN").orNull
                }
                authentication { create<HttpHeaderAuthentication>("header") }
            }
        }
    }
}

tasks.withType<PublishToMavenRepository>().configureEach {
    dependsOn(verifyReleaseVersion, tasks.test, boundedMemoryTest)
}
