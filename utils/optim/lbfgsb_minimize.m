function out = lbfgsb_minimize(fun,x0,l,u,opts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LBFGSB_MINIMIZE Projected limited-memory BFGS with Armijo line search
%
% SYNOPSIS: out = lbfgsb_minimize(fun,x0,l,u,opts)
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
%    .m          limited-memory history size
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
opts = set_default_opts(opts);

if any(isinf(l)) ...
        || any(isinf(u))
    opts.b_eps = 0;
end

x = project_box(x0,l,u,opts.b_eps);
[f,~,g] = fun(x);
d = numel(x);
m = opts.m;

S = zeros(d,m); 
Y = zeros(d,m); 
rho = zeros(1,m);
mem = 0; 
head = 0;

trajX = nan(d,opts.maxIter+1);
trajF = nan(1,opts.maxIter+1);
trajPG = nan(1,opts.maxIter+1);

trajX(:,1) = x;
trajF(1) = f;
trajPG(1) = projgrad_norm(x,g,l,u,opts.b_eps);

useLBFGS = true;
stallCount = 0;
exitflag = 0;

if opts.verbose
    fprintf(['iter %4d  f = %.6e  ' ...
        '||pg|| = %.3e\n'],0,f,trajPG(1));
end

for k = 1:opts.maxIter

    drawnow limitrate;   % allow Stop button callback to execute
    % quick stop check (responsive)
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;    % user stop
        break;
    end

    pg = trajPG(k);  % reuse stored value (computed previous iteration)
    if pg < opts.tolPG
        exitflag = 1; 
        break;
    end

    if k > 5
        if abs(trajF(k)-trajF(k-4)) ...
                <= opts.tolRelF*max(1,abs(trajF(k)))
            exitflag = 2; 
            break;
        end
    end

    % ----- direction -----
    if useLBFGS && mem > 0
        p = -lbfgs_two_loop(g,S,Y,rho,mem,head);
    else
        p = -g;
    end

    p = project_direction_box(x,p,l,u,opts.b_eps);
    if norm(p) < 1e-14
        p = -project_direction_box(x,g,l,u,opts.b_eps);
        if norm(p) < 1e-14
            exitflag = 3; 
            break;
        end
    end

    if abs(g'*p) < 1e-12 && norm(g) < 1e-6
        exitflag = 5; 
        break;
    end

    a_feas = feasible_step_box(x,p,l,u,opts.b_eps);
    alpha0 = min(opts.alpha0,a_feas);

    [x_new,f_new,g_new,alpha,ok] = ...
        projected_armijo(fun,x,f,g,p,alpha0,a_feas,l,u,opts);

    drawnow limitrate;   % process Stop after expensive forward run
    % second stop check: catches stop during line search / model evaluations
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;
        break;
    end

    if ~ok
        exitflag = 4; 
        break;
    end

    % ----- update memory -----
    s = x_new - x;
    y = g_new - g;
    ys = y'*s;

    sNy = norm(s)*norm(y);
    curv_ok = isfinite(ys) ...
        && isfinite(sNy) ...
        && (ys > 1e-10*sNy) ...
        && (ys > 1e-12) ...
        && (norm(y) > 1e-10);

    if curv_ok
        head = mod(head,m) + 1;
        S(:,head) = s;
        Y(:,head) = y;
        rho(head) = 1/ys;
        mem = min(mem+1,m);
        useLBFGS = true;
        stallCount = 0;
    else
        mem = 0;
        useLBFGS = false;
        stallCount = stallCount + 1;
    end

    % accept
    x = x_new;
    f = f_new;
    g = g_new;

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
            'alpha',alpha, ...
            'mem',mem, ...
            'stall',stallCount, ...
            'useLBFGS',useLBFGS));
    end

    if opts.verbose
        fprintf(['iter %4d  f = %.6e  ' ...
            '||pg|| = %.3e  alpha=%.2e  mem=%d\n'], ...
            k,f,trajPG(k+1),alpha,mem);
    end

    if stallCount >= 10
        exitflag = 6; 
        break;
    end

    if norm(g) < 10*opts.tolPG
        exitflag = 7; 
        break;
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

% -------
% Helpers
% -------
function opts = set_default_opts(opts)
if ~isfield(opts,'m')
    opts.m = 10; 
end
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

function q = lbfgs_two_loop(g,S,Y,rho,mem,head)
% Two-loop recursion to compute H_k * g (approx inverse Hessian times g).
% We return q = H*g.
if mem == 0
    q = g; % identity scaling
    return;
end
m = size(S,2);
alpha = zeros(1,mem);
q = g;
% indices from most recent backwards in ring buffer
for ii = 1:mem
    j = head - (ii-1);
    if j <= 0 
        j = j + m; 
    end
    alpha(ii) = rho(j) * (S(:,j)' * q);
    q = q - alpha(ii) * Y(:,j);
end
% Initial scaling gamma = (s_{k-1}' y_{k-1}) / (y_{k-1}' y_{k-1})
jlast = head;
ys = Y(:,jlast)' * S(:,jlast);
yy = Y(:,jlast)' * Y(:,jlast);
if isfinite(ys) && isfinite(yy) && yy > 0
    gamma = max(1e-4,min(1e4,ys / yy));
else
    gamma = 1;
end
r = gamma * q;

for ii = mem:-1:1
    j = head - (ii-1);
    if j <= 0
        j = j + m; 
    end
    beta = rho(j) * (Y(:,j)' * r);
    r = r + S(:,j) * (alpha(ii) - beta);
end
q = r;
end
