function result = calibrate_basin_SITE(mdl,dat,ode,loss,alg,misc,Phi)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CALIBRATE_BASIN_SITE Calibrate one model independently for one basin.
%
% SYNOPSIS:
%   result = calibrate_basin_SITE(mdl,dat,ode,loss,alg,misc,Phi)
%
% INPUT ARGUMENTS:
%   mdl             model structure and parameter bounds
%   dat             forcing and discharge data for one basin
%   ode             numerical solver settings
%   loss            objective and diagnostic settings
%   alg             calibration algorithm and trial settings
%   misc            backend and meteorological settings
%   Phi             optional normalized starting points, one per trial
%
% OUTPUT ARGUMENTS:
%   result          best fit, all trial outcomes, and diagnostic scores
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    d = numel(mdl.th_min);
    if nargin < 7 ...
            || isempty(Phi)
        Phi = local_latin_hypercube(d,alg.n);
    end
    if size(Phi,1) ~= d ...
            || size(Phi,2) ~= alg.n
        error('SITE:BadStartingPoints', ...
            'Phi must have size %d-by-%d.',d,alg.n);
    end
    
    mdl.pspace = 1;
    lowerBound = zeros(d,1);
    upperBound = ones(d,1);
    opts = optimizer_options_SITE(alg,0);
    
    request = crr_request(struct( ...
        'gradient',true,'jacobian',false));
    requestJ = crr_request(struct( ...
        'gradient',true,'jacobian',true));
    
    fun = @(x) local_objective(x,false,mdl,dat,ode, ...
        loss,misc.crr_backend,request,requestJ);
    funJ = @(x) local_objective(x,true,mdl,dat,ode, ...
        loss,misc.crr_backend,request,requestJ);
    
    bestF = inf;
    bestX = nan(d,1);
    trials = repmat(struct('f',NaN,'x',nan(d,1), ...
        'runtime',NaN,'iterations',NaN,'exitflag',NaN),alg.n,1);
    
    for trial = 1:alg.n
        timer = tic;
        switch alg.method
            case 1
                out = pgd_minimize(fun,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 2
                out = gaussnewton_minimize(funJ,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 3
                out = lm_minimize(funJ,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 4
                out = adam_minimize(fun,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 5
                out = lbfgsb_minimize(fun,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 6
                out = pcg_minimize(fun,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
            case 7
                out = hybrid_box_minimize(fun,Phi(:,trial), ...
                    lowerBound,upperBound,opts);
        end
        trials(trial).runtime = toc(timer);
        trials(trial).iterations = out.iter;
        trials(trial).exitflag = out.exitflag;
    
        [trialF,index] = min(out.trajF,[],'omitnan');
        if isempty(index) ...
                || ~isfinite(trialF)
            continue
        end
        trialX = out.trajX(:,index);
        trials(trial).f = trialF;
        trials(trial).x = trialX;
        if trialF < bestF
            bestF = trialF;
            bestX = trialX;
        end
    end
    
    if ~isfinite(bestF)
        error('SITE:CalibrationFailed', ...
            'Every optimizer trial returned a nonfinite objective.');
    end
    
    % Use a JKGE request for diagnostics so one additional model run returns
    % JKGE together with all six standard metrics and the FDC divergence.
    diagnosticLoss = loss;
    diagnosticLoss.fnc = 7;
    metricRequest = crr_request(struct('metrics',true));
    [~,metricOut] = local_run_crr(bestX,mdl,dat,ode, ...
        diagnosticLoss,misc.crr_backend,metricRequest);
    
    result = struct();
    result.x = bestX;
    result.theta = mdl.th_min(:) + bestX .* ...
        (mdl.th_max(:)-mdl.th_min(:));
    result.objective = bestF;
    result.metrics = metricOut.metrics;
    result.runtime = sum([trials.runtime],'omitnan');
    result.trials = trials;
end

function Phi = local_latin_hypercube(d,n)
% Draw one starting point from each stratum of every parameter.
% Keep the established interior range in normalized parameter space.
    Phi = zeros(d,n);
    for j = 1:d
        strata = randperm(n);
        Phi(j,:) = 0.1 + 0.8*(strata - 1 + rand(1,n))/n;
    end
end

function [f,residual,g,J] = local_objective(x,needJ,mdl,dat,ode, ...
    loss,backend,request,requestJ)
    if needJ
        req = requestJ;
    else
        req = request;
    end
    [f,out] = local_run_crr(x,mdl,dat,ode,loss,backend,req);
    residual = [];
    g = out.gradient;
    if needJ
        J = out.jacobian;
    else
        J = [];
    end
end

function [f,out] = local_run_crr(x,mdl,dat,ode,loss,backend,request)
    switch lower(char(backend))
        case 'cpp'
            [f,out] = crr_model_cpp(x,mdl,dat,ode,loss,request);
        case 'matlab'
            [f,out] = crr_model(x,mdl,dat,ode,loss,request);
        otherwise
            error('SITE:UnknownBackend', ...
                'Unknown CRR backend "%s".',backend);
    end
end
