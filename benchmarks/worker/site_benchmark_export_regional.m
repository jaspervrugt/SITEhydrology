function files=site_benchmark_export_regional(snapshotFile,outputRoot,coreRoot,configFile,manifestFile)
% Create native result files from verified records, including a first seed.
% Only the trusted publisher may call this; submitted MAT files are forbidden.
addpath(fullfile(coreRoot,'src'),genpath(fullfile(coreRoot,'utils')),fullfile(coreRoot,'models'));
snapshot=jsondecode(fileread(snapshotFile));contract=snapshot.contract;
configs=jsondecode(fileread(configFile));manifest=jsondecode(fileread(manifestFile));
hit=find(strcmp({configs.profiles.id},snapshot.profile));assert(isscalar(hit));C=configs.profiles(hit).run;
hit=find(strcmp({manifest.profiles.id},snapshot.profile));assert(isscalar(hit));profile=manifest.profiles(hit);
assert(profile.enabled && site_benchmark_contract_equal(profile.contract,contract),'SITE:ExportContract','Unapproved snapshot.');
for key={'precip','temp'},if isempty(C.meteo.(key{1})),C.meteo.(key{1})=NaN;end,end
definition=struct('model',C.model,'mcode',C.mcode,'calc','seq');
if C.model==99,definition.user_model_folder=fullfile(coreRoot,'user_model');addpath(definition.user_model_folder);end
mdl=read_model(definition,C.prd,false);
mdl=apply_model_configuration(mdl,read_numsettings(C.ode));
assert(strcmp(model_run_configuration(mdl).identity,contract.configuration));
% A clean destination avoids inheriting stale or unverified local scores.
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
ids=string(profile.basinIds(:));numeric=str2double(ids);
if all(isfinite(numeric)),[~,order]=sort(numeric);else,[~,order]=sort(ids);end
ids=ids(order);refs=nan(numel(ids),1);
s=site_result_store('load',scratch,contract.model,contract.resolution,ids,mdl,1, ...
    refs,refs,refs,refs,refs,refs,C.region,C.meteo,C.prd);
assert(site_benchmark_contract_equal(site_benchmark_contract(s,C),contract));
for k=1:numel(snapshot.records)
    r=snapshot.records(k);row=find(ids==string(r.basin));col=find(string(s.metricNames)==string(r.metric));
    assert(isscalar(row)&&isscalar(col)&&isfinite(r.train));
    s.train(row,col)=r.train;if isempty(r.evaluation),s.eval(row,col)=NaN;else,s.eval(row,col)=r.evaluation;end
    s.theta(row,:,col)=r.theta(:).';s.nTheta(row,:,col)=r.normalized(:).';
    s.optimizedLoss(row,col)=string(r.optimizedLoss);s.optimizer(row,col)=r.optimizer;s.runtime(row,col)=r.runtime;
    s.updated(row,col)=datetime(r.updated,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
    if isfield(r,'parameterRange'),s.rangeID(row,col)=r.parameterRange.id;else,s.rangeID(row,col)=1;end
    s.runCount(row,col)=1;
end
folder=fullfile(outputRoot,'results',C.region,contract.resolution,'period_001',s.profileTag);
if ~isfolder(folder),mkdir(folder);end
suffix=sprintf('%s_%s_%s_p001',contract.model,contract.resolution,s.profileTag);
s.resultDir=folder;s.fileMat=fullfile(folder,['SITE_' suffix '_checkpoint.mat']);
s.fileBook=fullfile(folder,['param_' suffix '.xlsx']);
s.fileSummary=fullfile(folder,sprintf('model_master_%s_%s_p001.xlsx',contract.resolution,s.profileTag));
s.sharedBenchmarkContract=contract;s.sharedBenchmarkProfile=snapshot.profile;
relative=strrep(s.fileMat,[outputRoot filesep],'');previous=fullfile(outputRoot,'inputs',relative);
if isfile(previous)
    old=load(previous,'store');old=old.store;
    assert(site_benchmark_profile_equal(site_benchmark_contract(old,C),contract));
    [found,rows]=ismember(ids,string(old.ids));assert(all(found));
    % Preserve historical counts and FDC references, while scores come only
    % from the independently verified snapshot above.
    fields={'runCount','improvementCount','fdcD0t','fdcD0e','fdcD0pt','fdcD0pe','fdcD0logpt','fdcD0logpe'};
    for j=1:numel(fields),key=fields{j};if isfield(old,key),s.(key)=old.(key)(rows,:);end,end
    for k=1:numel(snapshot.records)
        r=snapshot.records(k);row=find(ids==string(r.basin));col=find(string(s.metricNames)==string(r.metric));v=old.train(rows(row),col);
        better=isfinite(v) && ((s.maximize(col)&&r.train>v)||(~s.maximize(col)&&r.train<v));
        if better,s.improvementCount(row,col)=s.improvementCount(row,col)+1;end
    end
end
relative=strrep(s.fileSummary,[outputRoot filesep],'');previous=fullfile(outputRoot,'inputs',relative);
if ~isfile(s.fileSummary) && isfile(previous),copyfile(previous,s.fileSummary);end
s.rangeFile=fullfile(folder,sprintf('param_ranges_%s_%s.csv',contract.model,contract.resolution));
if isfield(snapshot,'parameterRanges'),ranges=snapshot.parameterRanges;else,ranges=struct('id',1,'thMin',contract.thMin,'thMax',contract.thMax);end
for k=1:numel(ranges)
    id=get_or_register_param_range(s.rangeFile,s.parNames,ranges(k).thMin,ranges(k).thMax);assert(id==ranges(k).id);
end
site_result_store('save',s);
files={s.fileMat,s.fileBook,s.fileSummary,s.rangeFile};files=strrep(files,[outputRoot filesep],'');files=strrep(files,filesep,'/');
end
