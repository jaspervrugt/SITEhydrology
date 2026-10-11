function covered=site_benchmark_submission_covered(payload,snapshot,approved)
% Published results must cover every saved fit before its submission is removed.
covered=false;
if isempty(snapshot)||~isfield(snapshot,'records')||isempty(snapshot.records)||isempty(payload.records),return,end
if ~site_benchmark_profile_equal(payload.contract,approved.contract)||~site_benchmark_profile_equal(snapshot.contract,approved.contract),return,end
if ~strcmp(snapshot.profile,approved.id),return,end
for k=1:numel(payload.records)
 r=payload.records(k);
 if ~isfinite(r.train)||~any(string(approved.basinIds)==string(r.basin)),return,end
 j=find(string(approved.contract.metrics)==string(r.metric));
 hit=find(string({snapshot.records.basin})==string(r.basin)&string({snapshot.records.metric})==string(r.metric));
 if ~isscalar(j)||~isscalar(hit)||~isfinite(snapshot.records(hit).train),return,end
 value=snapshot.records(hit).train;
 if (approved.contract.maximize(j)&&value<r.train)||(~approved.contract.maximize(j)&&value>r.train),return,end
end
covered=true;
end
