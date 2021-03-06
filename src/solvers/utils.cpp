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

#include "utils.h"

// Computes elapsed time in floating point seconds,
// from two <time.h> struct timespec objects
float measure_elapsed_time(const struct timespec* p_start_time,
                           const struct timespec* p_end_time)
{
    struct timespec diff_time;
    float f_diff_time;

    if ((p_end_time->tv_nsec < p_start_time->tv_nsec) )
    {
        diff_time.tv_sec = p_end_time->tv_sec - p_start_time->tv_sec - 1;
        diff_time.tv_nsec = 1000000000 + p_end_time->tv_nsec - p_start_time->tv_nsec;
    }
    else
    {
        diff_time.tv_sec = p_end_time->tv_sec - p_start_time->tv_sec;
        diff_time.tv_nsec = p_end_time->tv_nsec - p_start_time->tv_nsec;
    }

    f_diff_time = (float)diff_time.tv_sec;
    f_diff_time += (((float)diff_time.tv_nsec) * 1e-9);

    return(f_diff_time);
}
