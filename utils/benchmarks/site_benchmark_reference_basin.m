function result=site_benchmark_reference_basin(ctx,refs,contract,candidates,expectedHash)
if nargin<4,candidates=refs([]);end
if nargin<5,expectedHash='';end
% Check one basin; workers return numerical evidence, never write files.
rows=struct('basin',{},'metric',{},'train',{},'evaluation',{});
result=struct('state','failed','rows',rows,'identifier','','candidateRows',rows,'fingerprint','');
try
    assert(strcmp(ctx.configuration.identity,contract.configuration));
    if isfield(ctx.mdl,'user_model_folder'),addpath(ctx.mdl.user_model_folder,'-begin');end
    result.fingerprint=site_benchmark_input_fingerprint(ctx);
    if ~isempty(expectedHash)&&~strcmp(result.fingerprint,expectedHash),result.identifier='SITE:InputChecksumMismatch';return,end
    cache=containers.Map('KeyType','char','ValueType','any');
    for j=1:numel(refs)+numel(candidates)
        if j<=numel(refs),r=refs(j);else,r=candidates(j-numel(refs));end
        lo=contract.thMin(:);hi=contract.thMax(:);
        if isfield(r,'parameterRange'),lo=r.parameterRange.thMin(:);hi=r.parameterRange.thMax(:);end
        theta=r.theta(:);assert(numel(theta)==numel(lo)&&all(isfinite(theta)&theta>=lo&theta<=hi));
        key=sprintf('%.17g,',theta);
        if isKey(cache,key),values=cache(key);else
            mdl=ctx.mdl;mdl.th_min=lo;mdl.th_max=hi;mdl.pspace=1;
            request=crr_request(struct('metrics',true));x=(theta-lo)./(hi-lo);
            if strcmp(ctx.backend,'cpp'),[~,out]=crr_model_cpp(x,mdl,ctx.dat,ctx.ode,ctx.loss,request);
            else,[~,out]=crr_model(x,mdl,ctx.dat,ctx.ode,ctx.loss,request);end
            values=out.metrics;cache(key)=values;
        end
        [t,e]=metric(values,ctx.loss,r.metric);
        if ~sameScore(t,r.train)||~sameScore(e,r.evaluation)
            if j>numel(refs),result.identifier='SITE:CandidateScoreMismatch';end
            return
        end
        evidence=struct('basin',char(string(r.basin)),'metric',r.metric,'train',t,'evaluation',e);
        if j<=numel(refs),rows(end+1)=evidence;else,result.candidateRows(end+1)=evidence;end %#ok<AGROW>
    end
    result.state='passed';result.rows=rows;
catch ME
    result.identifier=ME.identifier;
end
end
function yes=sameScore(actual,claimed)
if isempty(actual),actual=NaN;end
if isempty(claimed),claimed=NaN;end
yes=(isnan(actual)&&isnan(claimed))||(isfinite(actual)&&isfinite(claimed)&&abs(actual-claimed)<=1e-8+1e-5*abs(claimed));
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
if isempty(t),t=NaN;end
if isempty(e),e=NaN;end
end
function s=skill(d,ref)
if isempty(d)||isempty(ref)||~isfinite(ref)||ref<=0,s=NaN;else,s=1-d/ref;end
end
