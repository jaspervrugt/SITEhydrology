function site_benchmark_worker(coreRoot,dataRoot,candidatePath,manifestPath,configPath,receiptPath,revision)
% Run only administrator-owned code/configuration against plain JSON data.
addpath(fullfile(coreRoot,'src'),genpath(fullfile(coreRoot,'utils')), ...
    genpath(fullfile(coreRoot,'models')),fullfile(coreRoot,'regions','US','US'));
payload=jsondecode(fileread(candidatePath));
configs=jsondecode(fileread(configPath));
C=[];
for k=1:numel(configs.profiles)
    p=configs.profiles(k);
    if strcmp(p.id,payload.profile),C=p.run;break,end
end
assert(~isempty(C),'SITE:VerificationProfile','No trusted worker configuration.');
C.SAGEhydro=coreRoot;
C.dirD=dataRoot;
C.dirM=fullfile(dataRoot,'daily','v1p2','forcing');
C.dirQ=fullfile(dataRoot,'daily','v1p2','streamflow');
C.file_univ=fullfile(coreRoot,'regions','US','US','US_531_basins.txt');
C.verifierRevision=revision;
if isfield(C.meteo,'precip') && isempty(C.meteo.precip),C.meteo.precip=NaN;end
if isfield(C.meteo,'temp') && isempty(C.meteo.temp),C.meteo.temp=NaN;end
assert(exist('crr_model_mex','file')==3,'SITE:VerificationBackend', ...
    'Build the pinned C++ core before verification.');
receipt=site_benchmark_verify_file(candidatePath,manifestPath,C,receiptPath);
assert(receipt.scores_verified,'SITE:VerificationRejected', ...
    'Submitted scores differ from independent calculations.');
fprintf('Verified %d numerical record(s).\n',receipt.checked);
end
