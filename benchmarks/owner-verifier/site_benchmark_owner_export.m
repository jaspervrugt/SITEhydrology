function site_benchmark_owner_export(job,core,snapshotFile,output)
% Export independently verified records using SITE's normal result writer.
site=fullfile(fileparts(core),'SITEhydrology');addpath(genpath(fullfile(site,'utils')),fullfile(core,'src'),genpath(fullfile(core,'utils')),fullfile(core,'models'));
v=load(fullfile(job,'owner-context.mat'),'C');C=v.C;snapshot=jsondecode(fileread(snapshotFile));profile=jsondecode(fileread(fullfile(job,'owner-profile.json')));
mdl=struct('model',C.model,'mcode',C.mcode,'calc','seq');if C.model==99,mdl.user_model_folder=C.user_model_folder;end;mdl=read_model(mdl,C.prd,false);mdl=apply_model_configuration(mdl,read_numsettings(C.ode));
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s'));ids=string(profile.basinIds(:));refs=nan(numel(ids),1);
s=site_result_store('load',scratch,snapshot.contract.model,snapshot.contract.resolution,ids,mdl,1,refs,refs,refs,refs,refs,refs,C.region,C.meteo,C.prd);
[s,~]=site_benchmark_apply_snapshot(s,snapshot);
folder=fullfile('results',C.region,snapshot.contract.resolution,'period_001',s.profileTag);suffix=sprintf('%s_%s_%s_p001',s.model,s.dtTag,s.profileTag);
paths={fullfile(folder,['SITE_' suffix '_checkpoint.mat']),fullfile(folder,['param_' suffix '.xlsx']),fullfile(folder,sprintf('model_master_%s_%s_p001.xlsx',s.dtTag,s.profileTag)),fullfile(folder,sprintf('param_ranges_%s_%s.csv',s.model,s.dtTag))};
s.resultDir=fullfile(output,folder);if ~isfolder(s.resultDir),mkdir(s.resultDir);end;s.fileMat=fullfile(output,paths{1});s.fileBook=fullfile(output,paths{2});s.fileSummary=fullfile(output,paths{3});s.rangeFile=fullfile(output,paths{4});
previous=fullfile(output,'inputs',paths{3});if isfile(previous),copyfile(previous,s.fileSummary);end
ranges=snapshot.parameterRanges;for k=1:numel(ranges),id=get_or_register_param_range(s.rangeFile,s.parNames,ranges(k).thMin,ranges(k).thMax);assert(id==ranges(k).id);end
s.sharedBenchmarkContract=snapshot.contract;s.sharedBenchmarkProfile=snapshot.profile;site_result_store('save',s);
% Public checkpoints contain relative destinations, not the owner's folders.
store=s;store.resultDir=folder;store.fileMat=paths{1};store.fileBook=paths{2};store.fileSummary=paths{3};store.rangeFile=paths{4};save(s.fileMat,'store','-v7.3');
write(fullfile(job,'exports.json'),strrep(paths,filesep,'/'));
run=struct();for f={'region','model','mcode','ode','prd','meteo','loss'},run.(f{1})=C.(f{1});end;write(fullfile(job,'public-run.json'),run);
end
function write(file,value),fid=fopen(file,'wb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fwrite(fid,unicode2native(jsonencode(value),'UTF-8'),'uint8');end
