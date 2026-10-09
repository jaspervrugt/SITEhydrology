function store=site_benchmark_seed_ui(fig,store,C,logFcn)
%SITE_BENCHMARK_SEED_UI Download verified defaults before GUI training.
% Network/compatibility failures leave existing local results untouched.
if ~isdeployed || ~isscalar(fig) || ~isgraphics(fig,'figure'),return,end
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
        if p.enabled && isequaln(orderfields(p.contract),orderfields(contract))
            profile=p.id;break
        end
    end
    if isempty(profile),return,end
    snapshot=site_benchmark_fetch_snapshot(profile);
    if isempty(snapshot),return,end
    assert(isequaln(orderfields(snapshot.contract),orderfields(contract)), ...
        'SITE:BenchmarkMismatch','Snapshot experiment differs.');
    [merged,report]=site_benchmark_apply_snapshot(store,snapshot);
    if report.improvements>0
        % The approved profile has exactly the current bounds, so a foreign
        % registry number can safely map to the local registered range.
        merged.rangeID(isnan(merged.rangeID) & isfinite(merged.train))=store.currentRangeID;
        site_result_store('save',merged);
        store=merged;
    end
    logFcn(sprintf('Shared benchmarks: downloaded latest verified results; %d local improvements.', ...
        report.improvements));
catch
    logFcn('Shared benchmarks: download unavailable or incompatible; continuing with local results.');
end
end
