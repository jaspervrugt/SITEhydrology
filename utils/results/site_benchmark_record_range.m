function range=site_benchmark_record_range(s,row,column)
% Resolve a local ID to actual bounds, never infer a foreign ID's meaning.
if isfield(s,'currentRangeID'),current=s.currentRangeID;else,current=1;end
id=s.rangeID(row,column);if ~isfinite(id),id=current;end
assert(isscalar(id)&&id>=1&&id==fix(id),'SITE:BenchmarkRange','Invalid range ID.');
name=sprintf('param_ranges_%s_%s.csv',s.model,s.dtTag);
file='';
if isfield(s,'rangeFile') && isfile(s.rangeFile),file=s.rangeFile;end
folder='';if isfield(s,'resultDir'),folder=s.resultDir;end
for depth=1:6
    if ~isempty(file),break,end
    candidate=fullfile(folder,name);if isfile(candidate),file=candidate;break,end
    parent=fileparts(folder);if strcmp(parent,folder),break,end;folder=parent;
end
if ~isempty(file)
    persistent tables
    if isempty(tables),tables=containers.Map('KeyType','char','ValueType','any');end
    stamp=dir(file);signature=[stamp.datenum stamp.bytes];
    if isKey(tables,file),cached=tables(file);else,cached=struct('signature',[]);end
    if ~isequal(cached.signature,signature)
        cached=struct('signature',signature,'table',readtable(file,'TextType','string'));tables(file)=cached;
    end
    T=cached.table;T=T(T.range_id==id,:);[~,order]=sort(T.n_par);T=T(order,:);
    assert(height(T)==numel(s.parNames)&&isequal(string(T.symbol(:)),string(s.parNames(:))), ...
        'SITE:BenchmarkRange','Range registry does not contain the fit''s bounds.');
    lo=T.th_min(:);hi=T.th_max(:);
else
    assert(id==current,'SITE:BenchmarkRange','Historical range registry is missing.');
    lo=s.thMin(:);hi=s.thMax(:);
end
assert(all(isfinite(lo)&isfinite(hi)&lo<hi),'SITE:BenchmarkRange','Invalid bounds.');
range=struct('id',id,'thMin',lo,'thMax',hi);
end
