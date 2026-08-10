cmake_minimum_required(VERSION 3.28...4.3)

project(myproject
    VERSION     0.1.0
    DESCRIPTION "A production-shaped C++23 project with modules"
    LANGUAGES   CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
# A normal variable, not a cache entry: caching it leaks the setting into any
# subproject FetchContent pulls in. It has to be global rather than per-target,
# because every consumer of a module needs scanning too so the generator can
# order the interface ahead of anything that imports it.
set(CMAKE_CXX_SCAN_FOR_MODULES ON)

# A hard error, not a warning: with any other generator configure would succeed
# and then fail deep inside the dependency scanner.
if(NOT CMAKE_GENERATOR MATCHES "^Ninja")
    message(FATAL_ERROR
        "C++ modules require a Ninja generator; got '${CMAKE_GENERATOR}'.")
endif()
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

include(CTest)
include(GNUInstallDirs)

option(MYPROJECT_BUILD_TESTS       "Build the test suite"                    ${PROJECT_IS_TOP_LEVEL})
option(MYPROJECT_INSTALL           "Generate install rules"                  ${PROJECT_IS_TOP_LEVEL})
option(MYPROJECT_ENABLE_HARDENING  "Hardening flags in optimised builds"     ON)
option(MYPROJECT_ENABLE_IPO        "Link-time optimisation where supported"  OFF)
option(MYPROJECT_ENABLE_CLANG_TIDY "Run clang-tidy as part of the build"     OFF)
option(MYPROJECT_FETCH_DEPENDENCIES
       "Download missing dependencies instead of failing" OFF)

# A semicolon list handed to -fsanitize=. Empty means none. This is a cache
# variable rather than a set of booleans because the sanitizers are mutually
# exclusive in groups, which booleans cannot express.
set(MYPROJECT_SANITIZERS "" CACHE STRING
    "Sanitizers to enable, e.g. address;undefined or thread")
set_property(CACHE MYPROJECT_SANITIZERS PROPERTY STRINGS
             "" "address;undefined" "thread" "undefined")

# ------------------------------------------------------------------ warnings
add_library(myproject_warnings INTERFACE)
add_library(myproject::warnings ALIAS myproject_warnings)

set(myproject_warning_flags
    -Wall -Wextra -Wpedantic
    -Wshadow -Wnon-virtual-dtor -Woverloaded-virtual -Wold-style-cast
    -Wcast-align -Wconversion -Wsign-conversion
    -Wnull-dereference -Wdouble-promotion -Wimplicit-fallthrough
    -Wformat=2 -Wunused)

if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    list(APPEND myproject_warning_flags
         -Wmisleading-indentation -Wduplicated-cond -Wduplicated-branches
         -Wlogical-op -Wuseless-cast)
endif()

# BUILD_INTERFACE so an installed consumer inherits none of this.
target_compile_options(myproject_warnings INTERFACE
    "$<BUILD_INTERFACE:${myproject_warning_flags}>")

# ----------------------------------------------------------------- hardening
# The target always exists so install(TARGETS) below never has to branch.
add_library(myproject_hardening INTERFACE)
add_library(myproject::hardening ALIAS myproject_hardening)

if(MYPROJECT_ENABLE_HARDENING AND NOT MSVC)
    include(CheckCXXSymbolExists)
    check_cxx_symbol_exists(_LIBCPP_VERSION "version" MYPROJECT_HAVE_LIBCXX)

    set(myproject_hardening_flags -fstack-protector-strong)

    # Branch on the standard library, not the compiler: Clang uses libstdc++ on
    # Linux and libc++ on macOS. -U comes first because a Nix cc-wrapper already
    # defines these, and a differing redefinition is -Wmacro-redefined, which is
    # fatal as soon as warnings become errors.
    if(MYPROJECT_HAVE_LIBCXX)
        list(APPEND myproject_hardening_flags
             -U_LIBCPP_HARDENING_MODE
             -D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST)
    else()
        list(APPEND myproject_hardening_flags -D_GLIBCXX_ASSERTIONS)
    endif()

    target_compile_options(myproject_hardening INTERFACE
        "$<BUILD_INTERFACE:${myproject_hardening_flags}>")

    # _FORTIFY_SOURCE needs optimisation to do anything, and interacts badly
    # with AddressSanitizer on GCC.
    if(NOT MYPROJECT_SANITIZERS)
        target_compile_options(myproject_hardening INTERFACE
            "$<BUILD_INTERFACE:$<$<NOT:$<CONFIG:Debug>>:-U_FORTIFY_SOURCE;-D_FORTIFY_SOURCE=3>>")
    endif()
endif()

# ---------------------------------------------------------------- sanitizers
# Directory scope, not target scope: a sanitizer has to instrument every
# translation unit in the build, including anything a dependency contributes.
if(MYPROJECT_SANITIZERS)
    if(MSVC)
        message(FATAL_ERROR "MYPROJECT_SANITIZERS is not supported with MSVC")
    endif()

    foreach(exclusive IN ITEMS address leak memory)
        if("thread" IN_LIST MYPROJECT_SANITIZERS AND ${exclusive} IN_LIST MYPROJECT_SANITIZERS)
            message(FATAL_ERROR
                "ThreadSanitizer cannot be combined with ${exclusive}Sanitizer; "
                "configure a second build tree instead.")
        endif()
    endforeach()

    list(JOIN MYPROJECT_SANITIZERS "," myproject_san)
    add_compile_options(-fsanitize=${myproject_san} -fno-omit-frame-pointer -g)
    add_link_options(-fsanitize=${myproject_san})

    # Without this UBSan prints a diagnostic and the process still exits 0, so
    # a test that trips the sanitizer still reports success. Meaningless for
    # TSan, which has no recovery mode.
    if(NOT "thread" IN_LIST MYPROJECT_SANITIZERS)
        add_compile_options(-fno-sanitize-recover=all)
        add_link_options(-fno-sanitize-recover=all)
    endif()
endif()

# ----------------------------------------------------------------------- IPO
if(MYPROJECT_ENABLE_IPO)
    include(CheckIPOSupported)
    check_ipo_supported(RESULT myproject_ipo OUTPUT myproject_ipo_why LANGUAGES CXX)
    if(myproject_ipo)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELEASE        ON)
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_RELWITHDEBINFO ON)
    else()
        message(WARNING "IPO requested but unavailable: ${myproject_ipo_why}")
    endif()
endif()

# ---------------------------------------------------------------- clang-tidy
if(MYPROJECT_ENABLE_CLANG_TIDY)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        # Expect this to fail on any translation unit that imports a module.
        # clang-tidy compiles in-process without the driver flags the real
        # compiler was given, so it rejects the BMI the build just produced
        # with a "configuration mismatch". Nothing in the project can fix that;
        # it is why the ci preset leaves this off. See README.md.
        message(WARNING
            "clang-tidy and C++20 modules do not currently work together; "
            "expect module-file configuration mismatch errors.")
        find_program(MYPROJECT_CLANG_TIDY NAMES clang-tidy REQUIRED)
        set(CMAKE_CXX_CLANG_TIDY "${MYPROJECT_CLANG_TIDY}")
    else()
        message(WARNING
            "MYPROJECT_ENABLE_CLANG_TIDY ignored: the warning set for "
            "${CMAKE_CXX_COMPILER_ID} contains flags clang-tidy rejects.")
    endif()
endif()

# ------------------------------------------------------------------- targets
add_library(myproject_core)
add_library(myproject::core ALIAS myproject_core)

# One library owns both the module interface and its implementation unit, so
# the target exists unconditionally and nothing downstream has to guard on
# whether there are any modules.
target_sources(myproject_core
    PRIVATE
        src/greeting_impl.cpp
    PUBLIC
        FILE_SET CXX_MODULES
        BASE_DIRS ${CMAKE_CURRENT_SOURCE_DIR}/src
        FILES     src/greeting.cppm)

target_compile_features(myproject_core PUBLIC cxx_std_23)
target_link_libraries(myproject_core PRIVATE myproject::warnings myproject::hardening)
set_target_properties(myproject_core PROPERTIES OUTPUT_NAME myproject EXPORT_NAME core)

add_executable(myproject_app src/main.cpp)
target_link_libraries(myproject_app
    PRIVATE myproject::core myproject::warnings myproject::hardening)
set_target_properties(myproject_app PROPERTIES OUTPUT_NAME myproject EXPORT_NAME app)

if(BUILD_TESTING AND MYPROJECT_BUILD_TESTS)
    add_subdirectory(tests)
endif()

# ------------------------------------------------------------------- install
if(MYPROJECT_INSTALL)
    include(CMakePackageConfigHelpers)

    # The interface targets are in the export set because linking them PRIVATE
    # into a static library still records them as $<LINK_ONLY:...> usage
    # requirements, and install(EXPORT) refuses to export a target that names
    # one it does not have.
    install(TARGETS myproject_core myproject_app
                    myproject_warnings myproject_hardening
        EXPORT   myprojectTargets
        RUNTIME  DESTINATION ${CMAKE_INSTALL_BINDIR}
        LIBRARY  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        ARCHIVE  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        FILE_SET CXX_MODULES
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cxx-modules/myproject)

    install(EXPORT myprojectTargets
        FILE        myproject-targets.cmake
        NAMESPACE   myproject::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/myproject
        CXX_MODULES_DIRECTORY cxx-modules)

    configure_package_config_file(
        cmake/myproject-config.cmake.in
        ${CMAKE_CURRENT_BINARY_DIR}/myproject-config.cmake
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/myproject)

    write_basic_package_version_file(
        ${CMAKE_CURRENT_BINARY_DIR}/myproject-config-version.cmake
        COMPATIBILITY SameMajorVersion)

    install(FILES
        ${CMAKE_CURRENT_BINARY_DIR}/myproject-config.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/myproject-config-version.cmake
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/myproject)
endif()
