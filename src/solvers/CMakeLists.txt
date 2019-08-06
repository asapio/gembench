

set(solvers_src_files 
    cuda_init.cu
    cuda_init.h
    solver_spvi.cu
    solver_spvi.h
    solver_vi.cpp
    solver_vi.h
    utils.h
    utils.cpp)

set (CMAKE_CXX_FLAGS "-O3")

cuda_add_library(solvers ${solvers_src_files})
