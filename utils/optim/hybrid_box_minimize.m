function out = hybrid_box_minimize(fun,x0,l,u,opts)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%HYBRID_BOX_MINIMIZE Adam warm start + box-constrained local finisher with
% analytic gradient safety
%
% SYNOPSIS: out = hybrid_box_minimize(fun,x0,l,u,opts)
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
%   opts        OPTIONAL: structure with hybrid optimizer settings
%    .tolPG      stopping tolerance projected gradient norm
%    .tolRelF    stopping tolerance relative objective change
%    .b_eps      small boundary buffer for box projection
%    .verbose    print iteration diagnostics? [0 no | 1 yes]
%    .adam_maxIter maximum # Adam warm-start iterations
%    .adam_alpha Adam learning rate
%    .adam_beta1 Adam first-moment decay parameter
%    .adam_beta2 Adam second-moment decay parameter
%    .adam_eps   Adam numerical safeguard
%    .stallPG    projected-gradient threshold for Adam stall detection
%    .stallStep  accepted-step threshold for Adam stall detection
%    .stallWindow # consecutive stall iterations before switching
%    .minAdamIterBeforeSwitch minimum # Adam iterations before switching
%    .finisher   local box optimizer ['lbfgsb' | 'pgd']
%    .finish_maxIter maximum # finisher iterations
%    .tolPG_finish stopping tolerance finisher projected gradient norm
%    .tolRelF_finish stopping tolerance finisher relative objective change
%    .stopFcn    OPTIONAL: user-supplied stop function handle
%    .iterFcn    OPTIONAL: iteration callback function handle
%
% OUTPUT ARGUMENTS:
%   out         structure with optimizer results
%    .x          final parameter vector
%    .f          final objective function value
%    .iter       total # iterations over both phases
%    .exitflag   termination flag
%    .bestSource source of final solution ['adam' | 'finisher']
%    .phase1     output structure of Adam warm start
%    .phase2     output structure of local finisher
%    .trajX      dxN matrix with combined parameter trajectory
%    .trajF      1xN vector with combined objective values
%    .trajPG     1xN vector with combined projected gradient norms
%    .x_best     best Adam parameter vector
%    .f_best     best Adam objective function value
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 5, opts = struct(); end
opts = set_default_opts_hybrid(opts);

x0 = project_box(x0,l,u,opts.b_eps);

% -------------
% Phase 1: Adam
% -------------
optsA = struct();
optsA.maxIter = opts.adam_maxIter;
optsA.tolPG = opts.tolPG;
optsA.tolRelF = opts.tolRelF;
optsA.b_eps = opts.b_eps;
optsA.alpha = opts.adam_alpha;
optsA.beta1 = opts.adam_beta1;
optsA.beta2 = opts.adam_beta2;
optsA.eps = opts.adam_eps;
optsA.verbose = opts.verbose;
optsA.stopFcn = [];
optsA.iterFcn = [];
optsA.stallPG = opts.stallPG;
optsA.stallStep = opts.stallStep;
optsA.stallWindow = opts.stallWindow;
optsA.minAdamIterBeforeSwitch = ...
    opts.minAdamIterBeforeSwitch;

if isfield(opts,'stopFcn') 
    optsA.stopFcn = opts.stopFcn; 
end
if isfield(opts,'iterFcn')
    optsA.iterFcn = @(msg) hybrid_emit(opts,'adam',msg); 
end

A = adam_minimize_hybrid(fun,x0,l,u,optsA);
xStart = A.x_best;

if opts.finish_maxIter <= 0
    out = struct();
    out.x = A.x_best;
    out.f = A.f_best;
    out.iter = A.iter;
    out.exitflag = A.exitflag;
    out.bestSource = "adam";
    out.phase1 = A;
    out.phase2 = [];
    out.trajX = A.trajX;
    out.trajF = A.trajF;
    out.trajPG = A.trajPG;
    out.x_best = A.x_best;
    out.f_best = A.f_best;
    return
end

% -----------------
% Phase 2: finisher
% -----------------
optsF = struct();
optsF.maxIter = opts.finish_maxIter;
optsF.tolPG = opts.tolPG_finish;
optsF.tolRelF = opts.tolRelF_finish;
optsF.b_eps = opts.b_eps;
optsF.verbose = opts.verbose;
if isfield(opts,'stopFcn') 
    optsF.stopFcn = opts.stopFcn; 
end
if isfield(opts,'iterFcn') 
    optsF.iterFcn = @(msg) hybrid_emit(opts,'finish',msg); 
end

switch lower(char(string(opts.finisher)))
    case 'lbfgsb'
        B = lbfgsb_minimize(fun,xStart,l,u,optsF);
    case 'pgd'
        B = pgd_minimize(fun,xStart,l,u,optsF);
    otherwise
        error(['      Error: hybrid_box_minimize: ' ...
            'Unknown finisher "%s".'], ...
            char(string(opts.finisher)));
end

out = struct();

if isfield(B,'f') ...
        && isfinite(B.f) ...
        && B.f <= A.f_best
    out.x = B.x;
    out.f = B.f;
    out.iter = A.iter + get_iter_safe(B);
    out.exitflag = 100 + get_exitflag_safe(B);
    out.bestSource = "finisher";
else
    out.x = A.x_best;
    out.f = A.f_best;
    out.iter = A.iter;
    out.exitflag = A.exitflag;
    out.bestSource = "adam";
end

[out.trajX,out.trajF,out.trajPG] = ...
    combine_hybrid_trajectories(A,B);
out.phase1 = A;
out.phase2 = B;
out.x_best = A.x_best;
out.f_best = A.f_best;
end


function out = adam_minimize_hybrid(fun,x0,l,u,opts)
if nargin < 5 
    opts = struct(); 
end
opts = set_default_opts_adam_hybrid(opts);

x = project_box(x0,l,u,opts.b_eps);
[f,~,g] = fun(x);

d = numel(x);
m = zeros(d,1);
v = zeros(d,1);

trajX = nan(d,opts.maxIter+1);
trajF = nan(1,opts.maxIter+1);
trajPG = nan(1,opts.maxIter+1);
trajA = nan(1,opts.maxIter+1);

pg = projgrad_norm(x,g,l,u,opts.b_eps);

trajX(:,1) = x;
trajF(1) = f;
trajPG(1) = pg;
trajA(1) = NaN;

x_best = x;
f_best = f;
g_best = g;

exitflag = 0;
stallCount = 0;

for k = 1:opts.maxIter

    drawnow limitrate;
    if isfield(opts,'stopFcn') ...
        && ~isempty(opts.stopFcn) ...
        && opts.stopFcn()
        exitflag = 9;
        break;
    end

    if pg < opts.tolPG
        exitflag = 1;
        break;
    end

    if k > 5 ...
            && abs(trajF(k)-trajF(max(1,k-4))) ...
            <= opts.tolRelF*max(1,abs(trajF(k)))
        exitflag = 2;
        break;
    end

    m = opts.beta1*m + (1-opts.beta1)*g;
    v = opts.beta2*v + (1-opts.beta2)*(g.^2);

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

    x_trial = project_box(x + a*p,l,u,opts.b_eps);
    [f_trial,~,g_trial] = fun(x_trial);

    drawnow limitrate;
    if isfield(opts,'stopFcn') ...
            && ~isempty(opts.stopFcn) ...
            && opts.stopFcn()
        exitflag = 9;
        break;
    end

    pg_trial = projgrad_norm(x_trial, ...
        g_trial,l,u,opts.b_eps);
    stepAcceptedNorm = norm(x_trial - x);

    x = x_trial;
    f = f_trial;
    g = g_trial;
    pg = pg_trial;

    if isfinite(f) && f < f_best
        x_best = x;
        f_best = f;
        g_best = g;
    end

    if k >= opts.minAdamIterBeforeSwitch ...
            && stepAcceptedNorm < opts.stallStep ...
            && pg > opts.stallPG
        stallCount = stallCount + 1;
    else
        stallCount = 0;
    end

    trajX(:,k+1) = x;
    trajF(k+1) = f;
    trajPG(k+1) = pg;
    trajA(k+1) = a;

    if isfield(opts,'iterFcn') ...
            && ~isempty(opts.iterFcn)
        opts.iterFcn(struct( ...
            'iter',k, ...
            'f',f, ...
            'pg',pg, ...
            'a',a, ...
            'stepNorm',norm(step), ...
            'acceptedStepNorm',stepAcceptedNorm));
    end

    if opts.verbose
        fprintf(['adam %4d  f=%.6e  ' ...
            '||pg||=%.3e  a=%.2e  ||dx||=%.3e\n'], ...
            k,f,pg,a,stepAcceptedNorm);
    end

    if stallCount >= opts.stallWindow
        exitflag = 11;
        break;
    end
end

iter = find(~isnan(trajF),1,'last') - 1;
if isempty(iter)
    iter = 0; 
end

out.x = x;
out.f = f;
out.g = g;
out.pg = pg;
out.x_best = x_best;
out.f_best = f_best;
out.g_best = g_best;
out.iter = iter;
out.exitflag = exitflag;
out.trajX = trajX(:,1:iter+1);
out.trajF = trajF(1:iter+1);
out.trajPG = trajPG(1:iter+1);
out.trajA = trajA(1:iter+1);
end


function hybrid_emit(opts,phase,msg)
if ~isfield(opts,'iterFcn') ...
        || isempty(opts.iterFcn)
    return
end
try
    if isstruct(msg)
        msg.phase = char(phase);
    end
    opts.iterFcn(msg);
catch
end
end


function opts = set_default_opts_hybrid(opts)
if ~isfield(opts,'b_eps')
    opts.b_eps = 1e-6; 
end
if ~isfield(opts,'tolPG')
    opts.tolPG = 1e-6; 
end
if ~isfield(opts,'tolRelF')
    opts.tolRelF = 1e-6; 
end
if ~isfield(opts,'tolPG_finish')
    opts.tolPG_finish = 1e-7; 
end
if ~isfield(opts,'tolRelF_finish')
    opts.tolRelF_finish = 1e-7; 
end
if ~isfield(opts,'verbose')
    opts.verbose = 0; 
end

if ~isfield(opts,'adam_maxIter')
    opts.adam_maxIter = 30; 
end
if ~isfield(opts,'adam_alpha')
    opts.adam_alpha = 0.005; 
end
if ~isfield(opts,'adam_beta1')
    opts.adam_beta1 = 0.9; 
end
if ~isfield(opts,'adam_beta2')
    opts.adam_beta2 = 0.999; 
end
if ~isfield(opts,'adam_eps')
    opts.adam_eps = 1e-8; 
end

if ~isfield(opts,'stallPG')
    opts.stallPG = 1e-2; 
end
if ~isfield(opts,'stallStep')
    opts.stallStep = 1e-8; 
end
if ~isfield(opts,'stallWindow')
    opts.stallWindow = 3; 
end
if ~isfield(opts,'minAdamIterBeforeSwitch')
    opts.minAdamIterBeforeSwitch = 8; 
end

if ~isfield(opts,'finisher')
    opts.finisher = 'lbfgsb'; 
end
if ~isfield(opts,'finish_maxIter')
    opts.finish_maxIter = 100; 
end
end


function opts = set_default_opts_adam_hybrid(opts)
if ~isfield(opts,'maxIter')
    opts.maxIter = 30; 
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
    opts.alpha = 0.005; 
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
if ~isfield(opts,'stallPG')
    opts.stallPG = 1e-2; 
end
if ~isfield(opts,'stallStep')
    opts.stallStep = 1e-8; 
end
if ~isfield(opts,'stallWindow')
    opts.stallWindow = 3; 
end
if ~isfield(opts,'minAdamIterBeforeSwitch')
    opts.minAdamIterBeforeSwitch = 8; 
end
end


function it = get_iter_safe(out)
if isstruct(out) ...
        && isfield(out,'iter') ...
        && ~isempty(out.iter)
    it = out.iter;
else
    it = NaN;
end
end


function ef = get_exitflag_safe(out)
if isstruct(out) ...
        && isfield(out,'exitflag') ...
        && ~isempty(out.exitflag)
    ef = out.exitflag;
else
    ef = NaN;
end
end


function [trajX,trajF,trajPG] = ...
    combine_hybrid_trajectories(A,B)
trajX = A.trajX;
trajF = A.trajF;
trajPG = A.trajPG;

if isempty(B) || ~isstruct(B)
    return
end

if ~isfield(B,'trajX') ...
        || isempty(B.trajX) ...
        || ~isfield(B,'trajF') ...
        || isempty(B.trajF)
    return
end

XB = B.trajX;
FB = B.trajF;

if size(XB,2) >= 2
    XB = XB(:,2:end);
    FB = FB(2:end);
    if isfield(B,'trajPG') ...
            && ~isempty(B.trajPG)
        PGB = B.trajPG(2:end);
    else
        PGB = nan(1,numel(FB));
    end
else
    XB = [];
    FB = [];
    PGB = [];
end

trajX = [trajX, XB];
trajF = [trajF, FB];
trajPG = [trajPG, PGB];
end
