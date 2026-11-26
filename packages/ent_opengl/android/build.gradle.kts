// The Android side of ent_opengl: the textures Flutter shows the GL renderer's frames in (EntOpenGlPlugin.kt) and the
// native window of each, which only the NDK gives (src/main/cpp/window.c).
group = "vn.kamora.ent_opengl"
version = "0.1.0"

buildscript {
	val kotlinVersion = "2.4.0"
	repositories {
		google()
		mavenCentral()
	}

	dependencies {
		classpath("com.android.tools.build:gradle:9.1.1")
		classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
	}
}

allprojects {
	repositories {
		google()
		mavenCentral()
	}
}

plugins {
	id("com.android.library")
}

android {
	namespace = "vn.kamora.ent_opengl"

	compileSdk = 36

	compileOptions {
		sourceCompatibility = JavaVersion.VERSION_17
		targetCompatibility = JavaVersion.VERSION_17
	}

	sourceSets {
		getByName("main") {
			java.srcDirs("src/main/kotlin")
		}
	}

	defaultConfig {
		minSdk = 24
	}

	externalNativeBuild {
		cmake {
			path = file("src/main/cpp/CMakeLists.txt")
		}
	}
}

kotlin {
	compilerOptions {
		jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
	}
}
