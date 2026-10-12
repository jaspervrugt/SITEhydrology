function records=site_benchmark_uniform_records(records)
% MATLAB decodes JSON arrays with different optional fields as cells.
if ~iscell(records)||isempty(records),return,end
assert(all(cellfun(@(r)isstruct(r)&&isscalar(r),records)),'SITE:BenchmarkRecords','Invalid records.');
keys={};for k=1:numel(records),keys=union(keys,fieldnames(records{k}));end
for k=1:numel(records)
 for j=1:numel(keys),if ~isfield(records{k},keys{j}),records{k}.(keys{j})=[];end,end
 records{k}=orderfields(records{k},keys);
end
records=reshape([records{:}],size(records));
end
