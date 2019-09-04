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

% This function takes the number of states, number of actors, and sparsity
% for an mdp, and generated a random mdp with those parameters. The output
% is store in a file with file name filename.mat (where filename is the
% entered file name), and contains the state transition matrix and the
% reward function. 
% Parameters:
%   Ns: Number of states
%   Na: Number of actors
%   sparsity: sparity
%   filename: file name the mdp should be outputed to (without extension)
% Return: None
function generate_mdp(Ns, Na, sparsity, filename)
assert(floor(Ns) == Ns);
assert(Ns > 0);
assert(floor(Na) == Na);
assert(Na > 0);
assert(sparsity >= 0 && sparsity <= 1);
assert(ischar(filename));

r = zeros(Na * Ns, 1); % reward
stm = zeros(Na * Ns, Ns); % state transition matrix

%% Create reward 
for i = 1:Ns
    num = (0.75 * rand) + 0.05;
    for j = 1:Na
        r(((i - 1) * Na) + j) = num; 
    end
end


%% Create stm
columns_filled = Ns - round(Ns * sparsity);
probabilities = zeros(columns_filled, 1);

for i = 1:Ns
    columns = randsample(Ns, columns_filled); % randomly choose columns to full
  
    % generate probabilities
    max = 0.9999;
    for j = 1:columns_filled
        max_prob = (2/(columns_filled));
        if j == columns_filled
            probabilities(j) = max + 0.0001;
        else
            prob = max * rand;
            if(prob > max_prob)
                prob = max_prob * rand;
            end
                probabilities(j) = prob;
                max = max - probabilities(j);
        end
    end
    probabilities = probabilities(randperm(columns_filled)); % random sort the probabilities
   
    % fill stm
    for j = 1:Na
        stm([((i - 1) * Na) + j], columns) = probabilities; 
    end
end

%%
save(filename, 'r', 'stm');
end
