function [payload,report]=site_benchmark_local_reference_check(payload,snapshot,snapshotHash,contextLoader,logFcn,pool)
% Check only contributing basins; transfer one basin per worker job.
clock=tic;
if nargin<6,pool=[];if exist('gcp','file')==2,pool=gcp('nocreate');end,end
report=struct('passed',0,'failed',0,'unseeded',0,'workers',1,'seconds',0);
ids=unique(string({payload.records.basin}));proof=struct('basin',{},'metric',{},'train',{},'evaluation',{});
if isempty(snapshot)
    report.unseeded=numel(ids);payload.records=payload.records([]);report.seconds=toc(clock);return
end
assert(site_benchmark_profile_equal(snapshot.contract,payload.contract),'SITE:ReferenceContract','Reference settings differ.');
metrics=string(payload.contract.metrics);refs=cell(numel(ids),1);results=cell(numel(ids),1);
eligible=false(numel(ids),1);
for b=1:numel(ids)
    refs{b}=snapshot.records(string({snapshot.records.basin})==ids(b));
    eligible(b)=numel(refs{b})==numel(metrics)&&isequal(sort(string({refs{b}.metric})),sort(metrics(:).'));
    if ~eligible(b),results{b}=struct('state','unseeded','rows',proof,'identifier','');end
end
candidateRefs=cell(numel(ids),1);expected=cell(numel(ids),1);
for b=1:numel(ids)
 candidateRefs{b}=payload.records(string({payload.records.basin})==ids(b));expected{b}='';
 if isfield(snapshot,'inputFingerprints')
  h=snapshot.inputFingerprints.records;hit=find(string({h.basin})==ids(b),1);
  assert(~isempty(hit),'SITE:InputChecksumMissing','Trusted input fingerprint is missing');expected{b}=h(hit).sha256;
 end
end
wanted=find(eligible);completed=0;
if ~isempty(pool)&&~isempty(wanted)
    report.workers=min(pool.NumWorkers,numel(wanted));
    logFcn(sprintf('Shared benchmarks: reference checks use %d workers.',report.workers));
    active=parallel.FevalFuture.empty(0,1);activeRows=zeros(0,1);next=1;
    try
        while next<=numel(wanted)||~isempty(active)
            while next<=numel(wanted)&&numel(active)<report.workers
                b=wanted(next);next=next+1;
                try
                    ctx=contextLoader(char(ids(b)));
                    active(end+1,1)=parfeval(pool,@site_benchmark_reference_basin,1,ctx,refs{b},payload.contract,candidateRefs{b},expected{b}); %#ok<AGROW>
                    activeRows(end+1,1)=b; %#ok<AGROW>
                catch ME
                    results{b}=struct('state','failed','rows',proof,'identifier',ME.identifier);
                end
            end
            if isempty(active),continue,end
            [index,value]=fetchNext(active);b=activeRows(index);results{b}=value;
            active(index)=[];activeRows(index)=[];completed=completed+1;
            if completed==1||mod(completed,10)==0||completed==numel(wanted)
                logFcn(sprintf('Shared benchmarks: checked reference basin %d of %d.',completed,numel(wanted)));
            end
            drawnow limitrate nocallbacks
        end
    catch ME
        cancel(active);rethrow(ME);
    end
else
    for b=wanted(:).'
        try,ctx=contextLoader(char(ids(b)));results{b}=site_benchmark_reference_basin(ctx,refs{b},payload.contract,candidateRefs{b},expected{b});
        catch ME,results{b}=struct('state','failed','rows',proof,'identifier',ME.identifier);end
        completed=completed+1;
        if completed==1||mod(completed,10)==0||completed==numel(wanted)
            logFcn(sprintf('Shared benchmarks: checked reference basin %d of %d.',completed,numel(wanted)));
        end
        drawnow limitrate nocallbacks
    end
end
accepted=strings(0,1);candidateProof=proof;fingerprints=struct('basin',{},'sha256',{});
for b=1:numel(ids)
    r=results{b};report.(r.state)=report.(r.state)+1;
    if strcmp(r.state,'passed'),accepted(end+1)=ids(b);proof=[proof r.rows];candidateProof=[candidateProof r.candidateRows];fingerprints(end+1)=struct('basin',char(ids(b)),'sha256',r.fingerprint); %#ok<AGROW>
    elseif strcmp(r.state,'failed')
        if isempty(r.identifier),logFcn(sprintf('Shared benchmarks: reference scores differ for basin %s; its results remain local.',ids(b)));
        else,logFcn(sprintf('Shared benchmarks: reference check failed for basin %s (%s); its results remain local.',ids(b),r.identifier));end
    end
end
payload.records=payload.records(ismember(string({payload.records.basin}),accepted));
payload.localReferenceCheck=struct('schema',2,'mode','local_reference','snapshotSha256',snapshotHash,'records',proof,'candidateRecords',candidateProof,'inputFingerprints',struct('schema',1,'algorithm','sha256-input-v1','records',fingerprints));
report.seconds=toc(clock);
end
