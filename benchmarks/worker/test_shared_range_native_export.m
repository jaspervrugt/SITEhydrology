function test_shared_range_native_export()
repo=pwd;stage=fullfile(repo,'native-range-smoke');if ~isfolder(stage),mkdir(stage);end;sage=fullfile(repo,'worker-work','SAGEhydrology');
addpath(fullfile(sage,'src'),genpath(fullfile(sage,'utils')),fullfile(sage,'models'));
addpath(fullfile(repo,'benchmarks','worker'));addpath(fullfile(repo,'utils','results'));
destination=fullfile(stage,'range-native-export-test');if ~isfolder(destination),mkdir(destination);end
payload=jsondecode(fileread(fullfile(repo,'benchmarks','tests','range_candidate.json')));
configs=jsondecode(fileread(fullfile(repo,'benchmarks','worker','worker-config.json')));C=configs.profiles(1).run;
C.meteo.precip=NaN;C.meteo.temp=NaN;
mdl=read_model(struct('model',C.model,'mcode',4,'calc','seq'),C.prd,false);mdl=apply_model_configuration(mdl,read_numsettings(C.ode));
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
store=site_result_store('load',scratch,'hbv','daily',string(payload.records(1).basin),mdl,1, ...
 NaN,NaN,NaN,NaN,NaN,NaN,'CAMELS_US',C.meteo,C.prd);
checkpoint=fullfile(scratch,'input.mat');save(checkpoint,'store');
snapshot=struct('schema',1,'profile',payload.profile,'contract',payload.contract,'records',payload.records, ...
 'parameterRanges',[struct('id',1,'thMin',payload.contract.thMin(:),'thMax',payload.contract.thMax(:)),payload.records(1).parameterRange]);
file=fullfile(scratch,'snapshot.json');fid=fopen(file,'w');fwrite(fid,jsonencode(snapshot),'char');fclose(fid);
files=site_benchmark_export_results(file,checkpoint,'',destination,sage,fullfile(repo,'benchmarks','worker','worker-config.json'));
assert(numel(files)==4);result=load(fullfile(destination,files{1}),'store');assert(all(result.store.rangeID==2));
T=readtable(fullfile(destination,files{4}));assert(isequal(unique(T.range_id),[1;2]));
book=readtable(fullfile(destination,files{2}),'Sheet','NSE','VariableNamingRule','preserve');assert(book.RangeID==2);
disp('Native checkpoint, Excel RangeID, and parameter-range CSV agree.');
end
