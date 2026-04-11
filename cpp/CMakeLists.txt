cmake_minimum_required(VERSION 3.31)
# [META] Project definition
project(my-project LANGUAGES CXX)
# [CXX] Language standard configuration
set(CMAKE_CXX_EXTENSIONS OFF)
# [TOOL] Tooling and introspection
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
# [SRCS] Explicit source file manifest
set(SOURCES
    src/main.cpp
)
add_executable(${PROJECT_NAME} ${SOURCES})
target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_EXTENSIONS OFF)
# [INCL] Header search paths
target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
# [FLAG] Core compiler options and warnings
target_compile_options(${PROJECT_NAME} PRIVATE
    -fcolor-diagnostics
    -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:RelWithDebInfo>:-O2 -g>
    $<$<CONFIG:Debug>:-g>
    $<$<CONFIG:Debug>:-Og>
)
# [QUAL] Sanitizers and quality gates
option(USE_SANITIZERS "Enable ASan/UBSan" ON)
if(USE_SANITIZERS AND CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(SAN_FLAGS -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_compile_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
        target_link_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
    endif()
endif()
# [TEST] Testing
enable_testing()
include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.17.0
)
FetchContent_MakeAvailable(googletest)
add_executable(${PROJECT_NAME}-tests
    tests/main_test.cpp
)
target_compile_features(${PROJECT_NAME}-tests PRIVATE cxx_std_23)
target_link_libraries(${PROJECT_NAME}-tests PRIVATE
    gtest_main
    gmock_main
)
target_include_directories(${PROJECT_NAME}-tests PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)
add_test(NAME ${PROJECT_NAME}-tests COMMAND ${PROJECT_NAME}-tests)
# [INST] Installation rules
install(TARGETS ${PROJECT_NAME} DESTINATION bin)
