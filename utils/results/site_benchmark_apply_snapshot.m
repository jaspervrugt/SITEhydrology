function [merged,report]=site_benchmark_apply_snapshot(store,snapshot)
%SITE_BENCHMARK_APPLY_SNAPSHOT Import numerical records without file writes.
% Caller must first validate the trusted URL, checksum and exact contract.
candidate=store;
candidate.train(:)=NaN;candidate.eval(:)=NaN;
candidate.theta(:)=NaN;candidate.nTheta(:)=NaN;
candidate.updated(:)=NaT;candidate.optimizedLoss(:)="";
candidate.runCount(:)=0;candidate.improvementCount(:)=0;
for k=1:numel(snapshot.records)
    r=snapshot.records(k);
    row=find(string(store.ids)==string(r.basin),1);
    j=find(string(store.metricNames)==string(r.metric),1);
    if isempty(row) || isempty(j),continue,end
    candidate.train(row,j)=r.train;
    if isempty(r.evaluation),candidate.eval(row,j)=NaN;
    else,candidate.eval(row,j)=r.evaluation;end
    candidate.theta(row,:,j)=r.theta(:).';
    candidate.nTheta(row,:,j)=r.normalized(:).';
    candidate.optimizedLoss(row,j)=string(r.optimizedLoss);
    candidate.optimizer(row,j)=r.optimizer;
    candidate.runtime(row,j)=r.runtime;
    candidate.updated(row,j)=datetime(r.updated,'InputFormat','yyyy-MM-dd''T''HH:mm:ss');
end
[merged,report]=site_benchmark_merge(store,candidate);
merged.rangeID(isnan(merged.rangeID) & isfinite(merged.train))=store.currentRangeID;
end
