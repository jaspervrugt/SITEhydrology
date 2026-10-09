function site_benchmark_retry_ui(fig,queue,logFcn)
% Retry preserved contributions without background sign-in dialogs.
% The queue survives app closure; this timer and credentials do not.
if ~isdeployed || ~isgraphics(fig,'figure'),return,end
key='SITEBenchmarkRetryTimer';
if isappdata(fig,key)
    old=getappdata(fig,key);
    if isvalid(old),stop(old);delete(old);end
end
seen=containers.Map('KeyType','char','ValueType','char');
t=timer('ExecutionMode','fixedSpacing','Period',300,'StartDelay',300, ...
    'BusyMode','drop','TimerFcn',@retry);
setappdata(fig,key,t);
listener=addlistener(fig,'ObjectBeingDestroyed',@cleanup);
setappdata(fig,'SITEBenchmarkRetryListener',listener);
start(t);
    function retry(~,~)
        if ~isgraphics(fig,'figure'),cleanup([],[]);return,end
        files=dir(fullfile(queue,'*_submission.mat'));
        for i=1:numel(files)
            path=fullfile(files(i).folder,files(i).name);
            stamp=sprintf('%.15g:%d',files(i).datenum,files(i).bytes);
            if isKey(seen,path) && strcmp(seen(path),stamp),continue,end
            result=site_benchmark_github_ui(fig,path,logFcn,true);
            if any(strcmp(result.state,{'submitted','current'})),seen(path)=stamp;end
        end
    end
    function cleanup(~,~)
        if isvalid(t),stop(t);delete(t);end
    end
end
