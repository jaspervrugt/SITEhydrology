function out = adam_minimize(fun,x0,l,u,opts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ADAM_MINIMIZE Projected Adam optimizer for box-constrained problems
%
% SYNOPSIS: out = adam_minimize(fun,x0,l,u,opts)
%
% INPUT ARGUMENTS:
%   fun         function handle with calling sequence
%               [f,~,g] = fun(x)
%               where
%                 f = scalar objective function value
%                 g = gradient vector
%   x0          dx1 vector with initial parameter values
%   l           dx1 vector with lower parameter bounds
%   u           dx1 vector with upper parameter bounds
%   opts        OPTIONAL: structure with optimizer settings
%    .maxIter    maximum # descent iterations
%    .tolPG      stopping tolerance projected gradient norm
%    .tolRelF    stopping tolerance relative objective change
%    .b_eps      small boundary buffer for box projection
%    .alpha      learning rate
%    .beta1      first-moment decay parameter
%    .beta2      second-moment decay parameter
%    .eps        small numerical safeguard
%    .verbose    print iteration diagnostics? [0 no | 1 yes]
%    .stopFcn    OPTIONAL: user-supplied stop function handle
%    .iterFcn    OPTIONAL: iteration callback function handle
%
% OUTPUT ARGUMENTS:
%   out         structure with optimizer results
%    .x          final parameter vector
%    .f          final objective function value
%    .g          final gradient vector
%    .pg         projected gradient norm at final iterate
%    .iter       # completed iterations
%    .exitflag   termination flag
%    .trajX      dx(iter+1) matrix with parameter trajectory
%    .trajF      1x(iter+1) vector with objective values
%    .trajPG     1x(iter+1) vector with projected gradient norms
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 5
    opts = struct(); 
end
opts = set_default_opts_adam(opts);

x = project_box(x0,l,u,opts.b_eps);
[f,~,g] = fun(x);

d = numel(x);
m = zeros(d,1);
v = zeros(d,1);

trajX = nan(d,opts.maxIter+1);
trajF = nan(1,opts.maxIter+1);
trajPG = nan(1,opts.maxIter+1);

trajX(:,1) = x;
trajF(1) = f;
trajPG(1) = projgrad_norm(x,g,l,u,opts.b_eps);

exitflag = 0;

for k = 1:opts.maxIter

    drawnow limitrate;   % allow Stop button callback to execute
    % quick stop check (responsive)
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;  % user stop
        break;
    end

    pg = trajPG(k);
    if pg < opts.tolPG
        exitflag = 1;
        break;
    end

    if k > 5 && abs(trajF(k)-trajF(k-4)) ...
            <= opts.tolRelF*max(1,abs(trajF(k)))
        exitflag = 2;
        break;
    end

    % Adam moments
    m = opts.beta1*m + (1-opts.beta1)*g;
    v = opts.beta2*v + (1-opts.beta2)*(g.^2);

    % bias correction
    mhat = m/(1-opts.beta1^k);
    vhat = v/(1-opts.beta2^k);

    step = opts.alpha * mhat ./ (sqrt(vhat) + opts.eps);
    p = -step;

    p = project_direction_box(x,p,l,u,opts.b_eps);
    if norm(p) < 1e-14
        exitflag = 3;
        break;
    end

    a_feas = feasible_step_box(x,p,l,u,opts.b_eps);
    a = min(1,a_feas);

    x = project_box(x + a*p,l,u,opts.b_eps);
    [f,~,g] = fun(x);

    drawnow limitrate;   % process Stop after expensive forward run
    % second stop check: catches stop during expensive model evaluation
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;
        break;
    end

    trajX(:,k+1) = x;
    trajF(k+1) = f;
    trajPG(k+1) = projgrad_norm(x,g,l,u,opts.b_eps);

    % per-iteration callback (UI streaming)
    if isfield(opts,'iterFcn') ...
            && ~isempty(opts.iterFcn)
        opts.iterFcn(struct( ...
            'iter',k, ...
            'f',f, ...
            'pg',trajPG(k+1), ...
            'a',a, ...
            'stepNorm',norm(step)));
    end

    if opts.verbose
        fprintf(['iter %4d  f=%.6e  ' ...
            '||pg||=%.3e  a=%.2e\n'], ...
            k,f,trajPG(k+1),a);
    end
end

% robust iteration count
iter = find(~isnan(trajF),1,'last') - 1;
if isempty(iter), iter = 0; end

out.x = x;
out.f = f;
out.iter = iter;
out.exitflag = exitflag;
out.trajX = trajX(:,1:iter+1);
out.trajF = trajF(1:iter+1);
out.trajPG = trajPG(1:iter+1);
end

% ------
% Helper
% ------
function opts = set_default_opts_adam(opts)
if ~isfield(opts,'maxIter')
    opts.maxIter = 200; 
end
if ~isfield(opts,'tolPG')
    opts.tolPG = 1e-6; 
end
if ~isfield(opts,'tolRelF')
    opts.tolRelF = 1e-6; 
end
if ~isfield(opts,'b_eps')
    opts.b_eps = 1e-6; 
end
if ~isfield(opts,'alpha')
    opts.alpha = 0.01; 
end
if ~isfield(opts,'beta1')
    opts.beta1 = 0.9; 
end
if ~isfield(opts,'beta2')
    opts.beta2 = 0.999; 
end
if ~isfield(opts,'eps')
    opts.eps = 1e-8; 
end
if ~isfield(opts,'verbose')
    opts.verbose = 0; 
end
end
