function loader=site_benchmark_local_context(C,ids,inputs)
% Reuse prepared run inputs; retry reads only the required local basin files.
if nargin<3,inputs=[];end
if isempty(inputs)
    mdl=struct('model',C.model,'mcode',C.mcode,'calc','seq');
    if isfield(C,'user_model_folder'),mdl.user_model_folder=C.user_model_folder;end
    [mdl,misc]=crr_prepare_backend(mdl,struct('meteo',C.meteo));
    ode=read_numsettings(C.ode);mdl=read_model(mdl,C.prd,false);mdl=apply_model_configuration(mdl,ode);
    bas=struct('sample','file','sort_by_gauge',true,'K',numel(ids),'K_t',numel(ids),'K_e',0);
    [~,allIDs,gname,zone]=read_attr(C.region,C.dirD,bas);bas=rmfield(bas,'K');
    scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
    selection=fullfile(scratch,'basins.txt');fid=fopen(selection,'w');assert(fid>=0);fprintf(fid,'%s\n',string(ids));fclose(fid);
    [~,bas]=sample_basins([],allIDs,bas,C.prd,gname,zone,C.dirD,C.file_univ,selection);
    [split,mdl]=build_split(mdl,C.prd,bas);[dat,aux]=read_meteo(C.region,C.dirM,bas,split,C.meteo);
    dat=read_Q(C.region,C.dirQ,mdl,dat,bas,split,aux);[quality,dat]=check_basins(dat,mdl,bas);assert(all(quality.valid));
    loss=C.loss;loss.fnc=7;[dat,loss]=prep_stats(dat,mdl,split,loss);
else
    mdl=inputs.mdl;ode=inputs.ode;dat=inputs.dat;bas=inputs.bas;loss=inputs.loss;misc.crr_backend=inputs.backend;
end
mdl.pspace=1;configuration=model_run_configuration(mdl);contexts=containers.Map('KeyType','char','ValueType','any');
for k=1:numel(dat)
    id=char(string(bas.id_gauge(k)));if ~ismember(string(id),string(ids)),continue,end
    oneLoss=loss;fields=fieldnames(loss.fdc.Q);
    for j=1:numel(fields),v=loss.fdc.Q.(fields{j});if isnumeric(v)&&numel(v)==numel(dat),oneLoss.fdc.Q.(fields{j})=v(k);end,end
    contexts(id)=struct('mdl',mdl,'ode',ode,'dat',dat{k},'loss',oneLoss, ...
        'backend',misc.crr_backend,'configuration',configuration);
end
loader=@(id)contexts(char(id));
end
