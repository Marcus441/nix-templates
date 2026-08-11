cmake_minimum_required(VERSION 3.25...4.3)

project(myproject
    VERSION     0.1.0
    DESCRIPTION "A small C++23 project"
    LANGUAGES   CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

option(USE_SANITIZERS "Enable ASan/UBSan in Debug builds" ON)

# The program and the test binary compile the same implementation files. A test
# executable is just another executable — sharing a library target between them
# is what the cpp-prod template adds.
set(SOURCES src/greeting.cpp)

add_executable(myproject src/main.cpp ${SOURCES})
target_include_directories(myproject PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)

enable_testing()

add_executable(myproject-tests tests/main_test.cpp ${SOURCES})
target_include_directories(myproject-tests PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME myproject-tests COMMAND myproject-tests)

if(USE_SANITIZERS AND NOT MSVC)
    # Debug only — the instrumentation is far too slow to leave on in a release
    # build. -fno-sanitize-recover is what makes the sanitizers fail the test:
    # by default UBSan prints a diagnostic and the process still exits 0.
    set(SAN_FLAGS
        $<$<CONFIG:Debug>:-fsanitize=address,undefined>
        $<$<CONFIG:Debug>:-fno-sanitize-recover=all>
        $<$<CONFIG:Debug>:-fno-omit-frame-pointer>)

    foreach(target myproject myproject-tests)
        target_compile_options(${target} PRIVATE ${SAN_FLAGS})
        target_link_options(${target} PRIVATE ${SAN_FLAGS})
    endforeach()
endif()

install(TARGETS myproject DESTINATION bin)
