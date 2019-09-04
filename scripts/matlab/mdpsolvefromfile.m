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

% This function takes in the filename of a .pomdp file, and uses mdpsolve 
% to find the fully observable solution of the pomdp. The result is stored 
% in out_dir_name in a file with the same name as the .pomdp file but a
% .txt extention.
% 
% The solver uses the MDPSOLVE MATLAB solver, available here:
% https://github.com/PaulFackler/MDPSolve/
% You must clone this repo locally first, and make sure the whole tree 
% is in the MATLAB path: e.g.- addpath(genpath
% 
% Parameters:
%   filename: The file name of the .pomdp file
%   out_dir_name: Where to put the solution
% Return: None

function mdpsolvefromfile(filename, out_dir_name)
    assert(ischar(filename));
    assert(ischar(out_dir_name));

    % Make sure the MDPSOLVE package is available and on the path
    assert(exist('mdpsolve.m', 'file') ~= 0);

    mdp1 = readPOMDP(filename, 0); %parser

    %R = squeeze(mdp1.reward3(1,:,:)); %rewards
    discount = mdp1.gamma; %discount factor
    P = []; % To be filled with transition probabilities

    Na = size((mdp1.transition), 3); % Number of actions
    Ns = size((mdp1.transition), 1); % Number of states

    % Rewards (convert from 3d to 2d)
    R = zeros(Ns, Na);
    for i = 1:Ns
        for j = 1:Na 
            reward = 0;
            for k = 1:Ns
                reward = reward + ((mdp1.reward3(k, i, j)) * ...
                        (mdp1.transition(k, i, j))); 
            end
            R(i, j) = reward;
        end  
    end


    % state/action combinations 
    % columns: 1) value of action 
    %          2) value of state 
    X = zeros(Na*Ns, 2);
    for i = 1:(Na*Ns)
        X(i,1) = ceil(i/Ns); 
        X(i,2) = mod((i - 1), Ns) + 1;   
    end

    % fill transtion probability in the format needed for mdpsolve
    for i = 1:(size((mdp1.transition), 3))
        P = [P ((mdp1.transition(:,:,i)))];
    end

    %scale probablities to 1 if they're close but not quite 
    for i = 1:(Na*Ns)
        sump = sum(P(:,i));
        if((sump > 0.99999) && (sump < 1.00001))
            scaling_factor = 1/sump;
            P(:,i) = P(:,i) * scaling_factor;
        end
    end

    % set up model structure
    clear model
    model.R = R;
    model.d = discount;
    model.P = P;
    model.X = X;

    % solve
    results = mdpsolve(model);

    %output
    [~, stripped_name, stripped_ext] = fileparts(filename);
    out_filename = [out_dir_name, filesep, stripped_name, '.txt'];
    fileID = fopen(out_filename, 'w');
%     disp('State, Optimal Control and Value \n')
%     fprintf('%1i %1i %8.6f\n',[(results.Xopt(:,[2 1]) - [1 1]) results.v]')
    fprintf(fileID, 'State, Optimal Control and Value \n');
    fprintf(fileID, '%1i %1i %8.6f\n',[(results.Xopt(:,[2 1]) - [1 1]) results.v]');
    fclose(fileID);
end