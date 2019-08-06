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
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// File parser interfaces
#include "pomdpCassandraWrapper.h"

// Solver interfaces
#include "solver_vi.h"
#include "solver_spvi.h"

// Misc files
#include "utils.h"

#define MAX_FILENAME_LEN (128)
static int s_print_help_exit = 0;

static void print_usage(void)
{
    printf("Example Usage:  gembench -m /path/to/my/foo.pomdp -s solver_name -o output_filename\n");
    printf("  -t Maximum time to try and solve an MDP, in seconds\n");
    printf("  -m Filename of the MDP to solve\n");
    printf("  -s Name of the solver to use {e.g.- vi, spvi, tvi}\n");
    printf("  -o Filename of the output to write\n");
    printf("  --help [-h] print this help message\n");
    printf("\n");
}

int  main( int argc, char **argv )
{
    (void)argc;
    (void)argv;

    char str_mdp_filename[MAX_FILENAME_LEN] = {'\0'};
    char str_solver_name[MAX_FILENAME_LEN] = {'\0'};
    char str_output_filename[MAX_FILENAME_LEN] = {'\0'};
    int max_solver_time_s = 0;

    int c;

    // Use getopt to parse command line arguments
    while (1)
    {
        static struct option long_options[] =
        {
                // Usage:
                {"help",                no_argument,       0, 'h'},
                {0, 0, 0, 0}
        };

        /* getopt_long stores the option index here. */
        int option_index = 0;
        c = getopt_long(argc, argv, "hm:s:t:o:", long_options, &option_index);

        /* Detect the end of the options. */
        if (c == -1)
        {
            break;
        }

        switch (c)
        {
            case 0:
                /* If this option set a flag, do nothing else now. */
                if (long_options[option_index].flag != 0)
                    break;
                break;

            case 'm':
                if (strlen(optarg) >= (MAX_FILENAME_LEN))
                {
                    printf("MDP file name must be less than %d characters\n", (MAX_FILENAME_LEN));
                    exit(EXIT_FAILURE);
                }
                else
                {
                    strcpy(str_mdp_filename, optarg);
                }
                break;

            case 'o':
                if (strlen(optarg) >= (MAX_FILENAME_LEN))
                {
                    printf("Output filename must be less than %d characters\n", (MAX_FILENAME_LEN));
                    exit(EXIT_FAILURE);
                }
                else
                {
                    strcpy(str_output_filename, optarg);
                }
                break;

            case 's':
                if (strlen(optarg) >= (MAX_FILENAME_LEN))
                {
                    printf("Solver name must be less than %d characters\n", (MAX_FILENAME_LEN));
                    exit(EXIT_FAILURE);
                }
                else
                {
                    strcpy(str_solver_name, optarg);
                }
                break;

            case 't':
                {
                     max_solver_time_s = atoi(optarg);
                }
                break;

            case 'h':
                s_print_help_exit = 1;
                break;
            case '?':
                /* getopt_long already printed an error message. */
                break;
            default:
                abort();
        }
    }

    if ((s_print_help_exit) || (str_mdp_filename[0] == '\0') || (str_solver_name[0] == '\0') )
    {
        print_usage();
        exit(EXIT_SUCCESS);
    }

    printf("MDP Name = %s\n", str_mdp_filename);
    printf("Solver Name = %s\n", str_solver_name);
    if (max_solver_time_s != 0)
    {
        printf("Max Solver Time = %d [s]\n", max_solver_time_s);
    }

    // ------------------------------
    // Read in MDP File
    // ------------------------------
    PomdpCassandraWrapper p;
    p.readFromFile(str_mdp_filename);

    printf("MDP file parsing complete: %s\n", str_mdp_filename);
    printf("\tNs=%d, Na=%d\n", p.getNumStates(), p.getNumActions());

    // ------------------------------
    // Allocate storage for generated policy and value vectors
    // ------------------------------
    uint32_t* out_policy = (uint32_t*)malloc(sizeof(uint32_t)*p.getNumStates());
    assert(out_policy != NULL);

    float* out_value_func = (float*)malloc(sizeof(float)*p.getNumStates());
    assert(out_value_func != NULL);

    // ------------------------------
    // Call the desired MDP solver
    // ------------------------------

    struct timespec solver_start_time, solver_end_time;
    clock_gettime(CLOCK_MONOTONIC_RAW, &solver_start_time);

    int solver_ret_arg=0;
    if (strcmp(str_solver_name, "vi")==0)
    {
        printf("Running vi solver...\n");
        solver_ret_arg = solver_vi_solve((void*)&p, out_policy, out_value_func, max_solver_time_s);
    }
    else if (strcmp(str_solver_name, "spvi")==0)
    {
        printf("Running spvi solver...\n");
        solver_ret_arg = solver_spvi_solve((void*)&p, out_policy, out_value_func, max_solver_time_s);
    }
    else
    {
        printf("%s solver not supported\n", str_solver_name);
        exit(EXIT_FAILURE);
    }

    if (solver_ret_arg == 0)
    {
        clock_gettime(CLOCK_MONOTONIC_RAW, &solver_end_time);

        float solver_elapsed_time = measure_elapsed_time(
                (const struct timespec*)&solver_start_time, (const struct timespec*)&solver_end_time);
        printf("Solver=%s, MDP=%s (Ns=%d,Na=%d), Time=%f[s]\n",
                str_solver_name, str_mdp_filename, p.getNumStates(), p.getNumActions(), solver_elapsed_time);
    }
    else
    {
        printf("Solver=%s, MDP=%s, Halted after %d [s] \n", str_solver_name, str_mdp_filename, max_solver_time_s);
    }

    // ------------------------------
    // Write out results
    // ------------------------------
    if (str_output_filename[0] != '\0')
    {
        FILE* fptr = fopen((const char*)str_output_filename, "w");
        if (fptr == NULL)
        {
            printf("Unable to store output in %s\n", str_output_filename);
        }
        else
        {
            fprintf(fptr, "State, Optimal Control and Value\n");
            for (uint32_t n=0; n<p.getNumStates(); n++)
            {
                fprintf(fptr, "%d %d %.6f \n", n, out_policy[n], out_value_func[n]);
            }
            fclose(fptr);
        }
    }
    return( 0 );
}
