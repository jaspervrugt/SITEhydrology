function envelope=site_benchmark_initial_envelope(submission,inputs)
% Queue numerical claims and input hashes; publication requires owner replay.
if nargin<2,inputs=[];end
C=submission.runConfig;payload=site_benchmark_payload(submission);
core=C.SAGEhydro;site_benchmark_initial_defaults(payload.contract,core,'');
ids=unique(string({payload.records.basin}));loader=site_benchmark_local_context(C,ids,inputs);
fingerprints=struct('basin',{},'sha256',{});
for k=1:numel(ids),fingerprints(end+1)=struct('basin',char(ids(k)),'sha256',site_benchmark_input_fingerprint(loader(char(ids(k)))));end
payload.profile='pending_initial_reference';
envelope=struct('schema',1,'kind','owner_initial_reference','payload',payload,'inputFingerprints',struct('schema',1,'algorithm','sha256-input-v1','records',fingerprints));
end
