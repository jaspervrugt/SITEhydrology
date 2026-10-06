function output = run_SITE(C)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%RUN_SITE Independently calibrate one hydrologic model for every basin.
%
%  Uses SAGEhydrology readers and differentiable models without sharing
%  information among basins. Scores each optimum with SITE diagnostics.
%
% SYNOPSIS:
%   output = run_SITE(C)
%
% INPUT ARGUMENTS:
%   C               SITE run configuration, paths, and optional UI callbacks
%
% OUTPUT ARGUMENTS:
%   output          calibrated results, model, basins, and run metadata
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    arguments
        C struct
    end

    % Optional SITE_ui callbacks. Command-line use remains unchanged when
    % C.ui is absent.
    ui = local_get(C,'ui',struct());
    setupClock = tic;
    required = {'root','region','dirD','dirM','dirQ','file_univ', ...
        'model','prd','meteo','loss','alg'};
    for i = 1:numel(required)
        if ~isfield(C,required{i})
            error('SITE:MissingConfiguration', ...
                'Configuration field C.%s is required.',required{i});
        end
    end
    optimizerOpts = local_get(C.alg,'opts',[]);
    % The calibrator reads user overrides from alg.options; its seventh
    % argument is reserved for starting points, not optimizer settings.
    C.alg.options = optimizerOpts;
    
    siteRoot = local_get(C,'SITEhydro', ...
        fullfile(C.root,'SITEhydrology'));
    sageRoot = local_get(C,'SAGEhydro', ...
        fullfile(C.root,'SAGEhydrology'));
    resultRoot = local_get(C,'resultDir', ...
        fullfile(siteRoot,'results'));
    if ~isdeployed
        addpath(fullfile(siteRoot,'src'), ...
            fullfile(siteRoot,'utils','optim'), ...
            fullfile(siteRoot,'utils','results'));
        addpath(fullfile(sageRoot,'utils'));
    end
    % SAGE and SITE need not share a common parent. bootstrap_SAGE still
    % accepts the parent of the selected SAGEhydrology installation.
    bootstrap_SAGE(fileparts(sageRoot),C.region,resultRoot);
    
    useGchmOde = strcmpi(string(C.model),'gchm_ode');
    mdl = struct();
    if useGchmOde
        mdl.model = 11;
        mdl.variant = 'gchm_ode';
        if ~isdeployed
            addpath(fullfile(sageRoot,'private','gchm'));
            addpath(fullfile(sageRoot,'private','gchm_ode'));
        end
    else
        mdl.model = C.model;
    end
    mdl.mcode = local_get(C,'mcode',4);
    mdl.calc = 'seq';
    mdl.names = ["hymod","hmodel","sacsma", ...
        "Xinanjiang","gr4jA","hbv","cfe_nwm", ...
        "gchm","user_model"];
    
    ode = local_get(C,'ode',struct());
    ode = read_numsettings(ode);
    misc = struct('meteo',C.meteo);
    if useGchmOde
        if mdl.mcode == 4 ...
                && exist('crr_gchm_ode','file') ~= 3
            error('SITE:GCHMOdeMissingMex', ...
                ['Compile private/gchm_ode/' ...
                'crr_gchm_ode before running SITE.']);
        end
        misc.crr_backend = 'matlab';
        status = 'standalone gchm_ode';
    else
        [mdl,misc,status] = crr_prepare_backend(mdl,misc);
    end
    fprintf('SITE backend: %s.\n',status);
    local_ui_log(ui,sprintf('(01) CRR backend ... %s.',status));
    if useGchmOde
        [mdl,d] = read_gchm_ode_info(mdl,C.prd);
    else
        [mdl,d] = read_model(mdl,C.prd);
    end
    if isfield(C,'parOverride') ...
            && ~isempty(C.parOverride)
        mdl = apply_parameter_override( ...
            mdl,C.parOverride,mdl.model,C.prd.dt);
    end
    if isfield(C,'th_min') ...
            && ~isempty(C.th_min)
        mdl.th_min = C.th_min(:);
    end
    if isfield(C,'th_max') ...
            && ~isempty(C.th_max)
        mdl.th_max = C.th_max(:);
    end
    if numel(mdl.th_min) ~= d ...
            || numel(mdl.th_max) ~= d ...
            || any(~isfinite(mdl.th_min)) ...
            || any(~isfinite(mdl.th_max)) ...
            || any(mdl.th_min >= mdl.th_max)
        error('SITE:BadParameterRanges', ...
            ['Parameter bounds must be finite %d-vectors with ' ...
            'each lower bound smaller than its upper bound.'],d);
    end

    % Resolve and approve a same-name model schema replacement before
    % loading basin data or modifying any result registry/workbook.
    dtTag = local_dt_tag(C.prd.dt);
    if useGchmOde
        modelName = 'gchm_ode';
    else
        modelName = lower(char(sage_model_name(mdl.model)));
    end
    resultDir = local_get(C,'resultDir',fullfile(siteRoot,'results'));
    [~,resultRegion] = fileparts(char(resultDir));
    if ~strcmpi(resultRegion,char(C.region))
        resultDir = fullfile(resultDir,char(C.region));
    end
    rangeFile = fullfile(resultDir,sprintf( ...
        'param_ranges_%s_%s.csv',modelName,dtTag));
    schemaChange = local_parameter_schema_change( ...
        rangeFile,mdl.par_names);
    if schemaChange.changed
        proceed = local_confirm_schema_replacement(ui, ...
            modelName,schemaChange);
        if ~proceed
            error('SITE:RunCancelled', ...
                ['SITE run cancelled before replacing the existing ' ...
                '%s result files.'],upper(modelName));
        end
    end
    revisionChange = local_result_revision_change(resultDir,modelName, ...
        dtTag,C.region,C.meteo,C.prd,mdl);
    if revisionChange.changed
        proceed = local_confirm_revision_replacement(ui, ...
            modelName,revisionChange);
        if ~proceed
            error('SITE:RunCancelled', ...
                ['SITE run cancelled before replacing the existing ' ...
                '%s result files.'],upper(modelName));
        end
    end
    
    bas = struct('sample','file');
    bas.K = local_count_ids(C.file_univ);
    bas.K_t = bas.K;
    bas.K_e = 0;
    dataClock = tic;
    local_ui_log(ui,'(02) read basin attributes ...');
    [~,allIDs,gname,zone] = read_attr(C.region,C.dirD,bas);
    local_ui_log(ui,'(03) select basins ...');
    [~,bas] = sample_basins([],allIDs,bas,C.prd,gname,zone, ...
        C.dirD,C.file_univ,C.file_univ);
    
    if isfield(C,'basinNumbers') ...
            && ~isempty(C.basinNumbers)
        wanted = C.basinNumbers(:);
        if any(wanted < 1 ...
                | wanted > bas.K ...
                | mod(wanted,1) ~= 0)
            error('SITE:BadBasinNumbers', ...
                'C.basinNumbers is out of range.');
        end
    else
        wanted = (1:bas.K).';
    end
    
    local_ui_log(ui,'(04) build train/eval time split ...');
    [split,mdl] = build_split(mdl,C.prd,bas);
    meteoRead = C.meteo;
    progressf = [];
    if isstruct(ui) && isfield(ui,'logProgressFcn') ...
            && isa(ui.logProgressFcn,'function_handle')
        progressf = ui.logProgressFcn;
    end
    if ~isempty(progressf)
        K = bas.K;
        progressf(sprintf( ...
            '(05) read meteorological data ... [0/%d,  0.0%% done]',K),true);
        meteoRead.progressFcn = @(k) progressf(sprintf( ...
            '(05) read meteorological data ... [%d/%d,%5.1f%% done]', ...
            k,K,100*k/K),false);
    else
        local_ui_log(ui,'(05) read meteorological data ...');
    end
    [dat,aux] = read_meteo(C.region,C.dirM,bas,split,meteoRead);
    if ~isempty(progressf)
        progressf(sprintf( ...
            '(05) read meteorological data ... [%d/%d,100.0%% done]',K,K),false);
        progressf('(05) read meteorological data ... ','finish');
    end
    basRead = bas;
    if ~isempty(progressf)
        progressf(sprintf( ...
            '(06) read discharge data ... [0/%d,  0.0%% done]',K),true);
        basRead.progressFcn = @(k) progressf(sprintf( ...
            '(06) read discharge data ... [%d/%d,%5.1f%% done]', ...
            k,K,100*k/K),false);
    else
        local_ui_log(ui,'(06) read discharge data ...');
    end
    dat = read_Q(C.region,C.dirQ,mdl,dat,basRead,split,aux);
    if ~isempty(progressf)
        progressf(sprintf( ...
            '(06) read discharge data ... [%d/%d,100.0%% done]',K,K),false);
        progressf('(06) read discharge data ... ','finish');
    end
    local_ui_log(ui,'(07) check data consistency ...');
    [eligibility,dat] = check_basins(dat,mdl,bas);

    % Mirror SAGE's data-quality summary in SITE_ui and restrict the
    % calibration queue to basins that passed the same consistency checks.
    try
        quality = summarize_hydro_quality(dat,bas,split);
        quality.eligible = eligibility.valid;
        quality.exclusion_reason = eligibility.reason;
        quality.coverage_q_train = eligibility.coverage_q_train;
        quality.coverage_q_eval = eligibility.coverage_q_eval;
        quality.runoff_ratio_train = eligibility.runoff_ratio_train;
        quality.runoff_ratio_eval = eligibility.runoff_ratio_eval;
        quality.hydrologic_alert = eligibility.hydrologic_alert;
        quality.documented_exclusion = eligibility.documented_exclusion;
        quality.minimum_q_coverage = eligibility.minimum_q_coverage;
        local_ui_call(ui,'qualityFcn',quality);
    catch qualityException
        local_ui_log(ui,['SITE data-quality dashboard warning: ' ...
            qualityException.message]);
    end
    try
        validWanted = logical(eligibility.valid(wanted));
        nExcluded = nnz(~validWanted);
        wanted = wanted(validWanted);
        if nExcluded > 0
            local_ui_log(ui,sprintf( ...
                '    SITE data-quality screening excluded %d requested basin(s).', ...
                nExcluded));
        end
        if isempty(wanted)
            error('SITE:NoEligibleBasins', ...
                'No requested basin passed data-quality screening.');
        end
    catch screeningException
        if strcmp(screeningException.identifier,'SITE:NoEligibleBasins')
            rethrow(screeningException)
        end
        local_ui_log(ui,['SITE eligibility filtering warning: ' ...
            screeningException.message]);
    end
    
    % Prepare all cached statistics, including JKGE and FDC, once.
    local_ui_log(ui,'(08) prepare diagnostic statistics ...');
    diagnosticLoss = C.loss;
    diagnosticLoss.fnc = 7;
    [dat,diagnosticLoss] = prep_stats(dat,mdl,split,diagnosticLoss);
    dataSeconds = toc(dataClock);
    local_ui_timing(ui,'data',dataSeconds);
    loss = diagnosticLoss;
    loss.fnc = C.loss.fnc;
    jkgeUsesDefault = loss.M == 2 && loss.method == 1 ...
        && loss.n_win == 31;
    if ~jkgeUsesDefault
        local_ui_log(ui,[ ...
            'WARNING: Non-default JKGE settings are active. ' ...
            'JKGE scores and JKGE completed-run counts will not be ' ...
            'written to the version 1 result workbooks. A future ' ...
            'release will store separate JKGE configurations.']);
    end
    
    if ~isfolder(resultDir)
        [made,message] = mkdir(resultDir);
        if ~made
            error('SITE:CannotCreateResultsDirectory', ...
                'Cannot create results directory %s: %s', ...
                resultDir,message);
        end
    end
    ids = string(bas.id_gauge(:));
    rangeID = get_or_register_param_range(rangeFile, ...
        mdl.par_names,mdl.th_min,mdl.th_max);
    local_ui_log(ui,'(09) load SITE results ...');
    store = site_result_store('load',resultDir,modelName, ...
        dtTag,ids,mdl,rangeID,diagnosticLoss.fdc.Q.D0t, ...
        diagnosticLoss.fdc.Q.D0e,diagnosticLoss.fdc.Q.D0pt, ...
        diagnosticLoss.fdc.Q.D0pe,diagnosticLoss.fdc.Q.D0logpt, ...
        diagnosticLoss.fdc.Q.D0logpe,C.region,C.meteo,C.prd);
    local_ui_log(ui,sprintf( ...
        '    SITE checkpoint: %d/%d basins already have scores | %s', ...
        nnz(any(isfinite(store.train),2)),numel(store.ids), ...
        store.fileMat));
    local_ui_call(ui,'storeFcn',store,bas);
    local_ui_timing(ui,'init',max(0,toc(setupClock)-dataSeconds));
    
    lossNames = {'SAR','RSS','NSE','KGE','Huber','FDC','JKGE'};
    if loss.fnc == 6
        fdcLetters = 'abc';
        lossNames{6} = ['FDC-6' fdcLetters(loss.fdc.formulation)];
    end
    saveEvery = local_get(C,'saveEvery',1);
    useParallel = local_get(C,'parallel',false);
    trainClock = tic;
    if useParallel
        [store,pool] = local_run_parallel(C,wanted,bas,ids,dat, ...
            mdl,ode,loss,misc,store,lossNames,saveEvery,trainClock);
    else
        pool = [];
        for ii = 1:numel(wanted)
            if local_ui_should_stop(ui)
                local_ui_log(ui,'SITE stop requested; sequential queue stopped.');
                break
            end
            k = wanted(ii);
            guiClock = tic;
            local_ui_progress(ui,'Calibrating',ii,numel(wanted));
            guiSeconds = toc(guiClock);
            result = calibrate_basin_SITE(mdl,dat{k},ode,loss, ...
                C.alg,misc);
            store = site_result_store('update',store,k,result, ...
                lossNames{loss.fnc},C.alg.method,loss);
            guiClock = tic;
            local_ui_iter(ui,sprintf('Completed basin %d/%d: %s', ...
                ii,numel(wanted),ids(k)));
            local_ui_result(ui,k,result,store,mdl,bas,ids);
            local_ui_timing(ui,'train',toc(trainClock));
            local_ui_gui_time(ui,k,guiSeconds+toc(guiClock),bas.K);
            if mod(ii,saveEvery) == 0 ...
                    || ii == numel(wanted)
                store = site_result_store('save',store);
            end
        end
    end
    local_ui_timing(ui,'train',toc(trainClock));
    
    output = struct('store',store, ...
        'mdl',mdl, ...
        'bas',bas, ...
        'prd',C.prd, ...
        'loss',loss, ...
        'alg',C.alg, ...
        'resultDir',resultDir, ...
        'parameterCount',d, ...
        'parallel',useParallel, ...
        'pool',pool, ...
        'eligibility',eligibility);
end

function change = local_parameter_schema_change(rangeFile,parNames)
change = struct('changed',false,'oldCounts',zeros(0,1), ...
    'newCount',numel(parNames),'rangeFile',rangeFile);
if ~isfile(rangeFile), return, end
try
    T = readtable(rangeFile,'TextType','string');
    required = {'range_id','n_par','symbol'};
    if ~all(ismember(required,T.Properties.VariableNames)) || isempty(T)
        return
    end
    ids = unique(double(T.range_id(:))).';
    expected = string(parNames(:));
    counts = zeros(numel(ids),1);
    matching = false;
    for k = 1:numel(ids)
        Ti = T(double(T.range_id) == ids(k),:);
        [~,order] = sort(double(Ti.n_par));
        Ti = Ti(order,:);
        counts(k) = height(Ti);
        if height(Ti) == numel(expected) ...
                && isequal(string(Ti.symbol(:)),expected)
            matching = true;
        end
    end
    change.changed = ~matching;
    change.oldCounts = unique(counts);
catch exception
    warning('SITE:SchemaInspectionFailed', ...
        'Could not inspect %s before the run: %s', ...
        rangeFile,exception.message);
end
end

function proceed = local_confirm_schema_replacement(ui,modelName,change)
oldText = strjoin(string(change.oldCounts(:).'),', ');
message = sprintf([ ...
    'Model %s already has SITE results with a different parameter ' ...
    'schema (%s parameters; current model: %d). Continuing will replace ' ...
    'the existing XLS/MAT results for this exact model name.'], ...
    upper(modelName),oldText,change.newCount);
local_ui_log(ui,['WARNING: ' message]);
if isstruct(ui) && isfield(ui,'confirmSchemaChangeFcn') ...
        && isa(ui.confirmSchemaChangeFcn,'function_handle')
    proceed = logical(ui.confirmSchemaChangeFcn(struct( ...
        'modelName',modelName,'message',message, ...
        'oldParameterCounts',change.oldCounts, ...
        'newParameterCount',change.newCount, ...
        'rangeFile',change.rangeFile)));
else
    warning('SITE:ParameterSchemaChanged','%s',message);
    proceed = true;
end
end

function change = local_result_revision_change(resultDir,modelName, ...
        dtTag,region,meteo,prd,mdl)
change = struct('changed',false,'oldVersion',NaN,'newVersion',NaN, ...
    'fileMat','','fileBook','');
if ~isfield(mdl,'result_version') || isempty(mdl.result_version)
    return
end
change.newVersion = double(mdl.result_version);
try
    paths = site_result_store('paths',resultDir,modelName,dtTag, ...
        region,meteo,prd);
    change.fileMat = paths.fileMat;
    change.fileBook = paths.fileBook;
    if isfile(paths.fileMat)
        previous = load(paths.fileMat,'store');
        if isfield(previous,'store') ...
                && isfield(previous.store,'resultVersion')
            change.oldVersion = double(previous.store.resultVersion);
        end
        change.changed = ~isequal(change.oldVersion,change.newVersion);
    elseif isfile(paths.fileBook)
        % Workbooks created before result revisions were tracked are
        % incompatible with a model that explicitly declares a revision.
        change.changed = true;
    end
catch exception
    warning('SITE:RevisionInspectionFailed', ...
        'Could not inspect existing %s results before the run: %s', ...
        upper(modelName),exception.message);
end
end

function proceed = local_confirm_revision_replacement(ui,modelName,change)
if isnan(change.oldVersion)
    oldText = 'unversioned';
else
    oldText = sprintf('revision %g',change.oldVersion);
end
message = sprintf([ ...
    'Model %s already has SITE results from an incompatible model/input ' ...
    'definition (%s; current revision: %g). Continuing will replace all ' ...
    'existing XLS/MAT parameters, scores, and histories for this exact ' ...
    'model name.'],upper(modelName),oldText,change.newVersion);
local_ui_log(ui,['WARNING: ' message]);
if isstruct(ui) && isfield(ui,'confirmSchemaChangeFcn') ...
        && isa(ui.confirmSchemaChangeFcn,'function_handle')
    proceed = logical(ui.confirmSchemaChangeFcn(struct( ...
        'modelName',modelName,'message',message, ...
        'oldResultVersion',change.oldVersion, ...
        'newResultVersion',change.newVersion, ...
        'checkpointFile',change.fileMat, ...
        'workbookFile',change.fileBook)));
else
    warning('SITE:ModelResultRevisionChanged','%s',message);
    proceed = true;
end
end

function [store,pool] = local_run_parallel(C,wanted,bas,ids,dat, ...
        mdl,ode,loss,misc,store,lossNames,saveEvery,trainClock)
% Keep only a small queue active and perform all persistence on the client.
    ui = local_get(C,'ui',struct());
    requestedWorkers = local_get(C,'numWorkers',[]);
    pool = gcp('nocreate');
    if isempty(pool)
        if isempty(requestedWorkers)
            pool = parpool('local');
        else
            pool = parpool('local',requestedWorkers);
        end
    elseif ~isempty(requestedWorkers) ...
            && pool.NumWorkers ~= requestedWorkers
        warning('SITE:ExistingPoolSize', ...
            ['Using the existing pool with ' ...
            '%d workers; C.numWorkers=%d ' ...
            'does not restart an active pool.'], ...
            pool.NumWorkers,requestedWorkers);
    end
    
    maxPending = local_get(C,'maxPending',pool.NumWorkers);
    maxPending = max(1,min(numel(wanted),floor(maxPending)));
    fprintf(['SITE parallel execution: ' ...
        '%d workers, %d active futures.\n'], ...
        pool.NumWorkers,maxPending);
    local_ui_log(ui,sprintf('    SITE parallel execution: %d workers, %d active futures.', ...
        pool.NumWorkers,maxPending));
    
    active = parallel.FevalFuture.empty(0,1);
    activeBasins = zeros(0,1);
    nextToSubmit = 1;
    completed = 0;
    
    while nextToSubmit <= numel(wanted) ...
            && numel(active) < maxPending ...
            && ~local_ui_should_stop(ui)
        [active,activeBasins] = local_submit(active,activeBasins, ...
            pool,wanted(nextToSubmit),dat,mdl,ode,loss,C.alg,misc);
        nextToSubmit = nextToSubmit + 1;
    end
    
    while ~isempty(active)
        [finishedIndex,result] = fetchNext(active);
        k = activeBasins(finishedIndex);
        completed = completed + 1;
        fprintf(['  Completed basin %d/%d: ' ...
            '%s (%d/%d requested)\n'], ...
            k,bas.K,ids(k),completed,numel(wanted));
        guiClock = tic;
        local_ui_iter(ui,sprintf('Completed basin %d/%d: %s', ...
            completed,numel(wanted),ids(k)));
        local_ui_progress(ui,'Completed',completed,numel(wanted));
        guiSeconds = toc(guiClock);
        store = site_result_store( ...
            'update',store,k,result, ...
            lossNames{loss.fnc},C.alg.method,loss);
        guiClock = tic;
        local_ui_result(ui,k,result,store,mdl,bas,ids);
        local_ui_timing(ui,'train',toc(trainClock));
        local_ui_gui_time(ui,k,guiSeconds+toc(guiClock),bas.K);
    
        active(finishedIndex) = [];
        activeBasins(finishedIndex) = [];
        if nextToSubmit <= numel(wanted) && ~local_ui_should_stop(ui)
            [active,activeBasins] = ...
                local_submit(active,activeBasins, ...
                pool,wanted(nextToSubmit), ...
                dat,mdl,ode,loss,C.alg,misc);
            nextToSubmit = nextToSubmit + 1;
        end
    
        if mod(completed,saveEvery) == 0 ...
                || completed == numel(wanted)
            store = site_result_store('save',store);
        end
    end
end

function [active,activeBasins] = ...
    local_submit(active,activeBasins, ...
        pool,k,dat,mdl,ode,loss,alg,misc)

    future = parfeval(pool,@calibrate_basin_SITE,1, ...
        mdl,dat{k},ode,loss,alg,misc);
    active(end + 1,1) = future;
    activeBasins(end + 1,1) = k;
end

function local_ui_log(ui,message)
    try
        if isstruct(ui) && isfield(ui,'logFcn') && ~isempty(ui.logFcn)
            ui.logFcn(char(string(message)));
        end
    catch
    end
end

function local_ui_iter(ui,message)
    try
        if isstruct(ui) && isfield(ui,'iterFcn') && ~isempty(ui.iterFcn)
            ui.iterFcn(char(string(message)));
        end
    catch
    end
end

function local_ui_progress(ui,message,k,K)
    try
        if isstruct(ui) && isfield(ui,'progressFcn') && ~isempty(ui.progressFcn)
            ui.progressFcn(char(string(message)),k,K);
        end
    catch
    end
end

function local_ui_call(ui,fieldName,varargin)
    try
        if isstruct(ui) && isfield(ui,fieldName) && ~isempty(ui.(fieldName))
            ui.(fieldName)(varargin{:});
        end
    catch
    end
end

function local_ui_timing(ui,phase,value)
    local_ui_call(ui,'timingFcn',phase,value);
end

function local_ui_gui_time(ui,k,value,K)
    local_ui_call(ui,'guiTimeFcn',k,value,K);
end

function local_ui_result(ui,k,result,store,mdl,bas,ids)
    try
        if isstruct(ui) && isfield(ui,'resultFcn') && ~isempty(ui.resultFcn)
            ui.resultFcn(k,result,store,mdl,bas,ids);
        end
    catch
    end
end

function tf = local_ui_should_stop(ui)
    tf = false;
    try
        if isstruct(ui) && isfield(ui,'shouldStop') && ~isempty(ui.shouldStop)
            tf = logical(ui.shouldStop());
        end
    catch
        tf = false;
    end
end

function value = local_get(S,name,default)

    if isfield(S,name) ...
            && ~isempty(S.(name))
        value = S.(name);
    else
        value = default;
    end
end

function n = local_count_ids(fileName)

    raw = readlines(fileName);
    raw = strip(raw);
    raw(raw == "" | startsWith(raw,"#")) = [];
    n = numel(raw);
end

function tag = local_dt_tag(dt)

    switch dt
        case 1
            tag = 'daily';
        case 24
            tag = 'hourly';
        case 96
            tag = '15min';
        otherwise
            tag = sprintf('dt_%g',dt);
    end
end
