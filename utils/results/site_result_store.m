function store = site_result_store(action,varargin)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SITE_RESULT_STORE Initialize, update and persist per-metric SITE results.
%
% SYNOPSIS:
%   store = site_result_store(action,varargin)
%
% INPUT ARGUMENTS:
%   action          'load', 'update', 'save', or 'paths'
%   varargin        inputs required by the selected action
%
% OUTPUT ARGUMENTS:
%   store           result store or resolved result paths
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch lower(action)
    case 'load'
        store = local_load(varargin{:});
    case 'update'
        store = local_update(varargin{:});
    case 'save'
        store = varargin{1};
        local_save(store);
    case 'paths'
        store = local_paths(varargin{:});
    otherwise
        error('SITE:BadStoreAction','Unknown store action "%s".',action);
end
end

function paths = local_paths(resultDir,modelName,dtTag,region,meteo,prd)
% Resolve the same provenance-specific filenames used by local_load.
provenance = local_provenance(region,meteo);
paths.profileTag = provenance.tag;
if nargin < 6 || isempty(prd)
    error('SITE:PeriodRequired','Period settings are required for SITE results.');
end
scopeDir = local_result_scope(resultDir,region,dtTag);
[paths.periodID,paths.period] = site_period_registry( ...
    scopeDir,dtTag,prd,false);
suffix = sprintf('%s_p%03d',provenance.tag,paths.periodID);
paths.periodDir = fullfile(scopeDir, ...
    sprintf('period_%03d',paths.periodID));
paths.resultDir = fullfile(paths.periodDir,provenance.tag);
paths.fileMat = fullfile(paths.resultDir,sprintf( ...
    'SITE_%s_%s_%s_checkpoint.mat', ...
    modelName,dtTag,suffix));
paths.fileBook = fullfile(paths.resultDir,sprintf( ...
    'param_%s_%s_%s.xlsx',modelName,dtTag,suffix));
paths.fileSummary = fullfile(paths.resultDir,sprintf( ...
    'model_master_%s_%s.xlsx',dtTag,suffix));
end

function scopeDir = local_result_scope(resultDir,region,dtTag)
% CAMELS-US offers multiple time resolutions; keep their periods separate.
scopeDir = resultDir;
if strcmpi(char(string(region)),'CAMELS_US')
    scopeDir = fullfile(resultDir,char(string(dtTag)));
end
end

function store = local_load(resultDir,modelName,dtTag,ids,mdl, ...
    currentRangeID,fdcD0t,fdcD0e,fdcD0pt,fdcD0pe, ...
    fdcD0logpt,fdcD0logpe,region,meteo,prd)
if ~isfolder(resultDir)
    mkdir(resultDir);
end
if nargin < 15
    error('SITE:MissingMeteoProvenance', ...
        'Region, meteorology and period are required to name results.');
end
if nargin < 7 || isempty(fdcD0t), fdcD0t = nan(numel(ids),1); end
if nargin < 8 || isempty(fdcD0e), fdcD0e = nan(numel(ids),1); end
if nargin < 9 || isempty(fdcD0pt), fdcD0pt = nan(numel(ids),1); end
if nargin < 10 || isempty(fdcD0pe), fdcD0pe = nan(numel(ids),1); end
if nargin < 11 || isempty(fdcD0logpt), fdcD0logpt = nan(numel(ids),1); end
if nargin < 12 || isempty(fdcD0logpe), fdcD0logpe = nan(numel(ids),1); end
fdcReferences = {fdcD0t,fdcD0e,fdcD0pt,fdcD0pe, ...
    fdcD0logpt,fdcD0logpe};
for i = 1:numel(fdcReferences)
    fdcReferences{i} = double(fdcReferences{i}(:));
    if numel(fdcReferences{i}) ~= numel(ids)
        error('SITE:BadFDCReference', ...
            'Each FDC reference vector must contain one value per basin.');
    end
end
[fdcD0t,fdcD0e,fdcD0pt,fdcD0pe,fdcD0logpt,fdcD0logpe] = ...
    fdcReferences{:};

store.metricNames = {'NSE','KGE','SAR','RSS','Huber', ...
    'S_fdc','S_p','S_logp','JKGE'};
store.maximize = [true true false false false true true true true];
store.model = char(modelName);
store.dtTag = char(dtTag);
store.provenance = local_provenance(region,meteo);
store.profileTag = store.provenance.tag;
[store.periodID,store.period] = site_period_registry( ...
    local_result_scope(resultDir,region,dtTag),dtTag,prd,true);
store.ids = string(ids(:));
store.parNames = string(mdl.par_names(:));
store.columnNames = site_parameter_names(store.parNames);
store.thMin = mdl.th_min(:);
store.thMax = mdl.th_max(:);
store.currentRangeID = currentRangeID;
store.fdcD0t = fdcD0t;
store.fdcD0e = fdcD0e;
store.fdcD0pt = fdcD0pt;
store.fdcD0pe = fdcD0pe;
store.fdcD0logpt = fdcD0logpt;
store.fdcD0logpe = fdcD0logpe;
paths = local_paths(resultDir,modelName,dtTag,region,meteo,prd);
if ~isfolder(paths.resultDir), mkdir(paths.resultDir); end
store.resultDir = paths.resultDir;
store.fileMat = paths.fileMat;
store.fileBook = paths.fileBook;
store.fileSummary = paths.fileSummary;

K = numel(ids);
d = numel(mdl.th_min);
nMetrics = numel(store.metricNames);
store.train = nan(K,nMetrics);
store.eval = nan(K,nMetrics);
store.nTheta = nan(K,d,nMetrics);
store.theta = nan(K,d,nMetrics);
store.optimizedLoss = strings(K,nMetrics);
store.optimizer = nan(K,nMetrics);
store.runtime = nan(K,nMetrics);
store.updated = NaT(K,nMetrics);
store.rangeID = nan(K,nMetrics);
store.runCount = zeros(K,nMetrics);

if isfile(store.fileMat)
    previous = load(store.fileMat,'store');
    if ~isfield(previous,'store') ...
            || ~isfield(previous.store,'provenance') ...
            || ~isequaln(previous.store.provenance,store.provenance) ...
            || (isfield(previous.store,'periodID') ...
            && previous.store.periodID ~= store.periodID) ...
            || ~isequal(previous.store.ids,store.ids) ...
            || ~isequal(previous.store.parNames,store.parNames)
        error('SITE:CheckpointMismatch', ...
            ['Checkpoint does not match forcing, PET, basin IDs, ' ...
            'or parameters: %s'],store.fileMat);
    end
    store = local_merge_previous(store,previous.store);
elseif isfile(store.fileBook)
    store = local_import_workbook(store);
    save(store.fileMat,'store','-v7.3');
    fprintf('SITE: restored checkpoint from %s.\n',store.fileBook);
end
end

function store = local_import_workbook(store)
% Rebuild a missing checkpoint without changing the historical workbook.
try
    sheets = string(sheetnames(store.fileBook));
catch exception
    error('SITE:WorkbookImportFailed', ...
        'Cannot read historical workbook %s: %s', ...
        store.fileBook,exception.message);
end
if ~any(sheets == "Run information")
    error('SITE:WorkbookProvenanceMissing', ...
        'Workbook has no Run information sheet: %s',store.fileBook);
end
info = readcell(store.fileBook,'Sheet','Run information');
p = store.provenance;
if ~strcmpi(local_info_value(info,'Meteorological forcing'), ...
        p.forcingName) ...
        || ~strcmpi(local_info_value(info, ...
        'Potential evapotranspiration'),p.petName) ...
        || local_import_number(local_info_value(info, ...
        'Forcing selection')) ~= p.data ...
        || local_import_number(local_info_value(info, ...
        'PET selection')) ~= p.pet
    error('SITE:WorkbookProvenanceMismatch', ...
        'Forcing or PET in %s does not match the requested run.', ...
        store.fileBook);
end
if any(strcmp(string(info(:,1)),'Region')) ...
        && ~strcmpi(local_info_value(info,'Region'),p.region)
    error('SITE:WorkbookProvenanceMismatch', ...
        'Region in %s does not match the requested run.',store.fileBook);
end
if any(strcmp(string(info(:,1)),'Model')) ...
        && ~strcmpi(local_info_value(info,'Model'),store.model)
    error('SITE:WorkbookProvenanceMismatch', ...
        'Model in %s does not match the requested run.',store.fileBook);
end
if any(strcmp(string(info(:,1)),'Temperature selection')) ...
        && isfinite(p.temp) ...
        && local_import_number(local_info_value(info, ...
        'Temperature selection')) ~= p.temp
    error('SITE:WorkbookProvenanceMismatch', ...
        'Temperature choice in %s does not match the requested run.', ...
        store.fileBook);
end

imported = 0;
for j = 1:numel(store.metricNames)
    sheet = string(store.metricNames{j});
    if ~any(sheets == sheet), continue, end
    cells = readcell(store.fileBook,'Sheet',char(sheet));
    K = numel(store.ids);
    if size(cells,1) ~= K + 1
        error('SITE:WorkbookBasinMismatch', ...
            'Sheet %s has the wrong number of basins.',sheet);
    end
    headings = string(cells(1,:));
    basinNumber = local_column(headings,'BasinNumber');
    basinID = local_column(headings,'BasinID');
    train = local_column(headings,'Train');
    eval = local_column(headings,'Eval');
    rangeID = local_column(headings,'RangeID');
    optimizedLoss = local_column(headings,'OptimizedLoss');
    optimizer = local_column(headings,'Optimizer');
    runtime = local_column(headings,'RuntimeSeconds');
    updated = local_column(headings,'Updated');
    d = numel(store.parNames);
    normalized = zeros(1,d);
    physical = zeros(1,d);
    for h = 1:d
        name = char(store.columnNames(h));
        normalized(h) = local_column(headings,['n_' name]);
        physical(h) = local_column(headings,name);
    end
    for k = 1:K
        row = cells(k + 1,:);
        if local_import_number(row{basinNumber}) ~= k ...
                || string(row{basinID}) ~= store.ids(k)
            error('SITE:WorkbookBasinMismatch', ...
                'Basin %d differs in sheet %s.',k,sheet);
        end
        score = local_import_number(row{train});
        if ~isfinite(score), continue, end
        nTheta = cellfun(@local_import_number,row(normalized));
        theta = cellfun(@local_import_number,row(physical));
        if any(~isfinite(nTheta)) || any(~isfinite(theta))
            error('SITE:WorkbookParameterMissing', ...
                'Stored parameters are incomplete for basin %d in %s.', ...
                k,sheet);
        end
        store.train(k,j) = score;
        store.eval(k,j) = local_import_number(row{eval});
        store.nTheta(k,:,j) = nTheta;
        store.theta(k,:,j) = theta;
        store.rangeID(k,j) = local_import_number(row{rangeID});
        store.optimizedLoss(k,j) = string(row{optimizedLoss});
        store.optimizer(k,j) = local_import_number(row{optimizer});
        store.runtime(k,j) = local_import_number(row{runtime});
        if isdatetime(row{updated})
            store.updated(k,j) = row{updated};
        end
        imported = imported + 1;
    end
end
if any(sheets == "RunCounts")
    cells = readcell(store.fileBook,'Sheet','RunCounts');
    headings = string(cells(1,:));
    basinNumber = local_column(headings,'BasinNumber');
    basinID = local_column(headings,'BasinID');
    K = numel(store.ids);
    if size(cells,1) ~= K + 1
        error('SITE:WorkbookBasinMismatch', ...
            'Sheet RunCounts has the wrong number of basins.');
    end
    for k = 1:K
        row = cells(k + 1,:);
        if local_import_number(row{basinNumber}) ~= k ...
                || string(row{basinID}) ~= store.ids(k)
            error('SITE:WorkbookBasinMismatch', ...
                'Basin %d differs in sheet RunCounts.',k);
        end
        for j = 1:numel(store.metricNames)
            label = [store.metricNames{j} '_completed_runs'];
            column = local_column(headings,label);
            value = local_import_number(row{column});
            if isfinite(value) && value >= 0 && value == fix(value)
                store.runCount(k,j) = value;
            else
                error('SITE:WorkbookRunCountInvalid', ...
                    'Invalid %s count for basin %d.',label,k);
            end
        end
    end
end
if imported == 0
    error('SITE:WorkbookEmpty', ...
        'No finite historical scores were found in %s.',store.fileBook);
end
fprintf('SITE: imported %d historical metric records.\n',imported);
end

function value = local_info_value(cells,label)
index = find(strcmp(string(cells(:,1)),label),1);
if isempty(index) || size(cells,2) < 2
    error('SITE:WorkbookProvenanceMissing', ...
        'Run information is missing %s.',label);
end
value = cells{index,2};
end

function index = local_column(headings,label)
index = find(strcmp(headings,label),1);
if isempty(index)
    error('SITE:WorkbookColumnMissing', ...
        'Historical workbook is missing column %s.',label);
end
end

function value = local_import_number(entry)
value = NaN;
if isnumeric(entry) && isscalar(entry)
    value = double(entry);
elseif isdatetime(entry) && isscalar(entry) ...
        && ~isnat(entry) && year(entry) == 1900 ...
        && month(entry) == 1
    % Old workbooks styled optimizer code 1-7 as an Excel date.
    value = double(day(entry));
elseif (ischar(entry) || isstring(entry)) ...
        && ~ismissing(string(entry))
    value = str2double(string(entry));
end
end

function provenance = local_provenance(region,meteo)
% CAMELS-FR has one fixed meteorological product. Older exported scripts
% represent that unnumbered product as NaN; its canonical selection is 1.
if strcmpi(string(region),'CAMELS_FR') ...
        && isfield(meteo,'data') && isscalar(meteo.data) ...
        && isnan(meteo.data)
    meteo.data = 1;
end
if ~isfield(meteo,'data') || ~isfield(meteo,'pet') ...
        || ~isscalar(meteo.data) || ~isscalar(meteo.pet) ...
        || ~isfinite(meteo.data) || ~isfinite(meteo.pet) ...
        || meteo.data ~= fix(meteo.data) ...
        || meteo.pet ~= fix(meteo.pet)
    error('SITE:InvalidMeteoSelection', ...
        'Meteorological forcing and PET choices must be integer codes.');
end
provenance.region = char(string(region));
provenance.data = double(meteo.data);
provenance.pet = double(meteo.pet);
provenance.source = '';
if isfield(meteo,'source')
    provenance.source = char(string(meteo.source));
end
provenance.precip = NaN;
provenance.temp = NaN;
if isfield(meteo,'precip'), provenance.precip = meteo.precip; end
if isfield(meteo,'temp'), provenance.temp = meteo.temp; end

if strcmpi(provenance.region,'CAMELS_US')
    forcingNames = {'Daymet','Maurer','NLDAS'};
    forcingTags = {'daymet','maurer','nldas'};
    petNames = {'Penman-Monteith','Priestley-Taylor','Makkink'};
    petTags = {'penman_monteith','priestley_taylor','makkink'};
    if provenance.data < 1 || provenance.data > 3 ...
            || provenance.pet < 1 || provenance.pet > 3
        error('SITE:InvalidCAMELSUSMeteoSelection', ...
            'CAMELS-US uses forcing and PET codes 1, 2, or 3.');
    end
    if ~all(isnan([provenance.precip,provenance.temp]))
        error('SITE:MixedCAMELSUSForcing', ...
            ['Separate precipitation or temperature selections need ' ...
            'a distinct provenance tag; use the linked data choice.']);
    end
    provenance.forcingName = forcingNames{provenance.data};
    provenance.petName = petNames{provenance.pet};
    provenance.tag = sprintf('%s_%s', ...
        forcingTags{provenance.data},petTags{provenance.pet});
elseif strcmpi(provenance.region,'CAMELS_FR')
    temperatureNames = {'mean temperature', ...
        'mean of minimum and maximum temperature', ...
        'minimum temperature','maximum temperature'};
    temperatureTags = {'tmean','tmin_tmax_mean','tmin','tmax'};
    petNames = {'Penman-Monteith','Penman','Oudin et al.'};
    petTags = {'penman_monteith','penman','oudin'};
    if provenance.data ~= 1 || provenance.precip ~= 1 ...
            || ~isfinite(provenance.temp) ...
            || provenance.temp ~= fix(provenance.temp) ...
            || provenance.temp < 1 || provenance.temp > 4 ...
            || provenance.pet < 1 || provenance.pet > 3
        error('SITE:InvalidCAMELSFRMeteoSelection', ...
            'CAMELS-FR forcing, temperature, or PET choice is invalid.');
    end
    provenance.forcingName = sprintf( ...
        'CAMELS-FR (%s)',temperatureNames{provenance.temp});
    provenance.petName = petNames{provenance.pet};
    provenance.tag = sprintf('camels_fr_%s_%s', ...
        temperatureTags{provenance.temp},petTags{provenance.pet});
else
    provenance.forcingName = sprintf('Forcing option %d', ...
        provenance.data);
    provenance.petName = sprintf('PET option %d',provenance.pet);
    provenance.tag = sprintf('data%d_pet%d', ...
        provenance.data,provenance.pet);
end
end

function store = local_update(store,k,result,lossName,optimizer,lossCfg)
if nargin < 6 || isempty(lossCfg)
    lossCfg = struct('M',2,'method',1,'n_win',31);
end
jkgeUsesDefault = local_default_jkge(lossCfg);
m = result.metrics;
candidatesT = [m.NSEt,m.KGEt,m.SARt,m.RSSt,m.Hubert, ...
    local_fdc_skill(m.Dfdct,store.fdcD0t(k)), ...
    local_fdc_skill(m.Dpt,store.fdcD0pt(k)), ...
    local_fdc_skill(m.Dlogpt,store.fdcD0logpt(k)),m.JKGEt];
candidatesE = [m.NSEe,m.KGEe,m.SARe,m.RSSe,m.Hubere, ...
    local_fdc_skill(m.Dfdce,store.fdcD0e(k)), ...
    local_fdc_skill(m.Dpe,store.fdcD0pe(k)), ...
    local_fdc_skill(m.Dlogpe,store.fdcD0logpe(k)),m.JKGEe];
if ~jkgeUsesDefault
    candidatesT(9) = NaN;
    candidatesE(9) = NaN;
end

runMetric = local_run_metric(lossName);
runIndex = find(strcmpi(string(store.metricNames),runMetric),1);
if runMetric == "JKGE" && ~jkgeUsesDefault
    runIndex = [];
elseif isempty(runIndex)
    error('SITE:UnknownRunMetric', ...
        'Cannot count completed run for loss function %s.', ...
        char(string(lossName)));
end
if ~isempty(runIndex)
    store.runCount(k,runIndex) = store.runCount(k,runIndex) + 1;
end

for j = 1:numel(store.metricNames)
    candidate = candidatesT(j);
    if ~isfinite(candidate)
        continue
    end
    incumbent = store.train(k,j);
    improves = ~isfinite(incumbent) ...
        || (store.maximize(j) && candidate > incumbent) ...
        || (~store.maximize(j) && candidate < incumbent);
    if improves
        if isfinite(incumbent)
            fprintf(['    Improved stored %s: ' ...
                '%.6g -> %.6g (loss function: %s).\n'], ...
                store.metricNames{j}, ...
                incumbent,candidate,char(string(lossName)));
        else
            fprintf(['    Stored first finite %s = ' ...
                '%.6g (loss function: %s).\n'], ...
                store.metricNames{j}, ...
                candidate,char(string(lossName)));
        end
        store.train(k,j) = candidate;
        store.eval(k,j) = candidatesE(j);
        store.nTheta(k,:,j) = result.x(:).';
        store.theta(k,:,j) = result.theta(:).';
        store.optimizedLoss(k,j) = string(lossName);
        store.optimizer(k,j) = optimizer;
        store.runtime(k,j) = result.runtime;
        store.updated(k,j) = datetime('now');
        store.rangeID(k,j) = store.currentRangeID;
    end
end
end

function store = local_merge_previous(store,old)
% Preserve all matching metric columns from checkpoints with older schemas.
if isfield(old,'metricNames') && ~isempty(old.metricNames)
    oldNames = string(old.metricNames);
else
    oldNames = ["NSE","KGE","SAR","RSS","Huber","FDC","JKGE"];
end
newNames = string(store.metricNames);
fields2 = {'train','eval','optimizedLoss','optimizer','runtime','updated','rangeID'};
fields3 = {'nTheta','theta'};
for oldIndex = 1:numel(oldNames)
    newIndex = find(strcmpi(newNames,oldNames(oldIndex)),1);
    if isempty(newIndex), continue, end
    for i = 1:numel(fields2)
        name = fields2{i};
        if isfield(old,name) && size(old.(name),2) >= oldIndex
            store.(name)(:,newIndex) = old.(name)(:,oldIndex);
        end
    end
    for i = 1:numel(fields3)
        name = fields3{i};
        if isfield(old,name) && size(old.(name),3) >= oldIndex
            store.(name)(:,:,newIndex) = old.(name)(:,:,oldIndex);
        end
    end
end
if isfield(old,'runCount') && isfield(old,'metricNames')
    for oldIndex = 1:numel(oldNames)
        newIndex = find(strcmpi(newNames,oldNames(oldIndex)),1);
        if ~isempty(newIndex) && size(old.runCount,2) >= oldIndex
            store.runCount(:,newIndex) = old.runCount(:,oldIndex);
        end
    end
end
end

function metric = local_run_metric(lossName)
name = upper(strrep(char(string(lossName)),'_','-'));
switch name
    case {'NSE','KGE','SAR','RSS','HUBER','JKGE'}
        metric = string(lossName);
    case {'FDC','FDC-6A'}
        metric = "S_fdc";
    case 'FDC-6B'
        metric = "S_p";
    case 'FDC-6C'
        metric = "S_logp";
    otherwise
        metric = "";
end
end

function tf = local_default_jkge(lossCfg)
tf = isstruct(lossCfg) ...
    && isfield(lossCfg,'M') && isfield(lossCfg,'method') ...
    && isfield(lossCfg,'n_win') ...
    && isequal(double(lossCfg.M),2) ...
    && isequal(double(lossCfg.method),1) ...
    && isequal(double(lossCfg.n_win),31);
end

function score = local_fdc_skill(divergence,reference)
score = NaN;
if isfinite(divergence) && divergence >= 0 ...
        && isfinite(reference) && reference > 0
    score = 1 - divergence/reference;
end
end
function local_save(store)
save(store.fileMat,'store','-v7.3');

K = numel(store.ids);
d = numel(store.parNames);
tempFileBook = [tempname(store.resultDir) '.xlsx'];
tempCleanup = onCleanup(@() local_delete_if_exists(tempFileBook));
for j = 1:numel(store.metricNames)
    T = table((1:K).',store.ids, ...
        'VariableNames',{'BasinNumber','BasinID'});
    for p = 1:d
        safe = char(store.columnNames(p));
        T.(['n_' safe]) = store.nTheta(:,p,j);
    end
    T.RangeID = store.rangeID(:,j);
    parameterSeparatorIndex = width(T) + 1;
    T.ParameterSeparator = strings(K,1);
    for p = 1:d
        safe = char(store.columnNames(p));
        T.(safe) = store.theta(:,p,j);
    end
    performanceSeparatorIndex = width(T) + 1;
    T.PerformanceSeparator = strings(K,1);
    T.Train = store.train(:,j);
    T.Eval = store.eval(:,j);
    metadataSeparatorIndex = width(T) + 1;
    T.MetadataSeparator = strings(K,1);
    T.OptimizedLoss = store.optimizedLoss(:,j);
    T.Optimizer = store.optimizer(:,j);
    T.RuntimeSeconds = store.runtime(:,j);
    T.Updated = store.updated(:,j);

    % writecell permits a genuinely blank separator-column heading;
    % MATLAB tables themselves require every variable to have a name.
    contents = [T.Properties.VariableNames; table2cell(T)];
    contents{1,parameterSeparatorIndex} = '';
    contents{1,performanceSeparatorIndex} = '';
    contents{1,metadataSeparatorIndex} = '';
    writecell(contents,tempFileBook,'Sheet',store.metricNames{j});
end
writecell(local_run_information(store,store.model), ...
    tempFileBook,'Sheet','Run information');
R = table((1:K).',store.ids, ...
    'VariableNames',{'BasinNumber','BasinID'});
for j = 1:numel(store.metricNames)
    R.([store.metricNames{j} '_completed_runs']) = ...
        store.runCount(:,j);
end
writetable(R,tempFileBook,'Sheet','RunCounts');
movefile(tempFileBook,store.fileBook,'f');
clear tempCleanup

summaryFile = store.fileSummary;
F = table((1:K).',store.ids,store.fdcD0t,store.fdcD0e, ...
    store.fdcD0pt,store.fdcD0pe, ...
    store.fdcD0logpt,store.fdcD0logpe, ...
    'VariableNames',{'BasinNumber','BasinID', ...
    'd0_fdc_train','d0_fdc_eval','d0_p_train','d0_p_eval', ...
    'd0_logp_train','d0_logp_eval'});
writetable(F,summaryFile,'Sheet','FDC_reference', ...
    'WriteMode','overwritesheet');

S = table((1:K).',store.ids, ...
    'VariableNames',{'BasinNumber','BasinID'});
for j = 1:numel(store.metricNames)
    name = store.metricNames{j};
    S.([name '_train']) = store.train(:,j);
    S.([name '_eval']) = store.eval(:,j);
    S.([name '_range_id']) = store.rangeID(:,j);
end
writetable(S,summaryFile,'Sheet',store.model, ...
    'WriteMode','overwritesheet');
writecell(local_run_information(store,'Multiple SITE models'), ...
    summaryFile,'Sheet','Run information','WriteMode','overwritesheet');
end

function local_delete_if_exists(fileName)
if isfile(fileName)
    delete(fileName);
end
end

function information = local_run_information(store,modelName)
p = store.provenance;
information = { ...
    'SITEhydrology run information',''; ...
    'Region',p.region; ...
    'Model',modelName; ...
    'Time resolution',store.dtTag; ...
    'Meteorological forcing',p.forcingName; ...
    'Forcing selection',p.data; ...
    'Precipitation and temperature',p.forcingName; ...
    'Potential evapotranspiration',p.petName; ...
    'PET selection',p.pet; ...
    'Source',p.source; ...
    'Result profile',p.tag; ...
    'Period ID',store.periodID; ...
    'Split method',char(store.period.method); ...
    'Training start',char(store.period.trainStart); ...
    'Training end',char(store.period.trainEnd); ...
    'Evaluation start',char(store.period.evalStart); ...
    'Evaluation end',char(store.period.evalEnd); ...
    'Spin-up days',store.period.spinup};
information(end+1,:) = {'Result schema', ...
    'SITE version 1: nine metrics; raw FDC removed'};
information(end+1,:) = {'Run count definition', ...
    'Completed basin calibrations since version 1'};
if isfinite(p.precip)
    information(end+1,:) = {'Precipitation selection',p.precip};
end
if isfinite(p.temp)
    information(end+1,:) = {'Temperature selection',p.temp};
end
end
