function yes=site_benchmark_profile_equal(a,b)
% Bounds vary by fit; every other approved experiment setting stays exact.
for key={'thMin','thMax'}
    if isfield(a,key{1}),a=rmfield(a,key{1});end
    if isfield(b,key{1}),b=rmfield(b,key{1});end
end
yes=site_benchmark_contract_equal(a,b);
end
