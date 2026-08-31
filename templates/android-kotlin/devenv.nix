{pkgs, ...}: let
  android-cli = pkgs.symlinkJoin {
    name = "android-cli-xcb";
    paths = [pkgs.android-cli];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/android --set QT_QPA_PLATFORM xcb
    '';
  };
in {
  packages = [
    android-cli
    pkgs.jdk17
    pkgs.gradle_9
    pkgs.kotlin
    pkgs.ktlint
  ];

  env.JAVA_HOME = pkgs.jdk17.home;

  enterShell = ''
    export ANDROID_AVD_HOME="''${ANDROID_AVD_HOME:-''${ANDROID_USER_HOME:-$HOME/.android}/avd}"
  '';
}
