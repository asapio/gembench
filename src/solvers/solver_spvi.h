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

#ifndef __SOLVER_SPVI_H__
#define __SOLVER_SPVI_H__

#include <stdint.h>

// Inputs:
//   p_mdp_obj : A pointer to some sort of MDP object. Currently only PomdpCassandraWrapper, but
//               make intentionally void* so we can pass around other types as well.
//   max_solver_time_s : if 0, run as long as necessary. Otherwise halt after this many seconds
// Outputs:
//   p_out_policy : A pointer to an array that is a length NUM_STATES vector of uint32_t's. The policy will be written put here.
//   p_out_value_func : A pointer to an array that is a length NUM_STATES vector of floats. The value function will be written out here.

// Return arg: 0 if completed, 1 if timed out
int solver_spvi_solve(void* p_mdp_obj, uint32_t* p_out_policy, float* p_out_value_func, int max_solver_time_s);

#endif //__SOLVER_SPVI_H__
