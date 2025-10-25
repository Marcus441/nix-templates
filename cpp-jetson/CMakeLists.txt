cmake_minimum_required(VERSION 3.18)
project(jetson-bin LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find dependencies
find_package(Eigen3 REQUIRED)
find_package(g2o REQUIRED)
find_package(Ceres REQUIRED)

file(GLOB SOURCES "src/*.cpp")
add_executable(${PROJECT_NAME} ${SOURCES})

target_include_directories(${PROJECT_NAME} PRIVATE src)

target_link_libraries(${PROJECT_NAME}
    Eigen3::Eigen
    g2o::core
    g2o::types_slam3d
    g2o::solvers_csparse
    Ceres::ceres
)

target_compile_options(${PROJECT_NAME} PRIVATE -pedantic -Wall -Wextra)

install(TARGETS ${PROJECT_NAME}
        RUNTIME DESTINATION bin)
