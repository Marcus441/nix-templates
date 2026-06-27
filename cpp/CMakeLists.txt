cmake_minimum_required(VERSION 3.25...3.31)

project(my-project LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

set(SOURCES
    src/main.cpp
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include

target_compile_options(${PROJECT_NAME} PRIVATE
    -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
    $<$<CONFIG:Release>:-O3>
    $<$<CONFIG:RelWithDebInfo>:-O2 -g>
    $<$<CONFIG:Debug>:-g -Og>
)

option(USE_SANITIZERS "Enable ASan/UBSan" ON)
if(USE_SANITIZERS AND CMAKE_BUILD_TYPE STREQUAL "Debug")
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(SAN_FLAGS -fsanitize=address,undefined -fno-omit-frame-pointer)
        target_compile_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
        target_link_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
    endif()
endif()

enable_testing()
include(FetchContent)
FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG        v1.17.0
    EXCLUDE_FROM_ALL
)

if(FETCHCONTENT_FULLY_DISCONNECTED)
    find_package(GTest REQUIRED)
    if(NOT TARGET gtest_main)
        add_library(gtest_main ALIAS GTest::gtest_main)
    endif()
    if(NOT TARGET gmock_main)
        if(TARGET GTest::gmock_main)
            add_library(gmock_main ALIAS GTest::gmock_main)
        else()
            add_library(gmock_main ALIAS GTest::gtest_main)
        endif()
    endif()
else()
    FetchContent_MakeAvailable(googletest)
endif()

add_executable(${PROJECT_NAME}-tests tests/main_test.cpp)
target_compile_options(${PROJECT_NAME}-tests PRIVATE
    -pedantic -Wall -Wextra -Wshadow -Wnon-virtual-dtor -Wunused
    $<$<CONFIG:Debug>:-g -Og>
)
target_link_libraries(${PROJECT_NAME}-tests PRIVATE gtest_main gmock_main)
add_test(NAME ${PROJECT_NAME}-tests COMMAND ${PROJECT_NAME}-tests)

install(TARGETS ${PROJECT_NAME} DESTINATION bin)
