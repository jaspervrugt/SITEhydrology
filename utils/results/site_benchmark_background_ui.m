function site_benchmark_background_ui(action,fig,value,logFcn)
% Lightweight Windows retry helper; never give it repository write authority.
if ~isdeployed || ~ispc || ~isgraphics(fig,'figure'),return,end
if ~isappdata(fig,'SITEBenchmarkRetryApproved'),return,end
root=fullfile(getenv('LOCALAPPDATA'),'SITEhydrology','benchmark-sync');
if ~isfolder(root),mkdir(root);end
source=fullfile(fileparts(mfilename('fullpath')),'site_benchmark_sync.ps1');
destination=fullfile(root,'site_benchmark_sync.ps1');
copyfile(source,destination,'f');
config=fullfile(fileparts(mfilename('fullpath')),'site_benchmark_github.json');
copyfile(config,fullfile(root,'site_benchmark_github.json'),'f');
if strcmp(action,'queue')
    loaded=load(value,'submission');
    payload=site_benchmark_payload(loaded.submission);
    [~,name]=fileparts(value);
    folder=fullfile(root,'pending');if ~isfolder(folder),mkdir(folder);end
    temporary=[tempname(folder) '.json'];
    cleanup=onCleanup(@()removeTemp(temporary)); %#ok<NASGU>
    fid=fopen(temporary,'wb');assert(fid>=0,'SITE:BenchmarkQueue','Cannot write pending payload.');
    bytes=unicode2native(jsonencode(payload),'UTF-8');fwrite(fid,bytes,'uint8');fclose(fid);
    movefile(temporary,fullfile(folder,[name '.json']),'f');
    invoke('Install','');
    logFcn('Shared benchmarks: pending results can retry after SITE closes while you are signed in to Windows.');
elseif strcmp(action,'credential')
    % Pass the credential through stdin; never through command arguments or
    % a plaintext temporary file. Windows encrypts it for the current user.
    invoke('SaveCredential',value);
else
    error('SITE:BenchmarkBackgroundAction','Unknown retry action.');
end
    function invoke(mode,input)
        executable=fullfile(getenv('WINDIR'),'System32','WindowsPowerShell','v1.0','powershell.exe');
        args={executable,'-NoProfile','-NonInteractive','-WindowStyle','Hidden', ...
            '-ExecutionPolicy','Bypass','-File',destination,'-Action',mode,'-StateRoot',root};
        process=java.lang.ProcessBuilder(args).start();
        writer=java.io.OutputStreamWriter(process.getOutputStream(),'UTF-8');
        if ~isempty(input),writer.write(char(input));end
        writer.close();
        finished=process.waitFor(int64(30),java.util.concurrent.TimeUnit.SECONDS);
        if ~finished,process.destroyForcibly();error('SITE:BenchmarkHelperTimeout','Retry helper timed out.');end
        assert(process.exitValue()==0,'SITE:BenchmarkHelper','Could not configure background retry; pending results remain local.');
    end
end
function removeTemp(path)
if isfile(path),delete(path);end
end
