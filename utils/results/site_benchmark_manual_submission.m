function [path,pending]=site_benchmark_manual_submission(action,value,url)
path='';pending=false;
if strcmp(action,'latest')
 files=dir(fullfile(value,'**','*_submission.mat'));if isempty(files),return,end
 [~,k]=max([files.datenum]);path=fullfile(files(k).folder,files(k).name);pending=true;
 receipt=[path '.upload.json'];
 if isfile(receipt)
  try,r=jsondecode(fileread(receipt));pending=~(strcmp(r.state,'submitted')&&strcmp(r.sha256,fileHash(path)));catch,end
 end
elseif strcmp(action,'submitted')
 if ~isfile(value),return,end
 info=dir(value);receipt=struct('schema',1,'state','submitted','sha256',fileHash(value),'url',url,'bytes',info.bytes,'datenum',info.datenum);
 destination=[value '.upload.json'];temporary=[tempname '.json'];fid=fopen(temporary,'wb');assert(fid>=0);fwrite(fid,unicode2native(jsonencode(receipt),'UTF-8'),'uint8');fclose(fid);movefile(temporary,destination,'f');
else,error('SITE:SubmissionAction','Unknown submission action.');end
end
function hash=fileHash(path)
fid=fopen(path,'rb');assert(fid>=0);c=onCleanup(@()fclose(fid));b=fread(fid,Inf,'*uint8');md=java.security.MessageDigest.getInstance('SHA-256');hash=lower(reshape(dec2hex(typecast(md.digest(b),'uint8'),2).',1,[]));
end
