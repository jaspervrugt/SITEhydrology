function removed=site_benchmark_cleanup_ui(pendingFile,logFcn)
% Remove only unchanged submission files whose fits are already published.
removed=false;
if ~isfile(pendingFile),return,end
[~,name,ext]=fileparts(pendingFile);
if ~strcmp(ext,'.mat')||~endsWith(name,'_submission'),return,end
try
 before=hashFile(pendingFile);v=load(pendingFile,'submission');s=v.submission;
 if isfield(s,'localCheckedPayload'),s=rmfield(s,'localCheckedPayload');end
 payload=site_benchmark_payload(s);
 manifest=webread('https://raw.githubusercontent.com/jaspervrugt/SITEhydrology/main/benchmarks/profiles.json',weboptions('ContentType','json','Timeout',30));
 approved=[];
 for k=1:numel(manifest.profiles)
  p=manifest.profiles(k);if p.enabled&&site_benchmark_profile_equal(p.contract,payload.contract),approved=p;break,end
 end
 if isempty(approved),return,end
 snapshot=site_benchmark_fetch_snapshot(approved.id);
 if ~site_benchmark_submission_covered(payload,snapshot,approved)||~strcmp(before,hashFile(pendingFile)),return,end
 % The background copy may be older or newer. Check it independently.
 if ispc
  copy=fullfile(getenv('LOCALAPPDATA'),'SITEhydrology','benchmark-sync','pending',[name '.json']);
  if isfile(copy)
   jsonHash=hashFile(copy);other=jsondecode(fileread(copy));
   if isfield(other,'kind')&&strcmp(other.kind,'owner_initial_reference'),other=other.payload;end
   if site_benchmark_submission_covered(other,snapshot,approved)&&strcmp(jsonHash,hashFile(copy)),delete(copy);end
  end
 end
 delete(pendingFile);removed=true;
 site_benchmark_log_ui(logFcn,'Shared benchmarks: published results confirmed; saved submission removed.');
catch
 % Offline, incompatible and partially published requests remain recoverable.
end
end
function h=hashFile(path)
fid=fopen(path,'rb');assert(fid>=0);c=onCleanup(@()fclose(fid));b=fread(fid,Inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');h=lower(reshape(dec2hex(typecast(md.digest(b),'uint8'),2).',1,[]));
end
