% -------------------------------------------------------------------------
% @ddblock_begin copyright
% 
% Copyright (c) 1997-2019
% Maryland DSPCAD Research Group, The University of Maryland at College Park
% All rights reserved.
% 
% IN NO EVENT SHALL THE UNIVERSITY OF MARYLAND BE LIABLE TO ANY PARTY
% FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES
% ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
% THE UNIVERSITY OF MARYLAND HAS BEEN ADVISED OF THE POSSIBILITY OF
% SUCH DAMAGE.
% 
% THE UNIVERSITY OF MARYLAND SPECIFICALLY DISCLAIMS ANY WARRANTIES,
% INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE SOFTWARE
% PROVIDED HEREUNDER IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF
% MARYLAND HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
% ENHANCEMENTS, OR MODIFICATIONS.
% 
% @ddblock_end copyright
% -------------------------------------------------------------------------

% This function takes the name of a directory and the mdpsolvefromfile
% script to find the solutions to all the .pomdp files in the folder. 

% The solver uses the MDPSOLVE MATLAB solver, available here:
% https://github.com/PaulFackler/MDPSolve/
% You must clone this repo locally first, and make sure the whole tree 
% is in the MATLAB path: e.g.- addpath(genpath

% % The solutions are printed to the console and files in the
% % same folder as the .pomdp files.
% Parameters:
%   in_dir_name: A directory with .pomdp files
%   out_dir_name: A directory where the solutions will go
% Return: None

function solvemanypomdp(in_dir_name, out_dir_name)
    close; clc;

    if nargin == 0
        in_dir_name = '..\..\datasets\cassandra';
        out_dir_name = '..\..\datasets\cassandra\solutions\MDPSOLVE';
    end

    assert(ischar(in_dir_name));
    assert(ischar(out_dir_name));
    
    files = dir(in_dir_name);
    num_files = length(files);

    t_start = tic();
    num_pomdp_files = 0;
    for i = 1:num_files
        if contains(upper(files(i).name), '.POMDP')
            num_pomdp_files = num_pomdp_files+1;
            file_name = fullfile(in_dir_name, files(i).name);
            try
                tic();
                fprintf('-----------------\n');
                fprintf('Solving POMDP file: %s\n', file_name);
                mdpsolvefromfile(file_name, out_dir_name);
                fprintf('Solver time = %d seconds\n', toc());
                
            catch ME
                fprintf('An error occured while solving POMDP: %s\n', file_name);
                disp(ME.getReport());
            end
        end
    end
    
    elapsed_time_s = toc(t_start);
    fprintf('%d .POMDP files solved in %f seconds\n', num_pomdp_files, elapsed_time_s);
    
end
