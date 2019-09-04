function pomdp = readPOMDP(filename,useSparse)
% readPOMDP - parser for "Tony's POMDP file format"
%
% pomdp = readPOMDP(filename,useSparse)
% 
% filename  - string denoting POMDP file to be parsed
% useSparse - boolean indicating whether or not sparse matrices
%             should be used
%
% returns
% pomdp     - struct (see below)
%
% Parser for "Tony's POMDP file format" [1], it allows you to read
% POMDP problems into Matlab, for instance the many examples on
% Anthony Cassandra's own page. It "works" on almost all of these
% examples, where "works" means the parser doesn't complain, I haven't
% checked for all examples whether the numbers are correct. Not all
% variations have been implemented, if you come across a valid POMDP
% file which is not parsed correctly, or find a bug, please drop me a
% note.
%
% Use at your own risk, and always compare the pomdp struct to the
% original .POMDP file.
%
% pomdp struct members definition:
% 
% nrStates       - (1 x 1) number of states
% states         - (nrStates x X) chars, name of each state *)
% nrActions      - (1 x 1) number of actions
% actions        - (nrActions x X) chars, name of each action *)
% nrObservations - (1 x 1) number of observations
% observations   - (nrObservations x X) chars, name of each
%                  observation *)
% gamma          - (1 x 1) discount factor
% values         - (1 x X) chars, 'reward' or 'cost'
% start          - (1 x nrStates) start distribution *)
% if useSparse
%   reward3S     - (1 x nrActions) cell array, containing structs:
%                   {nrActions}(nrStates x nrStates)
%                       a          s'         s          R(s',s,a)
%   observationS - (1 x nrActions) cell array, containing structs:
%                   {nrActions}(nrStates x nrObservations)
%                       a          s'         o          P(o|s',a)
%   transitionS  - (1 x nrActions) cell array, containing structs:
%                   {nrActions}(nrStates x nrStates)
%                       a          s'         s          P(s'|s,a)
% else
%   reward3        - (nrStates x nrStates x nrActions)
%                        s'         s           a        R(s',s,a)
%   observation    - (nrStates x nrActions x nrObservations)
%                        s'         a           o        P(o|s',a)
%   transition     - (nrStates x nrStates x nrActions)
%                        s'         s           a        P(s'|s,a)
% end
%
% Members marked by *) are optional: they might not be present in
% the POMDP file, in that case these members are non-existing or
% empty.
%
% [1]
% http://www.cs.brown.edu/research/ai/pomdp/examples/pomdp-file-spec.html
% 
% Matthijs Spaan <mtjspaan@science.uva.nl>
% Copyright (c) 2003 Universiteit van Amsterdam.  All rights reserved.
% $Id: readPOMDP.m,v 1.11 2003/12/09 17:25:34 mtjspaan Exp $

% This software or any part thereof may only be used for non-commercial  
% or research purposes, as long as the author and University are         
% mentioned. Commercial use without explicit prior written consent by    
% the Universiteit van Amsterdam is strictly prohibited. This copyright  
% notice must be included with any copy of this software or any part     
% thereof.                                                               
%                                                                        
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS    
% "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT      
% LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR  
% A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT   
% OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,  
% SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT       
% LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,  
% DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY  
% THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT    
% (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  
% OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.   

if nargin<2
  useSparse=0;
end

if nargin<1
  error('Specify filename to be parsed');
end

file0=textread(filename,'%s','delimiter','\n','whitespace','', ...
              'bufsize',100000);

% remove comments and empty lines
k=0;
for i=1:length(file0)
  comment=strfind(file0{i},'#');
  if ~isempty(comment)
    file0{i}(comment(1):end)=[];
  end
  if ~isempty(file0{i})
    k=k+1;
    file{k}=file0{i};
  end
end
clear file0;
nrLines=length(file);

% read the preamble
pomdp=processPreamble(file);

if pomdp.nrStates<1
  error(sprintf('POMDP has only %d states.',pomdp.nrStates));
end
if pomdp.nrActions<1
  error(sprintf('POMDP has only %d actions.',pomdp.nrActions));
end
if pomdp.nrObservations<1
  error(sprintf('POMDP has only %d observations.',pomdp.nrObservations));
end

% allocate memory, maximum sizes for sparse matrices are guesses
if useSparse
  for a=1:pomdp.nrActions
    pomdp.reward3S{a}=spalloc(pomdp.nrStates,pomdp.nrStates, ...
                              pomdp.nrStates);
    pomdp.observationS{a}=spalloc(pomdp.nrStates, ...
                                  pomdp.nrObservations, ...
                                  pomdp.nrStates);
    pomdp.transitionS{a}=spalloc(pomdp.nrStates, ...
                                 pomdp.nrStates, ...
                                 pomdp.nrStates);
  end
else
  pomdp.reward3=zeros(pomdp.nrStates,pomdp.nrStates, ...
                      pomdp.nrActions);
  pomdp.observation=zeros(pomdp.nrStates,pomdp.nrActions, ...
                          pomdp.nrObservations);
  pomdp.transition=zeros(pomdp.nrStates,pomdp.nrStates, ...
                         pomdp.nrActions);
end

% process each line
for i=1:nrLines
  if length(file{i})>0
    switch file{i}(1)
     case 'T'
      if ~isempty(strfind(file{i},':'))
        pomdp=processTransition(pomdp,file,i,useSparse);
      end
     case 'R'
      if ~isempty(strfind(file{i},':'))
        pomdp=processReward(pomdp,file,i,useSparse);
      end
     case 'O'
      if ~isempty(strfind(file{i},':'))
        pomdp=processObservation(pomdp,file,i,useSparse);
      end
     case 's'
      if strcmp('start:',file{i}(1:6))
        [s,f,t]=regexp(file{i},'([-\d\.]+)');
        [foo,d]=size(t);
        if d~=pomdp.nrStates
          pomdp.start=parseNextLine(file,i+1,pomdp.nrStates,1);
        else
          pomdp.start=zeros(1,d);
          string=file{i};
          for j=1:d
            pomdp.start(j)=str2double(string(t{j}(1):t{j}(2)));
          end
        end
      end
     otherwise
      continue;
    end
  end
end

function pomdp = processPreamble(file)

[nr,members]=getNumberAndMembers(file,'states:');
pomdp.nrStates=nr;
pomdp.states=members;

[nr,members]=getNumberAndMembers(file,'actions:');
pomdp.nrActions=nr;
pomdp.actions=members;

[nr,members]=getNumberAndMembers(file,'observations:');
pomdp.nrObservations=nr;
pomdp.observations=members;

for i=1:length(file)
  if strmatch('discount:',file{i});
    pomdp.gamma=sscanf(file{i},'discount: %f');
    break;
  end
end

for i=1:length(file)
  if strmatch('values:',file{i})
    pomdp.values=sscanf(file{i},'values: %s');
    break;
  end
end

function [nr, members] = getNumberAndMembers(file,baseString)

for i=1:length(file)
  if strmatch(baseString,file{i})
    string=file{i};
    break;
  end
end

% try to find a number here
[s,f,t]=regexp(string,sprintf('%s%s',baseString,'\s*(\d+)'));
if isempty(s)
  % catch 'X: <list of X>' where X={states,actions,observations}
  % first strip baseString
  [s,f,t]=regexp(string,baseString);
  string1=string(f(1)+1:end);
  % see if there are more members on the next line
  stop=0;
  k=0;
  while ~stop
    k=k+1;
    if isempty(strfind(file{i+k},':'))
      string1=strcat([string1 ' ' file{i+k}]);
    else
      stop=1;
    end
  end
  [s,f,t]=regexp(string1,'\s*(\S+)\s*');
  [foo,nr]=size(t);
  members='';
  for a=1:nr
    members=strvcat(members,string1(t{a}(1):t{a}(2)));
  end
else
  nr=str2double(string(t{1}(1):t{1}(2)));
  members='';
end

function pomdp = processTransition(pomdp,file,i,useSparse)

string=file{i};

if nnz(string==':')==3
  % catch 'T: <action> : <start-state> : <end-state> <prob>'
  pat='T\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s+([\d\.]+)';
  [s,f,t]=regexp(string,pat);

  if ~isempty(t)
    prob=str2double(string(t{1}(4,1):t{1}(4,2)));
  else % probably the prob is on the next line
       % catch 'T: <action> : <start-state> : <end-state> 
    pat='T\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*';
    [s,f,t]=regexp(string,pat);
    prob=parseNextLine(file,i+1,1,1);
  end

  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  from=expandState(pomdp,string(t{1}(2,1):t{1}(2,2)));
  to=expandState(pomdp,string(t{1}(3,1):t{1}(3,2)));

  if useSparse
    for a=1:length(action)
      pomdp.transitionS{action(a)}(to,from)=prob;
    end
  else
    pomdp.transition(to,from,action)=prob;
  end
elseif nnz(string==':')==2
  % catch 'T: <action> : <start-state>'
  pat='T\s*:\s*(\S+)\s*:\s*(\S+)';
  [s,f,t]=regexp(string,pat);
  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  from=expandState(pomdp,string(t{1}(2,1):t{1}(2,2)));
  % catch all probs
  % first try if they are at the end of this line
  string=string(t{1}(2,2)+1:end);
  [s,f,t]=regexp(string,'([\d\.]+)');
  [foo,d]=size(t);
  if d~=pomdp.nrStates
    % hmm, probably they are on the next line
    string=file{i+1};
    [s,f,t]=regexp(string,'([\d\.]+)');
    [foo,d]=size(t);
    if d~=pomdp.nrStates
      error(['Not the correct number of probabilities on the next ' ...
             'line.']);
    end
  end
  if useSparse
    for to=1:d
      prob=str2double(string(t{to}(1):t{to}(2)));
      for a=1:length(action)
        pomdp.transitionS{action(a)}(to,from)=prob;
      end
    end
  else
    for to=1:d
      prob=str2double(string(t{to}(1):t{to}(2)));
      pomdp.transition(to,from,action)=prob;
    end
  end
else
  % catch 'T: <action>
  pat='T\s*:\s*(\S+)\s*';
  [s,f,t]=regexp(string,pat);
  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  values=parseNextLine(file,i+1,pomdp.nrStates,pomdp.nrStates);
  if useSparse
    for a=1:length(action)
      pomdp.transitionS{action(a)}=values';
    end
  else
    pomdp.transition(:,:,action)=values';
  end
end

function pomdp = processObservation(pomdp,file,i,useSparse)

string=file{i};

if nnz(string==':')==3
  % catch 'O: <action> : <end-state> : <observation> <prob>'
  pat='O\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s+([\d\.]+)';
  [s,f,t]=regexp(string,pat);

  if ~isempty(t)
    prob=str2double(string(t{1}(4,1):t{1}(4,2)));
  else % probably the prob is on the next line
       % catch 'O: <action> : <start-state> : <end-state> 
    pat='O\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*';
    [s,f,t]=regexp(string,pat);
    prob=parseNextLine(file,i+1,1,1);
  end

  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  to=expandState(pomdp,string(t{1}(2,1):t{1}(2,2)));
  observation=expandObservation(pomdp,string(t{1}(3,1):t{1}(3,2)));

  if useSparse
    for a=1:length(action)
      pomdp.observationS{action(a)}(to,observation)=prob;
    end
  else
    pomdp.observation(to,action,observation)=prob;
  end
elseif nnz(string==':')==2
  % catch 'O: <action> : <end-state>'
  pat='O\s*:\s*(\S+)\s*:\s*(\S+)';
  [s,f,t]=regexp(string,pat);
  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  to=expandState(pomdp,string(t{1}(2,1):t{1}(2,2)));
  % catch all probs
  % first try if they are at the end of this line
  string=string(t{1}(2,2)+1:end);
  [s,f,t]=regexp(string,'([\d\.]+)');
  [foo,d]=size(t);
  if d~=pomdp.nrObservations
    % hmm, probably they are on the next line
    string=file{i+1};
    [s,f,t]=regexp(string,'([\d\.]+)');
    [foo,d]=size(t);
    if d~=pomdp.nrObservations
      error(['Not the correct number of probabilities on the next ' ...
             'line.']);
    end
  end
  if useSparse
    for obs=1:d
      prob=str2double(string(t{obs}(1):t{obs}(2)));
      for a=1:length(action)
        pomdp.observationS{action(a)}(to,obs)=prob;
      end
    end
  else
    for obs=1:d
      prob=str2double(string(t{obs}(1):t{obs}(2)));
      pomdp.observation(to,action,obs)=prob;
    end
  end
else
  % catch 'O: <action>
  pat='O\s*:\s*(\S+)\s*';
  [s,f,t]=regexp(string,pat);
  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  values=parseNextLine(file,i+1,pomdp.nrObservations, ...
                       pomdp.nrStates);
  if useSparse
    for a=1:length(action)
      pomdp.observationS{action(a)}=values;
    end
  else
    for a=1:length(action)
      pomdp.observation(:,action(a),:)=values;
    end
  end
end

function pomdp = processReward(pomdp,file,i,useSparse)

string=file{i};

if nnz(string==':')==4
  % catch 'R: <action> : <start-state> : <end-state> :
  % <observation> <reward>'
  % Reward can be negative
  pat=['R\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s+([-\d\.]+' ...
       ')'];
  [s,f,t]=regexp(string,pat);
  
  if ~isempty(t)
    reward=str2double(string(t{1}(5,1):t{1}(5,2)));
  else % probably the reward is on the next line
       % catch 'R: <action> : <start-state> : <end-state> :
       % <observation>'
    pat='R\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*:\s*(\S+)\s*';
    [s,f,t]=regexp(string,pat);
    reward=parseNextLine(file,i+1,1,1);
  end
  
  action=expandAction(pomdp,string(t{1}(1,1):t{1}(1,2)));
  from=expandState(pomdp,string(t{1}(2,1):t{1}(2,2)));
  to=expandState(pomdp,string(t{1}(3,1):t{1}(3,2)));
  % we ignore the observation

  if useSparse
    for a=1:length(action)
      pomdp.reward3S{action(a)}(to,from)=reward;
    end
  else
    pomdp.reward3(to,from,action)=reward;
  end
else
  error('Not yet implemented.');
end

function values = parseNextLine(file, i, nrCols, nrRows)

if strmatch('uniform',file{i})
  values=ones(nrRows,nrCols)/nrCols;
elseif strmatch('identity',file{i})
  values=eye(nrCols);
else
  [s,f,t]=regexp(file{i},'([-\d\.]+)');
  [foo,d]=size(t);
  if d~=nrCols
    error(['Not the correct number of probabilities on the next ' ...
           'line.']);
  end
  % check whether this is just a single line of numbers or a full
  % matrix
  if i<length(file)
    numbers=sscanf(file{i+1},'%f');
  else
    numbers=[];
  end
  if any(size(numbers)==0)
    values=zeros(1,d);
    string=file{i};
    for j=1:d
      values(j)=str2double(string(t{j}(1):t{j}(2)));
    end
  else
    % find out how many lines
    i1=i;
    numbers=sscanf(file{i1+1},'%f');
    running=1;
    while running
      numbers=sscanf(file{i1+1},'%f');
      if any(size(numbers)~=0)
        i1=i1+1;
      else
        running=0;
      end
    end
    values=zeros(i1+1-i,d);
    % parse them all
    for k=i:i1
      [s,f,t]=regexp(file{k},'([-\d\.]+)');
      string=file{k};
      for j=1:d
        values(k+1-i,j)=str2double(string(t{j}(1):t{j}(2)));
      end
    end
  end
end

function r = expandState(pomdp,c)

r=expandString(c,pomdp.nrStates,pomdp.states);

function r = expandAction(pomdp,c)

r=expandString(c,pomdp.nrActions,pomdp.actions);

function r = expandReward(pomdp,c)

r=expandString(c,pomdp.nrRewards,pomdp.rewards);

function r = expandObservation(pomdp,c)

r=expandString(c,pomdp.nrObservations,pomdp.observations);

function r = expandString(c,nr,members)

if strcmp(c,'*')
  r=cumsum(ones(nr,1));
else
  r=strmatch(c,members,'exact');
  if isempty(r) % apparently c is a numbered state
    r=str2double(c)+1; % Matlab starts at 1, not 0
  end
end
