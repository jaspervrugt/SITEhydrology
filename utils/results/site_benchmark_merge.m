function [merged,report] = site_benchmark_merge(globalStore,candidate)
%SITE_BENCHMARK_MERGE Merge strict training improvements without file writes.
% Publication callers must additionally validate the approved experiment
% contract, numerical settings and submission authorization.
required = {'model','dtTag','provenance','period','configuration', ...
    'parNames','thMin','thMax','metricNames','maximize','ids', ...
    'train','eval','theta','nTheta','optimizedLoss','optimizer', ...
    'runtime','updated','rangeID','runCount','improvementCount'};
assert(all(isfield(candidate,required)),'SITE:BenchmarkSchema', ...
    'Candidate has an incomplete result schema.');
validate(candidate);
assert(~candidate.configuration.changed,'SITE:BenchmarkNonDefault', ...
    'Changed initial states or additional values are not shared.');
if isempty(globalStore)
    % A first contribution establishes data, not an approved default profile.
    merged=candidate;
    valid=validCells(candidate);
    % Do not seed a global file with unfinished or invalid candidate slots.
    for j=1:numel(candidate.metricNames)
        bad=~valid(:,j);
        merged.train(bad,j)=NaN; merged.eval(bad,j)=NaN;
        merged.theta(bad,:,j)=NaN; merged.nTheta(bad,:,j)=NaN;
        merged.optimizedLoss(bad,j)=""; merged.updated(bad,j)=NaT;
        merged.optimizer(bad,j)=NaN; merged.runtime(bad,j)=NaN;
        merged.runCount(bad,j)=0; merged.improvementCount(bad,j)=0;
    end
    merged.rangeID(~valid)=NaN;
    report=struct('improvements',nnz(valid), ...
        'newBasins',numel(candidate.ids),'firstFile',true);
    return
end
assert(all(isfield(globalStore,required)),'SITE:BenchmarkSchema', ...
    'Global benchmark has an incomplete result schema.');
validate(globalStore);
identity={'model','dtTag','provenance','parNames', ...
    'metricNames','maximize'};
for i=1:numel(identity)
    key=identity{i};
    assert(isequaln(globalStore.(key),candidate.(key)), ...
        'SITE:BenchmarkMismatch','Benchmark mismatch: %s.',key);
end
assert(isequaln(globalStore.period.signature,candidate.period.signature) ...
    && strcmp(globalStore.configuration.identity,candidate.configuration.identity), ...
    'SITE:BenchmarkMismatch','Period or model configuration differs.');
assert(isfield(globalStore,'resultVersion')==isfield(candidate,'resultVersion'), ...
    'SITE:BenchmarkMismatch','Model revision metadata differs.');
if isfield(candidate,'resultVersion')
    assert(isequaln(globalStore.resultVersion,candidate.resultVersion), ...
        'SITE:BenchmarkMismatch','Model revision differs.');
end
% Full basin universe is fixed by the approved manifest; a submission can be
% a subset, but cannot invent or append basin IDs.
[found,rows]=ismember(string(candidate.ids),string(globalStore.ids));
assert(all(found),'SITE:BenchmarkUnknownBasin','Unknown basin in submission.');
merged=globalStore;
report=struct('improvements',0,'newBasins',0,'firstFile',false);
valid=validCells(candidate);
paired={'train','eval','optimizedLoss','optimizer','runtime','updated', ...
    'runCount','improvementCount'};
for k=1:numel(rows)
    r=rows(k);
    for j=1:numel(candidate.metricNames)
        a=candidate.train(k,j); b=merged.train(r,j);
        better=~isfinite(b) || (candidate.maximize(j) && a>b) ...
            || (~candidate.maximize(j) && a<b);
        if ~valid(k,j) || ~better, continue, end
        for f=1:numel(paired)
            key=paired{f}; merged.(key)(r,j)=candidate.(key)(k,j);
        end
        merged.theta(r,:,j)=candidate.theta(k,:,j);
        merged.nTheta(r,:,j)=candidate.nTheta(k,:,j);
        % rangeID is a local registry reference; never copy a foreign ID.
        merged.rangeID(r,j)=candidate.rangeID(k,j);
        report.improvements=report.improvements+1;
    end
end
end

function validate(s)
K=numel(s.ids); M=numel(s.metricNames); d=numel(s.parNames);
assert(numel(unique(string(s.ids)))==K,'SITE:BenchmarkDuplicateID', ...
    'Duplicate basin IDs.');
fields={'train','eval','optimizedLoss','optimizer','runtime','updated', ...
    'rangeID','runCount','improvementCount'};
for i=1:numel(fields)
    assert(isequal(size(s.(fields{i})),[K M]),'SITE:BenchmarkShape', ...
        'Invalid dimensions: %s.',fields{i});
end
assert(size(s.theta,1)==K && size(s.theta,2)==d && size(s.theta,3)==M ...
    && isequal(size(s.theta),size(s.nTheta)) ...
    && numel(s.maximize)==M && numel(s.thMin)==d && numel(s.thMax)==d, ...
    'SITE:BenchmarkShape','Invalid parameter dimensions.');
end

function valid=validCells(s)
valid=isfinite(s.train) & ~isnat(s.updated) & strlength(s.optimizedLoss)>0;
for j=1:numel(s.metricNames)
    for k=find(valid(:,j)).'
        bounds=site_benchmark_record_range(s,k,j);
        theta=s.theta(k,:,j).';x=s.nTheta(k,:,j).';
        valid(k,j)=all(isfinite(theta)&isfinite(x)) && ...
            all(theta>=bounds.thMin & theta<=bounds.thMax) && all(x>=0 & x<=1);
    end
end
end
