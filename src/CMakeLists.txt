cmake_minimum_required (VERSION 2.8)

project(gembench)

find_package(CUDA QUIET REQUIRED)


include_directories(parsers/cassandra)
include_directories(solvers)
include_directories(/home/ubuntu/NVIDIA_CUDA-9.0_Samples/common/inc)

link_directories(/usr/local/cuda-9.0/lib64)

add_subdirectory(parsers/cassandra)
add_subdirectory(solvers)

cuda_add_executable(gembench main.cpp)
set (CMAKE_CXX_FLAGS "-O3")

target_link_libraries(
    gembench
    parsers_cassandra 
    solvers
    cusparse)

