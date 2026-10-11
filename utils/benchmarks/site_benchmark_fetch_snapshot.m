function [snapshot,snapshotHash]=site_benchmark_fetch_snapshot(profile)
% Read an immutable public snapshot, validating its location and checksum.
snapshot=[];snapshotHash='';
assert(~isempty(regexp(profile,'^[a-z][a-z0-9_]{0,99}$','once')), ...
    'SITE:BenchmarkProfile','Invalid profile identifier.');
raw='https://raw.githubusercontent.com/jaspervrugt/SITEhydrology/main/benchmarks/';
try
    index=webread([raw 'index.json'],weboptions('ContentType','json','Timeout',30));
catch e
    if endsWith(e.identifier,'HTTP404StatusCodeError'),return,end
    rethrow(e);
end
if ~isfield(index.profiles,profile),return,end
entry=index.profiles.(profile);
assert(~isempty(regexp(entry.sha256,'^[0-9a-f]{64}$','once')), ...
    'SITE:BenchmarkChecksum','Invalid snapshot checksum.');
expected=['snapshots/' profile '/' entry.sha256 '.json'];
assert(strcmp(entry.path,expected),'SITE:BenchmarkPath','Unexpected snapshot path.');
url=[raw entry.path];
if isfield(entry,'downloadUrl')
    expectedURL=['https://github.com/jaspervrugt/SITEhydrology/releases/download/' ...
        'site-benchmarks/' profile '_' entry.sha256 '.json'];
    assert(strcmp(entry.downloadUrl,expectedURL),'SITE:BenchmarkURL','Unexpected snapshot URL.');
    url=expectedURL;
end
temporary=[tempname '.json'];cleanup=onCleanup(@()removeTemp(temporary)); %#ok<NASGU>
websave(temporary,url,weboptions('Timeout',60));
info=dir(temporary);assert(info.bytes<=20*1024*1024,'SITE:BenchmarkSize','Snapshot too large.');
fid=fopen(temporary,'rb');assert(fid>=0);
bytes=fread(fid,Inf,'*uint8').';fclose(fid);
md=java.security.MessageDigest.getInstance('SHA-256');
hash=lower(reshape(dec2hex(typecast(md.digest(bytes),'uint8'),2).',1,[]));
assert(strcmp(hash,entry.sha256),'SITE:BenchmarkChecksum','Snapshot checksum differs.');
snapshotHash=hash;
snapshot=jsondecode(native2unicode(bytes,'UTF-8'));
assert(snapshot.schema==1 && strcmp(snapshot.profile,profile), ...
    'SITE:BenchmarkProfile','Snapshot profile differs.');
end
function removeTemp(file)
if isfile(file),delete(file);end
end
