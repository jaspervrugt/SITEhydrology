function report=site_benchmark_verify(payload,contextLoader,profile)
%SITE_BENCHMARK_VERIFY Independently rerun proposed parameter vectors.
% Call only on the trusted worker with its own code, data and profile.
% contextLoader takes an approved basin ID; it must not use submitted paths,
% functions, model code, loss settings, or solver settings.
assert(isequaln(payload.contract,profile.contract), ...
    'SITE:VerificationContract','Submitted experiment is not approved.');
assert(strcmp(payload.profile,profile.id),'SITE:VerificationContract', ...
    'Submitted profile ID differs.');
records=payload.records;
report=struct('schema',1,'profile',profile.id,'scores_verified',false, ...
    'records',numel(records),'checked',0,'mismatches',strings(0,1), ...
    'verified_records',records);
basins=unique(string({records.basin}));
for b=1:numel(basins)
    id=basins(b);
    assert(any(string(profile.basinIds)==id),'SITE:VerificationBasin', ...
        'Unknown basin.');
    ctx=contextLoader(char(id));
    assert(string(ctx.basin)==id,'SITE:VerificationBasin','Context basin differs.');
    assert(isequal(ctx.mdl.th_min(:),double(profile.contract.thMin(:))) ...
        && isequal(ctx.mdl.th_max(:),double(profile.contract.thMax(:))) ...
        && strcmp(ctx.configuration.identity,profile.contract.configuration), ...
        'SITE:VerificationContext','Worker model configuration differs from approved profile.');
    rows=find(string({records.basin})==id);
    evaluated=containers.Map('KeyType','char','ValueType','any');
    for k=rows
        r=records(k);
        theta=double(r.theta(:));
        lo=ctx.mdl.th_min(:); hi=ctx.mdl.th_max(:);
        assert(numel(theta)==numel(lo) && all(isfinite(theta)) ...
            && all(theta>=lo & theta<=hi), ...
            'SITE:VerificationParameters','Invalid parameter vector.');
        x=(theta-lo)./(hi-lo);
        assert(numel(r.normalized)==numel(x) && ...
            all(abs(x-double(r.normalized(:)))<1e-9), ...
            'SITE:VerificationParameters','Normalized/physical parameters differ.');
        key=sprintf('%.17g,',theta);
        if isKey(evaluated,key)
            metrics=evaluated(key);
        else
            request=crr_request(struct('metrics',true));
            if strcmp(ctx.backend,'cpp')
                [~,out]=crr_model_cpp(x,ctx.mdl,ctx.dat,ctx.ode,ctx.loss,request);
            else
                [~,out]=crr_model(x,ctx.mdl,ctx.dat,ctx.ode,ctx.loss,request);
            end
            metrics=out.metrics;evaluated(key)=metrics;
        end
        [training,evaluation]=metric(metrics,ctx.loss,r.metric);
        % Publication uses these independently computed values, never the
        % client's rounded claim, even when it falls within the tolerance.
        report.verified_records(k).train=training;
        report.verified_records(k).evaluation=evaluation;
        report.checked=report.checked+1;
        % Numerical tolerances allow roundoff, not optimization-scale gains.
        if ~sameScore(training,r.train) || ~sameScore(evaluation,r.evaluation)
            report.mismatches(end+1)=id+"/"+string(r.metric);
        end
    end
    fprintf('Checked basin %d/%d: %s\n',b,numel(basins),char(id));
end
report.scores_verified=isempty(report.mismatches) && report.checked>0;
end

function yes=sameScore(actual,claimed)
% JSON null represents absent evaluation data; it must also be absent in
% the recomputed metric. Missing training data never validates.
if isempty(claimed),claimed=NaN;end
yes=(isnan(actual) && isnan(claimed)) || ...
    (isfinite(actual) && isfinite(claimed) ...
    && abs(actual-claimed)<=1e-8+1e-6*abs(actual));
end

function [t,e]=metric(m,loss,name)
switch char(name)
    case 'NSE',t=m.NSEt;e=m.NSEe;
    case 'KGE',t=m.KGEt;e=m.KGEe;
    case 'SAR',t=m.SARt;e=m.SARe;
    case 'RSS',t=m.RSSt;e=m.RSSe;
    case 'Huber',t=m.Hubert;e=m.Hubere;
    case 'JKGE',t=m.JKGEt;e=m.JKGEe;
    case 'S_fdc',t=skill(m.Dfdct,loss.fdc.Q.D0t);e=skill(m.Dfdce,loss.fdc.Q.D0e);
    case 'S_p',t=skill(m.Dpt,loss.fdc.Q.D0pt);e=skill(m.Dpe,loss.fdc.Q.D0pe);
    case 'S_logp',t=skill(m.Dlogpt,loss.fdc.Q.D0logpt);e=skill(m.Dlogpe,loss.fdc.Q.D0logpe);
    otherwise,error('SITE:VerificationMetric','Unapproved metric.');
end
end
function s=skill(d,ref)
if ~isfinite(ref) || ref<=0,s=NaN;else,s=1-d/ref;end
end
