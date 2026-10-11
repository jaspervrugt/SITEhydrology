function result=site_benchmark_github_ui(fig,pendingFile,logFcn,automatic)
rawLogFcn=logFcn; logFcn=@(message)site_benchmark_log_ui(rawLogFcn,message);
if nargin<4,automatic=false;end
%SITE_BENCHMARK_GITHUB_UI Submit a proposed update, never write benchmarks.
% Only deployed GUI calls are eligible. The origin label is informational;
% Publication validates approved profiles and local reference evidence.
result=struct('state','pending','url','');
if ~isdeployed || ~isscalar(fig) || ~isgraphics(fig,'figure'),return,end
configFile=fullfile(fileparts(mfilename('fullpath')),'site_benchmark_github.json');
if ~isfile(configFile),return,end
cfg=jsondecode(fileread(configFile));
if ~cfg.enabled || isempty(cfg.clientId)
    logFcn('Shared benchmarks: GitHub submission is not yet enabled.');return
end
assert(strcmp(cfg.owner,'jaspervrugt') && strcmp(cfg.repository,'SITEhydrology'), ...
    'SITE:BenchmarkRepository','Unexpected benchmark repository.');
if automatic
    if ~isappdata(fig,'SITEBenchmarkRetryApproved'),return,end
    token=site_benchmark_login_ui(fig,cfg.clientId,true);
    if isempty(token),return,end
else
    % Default-setting contributions are automatic; the pre-run dialog
    % explains this independently of the optional benchmark download.
    logFcn('Shared benchmarks: automatically submitting completed default-setting fits for verification; verified improvements can update GitHub.');
    setappdata(fig,'SITEBenchmarkRetryApproved',true);
    % Queue only after the local reference check succeeds.
end
stage='reading local pending results';
try
    loaded=load(pendingFile,'submission');
    if isfield(loaded.submission,'localCheckedPayload'),loaded.submission=rmfield(loaded.submission,'localCheckedPayload');end
    if isfield(loaded.submission,'initialEnvelope'),loaded.submission=rmfield(loaded.submission,'initialEnvelope');end
    payload=site_benchmark_payload(loaded.submission);
    % Download the trusted approved manifest before authenticating. Empty
    % manifests and unapproved profiles cannot request any upload.
    root=sprintf('https://api.github.com/repos/%s/%s',cfg.owner,cfg.repository);
    stage='checking approved GitHub profiles';
    manifest=api('get',[root '/contents/benchmarks/profiles.json'],'',[],true);
    manifest=jsondecode(native2unicode(matlab.net.base64decode( ...
        regexprep(manifest.content,'\s','')),'UTF-8'));
    profile='';
    for i=1:numel(manifest.profiles)
        approved=manifest.profiles(i);
        if approved.enabled && site_benchmark_profile_equal(approved.contract,payload.contract)
            profile=approved.id;break
        end
    end
    initialMode=isempty(profile);initialEnvelope=[];
    inputs=[];if isappdata(fig,'SITEBenchmarkReferenceInputs'),inputs=getappdata(fig,'SITEBenchmarkReferenceInputs');end
    if ~initialMode
        payload.profile=profile;payload.contract=approved.contract;
        stage='downloading current verified benchmark snapshot';
        [snapshot,snapshotHash]=site_benchmark_fetch_snapshot(profile);
        snapshot=site_benchmark_attach_input_checksums(snapshot,approved);
        payload=site_benchmark_filter_records(payload,snapshot,approved);
        if isempty(payload.records),logFcn('Shared benchmarks: current global results already match or exceed these local fits.');result.state='current';return,end
        initialMode=isempty(snapshot);
        if ~initialMode,initialMode=any(~ismember(string({payload.records.basin}),string({snapshot.records.basin})));end
    end
    if initialMode
        assert(isfield(loaded.submission,'runConfig'),'SITE:InitialRunConfig','Run the updated SITE before submitting a first reference.');
        stage='preparing first-reference input checksums';
        initialEnvelope=site_benchmark_initial_envelope(loaded.submission,inputs);
        initialEnvelope.payload.records=payload.records;initialEnvelope.inputFingerprints.records=initialEnvelope.inputFingerprints.records(ismember(string({initialEnvelope.inputFingerprints.records.basin}),unique(string({payload.records.basin}))));payload=initialEnvelope.payload;profile=payload.profile;
        loaded.submission.initialEnvelope=initialEnvelope;
        logFcn('Shared benchmarks: first results will wait for owner-computer verification.');
    else
        stage='checking existing GitHub fits on local data';
        if ~isfield(loaded.submission,'runConfig'),logFcn('Shared benchmarks: this older contribution needs a short run in the updated SITE before its local reference check.');return,end
        logFcn('Shared benchmarks: checking input fingerprints, reference fits and proposed improvements.');
        loader=site_benchmark_local_context(loaded.submission.runConfig,unique(string({payload.records.basin})),inputs);
        pool=site_benchmark_reference_pool(loaded.submission.runConfig,logFcn);
        [payload,check]=site_benchmark_local_reference_check(payload,snapshot,snapshotHash,loader,logFcn,pool);
        logFcn(sprintf('Shared benchmarks: reference check passed for %d basins; %d failed; %d need an initial reference.',check.passed,check.failed,check.unseeded));
        if isempty(payload.records),result.state='reference_required';return,end
    end
    loaded.submission.localCheckedPayload=payload;if initialMode,initialEnvelope.payload=payload;loaded.submission.initialEnvelope=initialEnvelope;end;submission=loaded.submission;
    temporary=[tempname '.mat'];save(temporary,'submission','-v7.3');movefile(temporary,pendingFile,'f');
    try,site_benchmark_background_ui('queue',fig,pendingFile,logFcn);
    catch,logFcn('Shared benchmarks: background retry could not be configured; pending results remain local.');end
    upload=payload;if initialMode,initialEnvelope.payload=payload;upload=initialEnvelope;loaded.submission.initialEnvelope=initialEnvelope;end
    body=jsonencode(upload); bytes=unicode2native(body,'UTF-8');
    assert(numel(bytes)<=20*1024*1024,'SITE:BenchmarkSize','Submission is too large.');
    stage='GitHub sign-in';
    if ~automatic,[token,credential]=site_benchmark_login_ui(fig,cfg.clientId);end
    if isempty(token)
        logFcn('Shared benchmarks: GitHub sign-in was not completed; pending results remain local. Background upload requires successful sign-in.');
        return
    end
    if ~automatic
        try,site_benchmark_background_ui('credential',fig,jsonencode(credential),logFcn);
        catch,logFcn('Shared benchmarks: sign-in could not be saved securely; retry is limited to this session.');end
    end
    stage='checking GitHub account';
    account=api('get','https://api.github.com/user',token,[],false);
    login=account.login;
    setappdata(0,'SITEBenchmarkContributor',login);
    for n=1:numel(payload.records)
        if isfield(payload.records(n),'contributor') && strcmp(payload.records(n).contributor,'Unknown')
            payload.records(n).contributor=login;
        end
    end
    loaded.submission.localCheckedPayload=payload;if initialMode,initialEnvelope.payload=payload;loaded.submission.initialEnvelope=initialEnvelope;end;submission=loaded.submission;
    temporary=[tempname '.mat'];save(temporary,'submission','-v7.3');movefile(temporary,pendingFile,'f');
    upload=payload;if initialMode,initialEnvelope.payload=payload;upload=initialEnvelope;loaded.submission.initialEnvelope=initialEnvelope;end
    body=jsonencode(upload);bytes=unicode2native(body,'UTF-8');
    assert(numel(bytes)<=20*1024*1024,'SITE:BenchmarkSize','Submission is too large.');
    repo=root;
    if ~strcmpi(login,cfg.owner)
        fork=api('post',[root '/forks'],token,struct('default_branch_only',true),false);
        repo=['https://api.github.com/repos/' fork.full_name];
        % Fork creation is asynchronous. Poll only this newly created fork.
        ready=false;
        for i=1:15
            try,api('get',[repo '/git/ref/heads/main'],token,[],false);ready=true;break
            catch,pause(2);drawnow;end
        end
        assert(ready,'SITE:BenchmarkForkPending','Fork is not ready; retry later.');
    end
    base=api('get',[root '/git/ref/heads/main'],token,[],false);
    digest=java.security.MessageDigest.getInstance('SHA-256');
    hash=lower(reshape(dec2hex(typecast(digest.digest(bytes),'uint8'),2).',1,[]));
    branch=['site-benchmark-' hash(1:20)];
    try
        existing=api('get',[repo '/git/ref/heads/' branch],token,[],false); %#ok<NASGU>
    catch
        api('post',[repo '/git/refs'],token, ...
            struct('ref',['refs/heads/' branch],'sha',base.object.sha),false);
    end
    path=['benchmarks/inbox/' hash '.json'];if initialMode,path=['benchmarks/initial-inbox/' hash '.json'];end
    commit=struct('message',['Propose SITE benchmark fits: ' profile], ...
        'content',matlab.net.base64encode(bytes),'branch',branch);
    try
        old=api('get',[repo '/contents/' path '?ref=' branch],token,[],false);
        commit.sha=old.sha;
    catch
        % Missing candidate is expected for a newly created branch.
    end
    stage='uploading proposed benchmark fits';
    api('put',[repo '/contents/' path],token,commit,false);
    head=[login ':' branch];
    assert(~isempty(regexp(login,'^[A-Za-z0-9-]+$','once')), ...
        'SITE:BenchmarkLogin','Unexpected GitHub login.');
    % Login and generated branch use URL-safe characters; encode the colon.
    stage='creating benchmark verification request';
    prs=api('get',[root '/pulls?state=open&head=' strrep(head,':','%3A')],token,[],false);
    title=['SITE benchmark contribution: ' profile];description='Generated by SITE after reproducing shared reference scores on local data.';
    if initialMode,title=['SITE initial reference: ' payload.contract.provenance.region '/' payload.contract.model '/' payload.contract.resolution];description='Numerical claims and input checksums. Owner-computer replay is required before publication.';end
    if isempty(prs)
        pr=api('post',[root '/pulls'],token,struct( ...
            'title',title, ...
            'head',head,'base','main','draft',true, ...
            'body',description),false);
    else
        pr=prs(1);
    end
    result.state='submitted';result.url=pr.html_url;
    % Keep the pending snapshot until acceptance; a submitted PR is not
    % proof that the global benchmark has changed.
    logFcn(['Shared benchmarks: proposed update submitted: ' result.url]);
catch ME
    % Report stage and identifier only, never API bodies or credentials.
    logFcn(sprintf('Shared benchmarks: submission failed while %s (%s).', ...
        stage,ME.identifier));
    logFcn(['Shared benchmarks: submission was not completed. ' ...
        'The pending results are preserved locally for retry.']);
end
end

function value=api(method,url,token,body,anonymous)
assert(startsWith(url,'https://api.github.com/'),'SITE:BenchmarkAPI','Unexpected API host.');
headers={'Accept','application/vnd.github+json'; ...
    'X-GitHub-Api-Version','2022-11-28';'User-Agent','SITEhydrology-benchmarks'};
if ~anonymous && ~isempty(token),headers(end+1,:)={'Authorization',['Bearer ' token]};end
options=weboptions('HeaderFields',headers,'Timeout',45, ...
    'ContentType','json','MediaType','application/json','RequestMethod',method);
if strcmp(method,'get'),value=webread(url,options);
else,value=webwrite(url,body,options);end
end

function value=orderValue(value)
if isstruct(value)
    value=orderfields(value);
    keys=fieldnames(value);
    for k=1:numel(value)
        for i=1:numel(keys),value(k).(keys{i})=orderValue(value(k).(keys{i}));end
    end
elseif iscell(value)
    for i=1:numel(value),value{i}=orderValue(value{i});end
end
end
