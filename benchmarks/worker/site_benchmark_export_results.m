function files=site_benchmark_export_results(snapshotFile,checkpointFile,masterFile,outputRoot,coreRoot,configFile)
% Export verified shared records into the existing public MAT/XLSX layout.
% All inputs are selected by the trusted publisher, never a contributor.
snapshot=jsondecode(fileread(snapshotFile));contract=snapshot.contract;
assert(strcmp(snapshot.profile,'camels_us_daily_nldas_pm_hbv_default'));
assert(strcmp(contract.model,'hbv')&&strcmp(contract.resolution,'daily')&&strcmp(contract.provenance.tag,'nldas_penman_monteith'));
loaded=load(checkpointFile,'store');store=loaded.store;
assert(strcmp(store.model,contract.model)&&strcmp(store.dtTag,contract.resolution));
assert(isequaln(jsondecode(char(store.period.signature)),jsondecode(char(contract.period))));
assert(isequal(string(store.parNames(:)),string(contract.parNames(:))));
assert(isequal(store.thMin(:),double(contract.thMin(:)))&&isequal(store.thMax(:),double(contract.thMax(:))));
assert(strcmp(store.provenance.tag,contract.provenance.tag));
if isfield(store,'sharedBenchmarkContract'),assert(isequaln(store.sharedBenchmarkContract,contract));end
addpath(fullfile(coreRoot,'src'),genpath(fullfile(coreRoot,'utils')),fullfile(coreRoot,'models'));
configs=jsondecode(fileread(configFile));C=configs.profiles(strcmp({configs.profiles.id},snapshot.profile)).run;
[mdl,~]=read_model(struct('model',C.model,'mcode',C.mcode,'calc','seq'),C.prd);
mdl=apply_model_configuration(mdl,read_numsettings(C.ode));
configuration=model_run_configuration(mdl);assert(strcmp(configuration.identity,contract.configuration));
store.configuration=configuration;store.sharedBenchmarkContract=contract;store.sharedBenchmarkProfile=snapshot.profile;
K=numel(store.ids);[~,order]=sort(str2double(string(store.ids)));
fields={'ids','train','eval','nTheta','theta','optimizedLoss','optimizer','runtime','updated','rangeID','runCount','improvementCount','fdcD0t','fdcD0e','fdcD0pt','fdcD0pe','fdcD0logpt','fdcD0logpe'};
for i=1:numel(fields)
 f=fields{i};if isfield(store,f),v=store.(f);assert(size(v,1)==K);store.(f)=v(order,:,:);end
end
if ~isfield(store,'improvementCount'),store.improvementCount=zeros(size(store.train));end
% The initial shared snapshot must cover every existing finite fit. Refuse
% to silently replace a complete legacy file with a partial first upload.
covered=false(size(store.train));
for k=1:numel(snapshot.records)
 r=snapshot.records(k);row=find(string(store.ids)==string(r.basin));j=find(string(store.metricNames)==string(r.metric));
 assert(isscalar(row)&&isscalar(j));assert(~covered(row,j));covered(row,j)=true;
 assert(isfinite(r.train)&&all(isfinite(r.theta))&&all(isfinite(r.normalized)));
 old=store.train(row,j);
 store.train(row,j)=r.train;if isempty(r.evaluation),store.eval(row,j)=NaN;else,store.eval(row,j)=r.evaluation;end
 store.theta(row,:,j)=r.theta(:).';store.nTheta(row,:,j)=r.normalized(:).';
 store.optimizedLoss(row,j)=string(r.optimizedLoss);store.optimizer(row,j)=r.optimizer;store.runtime(row,j)=r.runtime;
 store.updated(row,j)=datetime(r.updated,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
 if ~isfield(loaded.store,'sharedBenchmarkContract')
  % Bootstrap counts remain historical. This is numerical verification,
  % not an additional basin calibration.
 elseif isfinite(old)&&((store.maximize(j)&&r.train>old)||(~store.maximize(j)&&r.train<old))
  store.improvementCount(row,j)=store.improvementCount(row,j)+1;
 end
end
assert(all(covered(isfinite(loaded.store.train(order,:)))),'SITE:PartialSharedSeed','Shared snapshot omits existing finite fits.');
relative='results/CAMELS_US/daily/period_001/nldas_penman_monteith';folder=fullfile(outputRoot,relative);if ~isfolder(folder),mkdir(folder);end
store.resultDir=fullfile(outputRoot,'results','CAMELS_US');
store.fileMat=fullfile(folder,'SITE_hbv_daily_nldas_penman_monteith_p001_checkpoint.mat');
store.fileBook=fullfile(folder,'param_hbv_daily_nldas_penman_monteith_p001.xlsx');
store.fileSummary=fullfile(folder,'model_master_daily_nldas_penman_monteith_p001.xlsx');
assert(~strcmp(checkpointFile,store.fileMat),'SITE:ExportIsolation','Export must use a separate destination.');
if isfile(masterFile),copyfile(masterFile,store.fileSummary,'f');end
site_result_store('save',store);
files={strrep(store.fileMat,[outputRoot filesep],''),strrep(store.fileBook,[outputRoot filesep],''),strrep(store.fileSummary,[outputRoot filesep],'')};files=strrep(files,filesep,'/');
fid=fopen(fullfile(outputRoot,'result-files.json'),'wb');assert(fid>=0);fwrite(fid,unicode2native(jsonencode(strrep(files,'\','/')),'UTF-8'),'uint8');fclose(fid);
fprintf('Exported existing public result paths with sorted basin IDs.\n');
end
