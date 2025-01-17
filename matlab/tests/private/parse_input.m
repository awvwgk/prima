function [solver, options] = parse_input(argin)
%This function parses the input to a testing function, returning the name of the solver to test and
% the testing options. The testing function can have the signature
%
%   test(solver, dimrange, nocompile_flag, sequential_flag, reverse_flag, problem_type, competitor, options)
%
% where
% - `solver` is the name of solver to test
% - `dimrange` (optional) is the vector [mindim, maxdim], or "small", or "big", or "large", or "all"
% - `nocompile_flag` (optional) is either 'nocompile' or 'ncp', which means not to compile the solvers
% - `sequential_flag` (optional) is either 'sequential' or 'seq', which means to test the problems sequentially
% - `reverse_flag` (optional) is either 'reverse' or 'rev', which means to test the solvers in the reverse order
% - `problem_type` can be any of {'u', 'b', 'l', 'n', 'ub', 'ubl', 'ubln', 'bl', 'bln', 'ln'},
%   indicating the problem type to test
% - `competitor` (optional) can be any of {'classical', 'archiva', 'norma', 'single', 'quadruple'},
%   indicating the name of a competitor solver to test (only for profiling)
%   - 'classical' means to test the classical solvers
%   - 'archiva' means to compare with the "archiva" version of the solver, located under the
%     .development/archiva/dev_arch/ directory
%   - 'norma' means to compare with the "norma" version of the solver, located under the
%      .development/norma/ directory
%   - 'single' means to compare with the single precision version of the solver, namely the solver
%     invoked with the 'single' flag set to true
%   - 'quadruple' means to compare with the quadruple precision version of the solver, namely the solver
%     invoked with the 'quadruple' flag set to true
% - `options` (optional) is a structure containing options to pass to `isequiv`, `perfdata`, etc.
%
% If the testing function is `verify`, then the following signatures are also supported:
%
%   verify(solver, problem, nocompile_flag, sequential_flag, reverse_flag, problem_type, options)
%   verify(solver, problem, ir, nocompile_flag, sequential_flag, reverse_flag, problem_type, options)
%
% where
% - `problem` is a problem to test
% - `ir` is the index of the random run in `verify`
%
% If the testing function is `profile`, then the following signature is also supported
%
%   profile(solver, dimrange, problem_type, reload_flag)
%
% where
% - `reload_flag` is either 'reload' or 'load', indicating to load the data directly from the .mat
% file corresponding to `solver`, `dimrange`, and `problem_type`; in this case, both `solver` and
% `problem_type` must be specified
%
% Coded by Zaikun ZHANG (www.zhangzk.net).
%
% Started: July 2020
%
% Last Modified: Thursday, April 27, 2023 PM05:48:00
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

callstack = dbstack;
invoker = callstack(2).name;  % The function that calls this function.
known_solvers = {'cobyla','uobyqa','newuoa','bobyqa','lincoa', 'prima'};
known_sizes = {'small', 'big', 'large', 'all'};
nocompile_flags = {'nocompile', 'ncp'};
sequential_flags = {'sequential', 'seq'};
reverse_flags = {'reverse', 'rev'};
reload_flags = {'reload', 'load'};
problem_types = {'u', 'b', 'l', 'n', 'ub', 'ubl', 'ubln', 'bl', 'bln', 'ln'};
competitors = {'classical', 'archiva', 'norma', 'single', 'quadruple'};

% Default values.
solver = '';
prob = '';
ir = NaN;
mindim = 1;
maxdim = 50;
compile = true;
sequential = false;
reverse = false;
reload = false;
problem_type = '';
competitor = 'archiva';

if any(cellfun(@isstruct, argin))
    options = argin{find(cellfun(@isstruct, argin), 1)};
    argin = argin(~cellfun(@isstruct, argin));
else
    options = struct();
end

fun = @(x) ischstr(x) && ismember(x, nocompile_flags);
if any(cellfun(fun, argin))
    compile = false;
    argin = argin(~cellfun(fun, argin));
end

fun = @(x) ischstr(x) && ismember(x, sequential_flags);
if any(cellfun(fun, argin))
    sequential = true;
    argin = argin(~cellfun(fun, argin));
end

fun = @(x) ischstr(x) && ismember(x, reverse_flags);
if any(cellfun(fun, argin))
    reverse = true;
    argin = argin(~cellfun(fun, argin));
end

fun = @(x) ischstr(x) && ismember(x, problem_types);
if any(cellfun(fun, argin))
    problem_type = argin{find(cellfun(fun, argin), 1, 'first')};
    argin = argin(~cellfun(fun, argin));
end

fun = @(x) ischstr(x) && ismember(x, competitors);
if any(cellfun(fun, argin))
    competitor = argin{find(cellfun(fun, argin), 1, 'first')};
    argin = argin(~cellfun(fun, argin));
end

% After previous steps, 1 <= length(argin) <= 3.
wrong_input = (length(argin) < 1 || length(argin) > 3);

if length(argin) == 3 && strcmp(invoker, 'verify')
    if any(cellfun(@isintnum, argin))
        ir = argin{find(cellfun(@isintnum, argin), 1)};
        argin = argin(~cellfun(@isintnum, argin));
    end
end

if length(argin) == 3 && strcmp(invoker, 'profile')
    fun = @(x) ischstr(x) && ismember(x, reload_flags);
    if any(cellfun(fun, argin))
        reload = true;
        compile = false;
        argin = argin(~cellfun(fun, argin));
    else
        wrong_input = true;
    end
end

if length(argin) == 2
    if ischstr(argin{1}) && isnumvec(argin{2}) && length(argin{2}) == 2
        solver = argin{1};
        mindim = min(argin{2});
        maxdim = max(argin{2});
    elseif ischstr(argin{2}) && isnumvec(argin{1}) && length(argin{1}) == 2
        solver = argin{2};
        mindim = min(argin{1});
        maxdim = max(argin{1});
    elseif ischstr(argin{1}) && ischstr(argin{2})
        argin = lower(argin);
        if length(intersect(argin, known_solvers)) == 1
            solver = intersect(argin, known_solvers);
            solver = solver{1};
            sdiff = setdiff(argin, known_solvers);
            if length(intersect(sdiff, known_sizes)) == 1
                [mindim, maxdim, wrong_input] = parse_dim(sdiff{1});
            elseif strcmp(invoker, 'verify')
                prob = lower(sdiff{1});
            else
                wrong_input = true;
            end
        else
            wrong_input = true;
        end
    else
        wrong_input = true;
    end
end

if length(argin) == 1
    if ischstr(argin{1})
        solver = argin{1};
    else
        wrong_input = true;
    end
end

solver = lower(solver);

wrong_input = wrong_input || ~(ismember(solver, known_solvers) && (mindim <= maxdim) && mindim >= 1 && isintnum(mindim) && isintnum(maxdim));

if wrong_input
    if (strcmp(invoker, 'verify'))
        errmsg = sprintf('\nUsage:\n\n\t%s(solver, dimrange, nocompile_flag, sequential_flag, reverse_flag, problem_type, options), or %s(solver, problem, ir, nocompile_flag, sequential_flag, reverse_flag, problem_type, options).\n', invoker, invoker);
    elseif (strcmp(invoker, 'profile'))
        errmsg = sprintf('\nUsage:\n\n\t%s(solver, dimrange, nocompile_flag, sequential_flag, reverse_flag, problem_type, competitor, options), or %s(solver, dimrange, reload_flag, problem_type, options).\n', invoker, invoker);
    else
        errmsg = sprintf('\nUsage:\n\n\t%s(solver, dimrange, nocompile_flag, sequential_flag, reverse_flag, options).\n', invoker);
    end
    error(errmsg);
end

% Define the testing options.
options.compile = compile;
options.sequential = sequential;
options.reverse = reverse;
options.reload = reload;
options.competitor = competitor;
if isempty(prob)
    % Define the dimension range.
    options.mindim = mindim;
    options.maxdim = maxdim;

    % Revise the dimension range for COBYLA and UOBYQA.
    if strcmpi(solver, 'cobyla') || strcmpi(solver, 'uobyqa') || strcmpi(solver, 'prima')
        if options.maxdim == 50
            options.maxdim = 20;
        end
        if options.mindim == 51
            options.mindim = 21;
        end
        if options.maxdim == 100
            options.maxdim = 50;
        end
        if options.mindim == 101
            options.mindim = 51;
        end
        if options.maxdim == 200
            options.maxdim = 100;
        end
    end

    options.maxcon = 100*options.maxdim;

    % Revise the dimension range for verification to avoid overtime of GitHub Actions.
    if strcmpi(invoker, 'verify')
        if strcmpi(solver, 'cobyla')
            options.maxdim = min(options.maxdim, 80); %!!!
        elseif strcmpi(solver, 'newuoa')
            %options.maxdim = min(options.maxdim, 190);
            % N.B.: There is no unconstrained problem in [101, 190]!!!
        elseif strcmpi(solver, 'lincoa')
            options.maxdim = min(options.maxdim, 160); %!!!
            options.maxcon = 20*options.maxdim; %!!!
        end
    end

    % Define the number of random runs.
    if ~isfield(options, 'nr')
        if strcmpi(invoker, 'profile')
            options.nr = 5;
        else
            options.nr = 10; % For the verification, the actual number of run is 20 + nr.
        end
    end

    % Define the problem type(s) to test.
    if ~isempty(problem_type)
        options.type = problem_type;
    else
        switch solver
        case {'uobyqa', 'newuoa'}
            options.type = 'u';
        case 'bobyqa'
            options.type = 'ub';
        case 'lincoa'
            options.type = 'ubl';
        otherwise
            options.type = 'ubln';
        end
    end
else
    options.list = {prob};
    if (~isnan(ir))
        options.ir = ir;
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Auxiliary functions %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [mindim, maxdim, wrong_input] = parse_dim(dimrange)

wrong_input = false;
switch lower(dimrange)
case 'small'
    mindim = 1;
    maxdim = 50;
case 'big'
    mindim = 51;
    maxdim = 100;
case 'large'
    mindim = 101;
    maxdim = 200;
case 'all'
    mindim = 1;
    maxdim = 200;
otherwise
    wrong_input = true;
end
