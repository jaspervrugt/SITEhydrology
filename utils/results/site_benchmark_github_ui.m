function result=site_benchmark_github_ui(fig,pendingFile,logFcn,automatic)
if nargin<4,automatic=false;end
%SITE_BENCHMARK_GITHUB_UI Submit a proposed update, never write benchmarks.
% Only deployed GUI calls are eligible. The origin label is informational;
% trusted publication MUST recompute scores and validate approved profiles.
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
    reply=uiconfirm(fig,[ ...
        'Submit default-setting fits for verification on GitHub? ' ...
        'If the connection fails, SITE will retry while this window stays open.'], ...
        'Contribute SITE benchmarks','Options',{'Submit','Keep local'}, ...
        'DefaultOption',1,'CancelOption',2);
    if ~strcmp(reply,'Submit'),return,end
    setappdata(fig,'SITEBenchmarkRetryApproved',true);
end
try
    loaded=load(pendingFile,'submission');
    payload=site_benchmark_payload(loaded.submission);
    % Download the trusted approved manifest before authenticating. Empty
    % manifests and unapproved profiles cannot request any upload.
    root=sprintf('https://api.github.com/repos/%s/%s',cfg.owner,cfg.repository);
    manifest=api('get',[root '/contents/benchmarks/profiles.json'],'',[],true);
    manifest=jsondecode(native2unicode(matlab.net.base64decode( ...
        regexprep(manifest.content,'\s','')),'UTF-8'));
    profile='';
    for i=1:numel(manifest.profiles)
        approved=manifest.profiles(i);
        if approved.enabled && strcmp(jsonencode(orderValue(approved.contract)), ...
                jsonencode(orderValue(jsondecode(jsonencode(payload.contract)))))
            profile=approved.id;break
        end
    end
    if isempty(profile)
        logFcn('Shared benchmarks: this exact experiment has not yet been approved.');
        return
    end
    payload.profile=profile;
    snapshot=site_benchmark_fetch_snapshot(profile);
    payload=site_benchmark_filter_records(payload,snapshot,approved);
    if isempty(payload.records)
        logFcn('Shared benchmarks: current global results already match or exceed these local fits.');
        result.state='current';return
    end
    body=jsonencode(payload); bytes=unicode2native(body,'UTF-8');
    assert(numel(bytes)<=20*1024*1024,'SITE:BenchmarkSize','Submission is too large.');
    if ~automatic,token=site_benchmark_login_ui(fig,cfg.clientId);end
    if isempty(token),return,end
    account=api('get','https://api.github.com/user',token,[],false);
    login=account.login;
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
    path=['benchmarks/inbox/' hash '.json'];
    commit=struct('message',['Propose SITE benchmark fits: ' profile], ...
        'content',matlab.net.base64encode(bytes),'branch',branch);
    try
        old=api('get',[repo '/contents/' path '?ref=' branch],token,[],false);
        commit.sha=old.sha;
    catch
        % Missing candidate is expected for a newly created branch.
    end
    api('put',[repo '/contents/' path],token,commit,false);
    head=[login ':' branch];
    assert(~isempty(regexp(login,'^[A-Za-z0-9-]+$','once')), ...
        'SITE:BenchmarkLogin','Unexpected GitHub login.');
    % Login and generated branch use URL-safe characters; encode the colon.
    prs=api('get',[root '/pulls?state=open&head=' strrep(head,':','%3A')],token,[],false);
    if isempty(prs)
        pr=api('post',[root '/pulls'],token,struct( ...
            'title',['SITE benchmark contribution: ' profile], ...
            'head',head,'base','main','draft',true, ...
            'body',['Generated by SITE. Submitted scores require independent ' ...
                'verification before benchmark publication.']),false);
    else
        pr=prs(1);
    end
    result.state='submitted';result.url=pr.html_url;
    % Keep the pending snapshot until acceptance; a submitted PR is not
    % proof that the global benchmark has changed.
    logFcn(['Shared benchmarks: proposed update submitted: ' result.url]);
catch
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
