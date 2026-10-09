function ctx=site_benchmark_context(C,basinID)
%SITE_BENCHMARK_CONTEXT Prepare one basin from an administrator-owned profile.
% C must come from trusted worker configuration, NEVER from a submission.
% Does not optimize, load result checkpoints, or write benchmark workbooks.
assert(strcmp(C.region,'CAMELS_US') && C.prd.dt==1, ...
    'SITE:VerificationProfile','Only CAMELS-US daily is currently supported.');
assert(isnumeric(C.model) && isscalar(C.model) && ismember(C.model,1:7), ...
    'SITE:VerificationModel','Only approved built-in models may be verified.');
basinID=char(string(basinID));
assert(~isempty(regexp(basinID,'^\d{7,8}$','once')), ...
    'SITE:VerificationBasin','Invalid CAMELS-US basin identifier.');
oldPath=path; restore=onCleanup(@()path(oldPath)); %#ok<NASGU>
addpath(fullfile(C.SAGEhydro,'utils'));
scratch=tempname;mkdir(scratch);
cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
bootstrap_SAGE(fileparts(C.SAGEhydro),C.region,scratch);
selection=fullfile(scratch,'basin.txt');
fid=fopen(selection,'w'); assert(fid>=0);
fprintf(fid,'%s\n',basinID); fclose(fid);
mdl=struct('model',C.model,'mcode',C.mcode,'calc','seq');
misc=struct('meteo',C.meteo);
[mdl,misc]=crr_prepare_backend(mdl,misc);
ode=read_numsettings(C.ode);
[mdl,~]=read_model(mdl,C.prd);
mdl=apply_model_configuration(mdl,ode);
if isfield(C,'th_min'),mdl.th_min=C.th_min(:);end
if isfield(C,'th_max'),mdl.th_max=C.th_max(:);end
bas=struct('sample','file','sort_by_gauge',true,'K',1,'K_t',1,'K_e',0);
[~,allIDs,gname,zone]=read_attr(C.region,C.dirD,bas);
bas=rmfield(bas,'K');
[~,bas]=sample_basins([],allIDs,bas,C.prd,gname,zone, ...
    C.dirD,C.file_univ,selection);
assert(numel(bas.id_gauge)==1 && string(bas.id_gauge(1))==string(basinID), ...
    'SITE:VerificationBasin','Reader selected a different basin.');
[split,mdl]=build_split(mdl,C.prd,bas);
[dat,aux]=read_meteo(C.region,C.dirM,bas,split,C.meteo);
dat=read_Q(C.region,C.dirQ,mdl,dat,bas,split,aux);
[eligibility,dat]=check_basins(dat,mdl,bas);
assert(eligibility.valid(1),'SITE:VerificationData','Basin fails data screening.');
loss=C.loss;loss.fnc=7;
[dat,loss]=prep_stats(dat,mdl,split,loss);
mdl.pspace=1;
ctx=struct('mdl',mdl,'dat',dat{1},'ode',ode,'loss',loss, ...
    'backend',misc.crr_backend,'basin',basinID, ...
    'configuration',model_run_configuration(mdl));
end
