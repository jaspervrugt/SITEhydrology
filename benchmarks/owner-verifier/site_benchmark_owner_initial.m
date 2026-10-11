function site_benchmark_owner_initial(phase,job,core,dataRoot)
% Owner code and data only. Contributor JSON supplies numerical claims.
here=fileparts(mfilename('fullpath'));site=fullfile(fileparts(core),'SITEhydrology');addpath(here,genpath(fullfile(site,'utils')));
if strcmp(phase,'prepare')
 envelope=jsondecode(fileread(fullfile(job,'envelope.json')));request=envelope.payload;
 [contract,C,universe]=site_benchmark_initial_defaults(request.contract,core,dataRoot);
 bas=struct('sample','file','sort_by_gauge',true,'K',1,'K_t',1,'K_e',0);[~,ids,names,zones]=read_attr(C.region,C.dirD,bas);bas=rmfield(bas,'K');
 [~,bas]=sample_basins([],ids,bas,C.prd,names,zones,C.dirD,universe,universe);
 manifest=jsondecode(fileread(fullfile(job,'profiles-before.json')));profile=[];
 for k=1:numel(manifest.profiles),p=manifest.profiles(k);if p.enabled&&site_benchmark_profile_equal(p.contract,contract),profile=p;break,end,end
 if isempty(profile)
  hash=sha(unicode2native(jsonencode(contract),'UTF-8'));profile=struct('id',['initial_' hash(1:32)],'enabled',true,'contract',contract,'basinIds',string(bas.id_gauge(:)));
 end
 candidate=request;candidate.contract=profile.contract;candidate.profile=profile.id;
 if isfield(candidate,'localReferenceCheck'),candidate=rmfield(candidate,'localReferenceCheck');end
 % The client keeps the actual bounds for each fit; default bounds identify the model.
 for k=1:numel(candidate.records)
  if ~isfield(candidate.records(k),'parameterRange'),candidate.records(k).parameterRange=struct('id',1,'thMin',request.contract.thMin,'thMax',request.contract.thMax);end
 end
 write(fullfile(job,'candidate.json'),candidate);write(fullfile(job,'owner-profile.json'),profile);write(fullfile(job,'manifest.json'),struct('schema',1,'profiles',profile));
 save(fullfile(job,'owner-context.mat'),'C');return
end
assert(strcmp(phase,'verify'),'SITE:OwnerPhase');v=load(fullfile(job,'owner-context.mat'),'C');C=v.C;
candidate=jsondecode(fileread(fullfile(job,'candidate.json')));profile=jsondecode(fileread(fullfile(job,'owner-profile.json')));envelope=jsondecode(fileread(fullfile(job,'envelope.json')));
ids=unique(string({candidate.records.basin}));loader=site_benchmark_local_context(C,ids);contexts=cell(numel(ids),1);pieces=contexts;hashes=contexts;results=contexts;
fingerprints=envelope.inputFingerprints.records;
for k=1:numel(ids)
 contexts{k}=loader(char(ids(k)));pieces{k}=candidate.records(string({candidate.records.basin})==ids(k));h=find(string({fingerprints.basin})==ids(k));assert(isscalar(h),'SITE:OwnerFingerprint');hashes{k}=fingerprints(h).sha256;
 if isfield(profile,'inputFingerprints')&&isfield(profile.inputFingerprints,'records')
  approved=profile.inputFingerprints.records;hit=find(string({approved.basin})==ids(k));
  if ~isempty(hit),assert(isscalar(hit)&&strcmp(approved(hit).sha256,hashes{k}),'SITE:OwnerVerificationFailed','Registered input checksums differ.');end
 end
end
pool=parpool('Processes',min(4,numel(ids)));cleanup=onCleanup(@()delete(pool)); %#ok<NASGU>
parfor k=1:numel(ids),results{k}=site_benchmark_reference_basin(contexts{k},pieces{k}([]),profile.contract,pieces{k},hashes{k});end
assert(all(cellfun(@(r)strcmp(r.state,'passed'),results)),'SITE:OwnerVerificationFailed','Input checksums or submitted metrics differ from owner data.');
verified=candidate.records;
for k=1:numel(ids)
 rows=find(string({candidate.records.basin})==ids(k));proof=results{k}.candidateRows;
 for j=1:numel(rows),verified(rows(j)).train=proof(j).train;verified(rows(j)).evaluation=proof(j).evaluation;end
end
receipt=struct('schema',1,'profile',profile.id,'scores_verified',true,'checked',numel(verified),'verified_records',verified,'candidate_sha256',sha(bytes(fullfile(job,'candidate.json'))),'manifest_sha256',sha(bytes(fullfile(job,'manifest.json'))),'verifier_revision',char(getenv('SITE_OWNER_REVISION')),'verification_mode','independent');
profile.inputFingerprints=struct('schema',1,'algorithm','sha256-input-v1','records',struct('basin',{},'sha256',{}));
for k=1:numel(ids),profile.inputFingerprints.records(end+1)=struct('basin',char(ids(k)),'sha256',results{k}.fingerprint);end
write(fullfile(job,'owner-profile.json'),profile);write(fullfile(job,'receipt.json'),receipt);
end
function write(file,value),fid=fopen(file,'wb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fwrite(fid,unicode2native(jsonencode(value),'UTF-8'),'uint8');end
function b=bytes(file),fid=fopen(file,'rb');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));b=fread(fid,Inf,'*uint8').';end
function h=sha(b),md=java.security.MessageDigest.getInstance('SHA-256');h=lower(reshape(dec2hex(typecast(md.digest(b),'uint8'),2).',1,[]));end
