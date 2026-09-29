function out = pgd_minimize(fun,x0,l,u,opts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%PGD_MINIMIZE Projected gradient descent with Armijo line search
%
% SYNOPSIS: out = pgd_minimize(fun,x0,l,u,opts)
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
%    .c1         Armijo sufficient decrease constant
%    .ls_rho     line-search contraction factor
%    .ls_max     maximum # line-search reductions
%    .alpha0     initial step length
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
opts = set_default_opts_pgd(opts);

x = project_box(x0,l,u,opts.b_eps);
[f,~,g] = fun(x);

d = numel(x);
trajX = nan(d,opts.maxIter+1);
trajF = nan(1,opts.maxIter+1);
trajPG = nan(1,opts.maxIter+1);

trajX(:,1) = x; 
trajF(1) = f; 
trajPG(1) = projgrad_norm(x, ...
    g,l,u,opts.b_eps);

exitflag = 0;

for k = 1:opts.maxIter

    drawnow limitrate;   % allow Stop button callback to execute
    % quick stop check (responsive)
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;    % user stop
        break;
    end

    pg = trajPG(k);
    if pg < opts.tolPG
        exitflag = 1;
        break
    end

    if k > 5 && abs(trajF(k) - trajF(k-4)) ...
            <= opts.tolRelF * max(1,abs(trajF(k)))
        exitflag = 2;
        break
    end

    p = -g;  % raw gradient
    p = project_direction_box(x, ...
        p,l,u,opts.b_eps);
    if norm(p) < 1e-14
        exitflag = 3;
        break
    end

    a_feas = feasible_step_box(x, ...
        p,l,u,opts.b_eps);
    alpha0 = min(opts.alpha0,a_feas);

    [x_new,f_new,g_new,alpha,ok] = ...
        projected_armijo(fun, ...
        x,f,g,p,alpha0,a_feas,l,u,opts);

    drawnow limitrate;   % allow Stop button callback to execute
    % second stop check: catches stop during line search / fun evals
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;    % user stop
        break;
    end

    if ~ok
        exitflag = 4;
        break
    end

    x = x_new;
    f = f_new;
    g = g_new;

    trajX(:,k+1) = x;
    trajF(k+1) = f;
    trajPG(k+1) = projgrad_norm(x, ...
        g,l,u,opts.b_eps);

    % per-iteration callback (UI streaming)
    if isfield(opts,'iterFcn') ...
            && ~isempty(opts.iterFcn)
        opts.iterFcn(struct( ...
            'iter',k, ...
            'f',f, ...
            'pg',trajPG(k+1), ...
            'alpha',alpha ));
    end

    if opts.verbose
        fprintf(['iter %4d  f=%.6e  ' ...
            '||pg||=%.3e  alpha=%.2e\n'], ...
            k,f,trajPG(k+1),alpha);
    end

end

iter = find(~isnan(trajF),1,'last') - 1;   % number of completed steps
if isempty(iter)
    iter = 0; 
end

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
function opts = set_default_opts_pgd(opts)
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
if ~isfield(opts,'c1')
    opts.c1 = 1e-4; 
end
if ~isfield(opts,'ls_rho')
    opts.ls_rho = 0.7; 
end
if ~isfield(opts,'ls_max')
    opts.ls_max = 40; 
end
if ~isfield(opts,'alpha0')
    opts.alpha0 = 1; 
end
if ~isfield(opts,'verbose')
    opts.verbose = 0; 
end
end
