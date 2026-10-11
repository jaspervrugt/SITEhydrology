function snapshot=site_benchmark_attach_input_checksums(snapshot,profile,catalog)
% Attach owner checksums by dataset/resolution/forcing/period, not model.
if isempty(snapshot),return,end
if isfield(profile,'legacyAttribution'),snapshot.legacyAttribution=profile.legacyAttribution;end
if isfield(profile,'inputFingerprints')
 snapshot.inputFingerprints=profile.inputFingerprints;return
end
if nargin<3
 catalog=webread('https://raw.githubusercontent.com/jaspervrugt/SITEhydrology/main/benchmarks/inputs.json',weboptions('ContentType','json','Timeout',30));
end
identity=struct('resolution',profile.contract.resolution,'provenance',profile.contract.provenance,'period',profile.contract.period);
if isfield(identity.provenance,'source'),identity.provenance=rmfield(identity.provenance,'source');end
assert(catalog.schema==1&&strcmp(catalog.algorithm,'sha256-input-v1'),'SITE:InputChecksumCatalog','Unsupported trusted checksum catalog.');
for k=1:numel(catalog.entries)
 entry=catalog.entries(k);
 if entry.complete&&site_benchmark_contract_equal(entry.identity,identity)
  snapshot.inputFingerprints=entry.inputFingerprints;return
 end
end
error('SITE:InputChecksumUnavailable','Owner input checksums are not registered for this exact dataset, resolution, forcing and default period.');
end
