{ config, pkgs, ... }:
let
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    platformVersions = [
      "34"
      "35"
      "36"
    ];
    buildToolsVersions = [
      "34.0.0"
      "35.0.1"
      "36.0.0"
    ];
    includeSources = true;

    # WSL 内的 Android Emulator 加速链路不稳定，默认使用 Windows 模拟器或真机。
    includeEmulator = false;
    includeSystemImages = false;

    includeNDK = true;
    ndkVersions = [
      "26.3.11579264"
      "28.2.13676358"
    ];
    includeCmake = true;
    cmakeVersions = [ "3.22.1" ];
  };

  androidSdk = androidComposition.androidsdk;
  androidSdkRoot = "${androidSdk}/libexec/android-sdk";
in
{
  home.packages = [
    androidSdk
    pkgs.android-studio
    pkgs.jdk21
    pkgs.gradle
    pkgs.kotlin
  ];

  home.sessionVariables = {
    ANDROID_HOME = androidSdkRoot;
    ANDROID_SDK_ROOT = androidSdkRoot;
    ANDROID_NDK_HOME = "${androidSdkRoot}/ndk/28.2.13676358";
    ANDROID_NDK_ROOT = "${androidSdkRoot}/ndk/28.2.13676358";
    ANDROID_USER_HOME = "${config.home.homeDirectory}/.android";
    GRADLE_USER_HOME = "${config.home.homeDirectory}/.gradle";
    JAVA_HOME = "${pkgs.jdk21}/lib/openjdk";
    GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdkRoot}/build-tools/36.0.0/aapt2";
  };

  home.sessionPath = [
    "${androidSdkRoot}/cmdline-tools/latest/bin"
    "${androidSdkRoot}/platform-tools"
    "${androidSdkRoot}/build-tools/36.0.0"
  ];
}
