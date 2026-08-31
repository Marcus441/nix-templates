{pkgs, ...}: {
  packages = [
    pkgs.llvmPackages.clang
    pkgs.llvmPackages.clang-tools
    pkgs.llvmPackages.lldb
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.cpplint
  ];

  enterTest = ''
    cmake --preset default
    cmake --build --preset release
    ctest --preset release
  '';
}
