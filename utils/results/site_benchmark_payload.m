function payload=site_benchmark_payload(submission)
%SITE_BENCHMARK_PAYLOAD Export only numerical records and public provenance.
% Never upload local paths, run configuration directories, or MAT objects.
s=submission.store;
[clean,~]=site_benchmark_merge([],s);
record=struct('basin','','metric','','train',0,'evaluation',0, ...
    'theta',[],'normalized',[],'optimizedLoss','','optimizer',0, ...
    'runtime',0,'updated','','parameterRange',struct());
records=repmat(record,0,1);
for k=1:numel(clean.ids)
    for j=1:numel(clean.metricNames)
        if ~isfinite(clean.train(k,j)),continue,end
        r=record; r.basin=char(string(clean.ids(k)));
        r.metric=char(string(clean.metricNames{j}));
        r.train=clean.train(k,j); r.evaluation=clean.eval(k,j);
        r.theta=clean.theta(k,:,j);
        r.parameterRange=site_benchmark_record_range(s,k,j);
        r.normalized=(r.theta(:)-r.parameterRange.thMin(:))./(r.parameterRange.thMax(:)-r.parameterRange.thMin(:));
        r.optimizedLoss=char(clean.optimizedLoss(k,j));
        r.optimizer=clean.optimizer(k,j); r.runtime=clean.runtime(k,j);
        % Keep the recorded local time without inventing a timezone.
        r.updated=char(string(clean.updated(k,j),'yyyy-MM-dd''T''HH:mm:ss'));
        records(end+1,1)=r; %#ok<AGROW>
    end
end
contract=submission.contract;
if isfield(contract,'loss') && isfield(contract.loss,'fnc')
    contract.loss=rmfield(contract.loss,'fnc');
end
payload=struct('schema',1,'origin','SITE_compiled_GUI', ...
    'contract',contract,'records',records);
end
