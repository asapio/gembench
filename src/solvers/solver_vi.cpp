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

#include <assert.h>
#include <math.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

// Solver// File parser interfaces
#include "pomdpCassandraWrapper.h"

// Solver interfaces
#include "solver_vi.h"

// Misc files
#include "utils.h"


// TEMP - Load these into ram for now
static float* s_STMs_lut = NULL;
static float* s_R_2D_lut = NULL;
static uint32_t s_Na = 0;
static uint32_t s_Ns = 0;
static float s_discount_factor = 0;
static float s_stopping_thresh = 0;

// This function does one iteration of Bellman backup

// The previous value function is taken from "value"
// The resulting value function is stored in next_value
// The resulting policy is stored in next_policy
static void solver_do_backup(float* value,
                             float* next_value,
                             uint32_t* next_policy)
{
    float max_value;
    uint32_t best_action;
    float summation;
    for (uint32_t s_idx=0; s_idx<s_Ns; s_idx++)
    {
        // Initialization on each new starting state
        max_value = -1e6;
        best_action = -1;

        // Loop over all candidate actions
        for (uint32_t a_idx=0; a_idx<s_Na; a_idx++)
        {
            // Compute entire summation
            summation = 0.0f;
            for (uint32_t next_s_idx=0; next_s_idx<s_Ns; next_s_idx++)
            {
//                if (p_params->alg == SOLVER_ALG_VI)
#if 1
                uint32_t stm_index = a_idx*(s_Ns*s_Ns) + (s_idx*s_Ns) + next_s_idx;
                float p = s_STMs_lut[stm_index];
                summation += (p * value[next_s_idx]);
#else
                float p = p_mdp->STM(s_idx, a_idx, next_s_idx);
                if (p>0.0f)
                {
                    summation += (p * value[next_s_idx]);
                }
#endif
            }

            // Add immediate reward of (s,a)
            float immediate_reward;
#if 1
                uint32_t r_index = a_idx*s_Ns + s_idx;
                immediate_reward = s_R_2D_lut[r_index];
#else
                immediate_reward = p_mdp->R(s_idx, a_idx);
#endif
            float value_for_this_action = immediate_reward + s_discount_factor*summation;

            // Is this the new best action?
            if (value_for_this_action > max_value)
            {
                max_value = value_for_this_action;
                best_action = a_idx;

            }
        }   // end a_idx loop

        next_value[s_idx] = max_value;
        next_policy[s_idx] = best_action;

    } // end s_idx loop
}


static float compute_sup_norm(float* v1, float* v2, uint32_t N)
{
    float max_abs_delta = 0.0f;
    float abs_delta;
    for (uint32_t n=0; n<N; n++)
    {
        abs_delta = fabsf(v1[n]-v2[n]);
        if (abs_delta > max_abs_delta)
        {
            max_abs_delta = abs_delta;
        }
    }
    return max_abs_delta;
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

    float eps = 0.5f;
    s_stopping_thresh = (0.5f * (1-s_discount_factor)) / (2*s_discount_factor);

    s_STMs_lut = (float*)malloc(sizeof(float)*s_Ns*s_Ns*s_Na);
    s_R_2D_lut = (float*)malloc(sizeof(float)*s_Ns*s_Na);

    memset(s_STMs_lut, 0, sizeof(float)*s_Ns*s_Na*s_Ns);
    memset(s_R_2D_lut, 0, sizeof(float)*s_Ns*s_Na);

    uint32_t stm_idx = 0;
    for(uint32_t a_idx=0; a_idx<s_Na; a_idx++)
    {
        CassandraMatrix single_stm = p_mdp->getT(a_idx);
        for(uint32_t s_idx=0; s_idx<s_Ns; s_idx++)
        {
            for(uint32_t next_s_idx=0; next_s_idx<s_Ns; next_s_idx++)
            {
                float transition_prob = getEntryMatrix(single_stm, s_idx, next_s_idx);
                s_STMs_lut[stm_idx] = transition_prob;
//                printf("[%d] : STM(%d, %d) <= %f\n", stm_idx, s_idx, next_s_idx, transition_prob);

                stm_idx++;
            }
        }
    }

    uint32_t r_idx = 0;
    CassandraMatrix cassandra_RTranspose = p_mdp->getRTranspose();
//    displayMatrix(cassandra_RTranspose);
    for(uint32_t a_idx=0; a_idx<s_Na; a_idx++)
    {
        for(uint32_t s_idx=0; s_idx<s_Ns; s_idx++)
        {
            float reward = getEntryMatrix(cassandra_RTranspose, a_idx, s_idx);
            s_R_2D_lut[r_idx] = reward;
//            printf("[%d] : R(%d, %d) <= %f\n", r_idx, a_idx, s_idx, reward);

            r_idx++;
        }
    }
}

int solver_vi_solve(void* p_mdp_obj, uint32_t* p_out_policy, float* p_out_value_func, int max_solver_time_s)
{
    // Load in MDP from external format
    change_mdp_format(p_mdp_obj);

    // Set value func to all zeros
    memset(p_out_value_func, 0, sizeof(float)*s_Ns);

    // Allocate storage for temp working value function and policy
    float* next_value = (float*)malloc(sizeof(float)*s_Ns);
    uint32_t* next_policy = (uint32_t*)malloc(sizeof(uint32_t)*s_Ns);

//    printf("Starting Value Iteration\n");

    struct timespec start_time, elapsed_time;
    clock_gettime(CLOCK_MONOTONIC_RAW, &start_time);

    bool b_done = false;
    uint32_t num_iterations = 0;
    bool b_timed_out = false;
    while(!b_done)
    {
        num_iterations++;

        // Do one Bellman backup iteration
        solver_do_backup(p_out_value_func, next_value, next_policy);

        // Compute stopping criteria
        float sup_norm = compute_sup_norm(p_out_value_func, next_value, s_Ns);

        if (sup_norm < s_stopping_thresh)
        {
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
        memcpy(p_out_value_func, next_value, sizeof(float)*s_Ns);
    }

    // Done. Save off policy
    memcpy(p_out_policy, next_policy, sizeof(uint32_t)*s_Ns);

    // De-allocate everything malloc'd in this function
    if(next_policy != NULL) {free(next_policy);}
    if(next_value != NULL) {free(next_value);}

    if (s_STMs_lut != NULL) {free(s_STMs_lut);}
    if (s_R_2D_lut != NULL) {free(s_R_2D_lut);}

    if (b_timed_out)
    {
        return(1);
    }
    else
    {
        return(0);
    }
}
