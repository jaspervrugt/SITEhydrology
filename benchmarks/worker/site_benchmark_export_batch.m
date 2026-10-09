function site_benchmark_export_batch(publicationRoot,coreRoot,configFile)
state=jsondecode(fileread(fullfile(publicationRoot,'publication-state.json')));
if ~state.changed,return,end
index=jsondecode(fileread(fullfile(publicationRoot,'index.json')));
id='camels_us_daily_nldas_pm_hbv_default';entry=index.profiles.(id);
site_benchmark_export_results(fullfile(publicationRoot,entry.path), ...
 fullfile(publicationRoot,'inputs','SITE_hbv_daily_nldas_penman_monteith_p001_checkpoint.mat'), ...
 fullfile(publicationRoot,'inputs','model_master_daily_nldas_penman_monteith_p001.xlsx'), ...
 publicationRoot,coreRoot,configFile);
end
