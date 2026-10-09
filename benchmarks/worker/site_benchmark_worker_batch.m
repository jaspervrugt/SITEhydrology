function site_benchmark_worker_batch(coreRoot,dataRoot,candidateRoot,manifestPath,configPath,receiptRoot,revision)
% Candidate filenames/content are plain data from the trusted validator.
if ~isfolder(receiptRoot),mkdir(receiptRoot);end
files=dir(fullfile(candidateRoot,'*.json'));
assert(~isempty(files),'SITE:VerificationEmpty','No validated candidates.');
for k=1:numel(files)
    assert(~isempty(regexp(files(k).name,'^[0-9a-f]{64}\.json$','once)), ...
        'SITE:VerificationPath','Unexpected candidate filename.');
    site_benchmark_worker(coreRoot,dataRoot,fullfile(candidateRoot,files(k).name), ...
        manifestPath,configPath,fullfile(receiptRoot,files(k).name),revision);
end
end
