function same=site_benchmark_contract_equal(a,b)
% Compare experiment values independently of JSON array orientation,
% string/cell representation and nested struct field order.
a=orderValue(jsondecode(jsonencode(a)));
b=orderValue(jsondecode(jsonencode(b)));
same=isequaln(a,b);
end
function value=orderValue(value)
if isstruct(value)
    value=orderfields(value); keys=fieldnames(value);
    for k=1:numel(value)
        for i=1:numel(keys),value(k).(keys{i})=orderValue(value(k).(keys{i}));end
    end
elseif iscell(value)
    for i=1:numel(value),value{i}=orderValue(value{i});end
end
end
