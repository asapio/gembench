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
% script to find the fully observation solutions to all the .pomdp files in
% the folder. The solutions are printed to the console and files in the
% same folder as the .pomdp files.
% Parameters:
%   filename: The name of the directory with the .pomdp files
% Return: None
function solvemanypomdp(dir_name)
assert(ischar(dir_name));

files = dir(dir_name);

num_files = length(files);

for i = 1:num_files
    if(contains(files(i).name, '.pomdp') || contains(files(i).name, '.POMDP'))
        file_name = fullfile(dir_name, files(i).name);
        try
            mdpsolvefromfile(file_name);
        catch
            disp(['error occured with ', file_name]);
        end
    end
end
