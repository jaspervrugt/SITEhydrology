function payload=site_benchmark_filter_records(payload,snapshot,approved)
% Upload only potential improvements; the server still recomputes scores.
keep=false(size(payload.records));
if ~isempty(snapshot)
    assert(site_benchmark_profile_equal(snapshot.contract,payload.contract), ...
        'SITE:BenchmarkMismatch','Existing benchmark experiment differs.');
end
for k=1:numel(payload.records)
    r=payload.records(k);
    if ~any(string(approved.basinIds)==string(r.basin)),continue,end
    j=find(string(approved.contract.metrics)==string(r.metric),1);
    assert(~isempty(j),'SITE:BenchmarkMetric','Unknown metric.');
    incumbent=[];
    if ~isempty(snapshot) && ~isempty(snapshot.records)
        hit=find(string({snapshot.records.basin})==string(r.basin) & ...
            string({snapshot.records.metric})==string(r.metric),1);
        if ~isempty(hit),incumbent=snapshot.records(hit).train;end
    end
    keep(k)=isempty(incumbent) || ...
        (approved.contract.maximize(j) && r.train>incumbent) || ...
        (~approved.contract.maximize(j) && r.train<incumbent);
end
payload.records=payload.records(keep);
end
