function [merged,report]=site_benchmark_apply_snapshot(store,snapshot)
%SITE_BENCHMARK_APPLY_SNAPSHOT Import numerical records without file writes.
% Caller must first validate the trusted URL, checksum and exact contract.
candidate=store;
for key={'contributor','platform'}
 name=key{1};if ~isfield(store,name),store.(name)=repmat("Unknown",size(store.train));end
 candidate.(name)=repmat("Unknown",size(store.train));
end
candidate.train(:)=NaN;candidate.eval(:)=NaN;
candidate.theta(:)=NaN;candidate.nTheta(:)=NaN;
candidate.updated(:)=NaT;candidate.optimizedLoss(:)="";
candidate.runCount(:)=0;candidate.improvementCount(:)=0;candidate.rangeID(:)=NaN;
rangeFile=fullfile(store.resultDir,sprintf('param_ranges_%s_%s.csv',store.model,store.dtTag));
if isfield(store,'rangeFile'),rangeFile=store.rangeFile;end
candidate.rangeFile=rangeFile;
for k=1:numel(snapshot.records)
    r=snapshot.records(k);
    row=find(string(store.ids)==string(r.basin),1);
    j=find(string(store.metricNames)==string(r.metric),1);
    if isempty(row) || isempty(j),continue,end
    candidate.train(row,j)=r.train;
    if isempty(r.evaluation),candidate.eval(row,j)=NaN;
    else,candidate.eval(row,j)=r.evaluation;end
    candidate.theta(row,:,j)=r.theta(:).';
    if isfield(r,'parameterRange') && ~isempty(r.parameterRange)
        bounds=r.parameterRange;
    else
        bounds=struct('thMin',snapshot.contract.thMin,'thMax',snapshot.contract.thMax);
    end
    candidate.rangeID(row,j)=get_or_register_param_range(rangeFile,store.parNames,bounds.thMin,bounds.thMax);
    candidate.nTheta(row,:,j)=((r.theta(:)-bounds.thMin(:))./(bounds.thMax(:)-bounds.thMin(:))).';
    candidate.optimizedLoss(row,j)=string(r.optimizedLoss);
    candidate.optimizer(row,j)=r.optimizer;
    candidate.runtime(row,j)=r.runtime;
    for counter={'runCount','improvementCount','contributor','platform'}
        key=counter{1};candidate.(key)(row,j)=store.(key)(row,j);
        if isfield(r,key) && ~isempty(r.(key))
            if ismember(key,{'contributor','platform'}),candidate.(key)(row,j)=string(r.(key));else,candidate.(key)(row,j)=r.(key);end
        end
        if (~isfield(r,key)||isempty(r.(key))) && ismember(key,{'contributor','platform'}) && isfield(snapshot,'legacyAttribution') && isfield(snapshot.legacyAttribution,key)
            candidate.(key)(row,j)=string(snapshot.legacyAttribution.(key));
        end
    end
    candidate.updated(row,j)=datetime(r.updated,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
end
[merged,report]=site_benchmark_merge(store,candidate);
merged.rangeFile=rangeFile;
end
