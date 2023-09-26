function recursive(solver, options)
%RECURSIVE verifies that the solvers can be called recursively.

if nargin < 2
    options = struct();
end

% Set the dimension of the problem
if isfield(options, 'n')
    n = options.n;
else
    n = 10;
end

% Set the number of parallel runs
if isfield(options, 'np')
    np = options.np;
else
    np = 100;
end

% Set up the solver
if ~isfield(options, 'compile') || options.compile
    old_directory = pwd();
    cd(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    opt = struct();
    opt.verbose = false;
    opt.debug = true;
    opt.debug_only = true;
    opt.classical = false;
    opt.single = false;
    setup(solver, opt);
    cd(old_directory);
end
solver_name = solver;
solver = str2func(solver);


% Set the random seed. We ALTER THE SEED WEEKLY to test the solvers as much as possible.
if isfield(options, 'yw')
    yw = options.yw;
elseif isfield(options, 'seed')
    yw = options.seed;
else
    yw = year_week('Asia/Shanghai');
end
fprintf('\nYW = %d\n', yw);
% Define the random seed by yw
random_seed = yw;
orig_rng_state = rng();  % Save the current random number generator settings

% Conduct the test
tic;
fprintf('\n>>>>>> Parallel test for %s starts <<<<<<\n', solver_name);

% Call the solver
opt = struct();
opt.iprint = 1;
opt.debug = true;
opt.rhoend = 1.0e-6;
opt.maxeval = 500*n;

parfor i = 1:np
    fprintf('\n>>>>>> Parallel test for %s, %d-th run <<<<<<\n', solver_name, i);
    rng(random_seed + i);
    shift = randn(n, 1);
    fun = @(x) chrosen(x + shift);
    [x, fx, exitflag, output] = solver(fun, randn(n, 1), opt)
    assert(fx < 1.0e-5, 'The objective value is not small enough.')
end

fprintf('\n>>>>>> Parallel test for %s ends <<<<<<\n', solver_name);
toc;

% Restore the random number generator state
rng(orig_rng_state);

return