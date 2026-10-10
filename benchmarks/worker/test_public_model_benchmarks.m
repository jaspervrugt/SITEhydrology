function test_public_model_benchmarks()
repo=pwd;sage=fullfile(repo,'worker-work','SAGEhydrology');
addpath(fullfile(sage,'src'),genpath(fullfile(sage,'utils')),fullfile(sage,'models'),fullfile(repo,'utils','results'),fullfile(repo,'benchmarks','worker'));
manifest=jsondecode(fileread(fullfile(repo,'benchmarks','profiles.json')));configs=jsondecode(fileread(fullfile(repo,'benchmarks','worker','worker-config.json')));
dataRoot=fullfile(repo,'worker-data');
destination=fullfile(tempdir,'SITE-public-model-native-test');if ~isfolder(destination),mkdir(destination);end
for k=1:numel(manifest.profiles)
 p=manifest.profiles(k);C=configs.profiles(strcmp({configs.profiles.id},p.id)).run;
 C.SAGEhydro=sage;C.dirD=dataRoot;C.dirM=fullfile(dataRoot,'daily','v1p2','forcing');C.dirQ=fullfile(dataRoot,'daily','v1p2','streamflow');C.file_univ=fullfile(sage,'regions','US','US','US_531_basins.txt');C.meteo.precip=NaN;C.meteo.temp=NaN;
 evalc('loader=site_benchmark_context_batch(C,"1022500");');ctx=loader('1022500');
 assert(strcmp(ctx.configuration.identity,p.contract.configuration),'Default model configuration mismatch: %s',p.contract.model);
 assert(isequal(ctx.mdl.th_min(:),p.contract.thMin(:))&&isequal(ctx.mdl.th_max(:),p.contract.thMax(:)));
 % Simulate once, then independently rerun the same nine submitted metrics.
 x=0.5*ones(numel(ctx.mdl.th_min),1);theta=ctx.mdl.th_min(:)+x.*(ctx.mdl.th_max(:)-ctx.mdl.th_min(:));
 if strcmp(ctx.backend,'cpp'),[~,out]=crr_model_cpp(x,ctx.mdl,ctx.dat,ctx.ode,ctx.loss,crr_request(struct('metrics',true)));else,[~,out]=crr_model(x,ctx.mdl,ctx.dat,ctx.ode,ctx.loss,crr_request(struct('metrics',true)));end
 recordCells=cell(1,numel(p.contract.metrics));
 for j=1:numel(p.contract.metrics)
  name=p.contract.metrics{j};[a,b]=metric(out.metrics,ctx.loss,name);
  recordCells{j}=struct('basin','1022500','metric',name,'train',a,'evaluation',b,'theta',theta.','normalized',x.','optimizedLoss','RSS','optimizer',3,'runtime',1,'updated','2026-10-09T22:00:00','parameterRange',struct('id',1,'thMin',p.contract.thMin,'thMax',p.contract.thMax));
 end
 records=[recordCells{:}];
 payload=struct('schema',1,'profile',p.id,'contract',p.contract,'records',records);
 report=site_benchmark_verify(payload,loader,p);assert(report.scores_verified);
 snapshot=payload;snapshot.records=report.verified_records;snapshot.parameterRanges=records(1).parameterRange;
 file=fullfile(destination,[p.id '.json']);fid=fopen(file,'w');fwrite(fid,jsonencode(snapshot),'char');fclose(fid);
 files=site_benchmark_export_regional(file,destination,sage,fullfile(repo,'benchmarks','worker','worker-config.json'),fullfile(repo,'benchmarks','profiles.json'));assert(numel(files)==4);
 fprintf('Verified and exported %s.\n',p.contract.model);
end
end

function [t,e]=metric(m,loss,name)
switch char(name)
    case 'NSE',t=m.NSEt;e=m.NSEe;
    case 'KGE',t=m.KGEt;e=m.KGEe;
    case 'SAR',t=m.SARt;e=m.SARe;
    case 'RSS',t=m.RSSt;e=m.RSSe;
    case 'Huber',t=m.Hubert;e=m.Hubere;
    case 'JKGE',t=m.JKGEt;e=m.JKGEe;
    case 'S_fdc',t=skill(m.Dfdct,loss.fdc.Q.D0t);e=skill(m.Dfdce,loss.fdc.Q.D0e);
    case 'S_p',t=skill(m.Dpt,loss.fdc.Q.D0pt);e=skill(m.Dpe,loss.fdc.Q.D0pe);
    case 'S_logp',t=skill(m.Dlogpt,loss.fdc.Q.D0logpt);e=skill(m.Dlogpe,loss.fdc.Q.D0logpe);
    otherwise,error('SITE:VerificationMetric','Unapproved metric.');
end
end
function s=skill(d,ref)
if ~isfinite(ref) || ref<=0,s=NaN;else,s=1-d/ref;end
end
