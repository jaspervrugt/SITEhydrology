function out = lm_minimize(fun,x0,l,u,opts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LM_MINIMIZE Projected damped Levenberg-Marquardt box optimizer
%
% SYNOPSIS: out = lm_minimize(fun,x0,l,u,opts)
%
% INPUT ARGUMENTS:
%   fun         function handle with calling sequence
%               [f,r,J,g] = fun(x)
%               where
%                 f = scalar objective function value
%                 r = residual vector
%                 J = Jacobian matrix
%                 g = gradient vector
%   x0          dx1 vector with initial parameter values
%   l           dx1 vector with lower parameter bounds
%   u           dx1 vector with upper parameter bounds
%   opts        OPTIONAL: structure with optimizer settings
%    .maxIter    maximum # descent iterations
%    .tolPG      stopping tolerance projected gradient norm
%    .tolRelF    stopping tolerance relative objective change
%    .b_eps      small boundary buffer for box projection
%    .ridge      Tikhonov ridge added to J'J
%    .lambda0    initial damping parameter
%    .lambdaMin  minimum damping parameter
%    .lambdaMax  maximum damping parameter
%    .nu         damping update multiplier (> 1)
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
opts = set_default_opts_lm(opts);

x = project_box(x0,l,u,opts.b_eps);
[f,~,g,J] = fun(x);
d = numel(x);

lambda = opts.lambda0;
nu = opts.nu;

trajX = nan(d,opts.maxIter+1);
trajF = nan(1,opts.maxIter+1);
trajPG = nan(1,opts.maxIter+1);

trajX(:,1) = x; 
trajF(1) = f; 
trajPG(1) = projgrad_norm(x,g,l,u,opts.b_eps);

exitflag = 0;
k = 0;

while k < opts.maxIter

    drawnow limitrate;   % allow Stop button callback to execute
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;
        break;
    end

    pg = projgrad_norm(x,g,l,u,opts.b_eps);
    if pg < opts.tolPG
        exitflag = 1;
        break;
    end

    if k >= 5
        f_now = trajF(k+1);
        f_old = trajF(k-3+1);
        if abs(f_now - f_old) ...
                <= opts.tolRelF*max(1,abs(f_now))
            exitflag = 2;
            break;
        end
    end

    H = (J'*J) + opts.ridge*eye(d);
    dH = diag(H);
    dH(dH==0) = 1;
    D = diag(dH);

    p = - (H + lambda*D) \ g;
    p = project_direction_box(x,p,l,u,opts.b_eps);
    if norm(p) < 1e-14
        exitflag = 3;
        break;
    end

    a_feas = feasible_step_box(x,p,l,u,opts.b_eps);
    a = min(1,a_feas);

    x_trial = project_box(x + a*p,l,u,opts.b_eps);
    [f_trial,~,g_trial,J_trial] = fun(x_trial);

    drawnow limitrate;   % process Stop after expensive forward run
    % second stop check: catches stop during trial model evaluation
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;
        break;
    end

    if isfinite(f_trial) && f_trial < f
        x = x_trial;
        f = f_trial; 
        g = g_trial;
        J = J_trial;

        lambda = max(opts.lambdaMin,lambda/nu);
        k = k + 1;

        trajX(:,k+1) = x;
        trajF(k+1) = f;
        trajPG(k+1) = projgrad_norm(x,g,l,u,opts.b_eps);

        if isfield(opts,'iterFcn') ...
                && ~isempty(opts.iterFcn)
            opts.iterFcn(struct( ...
                'iter',k, ...
                'f',f, ...
                'pg',trajPG(k+1), ...
                'lambda',lambda, ...
                'accepted',true));
        end

        if opts.verbose
            fprintf(['iter %4d  f=%.6e  ' ...
                '||pg||=%.3e  a=%.2e  lambda=%.2e (acc)\n'], ...
                k,f,trajPG(k+1),a,lambda);
        end
    else
        lambda = min(opts.lambdaMax,lambda*nu);
    
        % OPTIONAL: emit reject event (can be noisy)
        if isfield(opts,'iterFcn') ...
                && ~isempty(opts.iterFcn)
            opts.iterFcn(struct( ...
                'iter',k, ...
                'f',f, ...
                'pg',trajPG(k+1), ...
                'lambda',lambda, ...
                'accepted',false));
        end

        if opts.verbose
            fprintf(['iter %4d reject ' ...
                'lambda=%.2e\n'],k,lambda);
        end

        if lambda >= opts.lambdaMax
            exitflag = 4;
            break;
        end
    end
end

iter = k;
out.x = x; 
out.f = f; 
out.g = g; 
out.iter = iter; 
out.exitflag = exitflag;
out.trajX = trajX(:,1:iter+1);
out.trajF = trajF(1:iter+1);
out.trajPG = trajPG(1:iter+1);
end

% ------
% Helper
% ------
function opts = set_default_opts_lm(opts)
if ~isfield(opts,'maxIter')
    opts.maxIter = 100; 
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
if ~isfield(opts,'ridge')
    opts.ridge = 1e-10; 
end
if ~isfield(opts,'lambda0')
    opts.lambda0 = 1e-3; 
end
if ~isfield(opts,'lambdaMin')
    opts.lambdaMin = 1e-12; 
end
if ~isfield(opts,'lambdaMax')
    opts.lambdaMax = 1e12; 
end
if ~isfield(opts,'nu')
    opts.nu = 2; 
end
if ~isfield(opts,'verbose')
    opts.verbose = 0; 
end
end
