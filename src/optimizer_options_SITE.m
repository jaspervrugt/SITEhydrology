function opts = optimizer_options_SITE(alg,verbose)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%OPTIMIZER_OPTIONS_SITE Defaults shared by the seven SITE optimizers.
%
% SYNOPSIS:
%   opts = optimizer_options_SITE(alg,verbose)
%
% INPUT ARGUMENTS:
%   alg             selected algorithm, iteration limit, and overrides
%   verbose         optional iteration-printing flag
%
% OUTPUT ARGUMENTS:
%   opts            optimizer-specific settings with common defaults
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 2
    verbose = 0;
end

opts = struct('maxIter',alg.i_max, ...
    'tolPG',1e-6,'tolRelF',1e-6, ...
    'b_eps',1e-6,'verbose',verbose, ...
    'stopFcn',@() false,'iterFcn',[]);

lineSearch = struct('c1',1e-4,'ls_rho',0.5, ...
    'ls_max',40,'alpha0',1);
jacobian = struct('ridge',1e-10);

switch alg.method
    case 1
        opts = local_merge(opts,lineSearch);
    case 2
        opts = local_merge(opts,lineSearch);
        opts = local_merge(opts,jacobian);
    case 3
        opts = local_merge(opts,jacobian);
        opts = local_merge(opts,struct( ...
            'lambda0',1e-3,'lambdaMin',1e-12, ...
            'lambdaMax',1e12,'nu',2));
    case 4
        opts = local_merge(opts,struct( ...
            'alpha',0.02,'beta1',0.9, ...
            'beta2',0.999,'eps',1e-8));
    case 5
        opts = local_merge(opts,lineSearch);
        opts.m = 5;
    case 6
        opts = local_merge(opts,lineSearch);
    case 7
        opts = local_merge(opts,struct( ...
            'adam_maxIter',25,'adam_alpha',0.005, ...
            'adam_beta1',0.9,'adam_beta2',0.999, ...
            'adam_eps',1e-8,'finish_maxIter',100, ...
            'tolPG_finish',1e-7,'tolRelF_finish',1e-7, ...
            'stallPG',1e-2,'stallStep',1e-8, ...
            'stallWindow',3,'minAdamIterBeforeSwitch',8, ...
            'finisher','lbfgsb'));
    otherwise
        error('SITE:UnknownOptimizer', ...
            'Unknown optimizer number %d.',alg.method);
end

if isfield(alg,'options') && isstruct(alg.options)
    opts = local_merge(opts,alg.options);
end

% The hybrid optimizer has two phase limits rather than a single maxIter
% loop. Keep their combined budget within the Training-tab limit.
if alg.method == 7
    opts.adam_maxIter = min(opts.adam_maxIter,alg.i_max);
    opts.finish_maxIter = min(opts.finish_maxIter, ...
        max(0,alg.i_max-opts.adam_maxIter));
end
end

function a = local_merge(a,b)
names = fieldnames(b);
for i = 1:numel(names)
    a.(names{i}) = b.(names{i});
end
end
