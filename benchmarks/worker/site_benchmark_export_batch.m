function site_benchmark_export_batch(publicationRoot,coreRoot,configFile)
state=jsondecode(fileread(fullfile(publicationRoot,'publication-state.json')));
if ~state.changed,return,end
index=jsondecode(fileread(fullfile(publicationRoot,'index.json')));
files={};
for k=1:numel(state.changed_profiles)
    id=state.changed_profiles{k};entry=index.profiles.(id);
    exported=site_benchmark_export_regional(fullfile(publicationRoot,entry.path), ...
        publicationRoot,coreRoot,configFile,fullfile(publicationRoot,'approved-profiles.json'));
    files=[files exported]; %#ok<AGROW>
end
files=unique(files,'stable');
fid=fopen(fullfile(publicationRoot,'result-files.json'),'wb');assert(fid>=0);
cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,unicode2native(jsonencode(files),'UTF-8'),'uint8');
end
