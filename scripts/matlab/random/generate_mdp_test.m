function generate_mdp_test(filename)
assert(ischar(filename));
close all;  clearvars -except filename;

% Generate input
Na = (14 * rand) + 1;
Na = floor(Na);
Ns = (5000 * rand) + 100;
Ns = floor(Ns);
sparsity = rand;

% File needed
repo_base_dir = 'C:\\Users\\Rocky\\Documents\\MATLAB\\dspcad';
stochastic_utils_dir = [repo_base_dir,'\\mdp_channelizer\\src\\stochastic_utils'];
if ~exist('validate_stochastic_mtrx.m','file')
        addpath(genpath(stochastic_utils_dir));
        assert(exist('validate_stochastic_mtrx.m','file') ~= 0);
end

% Generate the mdp
generate_mdp(Ns, Na, sparsity, filename);

% Check the reward of generated mdp
load([filename '.mat'], 'r');
size_r = size(r);
assert(all(size_r == [Ns*Na, 1]));

% Check the stm of generated mdp
load([filename '.mat'], 'stm');
size_stm = size(stm);
assert(all(size_stm == [Ns*Na, Ns]));

 for a_idx = 1:Na

        start_row = ((a_idx-1)*Ns)+1;
        final_row = a_idx*Ns;
        a_idx_stm = stm((start_row:final_row), :);
        assert(all(size(a_idx_stm) == [Ns, Ns]));

        validate_stochastic_mtrx(a_idx_stm);
        
        num_nonzero_entries = nnz(a_idx_stm);
        num_entries = numel(a_idx_stm);
        spars = 1 - (num_nonzero_entries/num_entries);
        assert((spars < (sparsity + 0.005)) && (spars > (sparsity - 0.005)));
end

end


    
    

    
