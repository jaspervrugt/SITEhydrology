function [contract,C,universe]=site_benchmark_initial_defaults(request,core,dataRoot)
% Construct defaults from owner-installed code, never submitted settings.
addpath(fullfile(core,'src'),genpath(fullfile(core,'utils')),genpath(fullfile(core,'regions')),fullfile(core,'models'));
[~,regions]=region_helpers('list');assert(ismember(string(request.provenance.region),string(regions)),'SITE:InitialRegion');
names=["hymod","hmodel","sacsma","xinanjiang","gr4ja","hbv","cfe_nwm","user_model"];codes=[1 2 3 4 5 6 7 99];i=find(strcmpi(names,request.model));assert(isscalar(i),'SITE:InitialModel');
R=region_helpers('config',core,request.provenance.region);tags=["daily","hourly","15min"];labels=["Daily","Hourly","15 minutes"];iTag=find(tags==string(request.resolution));assert(isscalar(iTag),'SITE:InitialResolution');
label=char(labels(iTag));if iTag==3,label=R.resolutions{find(contains(string(R.resolutions),"15"),1)};end
assert(ismember(string(label),string(R.resolutions)),'SITE:InitialResolution');X=region_helpers('resolution',core,request.provenance.region,label);
C=struct('region',request.provenance.region,'model',codes(i),'mcode',4,'SAGEhydro',core,'ode',struct(),'loss',struct('fnc',7,'M',2,'n_win',31,'method',1,'observed',{{'Q'}},'fdc',struct('formulation',1)));
C.prd=struct('dt',X.dt,'method','manual','spinup',X.period.spinup_days,'dts',dmy(X.period.manual.train_start),'dte',dmy(X.period.manual.train_end),'des',dmy(X.period.manual.eval_start),'dee',dmy(X.period.manual.eval_end));
% Resolve numerical forcing choices through the trusted registry.
C.meteo=struct('data',1,'pet',1,'precip',NaN,'temp',NaN);keys={'product','pet','precipitation','temperature'};fields={'data','pet','precip','temp'};
for k=1:4
 control=X.meteo.(keys{k});fallback=1;if k>2,fallback=NaN;end;fallback=choice(control.default,fallback);
 selected=fallback;
 if isfield(request.provenance,fields{k}),selected=request.provenance.(fields{k});end
 % Provenance uses dataset-specific names; select a matching provenance below.
 C.meteo.(fields{k})=selected;
end
% Products are registered by their public provenance, not client paths.
products=cellfun(@choice,X.meteo.product.items);pets=cellfun(@choice,X.meteo.pet.items);precips=cellfun(@(s)choice(s,NaN),X.meteo.precipitation.items);temps=cellfun(@(s)choice(s,NaN),X.meteo.temperature.items);found=false;
for a=products(:).',for b=pets(:).',for c=precips(:).',for d=temps(:).'
 meteo=struct('data',a,'pet',b,'precip',c,'temp',d);p=site_result_store('provenance',C.region,meteo);p=rmfield(p,'source');
 if site_benchmark_contract_equal(p,request.provenance),C.meteo=meteo;found=true;break,end
end;if found,break,end;end;if found,break,end;end;if found,break,end;end
assert(found,'SITE:InitialForcing','Forcing/PET choice is not registered.');
P=region_helpers('resolvepaths',R,X,dataRoot);for f={'dirD','dirM','dirQ'},C.(f{1})=P.(f{1});end
count=X.basins.universe(1);name=sprintf(R.basin_file_pattern,count);if isfield(X.basins,'file'),name=X.basins.file;end
C.file_univ=fullfile(region_helpers('regiondir',core,C.region),name);universe=C.file_univ;
mdl=struct('model',C.model,'mcode',4,'calc','seq');if C.model==99,C.user_model_folder=fullfile(fileparts(core),'user_model');if ~isfolder(C.user_model_folder),C.user_model_folder=fullfile(core,'user_model');end;mdl.user_model_folder=C.user_model_folder;end
mdl=read_model(mdl,C.prd,false);mdl=apply_model_configuration(mdl,read_numsettings(struct()));
scratch=tempname;mkdir(scratch);cleanup=onCleanup(@()rmdir(scratch,'s'));refs=zeros(0,1);
s=site_result_store('load',scratch,char(names(i)),char(tags(iTag)),strings(0,1),mdl,1,refs,refs,refs,refs,refs,refs,C.region,C.meteo,C.prd);
contract=site_benchmark_contract(s,C);if isfield(contract.loss,'fnc'),contract.loss=rmfield(contract.loss,'fnc');end
assert(site_benchmark_profile_equal(contract,request),'SITE:InitialDefaults','Experiment differs from GUI defaults.');
end
function v=choice(s,fallback),if nargin<2,fallback=1;end;m=regexp(char(s),'^\s*(\d+)','tokens','once');v=fallback;if ~isempty(m),v=str2double(m{1});end,end
function v=dmy(s),t=datetime(s,'InputFormat','dd/MM/yyyy');v=[day(t) month(t) year(t)];end
