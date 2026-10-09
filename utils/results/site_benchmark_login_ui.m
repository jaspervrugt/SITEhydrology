function [token,credential]=site_benchmark_login_ui(fig,clientId,cachedOnly)
if nargin<3,cachedOnly=false;end
assert(isdeployed && isscalar(fig) && isgraphics(fig,'figure'), ...
    'SITE:BenchmarkGUIRequired','Sign-in requires the compiled SITE GUI.');
% Memory-only access token. No shared credentials, client secret or disk cache.
persistent sessionToken sessionCredential
token='';credential=struct();
if ~isempty(sessionToken)
    try
        api('get','https://api.github.com/user',sessionToken,[],false);
        token=sessionToken;if ~isempty(sessionCredential),credential=sessionCredential;end;return
    catch
        sessionToken='';
    end
end
if cachedOnly,return,end
options=weboptions('MediaType','application/x-www-form-urlencoded', ...
    'HeaderFields',{'Accept','application/json'},'Timeout',30);
device=webwrite('https://github.com/login/device/code', ...
    'client_id',clientId,'scope','public_repo',options);
assert(strcmp(device.verification_uri,'https://github.com/login/device'), ...
    'SITE:BenchmarkLoginURL','Unexpected authorization URL.');
dlg=uiprogressdlg(fig,'Title','Sign in to GitHub', ...
    'Message',['Enter this code in your browser: ' device.user_code], ...
    'Indeterminate','on','Cancelable','on');
cleanup=onCleanup(@()close(dlg));
web(device.verification_uri,'-browser');
interval=max(5,double(device.interval)); clock=tic;
while toc(clock)<double(device.expires_in)
    for i=1:ceil(interval*5)
        if ~isgraphics(fig) || dlg.CancelRequested,return,end
        pause(0.2);drawnow;
    end
    answer=webwrite('https://github.com/login/oauth/access_token', ...
        'client_id',clientId,'device_code',device.device_code, ...
        'grant_type','urn:ietf:params:oauth:grant-type:device_code',options);
    if isfield(answer,'access_token')
        token=answer.access_token;sessionToken=token;
        credential=struct('clientId',clientId,'access_token',token);
        if isfield(answer,'refresh_token'),credential.refresh_token=answer.refresh_token;end
        now=posixtime(datetime('now','TimeZone','UTC'));
        if isfield(answer,'expires_in'),credential.expiresAt=now+double(answer.expires_in);end
        if isfield(answer,'refresh_token_expires_in'),credential.refreshExpiresAt=now+double(answer.refresh_token_expires_in);end
        sessionCredential=credential;return
    end
    if strcmp(answer.error,'slow_down'),interval=interval+5;
    elseif ~strcmp(answer.error,'authorization_pending'),return,end
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

