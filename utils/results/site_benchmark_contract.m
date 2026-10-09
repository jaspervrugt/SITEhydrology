function contract=site_benchmark_contract(s,C)
%SITE_BENCHMARK_CONTRACT Identity shared by upload and download checks.
contract=struct('schema',1,'model',s.model,'resolution',s.dtTag, ...
    'provenance',s.provenance,'period',s.period.signature, ...
    'configuration',s.configuration.identity,'parNames',s.parNames, ...
    'thMin',s.thMin,'thMax',s.thMax,'metrics',{s.metricNames}, ...
    'maximize',s.maximize);
if isfield(s,'resultVersion'),contract.resultVersion=s.resultVersion;end
% Descriptive GUI labels do not change the forcing or PET product.
if isfield(contract.provenance,'source')
    contract.provenance=rmfield(contract.provenance,'source');
end
if isfield(C,'ode'),settings=C.ode;else,settings=struct();end
contract.ode=read_numsettings(settings);
if isfield(C,'mcode'),contract.mcode=C.mcode;end
if isfield(C,'loss')
    contract.loss=C.loss;
    if isfield(contract.loss,'fnc'),contract.loss=rmfield(contract.loss,'fnc');end
    if ~isfield(contract.loss,'observed'),contract.loss.observed={'Q'};end
end
end
