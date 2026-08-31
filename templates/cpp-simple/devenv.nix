{pkgs, ...}: {
  packages = [
    pkgs.gnumake
    pkgs.llvmPackages.clang-tools
    pkgs.cpplint
    (
      if pkgs.stdenv.hostPlatform.isDarwin
      then pkgs.clang
      else pkgs.gcc
    )
  ];

  enterTest = ''
    make
    make run
  '';
}
