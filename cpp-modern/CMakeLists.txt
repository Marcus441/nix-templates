cmake_minimum_required(VERSION 4.0...4.3)
# [META] Project definition
project(my-project LANGUAGES CXX)
# [CXX] Language standard configuration
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# [TOOL] Tooling and introspection
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES ON)
# [WARN] Modules require Ninja generator
if(NOT CMAKE_GENERATOR MATCHES "Ninja")
    message(WARNING "C++ modules require the Ninja generator. "
                    "Configure with: cmake -G Ninja ...")
endif()
# [QUAL] Declare options early so they're available everywhere below
option(USE_SANITIZERS "Enable ASan/UBSan" ON)
# [QUAL] Propagate sanitizer flags globally so FetchContent deps pick them up
if(USE_SANITIZERS AND CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(CMAKE_CXX_FLAGS_DEBUG
            "${CMAKE_CXX_FLAGS_DEBUG} -fsanitize=address,undefined -fno-omit-frame-pointer")
        set(CMAKE_EXE_LINKER_FLAGS_DEBUG
            "${CMAKE_EXE_LINKER_FLAGS_DEBUG} -fsanitize=address,undefined")
        set(CMAKE_SHARED_LINKER_FLAGS_DEBUG
            "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} -fsanitize=address,undefined")
    endif()
endif()
# [MODS] C++23 named module sources — add your module interface units here
set(MODULE_SOURCES
    src/modules/my_module.cpp
)
# [MODS] Module library — compiled once, shared by app and tests via linking
if(MODULE_SOURCES)
    add_library(${PROJECT_NAME}-modules STATIC)
    target_compile_features(${PROJECT_NAME}-modules PUBLIC cxx_std_23)
    set_target_properties(${PROJECT_NAME}-modules PROPERTIES CXX_EXTENSIONS OFF)
    target_sources(${PROJECT_NAME}-modules
        PUBLIC
            FILE_SET CXX_MODULES
            BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
            FILES     ${MODULE_SOURCES}
    )
    target_compile_options(${PROJECT_NAME}-modules PRIVATE
        -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
        $<$<CONFIG:Release>:-O3>
        $<$<CONFIG:RelWithDebInfo>:-O2 -g>
        $<$<CONFIG:Debug>:-g -Og>
    )
endif()
# [SRCS] Main executable
add_executable(${PROJECT_NAME}
    src/main.cpp
)
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_EXTENSIONS OFF)
target_compile_options(${PROJECT_NAME} PRIVATE
    -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:RelWithDebInfo>:-O2 -g>
    $<$<CONFIG:Debug>:-g -Og>
)
if(MODULE_SOURCES)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}-modules)
endif()
# [TEST] Testing
enable_testing()
include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.17.0
    EXCLUDE_FROM_ALL
)
# [TEST] In sandboxed builds (e.g. Nix), fall back to system-provided GTest
if(FETCHCONTENT_FULLY_DISCONNECTED)
    find_package(GTest REQUIRED)
    # Nix exposes GTest::gtest_main and GTest::gmock — normalise to the names
    # FetchContent would have provided so the rest of the file is unchanged
    if(NOT TARGET gtest_main)
        add_library(gtest_main ALIAS GTest::gtest_main)
    endif()
    if(NOT TARGET gmock_main)
        if(TARGET GTest::gmock_main)
            add_library(gmock_main ALIAS GTest::gmock_main)
        else()
            # Older gtest packages don't ship gmock_main separately — alias gtest_main
            add_library(gmock_main ALIAS GTest::gtest_main)
        endif()
    endif()
else()
    FetchContent_MakeAvailable(googletest)
endif()
add_executable(${PROJECT_NAME}-tests
    tests/main_test.cpp
)
target_compile_features(${PROJECT_NAME}-tests PRIVATE cxx_std_23)
set_target_properties(${PROJECT_NAME}-tests PROPERTIES CXX_EXTENSIONS OFF)
target_compile_options(${PROJECT_NAME}-tests PRIVATE
    -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
    $<$<CONFIG:Debug>:-g -Og>
)
target_link_libraries(${PROJECT_NAME}-tests PRIVATE
    gtest_main
    gmock_main
)
if(MODULE_SOURCES)
    target_link_libraries(${PROJECT_NAME}-tests PRIVATE ${PROJECT_NAME}-modules)
endif()
add_test(NAME ${PROJECT_NAME}-tests COMMAND ${PROJECT_NAME}-tests)
# [INST] Installation rules
install(TARGETS ${PROJECT_NAME} DESTINATION bin)
if(MODULE_SOURCES)
    install(TARGETS ${PROJECT_NAME}-modules
        FILE_SET CXX_MODULES DESTINATION modules
    )
endif()
