function site_benchmark_admin_seed(coreRoot,dataRoot,candidatePath,manifestPath,configPath,pinPath,outputRoot,revision)
% Administrator-only bootstrap: recompute the owner-published baseline.
% Never called by the contribution workflow; source bytes are pinned here.
pin=jsondecode(fileread(pinPath));
assert(strcmp(hashFile(candidatePath),pin.sha256),'SITE:BaselinePin','Historical source changed.');
addpath(fullfile(coreRoot,'src'),genpath(fullfile(coreRoot,'utils')),fullfile(coreRoot,'models'),fullfile(coreRoot,'regions','US','US'));
payload=jsondecode(fileread(candidatePath));manifest=jsondecode(fileread(manifestPath));
profile=manifest.profiles(strcmp({manifest.profiles.id},payload.profile));assert(isscalar(profile)&&profile.enabled);
configs=jsondecode(fileread(configPath));C=configs.profiles(strcmp({configs.profiles.id},profile.id)).run;
C.SAGEhydro=coreRoot;C.dirD=dataRoot;C.dirM=fullfile(dataRoot,'daily','v1p2','forcing');C.dirQ=fullfile(dataRoot,'daily','v1p2','streamflow');
C.file_univ=fullfile(coreRoot,'regions','US','US','US_531_basins.txt');
if isempty(C.meteo.precip),C.meteo.precip=NaN;end;if isempty(C.meteo.temp),C.meteo.temp=NaN;end
assert(exist('crr_model_mex','file')==3);
receipt=site_benchmark_verify(payload,@(id)site_benchmark_context(C,id),profile);
assert(receipt.checked==numel(payload.records)&&receipt.checked>0);
assert(all(isfinite([receipt.verified_records.train])),'SITE:BaselineScores','Historical parameters produced nonfinite scores.');
% These are owner baseline values recalculated by the pinned native core,
% not untrusted submitted claims. Preserve the discrepancy report separately.
payload.records=receipt.verified_records;
if ~isfolder(outputRoot),mkdir(outputRoot);end
candidateFile=fullfile(outputRoot,'baseline-candidate.json');writeJson(candidateFile,payload);
receipt.historical_recomputed=true;receipt.historical_mismatches=receipt.mismatches;
receipt.mismatches=strings(0,1);receipt.scores_verified=true;
receipt.candidate_sha256=hashFile(candidateFile);receipt.manifest_sha256=hashFile(manifestPath);receipt.verifier_revision=revision;
writeJson(fullfile(outputRoot,'baseline-receipt.json'),receipt);
fprintf('Trusted baseline recomputed: %d records.\n',receipt.checked);
end
function writeJson(path,value)
fid=fopen(path,'wb');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,unicode2native(jsonencode(value),'UTF-8'),'uint8');
end
function hash=hashFile(path)
fid=fopen(path,'rb');assert(fid>=0);bytes=fread(fid,Inf,'*uint8').';fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');hash=lower(reshape(dec2hex(typecast(md.digest(bytes),'uint8'),2).',1,[]));
end
