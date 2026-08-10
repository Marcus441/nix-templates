# find_package first, FetchContent only on request. The dev shell and the Nix
# sandbox both provide GoogleTest, so the default path never touches the
# network and both environments take the same branch.
find_package(GTest CONFIG QUIET)
if(NOT GTest_FOUND)
    find_package(GTest MODULE QUIET)
endif()

if(NOT GTest_FOUND)
    if(NOT MYPROJECT_FETCH_DEPENDENCIES)
        message(FATAL_ERROR
            "GoogleTest was not found. `nix develop` provides it; otherwise "
            "install it, or reconfigure with -DMYPROJECT_FETCH_DEPENDENCIES=ON "
            "to download it.")
    endif()

    include(FetchContent)
    FetchContent_Declare(googletest
        URL      https://github.com/google/googletest/archive/refs/tags/v1.17.0.tar.gz
        URL_HASH SHA256=65fab701d9829d38cb77c14acdc431d2108bfdbf8979e40eb8ae567edf10b27c
        EXCLUDE_FROM_ALL)
    FetchContent_MakeAvailable(googletest)
endif()

add_executable(myproject_tests greeting_test.cpp)
target_link_libraries(myproject_tests
    PRIVATE myproject::core myproject::warnings GTest::gtest_main GTest::gmock)

include(GoogleTest)
# PRE_TEST defers discovery to ctest time. The default, POST_BUILD, runs the
# test binary during the build, which breaks under sanitizers and cross builds.
gtest_discover_tests(myproject_tests DISCOVERY_MODE PRE_TEST)
