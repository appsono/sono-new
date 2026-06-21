{
  description = "dev env for sono";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        config.android_sdk.accept_license = true;
      };

      androidComposition = pkgs.androidenv.composeAndroidPackages {
        platformVersions = [ "34" "35" "36" ];
        buildToolsVersions = [ "35.0.0" ];
        includeNDK = true;
        ndkVersions = [ "27.3.13750724" ];
        cmakeVersions = [ "3.22.1" ];
        includeEmulator = false;
        includeSystemImages = false;
        extraLicenses = [
          "android-sdk-preview-license"
          "android-googletv-license"
          "android-sdk-arm-dbt-license"
          "google-gdk-license"
          "intel-android-extra-license"
          "intel-android-sysimage-license"
          "mips-android-sysimage-license"
        ];
      };
      androidSdk = androidComposition.androidsdk;
    in {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = [
          pkgs.flutter341
          pkgs.jdk21
          androidSdk

          #linux desktop build deps
          pkgs.pkg-config
          pkgs.cmake
          pkgs.ninja
          pkgs.clang
          pkgs.gtk3
          pkgs.sqlite
          pkgs.mpv-unwrapped #provides libmpv for media_kit
          pkgs.libsysprof-capture #provides sysprof-capture-4.pc needed by glib
          pkgs.mimalloc
          pkgs.libsecret #flutter_secure_storage_linux
          pkgs.pcre2
        ];

        ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
        ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
        JAVA_HOME = "${pkgs.jdk21}";

        shellHook = ''
          export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
          flutter config --no-analytics >/dev/null 2>&1 || true
        '';
      };
    };
}
