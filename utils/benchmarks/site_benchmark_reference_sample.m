function ids=site_benchmark_reference_sample(snapshot,availableIDs,count)
% Sample across the prepared basin order, excluding incomplete references.
if nargin<3,count=3;end
availableIDs=unique(string(availableIDs(:)),'stable');complete=false(size(availableIDs));metrics=string(snapshot.contract.metrics);
for b=1:numel(availableIDs)
    refs=snapshot.records(string({snapshot.records.basin})==availableIDs(b));
    complete(b)=numel(refs)==numel(metrics)&&isequal(sort(string({refs.metric})),sort(metrics(:).'));
end
ids=availableIDs(complete);
if ~isempty(ids),ids=ids(unique(round(linspace(1,numel(ids),min(count,numel(ids))))));end
end
