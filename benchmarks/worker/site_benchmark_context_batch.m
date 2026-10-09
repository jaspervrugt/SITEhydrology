function loader=site_benchmark_context_batch(C,ids)
% Read trusted verification inputs together; never optimize or load scores.
assert(strcmp(C.region,'CAMELS_US')&&C.prd.dt==1);
assert(isnumeric(C.model)&&isscalar(C.model)&&ismember(C.model,1:7)&&C.mcode==4);
ids=string(ids(:));assert(all(~cellfun('isempty',regexp(cellstr(ids),'^\d{7,8}$','once'))));
addpath(fullfile(C.SAGEhydro,'src'),genpath(fullfile(C.SAGEhydro,'utils')),genpath(fullfile(C.SAGEhydro,'models')),fullfile(C.SAGEhydro,'regions','US','US'));
mdl=struct('model',C.model,'mcode',C.mcode,'calc','seq');misc=struct('meteo',C.meteo);[mdl,misc]=crr_prepare_backend(mdl,misc);assert(strcmp(misc.crr_backend,'cpp'));
ode=read_numsettings(C.ode);[mdl,~]=read_model(mdl,C.prd);mdl=apply_model_configuration(mdl,ode);if isfield(C,'th_min'),mdl.th_min=C.th_min(:);end;if isfield(C,'th_max'),mdl.th_max=C.th_max(:);end
bas=struct('sample','file','sort_by_gauge',true,'K',numel(ids),'K_t',numel(ids),'K_e',0);[~,allIDs,gname,zone]=read_attr(C.region,C.dirD,bas);bas=rmfield(bas,'K');scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s'));selection=fullfile(scratch,'basins.txt');fid=fopen(selection,'w');fprintf(fid,'%s\n',string(ids));fclose(fid);
[~,bas]=sample_basins([],allIDs,bas,C.prd,gname,zone,C.dirD,C.file_univ,selection);assert(numel(bas.id_gauge)==numel(ids)&&all(ismember(string(ids),string(bas.id_gauge))));
[split,mdl]=build_split(mdl,C.prd,bas);[dat,aux]=read_meteo(C.region,C.dirM,bas,split,C.meteo);dat=read_Q(C.region,C.dirQ,mdl,dat,bas,split,aux);[eligibility,dat]=check_basins(dat,mdl,bas);assert(all(eligibility.valid));loss=C.loss;loss.fnc=7;[dat,loss]=prep_stats(dat,mdl,split,loss);mdl.pspace=1;
contexts=containers.Map('KeyType','char','ValueType','any');configuration=model_run_configuration(mdl);
for k=1:numel(dat)
 oneLoss=loss;fields=fieldnames(loss.fdc.Q);for j=1:numel(fields),v=loss.fdc.Q.(fields{j});if isnumeric(v)&&numel(v)==numel(dat),oneLoss.fdc.Q.(fields{j})=v(k);end,end
 ctx=struct('mdl',mdl,'dat',dat{k},'ode',ode,'loss',oneLoss,'backend',misc.crr_backend,'basin',char(string(bas.id_gauge(k))),'configuration',configuration);contexts(ctx.basin)=ctx;
end
loader=@(id)contexts(char(id));
end

