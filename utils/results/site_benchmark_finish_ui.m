function status = site_benchmark_finish_ui(fig,output,C,logFcn)
rawLogFcn=logFcn; logFcn=@(message)site_benchmark_log_ui(rawLogFcn,message);
%SITE_BENCHMARK_FINISH_UI Prepare one recoverable end-of-run contribution.
% Called exclusively by SITE_ui, after run_SITE has returned and saved.
% No token is embedded and no remote files are modified by this helper.
% Source MATLAB GUIs are not eligible; only deployed distributions enter
% this path. This client guard is not a substitute for server validation.
status=struct('state','skipped','file','','message','');
if ~isdeployed
    status.message=['Shared benchmarks: contributions are available only ' ...
        'from the compiled SITE application. Source runs remain local.'];
    logFcn(status.message); return
end
assert(isscalar(fig) && isgraphics(fig,'figure'),'SITE:BenchmarkGUIRequired', ...
    'Benchmark synchronization requires the SITE GUI.');
if ~isfield(output,'store') || isempty(output.store), return, end
s=output.store;
if isfield(output,'referenceInputs')
    setappdata(fig,'SITEBenchmarkReferenceInputs',output.referenceInputs);
    referenceCleanup=onCleanup(@()clearReferenceInputs(fig)); %#ok<NASGU>
end
if ~isfield(s,'configuration') || s.configuration.changed
    status.message='Shared benchmarks: nondefault model configuration remains local.';
    logFcn(status.message); return
end
% Exact values are checked against a centrally approved profile before any
% publication. Period IDs and filenames alone never establish eligibility.
contract=site_benchmark_contract(s,C);
% Region-independent eligibility: only centrally enabled exact contracts
% participate. Unknown regions/default profiles remain local until their
% official input data and numerical verification path are registered.
try
    manifest=webread( ...
        'https://raw.githubusercontent.com/jaspervrugt/SITEhydrology/main/benchmarks/profiles.json', ...
        weboptions('ContentType','json','Timeout',30));
    approved=false;
    for k=1:numel(manifest.profiles)
        profile=manifest.profiles(k);
        if profile.enabled && site_benchmark_profile_equal(profile.contract,contract)
            approved=true;break
        end
    end
    if ~approved
        status.message='Shared benchmarks: no enabled default profile matches this experiment; results remain local.';
        logFcn(status.message);return
    end
catch
    % An offline completion must preserve a recoverable contribution.
    logFcn('Shared benchmarks: profile lookup unavailable; saving locally for later eligibility checking.');
end
% Algorithm, trials and optimizer settings deliberately do not enter the
% experiment identity. The server will normalize loss selection separately
% from loss-definition settings when approving profiles.
[~,report]=site_benchmark_merge([],s);
if report.improvements==0
    status.message='Shared benchmarks: no completed finite fits to submit.';
    logFcn(status.message); return
end
queue=fullfile(s.resultDir,'shared-benchmark-pending');
if ~isfolder(queue),mkdir(queue);end
% One pending snapshot per existing local result file, preventing an ever
% growing queue on repeated runs. Original checkpoints are never modified.
[~,name]=fileparts(s.fileMat);
destination=fullfile(queue,[name '_submission.mat']);
submission=struct('schema',1,'contract',contract,'store',s, ...
    'created',datetime('now','TimeZone','UTC'),'origin','SITE_ui');
submission.runConfig=C;if isfield(submission.runConfig,'ui'),submission.runConfig=rmfield(submission.runConfig,'ui');end
% Build outside synchronized folders to avoid Dropbox locking the MAT file.
temp=[tempname '.mat'];
cleanup=onCleanup(@()deleteTemp(temp));
save(temp,'submission','-v7.3');
movefile(temp,destination,'f');
clear cleanup
status.state='pending'; status.file=destination;
status.message=sprintf(['Shared benchmarks: %d completed metric fits prepared. ' ...
    'A pending contribution is saved locally.'],report.improvements);
logFcn(status.message);
remote=site_benchmark_github_ui(fig,destination,logFcn);
if strcmp(remote.state,'submitted'),status.state='submitted';end
site_benchmark_retry_ui(fig,queue,logFcn);
end

function deleteTemp(path)
if isfile(path),delete(path);end
end

function clearReferenceInputs(fig)
if isgraphics(fig)&&isappdata(fig,'SITEBenchmarkReferenceInputs'),rmappdata(fig,'SITEBenchmarkReferenceInputs');end
end
