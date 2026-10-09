function receipt=site_benchmark_verify_file(candidatePath,manifestPath,C,receiptPath)
%SITE_BENCHMARK_VERIFY_FILE Trusted numerical worker entry point.
% C and receiptPath are administrator-owned. Never read either from a PR.
assert(isfield(C,'verifierRevision') && strlength(string(C.verifierRevision))>0, ...
    'SITE:VerifierRevision','A pinned verifier revision is required.');
originalPath=path;restore=onCleanup(@()path(originalPath)); %#ok<NASGU>
addpath(fullfile(C.SAGEhydro,'src'),genpath(fullfile(C.SAGEhydro,'utils')), ...
    fullfile(C.SAGEhydro,'models'));
bytes=readBytes(candidatePath);
assert(numel(bytes)<=20*1024*1024,'SITE:VerificationSize','Candidate too large.');
payload=jsondecode(native2unicode(bytes,'UTF-8'));
manifestBytes=readBytes(manifestPath);
manifest=jsondecode(native2unicode(manifestBytes,'UTF-8'));
profile=[];
for i=1:numel(manifest.profiles)
    p=manifest.profiles(i);
    if p.enabled && strcmp(p.id,payload.profile),profile=p;break,end
end
assert(~isempty(profile),'SITE:VerificationProfile','Profile is not approved.');
loader=site_benchmark_context_batch(C,unique(string({payload.records.basin})));
receipt=site_benchmark_verify(payload,loader,profile);
receipt.candidate_sha256=digest(bytes);
receipt.manifest_sha256=digest(manifestBytes);
receipt.verifier_revision=C.verifierRevision;
% Receipts stay in a trusted private work directory, not the contribution.
fid=fopen(receiptPath,'w');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,unicode2native(jsonencode(receipt),'UTF-8'),'uint8');
end

function bytes=readBytes(file)
fid=fopen(file,'rb');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8').';
end
function hash=digest(bytes)
md=java.security.MessageDigest.getInstance('SHA-256');
hash=lower(reshape(dec2hex(typecast(md.digest(bytes),'uint8'),2).',1,[]));
end

