function pool=site_benchmark_reference_pool(C,logFcn)
% Share the calibration pool; never replace or delete an existing pool.
pool=[];
if ~isfield(C,'parallel')||~C.parallel,return,end
try
    pool=gcp('nocreate');
    if isempty(pool)
        logFcn('Shared benchmarks: opening workers for reference checks and training.');
        if isfield(C,'numWorkers')&&~isempty(C.numWorkers),pool=parpool('local',C.numWorkers);
        else,pool=parpool('local');end
    end
catch
    logFcn('Shared benchmarks: workers unavailable; reference checks will run sequentially.');
end
end
