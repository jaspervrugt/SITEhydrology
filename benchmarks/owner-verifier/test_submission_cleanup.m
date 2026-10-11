function test_submission_cleanup()
core=fileparts(fileparts(fileparts(mfilename('fullpath'))));site=fullfile(fileparts(core),'SITEhydrology');addpath(genpath(fullfile(site,'utils')));
fixture=fullfile(core,'benchmarks','tests','hbv_candidate.json');if ~isfile(fixture),fixture=fullfile(core,'.codex-work','site-parameter-ranges','benchmarks','tests','hbv_candidate.json');end
payload=jsondecode(fileread(fixture));payload.records=payload.records(1);
approved=struct('id',payload.profile,'contract',payload.contract,'basinIds',string(payload.records.basin));snapshot=struct('profile',payload.profile,'contract',payload.contract,'records',payload.records);
assert(site_benchmark_submission_covered(payload,snapshot,approved));
metric=find(string(payload.contract.metrics)==string(payload.records.metric));direction=2*double(payload.contract.maximize(metric))-1;
snapshot.records.train=payload.records.train+direction*.01;assert(site_benchmark_submission_covered(payload,snapshot,approved));
snapshot.records.train=payload.records.train-direction*.01;assert(~site_benchmark_submission_covered(payload,snapshot,approved));
snapshot.records=payload.records;snapshot.records.basin='missing';assert(~site_benchmark_submission_covered(payload,snapshot,approved));
snapshot.records=payload.records;snapshot.contract.period='wrong';assert(~site_benchmark_submission_covered(payload,snapshot,approved));
snapshot.contract=payload.contract;snapshot.profile='wrong';assert(~site_benchmark_submission_covered(payload,snapshot,approved));
assert(~site_benchmark_cleanup_ui(fullfile(tempdir,'ordinary_checkpoint.mat'),@(m)disp(m)));
disp('SUBMISSION CLEANUP SAFETY CHECKS PASSED');
messages=checkcode(fullfile(site,'gui','SITE_ui.m'),'-id');bad=contains(string({messages.message}),'Parse error');assert(~any(bad));
end
