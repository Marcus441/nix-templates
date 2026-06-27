cmake_minimum_required(VERSION 3.28...3.31)
project(my-project LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_SCAN_FOR_MODULES ON)

if(NOT CMAKE_GENERATOR MATCHES "Ninja")
    message(WARNING "C++ modules require the Ninja generator.")
endif()

add_library(project_configs INTERFACE)

set(MODULE_SOURCES src/modules/my_module.cpp)

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
    target_link_libraries(${PROJECT_NAME}-modules INTERFACE project_configs)
endif()

set(SOURCES
    src/main.cpp
)

add_executable(${PROJECT_NAME} ${SOURCES})

target_compile_features(${PROJECT_NAME} PRIVATE cxx_std_23)
set_target_properties(${PROJECT_NAME} PROPERTIES CXX_EXTENSIONS OFF)
target_link_libraries(${PROJECT_NAME} PRIVATE project_configs)

if(MODULE_SOURCES)
    target_link_libraries(${PROJECT_NAME} PRIVATE ${PROJECT_NAME}-modules)
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
target_link_libraries(${PROJECT_NAME}-tests PRIVATE gtest_main gmock_main ${PROJECT_NAME}-modules)
add_test(NAME ${PROJECT_NAME}-tests COMMAND ${PROJECT_NAME}-tests)

option(USE_SANITIZERS "Enable ASan/UBSan in Debug mode" ON)

if(USE_SANITIZERS)
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(SAN_FLAGS $<$<CONFIG:Debug>:-fsanitize=address,undefined -fno-omit-frame-pointer>)
        
        target_compile_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
        target_link_options(${PROJECT_NAME} PRIVATE ${SAN_FLAGS})
        
        target_compile_options(${PROJECT_NAME}-tests PRIVATE ${SAN_FLAGS})
        target_link_options(${PROJECT_NAME}-tests PRIVATE ${SAN_FLAGS})
    endif()
endif()


install(TARGETS ${PROJECT_NAME} DESTINATION bin)
