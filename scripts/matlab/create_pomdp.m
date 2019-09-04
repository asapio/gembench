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

% This function takes in a state transition matrix, reward, and discout
% factor, and creates a file with file name filename in the .POMDP format
% Parameters:
%   stm: State transition matrix. Should be of size (Ns*Na) x Ns. Each row
%   row should add up to 1, with the rows representing (s * Na) + a, and 
%   and columns s'. (eg the first Na rows represent the probabilities of 
%   the state 0 to go to states 0, 1, ..., (Ns - 1) on actions 0, 1, ...,
%   (Na - 1))
%   r: Rewards. Each entry represents (s * Na) + a. (e.g the first Na 
%   entries represent rewards for state 0 on actions 0,1,...,(Na - 1))
%   discount: The discount factor
%   filename: file name the mdp should be outputed to (without extension)
% Return: None
function create_pomdp(stm, r, discount, filename)
assert(ischar(filename));
assert(discount > 0 && discount <= 1);

% Check the stm of generated mdp
size_stm = size(stm);
Ns = size_stm(2);
Na = size_stm(1)/Ns;
assert(all(size_stm == [Ns*Na, Ns]));

% Check the reward of generated mdp
size_r = size(r);
assert(all(size_r == [Ns*Na, 1]));

% validate that the stm is schotastic
for a_idx = 1:Na
    start_row = ((a_idx-1)*Ns)+1;
    final_row = a_idx*Ns;
    a_idx_stm = stm((start_row:final_row), :);
    assert(all(size(a_idx_stm) == [Ns, Ns]));

    validate_stochastic_mtrx(a_idx_stm);
end

% open file for writing
fileID = fopen(filename, 'w');

% add preamble
fprintf(fileID, 'discount: %8.8f\n', discount);
fprintf(fileID, 'values: reward\n');
fprintf(fileID, 'states: %d\n', Ns);
fprintf(fileID, 'actions: %d\n', Na);
fprintf(fileID, 'observations: %d\n', Ns);

% add state transition probabilities
for i = 0:(Ns - 1)
    for j = 0:(Na - 1)
        for k = 0:(Ns - 1)
            prob = stm((i*Na) + j + 1, k + 1);
            if(prob ~= 0) 
                % don't print if probability is 0
                fprintf(fileID, 'T: %d : %d : %d %8.8f\n', j, i, k, stm((i*Na) + j + 1, k + 1));
            end 
        end
    end
end

% add observations
for i = 0:(Ns - 1)
    %fully observable
    fprintf(fileID, 'O : * : %d : %d 1.000000\n', i, i);
end

% add rewards
for i = 0:(Ns - 1)
    for j = 0:(Na - 1)
        % reward only depends on start state and action
        fprintf(fileID, 'R : %d : %d : * : * %8.8f\n', j, i, r((i*Na) + j + 1));
    end
end

fclose(fileID);

end