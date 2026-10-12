function rows=site_benchmark_submission_list(root,region,limit)
% List saved submissions for one selected dataset without loading their stores.
[~,leaf]=fileparts(root);if strcmp(leaf,region),folder=root;else,folder=fullfile(root,region);end
files=dir(fullfile(folder,'**','*_submission.mat'));[~,order]=sort([files.datenum],'descend');files=files(order(1:min(limit,numel(order))));
rows=struct('path',{},'model',{},'saved',{},'resolution',{},'status',{},'url',{});
for k=1:numel(files)
 path=fullfile(files(k).folder,files(k).name);parts=regexp(files(k).name,'^SITE_(.+?)_(daily|hourly|15min)_','tokens','once');model=files(k).name;resolution='';if ~isempty(parts),model=parts{1};resolution=parts{2};end
 status='Awaiting upload';url='';receipt=[path '.upload.json'];
 if isfile(receipt)
  try
   r=jsondecode(fileread(receipt));
   if strcmp(r.state,'submitted')&&isfield(r,'bytes')&&isfield(r,'datenum')&&r.bytes==files(k).bytes&&r.datenum==files(k).datenum&&~isempty(regexp(r.url,'^https://github.com/jaspervrugt/SITEhydrology/pull/[0-9]+$','once')),status='Submitted';url=r.url;end
  catch,end
 end
 rows(end+1)=struct('path',path,'model',model,'saved',datestr(files(k).datenum,'dd mmm yyyy HH:MM'),'resolution',resolution,'status',status,'url',url);
end
end
