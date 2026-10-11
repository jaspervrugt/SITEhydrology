function site_benchmark_preflight_ui(fig,store,C,snapshot,snapshotHash,inputs,logFcn)
% An early sample gives feedback; final improved-basin checks remain required.
if isempty(inputs),return,end
try
    ids=site_benchmark_reference_sample(snapshot,store.ids,3);
    if isempty(ids),logFcn('Shared benchmarks: no complete reference basin available for the preliminary check.');return,end
    logFcn(sprintf('Shared benchmarks: preliminary reference check for %d basins.',numel(ids)));
    payload=struct('contract',snapshot.contract,'records',snapshot.records(ismember(string({snapshot.records.basin}),ids)));
    loader=site_benchmark_local_context(C,ids,inputs);pool=site_benchmark_reference_pool(C,logFcn);
    [~,report]=site_benchmark_local_reference_check(payload,snapshot,snapshotHash,loader,logFcn,pool);
    if report.failed>0
        setappdata(fig,'SITEBenchmarkPreflightBlocked',true);
        logFcn('Shared benchmarks: preliminary reference mismatch. Training will continue; this run remains local.');
    else
        logFcn('Shared benchmarks: preliminary reference check passed. Improved basins will be checked against the latest reference at the end.');
    end
catch ME
    logFcn(sprintf('Shared benchmarks: preliminary check unavailable (%s); final reference checks are still required.',ME.identifier));
end
end
