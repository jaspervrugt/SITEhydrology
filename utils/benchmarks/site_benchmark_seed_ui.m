function store=site_benchmark_seed_ui(fig,store,C,logFcn,inputs)
if nargin<5,inputs=[];end
rawLogFcn=logFcn; logFcn=@(message)site_benchmark_log_ui(rawLogFcn,message);
%SITE_BENCHMARK_SEED_UI Download verified defaults before GUI training.
% Network/compatibility failures leave existing local results untouched.
if ~isdeployed || ~isscalar(fig) || ~isgraphics(fig,'figure'),return,end
if isappdata(fig,'SITEBenchmarkPreflightBlocked'),rmappdata(fig,'SITEBenchmarkPreflightBlocked');end
if ~isfield(store,'configuration') || store.configuration.changed,return,end
configFile=fullfile(fileparts(mfilename('fullpath')),'site_benchmark_github.json');
cfg=jsondecode(fileread(configFile));
if ~cfg.enabled,return,end
try
    contract=jsondecode(jsonencode(site_benchmark_contract(store,C)));
    raw='https://raw.githubusercontent.com/jaspervrugt/SITEhydrology/main/benchmarks/';
    options=weboptions('ContentType','json','Timeout',30);
    manifest=webread([raw 'profiles.json'],options);
    profile='';
    for k=1:numel(manifest.profiles)
        p=manifest.profiles(k);
        if p.enabled && site_benchmark_profile_equal(p.contract,contract)
            profile=p.id;break
        end
    end
    if isempty(profile),return,end
    % Default profiles always fetch the current shared reference.
    setappdata(fig,'SITEBenchmarkRetryApproved',true);
    logFcn('Shared benchmarks: downloading latest default results from GitHub. Better local fits are retained.');
    [snapshot,snapshotHash]=site_benchmark_fetch_snapshot(profile);
    if isempty(snapshot)
        logFcn('Shared benchmarks: no shared reference yet; continuing with local results.');return
    end
    snapshot=site_benchmark_attach_input_checksums(snapshot,p);
    assert(site_benchmark_profile_equal(snapshot.contract,contract), ...
        'SITE:BenchmarkMismatch','Snapshot experiment differs.');
    [merged,report]=site_benchmark_apply_snapshot(store,snapshot);
    if report.improvements>0 || (isfield(report,'metadataUpdates')&&report.metadataUpdates>0)
        % The approved profile has exactly the current bounds, so a foreign
        % registry number can safely map to the local registered range.
        merged.rangeID(isnan(merged.rangeID) & isfinite(merged.train))=store.currentRangeID;
        site_result_store('save',merged);
        store=merged;
    end
    logFcn(sprintf('Shared benchmarks: downloaded latest verified results; %d entries improved using downloaded GitHub results.', ...
        report.improvements));
    site_benchmark_preflight_ui(fig,store,C,snapshot,snapshotHash,inputs,logFcn);
catch
    logFcn('Shared benchmarks: download unavailable or incompatible; continuing with local results.');
end
end
