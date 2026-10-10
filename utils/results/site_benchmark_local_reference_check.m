function [payload,report]=site_benchmark_local_reference_check(payload,snapshot,snapshotHash,contextLoader,logFcn)
% Reproduce each stored objective's incumbent fit on the user's local data.
% This is a cooperative consistency check, not independent score verification.
report=struct('passed',0,'failed',0,'unseeded',0);
ids=unique(string({payload.records.basin}));proof=struct('basin',{},'metric',{},'train',{},'evaluation',{});
accepted=strings(0,1);metrics=string(payload.contract.metrics);
if isempty(snapshot)
    report.unseeded=numel(ids);payload.records=payload.records([]);return
end
assert(site_benchmark_profile_equal(snapshot.contract,payload.contract),'SITE:ReferenceContract','Reference settings differ.');
for b=1:numel(ids)
    if b==1||mod(b,10)==0,logFcn(sprintf('Shared benchmarks: checking reference basin %d of %d.',b,numel(ids)));end
    id=ids(b);refs=snapshot.records(string({snapshot.records.basin})==id);
    if numel(refs)~=numel(metrics)||~isequal(sort(string({refs.metric})),sort(metrics(:).'))
        report.unseeded=report.unseeded+1;continue
    end
    try
        ctx=contextLoader(char(id));assert(strcmp(ctx.configuration.identity,payload.contract.configuration));
        cache=containers.Map('KeyType','char','ValueType','any');rows=proof;ok=true;
        for j=1:numel(refs)
            r=refs(j);lo=payload.contract.thMin(:);hi=payload.contract.thMax(:);
            if isfield(r,'parameterRange'),lo=r.parameterRange.thMin(:);hi=r.parameterRange.thMax(:);end
            theta=r.theta(:);assert(all(isfinite(theta)&theta>=lo&theta<=hi));
            key=sprintf('%.17g,',theta);
            if isKey(cache,key),values=cache(key);else
                mdl=ctx.mdl;mdl.th_min=lo;mdl.th_max=hi;mdl.pspace=1;
                request=crr_request(struct('metrics',true));x=(theta-lo)./(hi-lo);
                if strcmp(ctx.backend,'cpp'),[~,out]=crr_model_cpp(x,mdl,ctx.dat,ctx.ode,ctx.loss,request);
                else,[~,out]=crr_model(x,mdl,ctx.dat,ctx.ode,ctx.loss,request);end
                values=out.metrics;cache(key)=values;
            end
            [t,e]=metric(values,ctx.loss,r.metric);
            if ~sameScore(t,r.train)||~sameScore(e,r.evaluation),ok=false;break,end
            rows(end+1)=struct('basin',char(id),'metric',r.metric,'train',t,'evaluation',e); %#ok<AGROW>
        end
        if ok,accepted(end+1)=id;proof=rows;report.passed=report.passed+1;
        else,report.failed=report.failed+1;logFcn(sprintf('Shared benchmarks: reference scores differ for basin %s; its results remain local.',id));end
    catch
        report.failed=report.failed+1;logFcn(sprintf('Shared benchmarks: reference check failed for basin %s; its results remain local.',id));
    end
    drawnow limitrate nocallbacks
end
payload.records=payload.records(ismember(string({payload.records.basin}),accepted));
payload.localReferenceCheck=struct('schema',1,'mode','local_reference', ...
    'snapshotSha256',snapshotHash,'records',proof);
end

function yes=sameScore(actual,claimed)
if isempty(claimed),claimed=NaN;end
yes=(isnan(actual)&&isnan(claimed))||(isfinite(actual)&&isfinite(claimed)&&abs(actual-claimed)<=1e-8+1e-6*abs(claimed));
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
 otherwise,error('SITE:ReferenceMetric','Unknown metric.');
end
end
function s=skill(d,ref)
if ~isfinite(ref)||ref<=0,s=NaN;else,s=1-d/ref;end
end
