{pkgs, ...}: {
  packages = [
    pkgs.pkg-config
    (
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.lldb
      else pkgs.gdb
    )
  ];

  languages.rust.enable = true;

  env.RUST_BACKTRACE = "1";

  enterTest = ''
    cargo test
  '';
}
