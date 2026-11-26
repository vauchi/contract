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

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    testImplementation("junit:junit:4.13.2")
}

tasks.test {
    systemProperty("vauchi.contractCheckout", projectDir.parentFile.absolutePath)
}
