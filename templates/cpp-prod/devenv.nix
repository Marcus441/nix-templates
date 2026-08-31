{pkgs, ...}: {
  packages = [
    pkgs.llvmPackages.clang
    pkgs.llvmPackages.clang-tools
    pkgs.llvmPackages.lldb
    pkgs.llvmPackages.bintools
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.gtest
    pkgs.cpplint
    pkgs.gcovr
  ];

  enterTest = ''
    cmake --workflow --preset release
  '';
}
