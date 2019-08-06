/*******************************************************************************
@ddblock_begin copyright

Copyright (c) 1997-2019
Maryland DSPCAD Research Group, The University of Maryland at College Park 

Permission is hereby granted, without written agreement and without license or
royalty fees, to use, copy, modify, and distribute this software and its
documentation for any purpose other than its incorporation into a commercial
product, provided that the above copyright notice and the following two
paragraphs appear in all copies of this software.

IN NO EVENT SHALL THE UNIVERSITY OF MARYLAND BE LIABLE TO ANY PARTY
FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
THE UNIVERSITY OF MARYLAND HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGE.

THE UNIVERSITY OF MARYLAND SPECIFICALLY DISCLAIMS ANY WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
MARYLAND HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
ENHANCEMENTS, OR MODIFICATIONS.

@ddblock_end copyright
*******************************************************************************/

// C
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// CUDA Runtime
#include <cuda.h>
#include <cuda_runtime.h>
#include <helper_cuda.h>
#include "cusparse.h"

// CUDA files
#include "cuda_init.h"

// Solver// File parser interfaces
#include "pomdpCassandraWrapper.h"

// Solver interfaces
#include "solver_spvi.h"

// Misc files
#include "utils.h"

// #define ALLOW_PRINTS

// TEMP - Load these into ram for now

static int    s_nnz = 0;
static size_t s_Ns = 0;
static size_t s_Na = 0;
static size_t s_NsNa = 0;     // Shorthand for "Ns times Na"
static size_t s_Ns2Na = 0;    // Shorthand for "Ns squared times Na"
static float s_discount_factor = 0;
static float s_stopping_thresh = 0;

// Pointers to buffers in CPU RAM
static int*   s_host_cooRowIndex = NULL;
static int*   s_host_cooColIndex = NULL;
static float* s_host_cooVal = NULL;

// Pointers to buffers in GPU
static float* s_dev_PV;
static float* s_dev_CV;
static int*   s_dev_CP;
static float* s_dev_Q;
static float* s_dev_R;
static int*   s_dev_cooRowIndex;
static int*   s_dev_cooColIndex;
static float* s_dev_cooVal;
static int*   s_dev_csrRowPtr=0;

static cusparseHandle_t s_handle = 0;
static cusparseMatDescr_t s_stms_descr=0;


// Memory using in sup_norm reduction kernel
// Needs file scope so we can free the malloc'd memory
// after the solver completes
static float* s_h_reduce_out_vec = NULL;
static float* s_d_reduce_out_vec = NULL;

__global__
void select_best_action(int num_states, int num_actions, const float *dev_Q, float *dev_CV, int* dev_CP)
{
    int n = blockIdx.x*blockDim.x + threadIdx.x;

    // More kernels than states will be launched, dont go out of bounds
    if (n < num_states)
    {
        float max_value = -1e6;
        int32_t best_action = -1;

        for (int a_idx=0; a_idx<num_actions; a_idx++)
        {
            // Compute index in Q
            int32_t q_index = a_idx*(num_states) + n;

            float value_for_this_action = dev_Q[q_index];

            // Is this the new best action?
            if (value_for_this_action > max_value)
            {
                max_value = value_for_this_action;
                best_action = a_idx;
            }
        }

        dev_CV[n] = max_value;
        dev_CP[n] = best_action;
    }
}

// Reduction kernel taken from "reduction" example in CUDA samples.
// More info can be found here:
// http://developer.download.nvidia.com/compute/cuda/1.1-Beta/x86_website/projects/reduction/doc/reduction.pdf
// This is the "#4" example in the presentation

__global__
void reduce_sup_norm(const float *g_idata_1, const float *g_idata_2, float *g_odata, unsigned int n)
{
    extern __shared__ float sdata[];

//    // perform first level of reduction,
//    // reading from global memory, writing to shared memory
    unsigned int tid = threadIdx.x;
    unsigned int i = blockIdx.x*(blockDim.x*2) + threadIdx.x;

//    T mySum = (i < n) ? g_idata[i] : 0;
    float myMaxDelta = (i < n) ? fabsf(g_idata_1[i]-g_idata_2[i]) : 0.0f;

    if ((i + blockDim.x) < n)
    {
//        mySum += g_idata[i+blockDim.x];
        float newDelta = fabsf(g_idata_1[i+blockDim.x]-g_idata_2[i+blockDim.x]);
        myMaxDelta = newDelta > myMaxDelta ? newDelta : myMaxDelta;
    }

    sdata[tid] = myMaxDelta;
    __syncthreads();

    // do reduction in shared mem
    for (unsigned int s=blockDim.x/2; s>0; s>>=1)
    {
        if (tid < s)
        {
//            sdata[tid] = mySum = mySum + sdata[tid + s];
            float newDelta = sdata[tid + s];
            myMaxDelta = newDelta > myMaxDelta ? newDelta : myMaxDelta;
            sdata[tid] = myMaxDelta;
        }
        __syncthreads();
    }

    // write result for this block to global mem
    if (tid == 0)
    {
//        g_odata[blockIdx.x] = mySum;
        g_odata[blockIdx.x] = myMaxDelta;
    }
}



static void solver_do_backup(
        const float* dev_R,
        const float* dev_PV,
        float* dev_CV,
        int* dev_CP,
        float* dev_Q)
{
    static const float fOne = 1.0f;

    cudaError_t cudaErr;

    // Copy dev_R into dev_Q
    cudaErr = cudaMemcpy(dev_Q, dev_R, (size_t)(s_NsNa*sizeof(float)), cudaMemcpyDeviceToDevice);
    assert(cudaErr == cudaSuccess);

    float alpha = s_discount_factor;

    // Multiply Matrix times vector
    cusparseStatus_t status;
    status = cusparseScsrmv(s_handle,
            CUSPARSE_OPERATION_NON_TRANSPOSE,
            s_NsNa,                    // int m, Rows in Matrix
            s_Ns,                       // int n, Cols in Matrix
            s_nnz,                      // int nnz, # of Non-Zero elements in Matrix
            &alpha,                     // const float *alpha, // Addition constant
            s_stms_descr,               // const cusparseMatDescr_t descrA, // Matrix descriptor
            s_dev_cooVal,                 // const float *csrValA, // Values
            s_dev_csrRowPtr,              // const int *csrRowPtrA, // CSR format row pointer
            s_dev_cooColIndex,            // const int *csrColIndA, // CSR format col indicies
            &dev_PV[0],                 // const float *x,
            &fOne,                      // const float *beta,   // Addition constant
            &dev_Q[0]);                 // float *y);   //
    assert(status == CUSPARSE_STATUS_SUCCESS);

    // Select best action using CUDA kernel
    // Launch 1 kernel per MDP state
    // Use thread blocks with 256 threads per thread block
    select_best_action<<<(s_Ns+255)/256, 256>>>(s_Ns, s_Na, dev_Q, dev_CV,dev_CP);

    cudaDeviceSynchronize();
}

float compute_sup_norm(const float* dev_v1,
                       const float* dev_v2,
                       uint32_t N)
{
//    static int kernel_num_blocks = (N+255)/256;
    static int kernel_num_blocks = (N+255)/(256*2); // Need half the blocks due to optimization in kernel
    static int kernel_num_threads = 256;

    cudaError_t cudaErr;

    // #warning "Temp hack using CPU Sup Norm!"

    // USE CPU version for now
    if (kernel_num_blocks == 0)
    {
        // N here is <= 256
        float host_v1[N];
        float host_v2[N];

        cudaErr = cudaMemcpy(host_v1, dev_v1, (size_t)(N*sizeof(float)), cudaMemcpyDeviceToHost);
        assert(cudaErr == cudaSuccess);
        cudaErr = cudaMemcpy(host_v2, dev_v2, (size_t)(N*sizeof(float)), cudaMemcpyDeviceToHost);
        assert(cudaErr == cudaSuccess);

        float max_abs_delta = 0.0f;
        float abs_delta;
        for (uint32_t n=0; n<N; n++)
        {
            abs_delta = fabsf(host_v1[n]-host_v2[n]);
            if (abs_delta > max_abs_delta)
            {
                // printf("[%d] %f > %f, new_max_abs_delta\n", n, abs_delta, max_abs_delta);
                max_abs_delta = abs_delta;
            }
        }
        return max_abs_delta;
    }
    else
    {
        // USE GPU VERSION
        if (s_h_reduce_out_vec == NULL)
        {
            // TODO - We could allocate these earlier. Doing them here since size is a function of
            // kernel_num_blocks

            #ifdef ALLOW_PRINTS
            printf("N = %d, NB = %d, NT = %d\n", N, kernel_num_blocks, kernel_num_threads);
            #endif

            s_h_reduce_out_vec = (float*)malloc(sizeof(float)*kernel_num_blocks);
            assert(s_h_reduce_out_vec != NULL);
        }
        if (s_d_reduce_out_vec == NULL)
        {

            cudaErr = cudaMalloc((void**)&s_d_reduce_out_vec, kernel_num_blocks*sizeof(float));
            assert(cudaErr == cudaSuccess);
        }

        // Do first stage reduction using CUDA kernel
        // This leaves a length kernel_num_blocks array that needs to still be reduced
        reduce_sup_norm<<<kernel_num_blocks, kernel_num_threads, kernel_num_threads*sizeof(float)>>>(dev_v1, dev_v2, s_d_reduce_out_vec, N);
        cudaDeviceSynchronize();

        cudaErr = cudaMemcpy(s_h_reduce_out_vec, s_d_reduce_out_vec, (size_t)(kernel_num_blocks*sizeof(float)), cudaMemcpyDeviceToHost);
        checkCudaErrors(cudaErr);
        assert(cudaErr == cudaSuccess);

        float temp_max = 0.0f;
        for (int n=0; n<kernel_num_blocks; n++)
        {
            if (s_h_reduce_out_vec[n] > temp_max)
            {
                temp_max = s_h_reduce_out_vec[n];
            }
        }

        //printf("CPU,CUDA sup_norm = %f %f\t", max_abs_delta, temp_max);
        return temp_max;
    }

}

// This function currently assumes that the input format is the cassandra format
// It converts the cassandra format to the MDP format that this solver uses
// The converted mdp variables have file scope.
// The intention is to handle other incoming formats here as well
static void change_mdp_format(void* p_mdp_obj)
{
    PomdpCassandraWrapper* p_mdp = (PomdpCassandraWrapper*)p_mdp_obj;
    s_discount_factor = p_mdp->getDiscount();
    s_Ns = p_mdp->getNumStates();
    s_Na = p_mdp->getNumActions();

    s_NsNa = s_Ns*s_Na;
    s_Ns2Na = s_Ns*s_Ns*s_Na;

    float eps = 0.5f;
    s_stopping_thresh = (eps * (1-s_discount_factor)) / (2*s_discount_factor);

    // -------------------------------------
    // Load MDP STM,R into Host RAM
    // -------------------------------------
    // Populate STMs in COO format

    s_nnz = 0;
    for(uint32_t a_idx=0; a_idx<s_Na; a_idx++)
    {
        CassandraMatrix single_stm = p_mdp->getT(a_idx);
        s_nnz += single_stm->num_non_zero;
    }

    printf("Total non-zero entries = %d / %lu (= %.3f %% Sparse)\n",
           s_nnz, s_Ns2Na, 100.0f*((float)(s_Ns2Na-s_nnz))/(float(s_Ns2Na)));

    s_host_cooRowIndex = (int*)malloc(s_nnz*sizeof(int));
    s_host_cooColIndex = (int*)malloc(s_nnz*sizeof(int));
    s_host_cooVal =    (float*)malloc(s_nnz*sizeof(float));

    uint32_t count = 0;
    for(uint32_t a_idx=0; a_idx<s_Na; a_idx++)
    {
        CassandraMatrix single_stm = p_mdp->getT(a_idx);
        // displayMatrix(single_stm);
        for (uint32_t s_idx=0; s_idx<s_Ns; s_idx++)
        {
            for (uint32_t next_s_idx=0; next_s_idx<s_Ns; next_s_idx++)
            {
                float transition_prob = getEntryMatrix(single_stm, s_idx, next_s_idx);
                if (transition_prob > 0.0f)
                {
                    assert(count < s_nnz);
                    s_host_cooRowIndex[count] = s_idx + a_idx*s_Ns;
                    s_host_cooColIndex[count] = next_s_idx;
                    s_host_cooVal[count] = transition_prob;
                    count++;
                }
            }
        }
    }
    assert(count == s_nnz);

    // Populate R in full matrix format
    float* R_2D_lut = (float*)malloc(sizeof(float)*s_NsNa);
    memset(R_2D_lut, 0, sizeof(float)*s_NsNa);

    uint32_t r_idx = 0;
    CassandraMatrix cassandra_RTranspose = p_mdp->getRTranspose();
    // displayMatrix(cassandra_RTranspose);
    for(uint32_t a_idx=0; a_idx<s_Na; a_idx++)
    {
        for(uint32_t s_idx=0; s_idx<s_Ns; s_idx++)
        {
            float reward = getEntryMatrix(cassandra_RTranspose, a_idx, s_idx);
            R_2D_lut[r_idx] = reward;
            // printf("[%d] : R(%d, %d) <= %f\n", r_idx, a_idx, s_idx, reward);
            r_idx++;
        }
    }

    // -------------------------------------
    // Allocate Storage on device
    // -------------------------------------
    cudaError_t cudaStat;

    // Previous value function (init to zero)
    cudaStat = cudaMalloc((void**)&s_dev_PV, s_Ns*sizeof(float));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMemset(s_dev_PV, 0, s_Ns);
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_CV, s_Ns*sizeof(float));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_CP, s_Ns*sizeof(int));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_Q, s_NsNa*sizeof(float));
    assert(cudaStat == cudaSuccess);

    // Rewards
    cudaStat = cudaMalloc((void**)&s_dev_R, s_NsNa*sizeof(float));
    assert(cudaStat == cudaSuccess);

    // STMs
    cudaStat = cudaMalloc((void**)&s_dev_cooRowIndex, s_nnz*sizeof(int));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_cooColIndex, s_nnz*sizeof(int));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_cooVal, s_nnz*sizeof(float));
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMalloc((void**)&s_dev_csrRowPtr,(s_Ns+1)*sizeof(int));
    assert(cudaStat == cudaSuccess);

    // -------------------------------------
    // Copy data to device
    // -------------------------------------

    // Copy STM from host to device
    cudaStat = cudaMemcpy(s_dev_cooRowIndex, s_host_cooRowIndex, (size_t)(count*sizeof(int)), cudaMemcpyHostToDevice);
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMemcpy(s_dev_cooColIndex, s_host_cooColIndex, (size_t)(count*sizeof(int)), cudaMemcpyHostToDevice);
    assert(cudaStat == cudaSuccess);

    cudaStat = cudaMemcpy(s_dev_cooVal, s_host_cooVal, (size_t)(count*sizeof(float)), cudaMemcpyHostToDevice);
    assert(cudaStat == cudaSuccess);

    // Copy rewards from host to device
    const float* host_R = R_2D_lut;
    cudaStat = cudaMemcpy(s_dev_R, host_R, (size_t)(s_NsNa*sizeof(float)), cudaMemcpyHostToDevice);
    assert(cudaStat == cudaSuccess);

    // Dont need this anymore. Free it.
    if (R_2D_lut != NULL) {free(s_h_reduce_out_vec);}

    // -------------------------------------
    // Init cuSpare library and structures
    // -------------------------------------
    cusparseStatus_t status = cusparseCreate(&s_handle);
    if (status != CUSPARSE_STATUS_SUCCESS)
    {
        printf("CUSPARSE Library initialization failed");
        assert(false);
    }

    // create and setup matrix descriptor
    status = cusparseCreateMatDescr(&s_stms_descr);
    if (status != CUSPARSE_STATUS_SUCCESS)
    {
        printf("Matrix descriptor initialization failed");
        assert(false);
    }
    cusparseSetMatType(s_stms_descr,CUSPARSE_MATRIX_TYPE_GENERAL);
    cusparseSetMatIndexBase(s_stms_descr,CUSPARSE_INDEX_BASE_ZERO);

    // Transform STMs from COO to CSR format
    status = cusparseXcoo2csr(s_handle,
            s_dev_cooRowIndex,
            count,
            s_Ns,
            s_dev_csrRowPtr,
            CUSPARSE_INDEX_BASE_ZERO);
    assert(status == CUSPARSE_STATUS_SUCCESS);
}

int solver_spvi_solve(void* p_mdp_obj, uint32_t* p_out_policy, float* p_out_value_func, int max_solver_time_s)
{
    printf("Solver spvi\n");

    assert(cuda_init(0) == EXIT_SUCCESS);

    // Load in MDP from external format
    change_mdp_format(p_mdp_obj);


    // printf("Starting Value Iteration\n");

    struct timespec start_time, elapsed_time;
    clock_gettime(CLOCK_MONOTONIC_RAW, &start_time);

    bool b_done = false;
    uint32_t num_iterations = 0;
    bool b_timed_out = false;
    while(!b_done)
    {
        num_iterations++;
        solver_do_backup(
                s_dev_R,
                s_dev_PV,
                s_dev_CV,
                s_dev_CP,
                s_dev_Q);

        // Compute stopping criteria
        float sup_norm = compute_sup_norm((const float*)s_dev_CV, (const float*)s_dev_PV, (uint32_t)s_Ns);

        if (sup_norm < s_stopping_thresh)
        {
            // Done
            b_done = true;
            printf("Iteration %d: %f < %f (STOP)\n", num_iterations, sup_norm, s_stopping_thresh);
        }
        else
        {
            // Check for time out
            if (max_solver_time_s != 0)
            {
                clock_gettime(CLOCK_MONOTONIC_RAW, &elapsed_time);

                float solver_elapsed_time = measure_elapsed_time(
                        (const struct timespec*)&start_time, (const struct timespec*)&elapsed_time);

//                printf("(%.1f of %d[s]) : ", solver_elapsed_time, max_solver_time_s);

                if ((int)solver_elapsed_time >= max_solver_time_s)
                {
                    b_done = true;
                    b_timed_out = true;
                }
            }
            //            printf("Iteration %d : %f > %f\n", num_iterations, sup_norm, s_stopping_thresh);
        }

        //        if (num_iterations == 2) b_done = true;

        // The value function computed in this iteration now becomes the "previous" value function.
        cudaError_t cudaErr;
        cudaErr = cudaMemcpy(s_dev_PV, s_dev_CV, (size_t)(s_Ns*sizeof(float)), cudaMemcpyDeviceToDevice);
        assert(cudaErr == cudaSuccess);
    }

    // Done. Save off policy and value
    cudaError_t cudaErr;
    cudaErr = cudaMemcpy(p_out_policy, s_dev_CP, (size_t)(s_Ns*sizeof(int)), cudaMemcpyDeviceToHost);
    assert(cudaErr == cudaSuccess);

    cudaErr = cudaMemcpy(p_out_value_func, s_dev_CV, (size_t)(s_Ns*sizeof(float)), cudaMemcpyDeviceToHost);
    assert(cudaErr == cudaSuccess);


    // Free any CPU RAM that was malloc'd in this function
    if (s_host_cooRowIndex != NULL) {free(s_host_cooRowIndex);}
    if (s_host_cooColIndex != NULL) {free(s_host_cooColIndex);}
    if (s_host_cooVal != NULL) {free(s_host_cooVal);}
    if (s_h_reduce_out_vec != NULL) {free(s_h_reduce_out_vec);}


    // Free all GPU memory allocations
    assert(cuda_deinit() == EXIT_SUCCESS);

    if (b_timed_out)
    {
        return(1);
    }
    else
    {
        return(0);
    }

}


