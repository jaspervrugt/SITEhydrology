function SITE_ui(varargin)
% Ignore launcher arguments; configuration is selected inside the GUI.
%#function compile_model
%#function print_SAGE
%#function write_header
%#function split_basin_ids
%#function region_config_AR
%#function region_config_AT
%#function region_config_AU
%#function region_config_BE
%#function region_config_BR
%#function region_config_CA
%#function region_config_CH
%#function region_config_CL
%#function region_config_COL
%#function region_config_CZ
%#function region_config_DE
%#function region_config_DEH
%#function region_config_DK
%#function region_config_EE
%#function region_config_ET
%#function region_config_ES
%#function region_config_FI
%#function region_config_FR
%#function region_config_GB
%#function region_config_IE
%#function region_config_IL
%#function region_config_IND
%#function region_config_IS
%#function region_config_JM
%#function region_config_KR
%#function region_config_KRH
%#function region_config_LUX
%#function region_config_MX
%#function region_config_NA
%#function region_config_NO
%#function region_config_NZ
%#function region_config_PE
%#function region_config_PL
%#function region_config_PR
%#function region_config_PT
%#function region_config_RU
%#function region_config_SE
%#function region_config_US
%#function region_config_USH
%#function region_config_ZA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SITE_UI SITE graphical user interface derived directly from SAGE_ui.
%execution, postprocessing, export, and diagnostic analysis of
%Sensitivity-Aware Gradient Estimation (SAGE)
%
% SYNOPSIS: SITE_ui() or SITE_ui(varargin)
%
% This graphical user interface:
%   - Builds a SAGE configuration from user-selected settings
%     (paths/region/model/parameters/ODE|solver/period/meteo/
%      loss function/optimization)
%   - Runs large-sample SAGE training for the selected hydrologic model
%   - Supports multiple CAMELS-style regional datasets with region-specific
%     attributes, basin ids, meteorological forcing, discharge data,
%     time periods, data resolution, and basin-sampling defaults
%   - Supports built-in hydrologic models and optional user-supplied
%     models through a compiled platform-specific MEX interface
%   - Streams run-time output to the GUI
%       * Summary tab: overall run status and selected settings
%       * Preview tab: current configuration as formatted text
%       * Checks tab: readiness and evaluation diagnostics
%       * Log tab: pipeline messages, warnings, and errors
%       * Iter tab: iteration-level optimization output from SAGE
%       * Region tab: map of training/evaluation basins and
%         parameter values for the active regional data set
%       * Zones tab: zone-wise ECDF summaries and interbasin scores
%       * Zone table tab: tabular zone-wise performance summaries
%       * Metrics tab: run-time, memory, CPU, and pool diagnostics
%       * Information tab: neuron-level KSG / excess mutual information,
%         effective hidden-layer width, and information flow through depth
%       * Feedback tab: run summary, guidance, and diagnostic messages
%   - Provides editable parameter bounds for the selected hydrologic model
%   - Supports direct selection or upload of basin split files
%   - Uses training basins only; an optional evaluation period can be
%     applied to those same training basins
%   - Preserves prepared basin divisions when model, period, loss,
%     optimizer, or postprocessor settings are changed
%   - Invalidates prepared basin divisions when basin universe,
%     train/evaluation basin counts, sampling method, basin file,
%     region, or data resolution changes
%   - Supports rainfall-block train/evaluation splitting with local
%     basin-specific train/evaluation masks and minimum two-water-year
%     period checks
%   - Supports configurable loss functions and optimization algorithms
%   - Supports JKGE options with method-dependent controls and restrictions
%     for random time masks
%   - Supports robust Huber-loss settings for zero-flow dominated basins
%   - Supports save/load of GUI sessions and export of MATLAB run scripts
%   - Supports direct download/install of regional daily, hourly, and
%     Luxembourg 15-minute data
%   - Supports interactive postprocessor basin selection for training and
%     evaluation scenarios, including synchronized updates of region maps
%     and FDC views
%   - Supports export of open SAGE diagnostic figures to PowerPoint
%
% Requires (on MATLAB path):
%   - SAGEhydrology codebase
%       read_attr, sample_basins, read_model, read_meteo, read_Q,
%       camels, pmetrics, print_SAGE,
%       pproc_SAGE, plot_SAGE, setup_parpool, compile_model,
%       save_to_pptx
%   - read_numsettings.m
%   - install_SAGEhydrology.m or data_helpers.m
%     [for regional data download/install functionality]
%
% User model support:
%   - The user_model option is intended for mcode = 4 only
%   - user_model calls a user-supplied compiled MEX file
%       crr_user_model.mexw64      Windows
%       crr_user_model.mexmaca64   macOS
%   - The user-supplied MEX file must implement the complete
%     user_model(par,mdl,data,ode,check) interface and return:
%       q_n, J, Jth, Z
%   - The deployed executable cannot execute newly edited external .m
%     files at runtime; therefore, model-specific runtime logic must be
%     compiled into the user-supplied MEX implementation
%   - read_user_model.m is used to define parameter metadata, bounds,
%     parameter names, units, and state initialization for the GUI
%
% Notes:
%   - Meteorological forcing choices are region dependent
%   - CAMELS-US supports Daymet, Maurer, and NLDAS options
%   - Other regional CAMELS-style data sets use their native forcing
%     products and reader-specific PET/temperature options where available
%   - Data-resolution controls are region dependent and enforced by the GUI
%   - Parameter-table defaults are obtained from read_model
%   - User edits of parameter bounds are stored per (model,dt)
%   - Basin division is retained unless basin-selection settings, basin
%     files, sampling settings, region, or data resolution are changed
%   - Period changes do not require a new basin division, except when they
%     affect data-resolution-dependent bookkeeping
%   - Recompilation of the hydrologic model does not by itself require a
%     new basin division
%   - Rainfall-block splitting requires at least two water years of usable
%     data and uses local train/evaluation masks when available
%   - Stop button requests graceful termination after the current iteration
%   - Postprocessing uses the latest available retained network output
%   - Changes to postprocessor basin selection update GUI diagnostics
%     immediately, but do not modify an already running SAGE simulation
%   - Metrics tab uses a timer to refresh system diagnostics
%   - PowerPoint export uses latest GUI/pipeline configuration structure
%
% Future work:
%   Implement adaptive Huber settings, including optional annealing of c
%   and/or S_y, and diagnostics for the fraction of clipped residuals.
%   This may reduce slow tail convergence caused by saturated Huber
%   gradients in zero-flow dominated catchments. Implement L = M+C+V to
%   increase gradients for JKGE.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% © Written by Jasper A. Vrugt, Apr. 2026 / updated Jun. 2026             %
% University of California, Irvine                                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % ------------------------------
    %  Screen-aware initial GUI size
    % ------------------------------
    scr = get(groot,'ScreenSize');   % [left bottom width height]
    % baseW = 1620;
    % baseH = 940;
    baseW = 1954;
    baseH = 1000;
    marginX = 40;
    marginY = 80;
    maxW = scr(3) - 2*marginX;
    maxH = scr(4) - 2*marginY;
    scale = min([1, maxW/baseW, maxH/baseH]);
    figW = baseW * scale;
    figH = baseH * scale;
    figX = scr(1) + (scr(3) - figW)/2;
    figY = scr(2) + (scr(4) - figH)/2;
    figPos = round([figX figY figW figH]);

    % ----------------------
    %  Screen-aware fontsize
    % ----------------------
    
    % Respect the computed screen scale while keeping fonts readable.
    uiScale = min(1.15,max(0.9,scale));
    if ~isdeployed
        addpath(fullfile(fileparts(mfilename('fullpath')),'sage'));
    end 
    % SITE and SAGE share one authoritative visual theme. In source mode,
    % make the sibling SAGE utilities available before resolving fonts;
    % MATLAB Compiler includes the statically referenced dependency.
    if ~isdeployed && exist('sage_visual_theme','file') ~= 2
        siteUiDirectory = fileparts(mfilename('fullpath'));
        siteSoftwareRoot = fileparts(fileparts(siteUiDirectory));
        sageUtilityCandidates = { ...
            fullfile(siteSoftwareRoot,'SAGEhydrology','utils')};
        try
            preferredSAGE = char(getpref( ...
                'SITEhydrology','SAGEhydro',''));
            sageUtilityCandidates{end+1} = ...
                fullfile(preferredSAGE,'utils');
        catch
        end
        sageEntry = which('SAGE_ui');
        if ~isempty(sageEntry)
            sageUtilityCandidates{end+1} = fullfile( ...
                fileparts(fileparts(sageEntry)),'utils');
        end
        for candidateIndex = 1:numel(sageUtilityCandidates)
            sageUtilities = sageUtilityCandidates{candidateIndex};
            if isfolder(sageUtilities)
                addpath(genpath(sageUtilities));
                break
            end
        end
    end
    visualTheme = sage_visual_theme(uiScale,scr(3));
    themeFonts = visualTheme.fonts.gui;
    fontsizeDropdown = themeFonts.dropdown;
    fontsizePreview = themeFonts.preview;
    fontsizeGUI = themeFonts.gui;
    fontsizeSlice = themeFonts.slice;
    fontsizeButton = themeFonts.button;
    fontsizePathText = themeFonts.path;
    fontsizeValueODE = themeFonts.value;
    fontsizeParamtable = themeFonts.table;
    fontsizeReadiness = themeFonts.readiness;
    rowHValuePeriod = max(28,round(1.8*fontsizeValueODE));
    rowHValueBasins = max(28,round(1.8*fontsizeValueODE));
    rowHValueTraining = max(28,round(1.8*fontsizeValueODE));
    fontsizeChecks = themeFonts.checks;
    fontsizeIter = themeFonts.iteration;

    mapFontScale = 1.0/uiScale;
    fontsizeMapTick = round(12 * mapFontScale^2);
    fontsizeMapLabel = round(12 * mapFontScale^2);
    fontsizeMapTitle = 18; % was 17 
    fontsizeMapLegend = fontsizeMapTitle;

    fontsizeDiagTick = themeFonts.diagnosticTick;
    fontsizeDiagLabel = themeFonts.diagnosticLabel;
    fontsizeDiagTitle = themeFonts.diagnosticTitle;
    %fontsizeDiagLegend = round(14.5 * uiScale); % was 13.5
    fontsizeDiagText = themeFonts.diagnosticText;
    fontsizeNotes = themeFonts.notes;

    % Use a compact size for the remaining diagnostic plots.
    % Apply this scale consistently to diagnostic plots.
    % diagAxisScale = 0.88;
    diagAxisScale = 1.1; 
    fontsizeDiagTickPlot = round(diagAxisScale * fontsizeDiagTick);
    fontsizeDiagLabelPlot = round(diagAxisScale * fontsizeDiagLabel);
    % Use compact axis labels for diagnostic plots.
    %fontsizeDiagAxisLabel = max(1,fontsizeDiagLabelPlot-2);
    fontsizeDiagTitlePlot = round(diagAxisScale * fontsizeDiagTitle) + 2;
    fontsizeDiagFontPlot = fontsizeDiagLabelPlot + 2;

    % --------------
    %  Default state
    % --------------

    % Locate utilities in MATLAB source mode. MATLAB Compiler controls
    % the search path in deployed mode, where addpath is unsupported.
    if ~isdeployed
        uiDirectory = fileparts(mfilename('fullpath'));
        softwareRoot = fileparts(fileparts(uiDirectory));
        utilityCandidates = { ...
            fullfile(fileparts(uiDirectory),'utils'), ...
            fullfile(uiDirectory,'utils'), ...
            fullfile(softwareRoot,'SAGEhydrology','utils')};

        utilityFunction = which('ensureSAGEpath');
        if ~isempty(utilityFunction)
            utilityCandidates{end+1} = fileparts(utilityFunction);
        end

        utilityDirectory = '';
        for utilityIndex = 1:numel(utilityCandidates)
            candidate = utilityCandidates{utilityIndex};
            if isfolder(candidate) ...
                    && isfile(fullfile(candidate,'ensureSAGEpath.m'))
                utilityDirectory = candidate;
                break
            end
        end

        if isempty(utilityDirectory)
            error('SAGE_ui:MissingUtilities', ...
                'SAGE utility folder not found. Checked: %s', ...
                strjoin(utilityCandidates,'; '));
        end
        addpath(genpath(utilityDirectory));
        siteSourceDirectory = fullfile(fileparts(uiDirectory),'src');
        if ~isfile(fullfile(siteSourceDirectory,'run_SITE.m'))
            error('SITE_ui:MissingRunner', ...
                'SITE runner not found in %s.',siteSourceDirectory);
        end
        addpath(siteSourceDirectory);
        siteUtilityDirectory = fullfile(fileparts(uiDirectory),'utils');
        addpath(fullfile(siteUtilityDirectory,'optim'), ...
            fullfile(siteUtilityDirectory,'results'), ...
            fullfile(siteUtilityDirectory,'benchmarks'));
        guiSupportDirectory = fullfile(uiDirectory,'support');
        if ~isfolder(guiSupportDirectory)
            error('SITE_ui:MissingSupport', ...
                'SITE GUI support folder not found in %s.',uiDirectory);
        end
        addpath(guiSupportDirectory,fullfile(uiDirectory,'sage'));
    end

    S = struct();
    S.cfg = local_default_config();

    S.ui = struct();
    S.runtime = struct();
    S.runtime.isRunning = false;
    S.runtime.dataReady = false;
    S.runtime.stopRequested = false;
    S.runtime.postprocessAfterStop = true;
    S.runtime.lastError = '';
    S.runtime.lastStatus = 'Idle';
    S.runtime.lastConfig = [];
    S.runtime.lastOut = [];
    S.runtime.informationSnapshot = [];
    S.runtime.informationCache = struct();
    S.runtime.informationTime = zeros(1,0);
    S.runtime.pendingInformationExcess = [];
    S.runtime.allowExcessInformation = false;
    S.runtime.startTime = [];
    S.runtime.endTime = [];
    S.runtime.compileOK = false;
    S.runtime.compileMessage = ...
        'CRR backend not checked yet';
    S.runtime.dependencyNotice = ...
        'No dependency changes yet';
    S.runtime.postSelectionIsRandom = false;
    % One persisted snapshot owns diagnostic basin choices for a run.
    S.runtime.prepared = false;
    S.runtime.preparedBasins = [];
    S.runtime.preparedLatLon = [];
    S.runtime.previewRuntime = struct('tout',[], ...
        'id_train',[], ...
        'id_eval',[],'idx',[]);
    S.runtime.attr = struct('At',[], ...
        'An',[],'iter',[], ...
        'names',strings(0,1),'last_i',0);
    S.runtime.conusParameterIndex = 1;
    S.runtime.checksOK = false;
    S.runtime.initializingUI = false;
    % A region selection made while controls are still being initialized
    % is replayed once initialization is complete.
    S.runtime.pendingRegionChange = false;
    S.runtime.isClosing = false;
    S.runtime.sessionSchemaVersion = 3;
    S.runtime.guiVersion = '2026.09.26-SITE-exact-SAGE-fork';
    S.runtime.recoveryFile = fullfile(tempdir,'SITE_ui_recovery.mat');
    S.runtime.runManifestFile = '';
    % Refresh machine/pool diagnostics once after the first completed
    % iteration of each run, even when Summary is not the active tab.
    S.runtime.summaryAutoRefreshed = false;
    S.runtime.stopRequestTime = [];
    S.runtime.userSelectedRightTabDuringRun = false;
    S.runtime.lastProgressText = '';
    % Expensive disk/map work is performed lazily when its tab is opened.
    S.runtime.dataStatusDirty = true;
    S.runtime.mapInitialized = false;
    S.runtime.worldCoverageDrawn = false;

    S.runtime.mapFile = '';
    S.runtime.mapScale = 'none';
    S.runtime.mapDownloadMessage = '';
    % Renderer-protection state. The GUI stores all messages/results but
    % pushes updates to the Chromium-based uifigure renderer sparingly.
    S.runtime.lastGuiDrawClock = tic;
    S.runtime.lastYieldClock = tic;
    S.runtime.guiDrawPeriod = 0.75;   % seconds
    S.runtime.yieldPeriod = 0.25;     % seconds
    S.runtime.maxVisibleLogLines = 1500;
    S.runtime.maxVisibleIterLines = 1500;

    S.store = struct();
    S.store.parOverride = struct();
    S.store.odeOverride = struct();
    S.store.modelOptions = struct();
    S.store.logAll = strings(0,1);
    S.store.iterAll = strings(0,1);
    S.store.runNotes = "";
    S.store.siteOptByMethod = struct();
    
    S.flags = struct();
    S.flags.advancedMode = true;
    S.flags.followIterTail = true;
    S.flags.traceAuto = true;
    S.flags.attribAuto = true;
    S.flags.traceGrid = false;
    S.flags.plainConus = false;
    
    % performance cache
    S.perf = struct();
    S.perf.timer = [];
    S.perf.tHeavy = tic;
    S.perf.heavyEvery = 30;
    S.perf.tCPU = tic;
    S.perf.cpuEvery = 5;
    % Live diagnostic refresh cadence. Expensive plots are refreshed only
    % when visible and at the requested completed-iteration interval.
    S.perf.refreshEvery = struct( ...
        'metrics',2, ...
        'generalization',1, ...
        'zoneTable',5, ...
        'paramMap',1, ...
        'measurementError',10, ...
        'information',1);
    S.perf.cache = struct('matlab','','machine','', ...
        'arch','','ncores',[]);
    S.perf.fixedReady = false;
    
    S.cache = struct();
    S.cache.modelBase = [];
    S.cache.modelBaseKey = "";
    S.cache.regionConfig = [];
    S.cache.regionConfigKey = "";
    % Cache Natural Earth geometry after the first shapefile read.
    % Reading the 10 m shapefile repeatedly is substantially slower than
    % plotting the already-loaded country coordinates.
    S.cache.naturalEarthFile = '';
    S.cache.naturalEarthShapes = [];
    S.cache.countryBoundary = struct();
    % Fast interactive map rendering:
    % use Natural Earth 50 m geometry in the GUI and avoid rebuilding an
    % unchanged parameter map. The 10 m file remains available elsewhere.
    S.cache.paramMapRenderKey = "";
    S.runtime.preferFastMap50m = true;
    % initialize root/path helpers
    try
        ensureInstallerOnPath(S.cfg.root);
        ensureSAGEpath(S.cfg.root);
    catch ME
        warning('SAGE_ui:pathSetup', ...
            'Could not initialize the SAGE path: %s', ...
            ME.message);
    end
    
    % ------------------
    %  Figure and layout
    % ------------------
    f = uifigure('Name', ...
        'SITEhydrology - Graphical User Interface', ...
        'Position',figPos, ...
        'Visible','off', ...
        'AutoResizeChildren','off', ...
        'CloseRequestFcn',@onCloseRequest);
    benchmarkMenu=uimenu(f,'Text','Shared benchmarks');
    uimenu(benchmarkMenu,'Text','Retry saved contribution...', ...
        'MenuSelectedFcn',@onRetrySavedBenchmark);
    % Clear stale table-cell highlighting whenever focus moves to a
    % non-table part of the GUI.  Individual table callbacks remain intact.
    try
        f.WindowButtonDownFcn = @onMainFigureButtonDown;
    catch
    end

    % Standalone styling callbacks keep parser-heavy helper bodies out of
    % the already large nested SITE_ui workspace.
    diagStyleFcn = @(ax) site_styleDiagnosticAxes(ax,f.Color, ...
        fontsizeDiagTickPlot,fontsizeDiagTitlePlot, ...
        fontsizeDiagLabelPlot);
    perfStyleFcn = @(ax) site_stylePerfAxis(ax,f.Color, ...
        fontsizeDiagTickPlot,fontsizeDiagTitlePlot, ...
        fontsizeDiagLabelPlot,fontsizeDiagFontPlot);

    gMain = uigridlayout(f,[1 2]);
    % Use the native MATLAB theme for every embedded plot and HTML surface.
    f.Color = gMain.BackgroundColor;
    % Explicitly resize the root grid with the figure. MATLAB suppresses
    % SizeChangedFcn when AutoResizeChildren is enabled.
    try
        gMain.Units = 'pixels';
    catch
    end
    f.SizeChangedFcn = @onMainFigureResized;
    gMain.RowHeight = {'1x'};
    gMain.ColumnWidth = {'2.6x','3x'};
    gMain.Padding = [10 10 10 10];
    gMain.ColumnSpacing = 10;
    onMainFigureResized();
    
    %% LEFT SIDE ----------------------------------------------------------
    pLeft = uipanel(gMain,'Title','');
    pLeft.Layout.Row = 1;
    pLeft.Layout.Column = 1;
    
    gLeft = uigridlayout(pLeft,[3 1]);
    gLeft.RowHeight = {28,'1x',34};
    gLeft.ColumnWidth = {'1x'};
    gLeft.Padding = [10 10 10 10];
    gLeft.RowSpacing = 8;
    
    % -------------------------------------
    % header row: title + controls + status
    % -------------------------------------
    gHdrLeft = uigridlayout(gLeft,[1 4]);
    gHdrLeft.Layout.Row = 1;
    gHdrLeft.Layout.Column = 1;
    gHdrLeft.RowHeight = {30};
    % Save/load remain compact at the left; the status receives all
    % remaining horizontal space, which prevents truncation on laptops.
    gHdrLeft.ColumnWidth = {'fit',110,110,'1x'};
    gHdrLeft.Padding = [0 0 0 0];
    gHdrLeft.ColumnSpacing = 8;
    
    lblConfiguration = uilabel(gHdrLeft, ...
        'Text','Configuration', ...
        'FontName',visualTheme.fonts.family.gui, ...
        'fontsize',fontsizeSlice, ...
        'fontweight','bold', ...
        'horizontalalignment','left');
    lblConfiguration.Layout.Row = 1;
    lblConfiguration.Layout.Column = 1;

    % Keep the Advanced-mode implementation and state available, but hide
    % the control from the normal interface for now.  Setting Visible to
    % 'on' later is sufficient to reactivate it programmatically.
    S.ui.cbAdvanced = uicheckbox(f, ...
        'Text','Advanced mode', ...
        'Value',true, ...
        'Visible','off', ...
        'Position',[1 1 1 1], ...
        'fontsize',fontsizeGUI, ...
        'ValueChangedFcn',@onAdvancedModeChanged);
    
    S.ui.btnSaveSession = uibutton(gHdrLeft, ...
        'Text','Save session', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onSaveSession);
    S.ui.btnSaveSession.Layout.Row = 1;
    S.ui.btnSaveSession.Layout.Column = 2;
    
    S.ui.btnLoadSession = uibutton(gHdrLeft, ...
        'Text','Load session', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onLoadSession);
    S.ui.btnLoadSession.Layout.Row = 1;
    S.ui.btnLoadSession.Layout.Column = 3;
    
    S.ui.lblRunStatus = uilabel(gHdrLeft, ...
        'Text','Idle', ...
        'horizontalalignment','right', ...
        'fontsize',fontsizeGUI, ...
        'fontweight','bold');
    S.ui.lblRunStatus.Layout.Row = 1;
    S.ui.lblRunStatus.Layout.Column = 4;
    
    % ---------
    % tab group
    % ---------
    S.ui.tgLeft = uitabgroup(gLeft);
    S.ui.tgLeft.Layout.Row = 2;
    S.ui.tgLeft.Layout.Column = 1;
    
    tabNotes = uitab(S.ui.tgLeft,'Title','Notes');
    tabPaths = uitab(S.ui.tgLeft,'Title','Paths');

    tabRegion = uitab(S.ui.tgLeft,'Title','Region');
    tabPeriod = uitab(S.ui.tgLeft,'Title','Period');
    tabMeteo = uitab(S.ui.tgLeft,'Title','Meteo');
    tabBasins = uitab(S.ui.tgLeft,'Title','Basins');

    tabModel = uitab(S.ui.tgLeft,'Title','Model');
    tabPars = uitab(S.ui.tgLeft,'Title','Parameters');
    tabODE = uitab(S.ui.tgLeft,'Title','ODE | Solver');

    % SITE has no user-facing Attributes tab. Default regional attributes
    % are selected internally for basin zoning/metadata compatibility.
    tabLoss = uitab(S.ui.tgLeft,'Title','Loss function');
    tabTrain = uitab(S.ui.tgLeft,'Title','Training');

    tabDiag = uitab(S.ui.tgLeft,'Title','Diagnostics');
    S.ui.tgLeft.SelectionChangedFcn = @onLeftTabChanged;
    S.ui.tabRegion = tabRegion;
    S.ui.tabMeteo = tabMeteo;
    S.ui.tabModel = tabModel;
    S.ui.tabPars = tabPars;
    S.ui.tabODE = tabODE;
    S.ui.tabLoss = tabLoss;
    S.ui.tabTrain = tabTrain;
    
    try
        tabRegion.Scrollable = 'on'; 
    catch
    end
    try
        tabPeriod.Scrollable = 'on'; 
    catch
    end
    try
        tabMeteo.Scrollable = 'on'; 
    catch
    end
    try
        tabBasins.Scrollable = 'on';
    catch
    end
    try
        tabDiag.Scrollable = 'on';
    catch
    end
    try
        tabTrain.Scrollable = 'on';
    catch
    end
    
    % -------------------
    % bottom button strip
    % -------------------
    gBottomLeft = uigridlayout(gLeft,[1 5]);
    gBottomLeft.Layout.Row = 3;
    gBottomLeft.Layout.Column = 1;
    gBottomLeft.ColumnWidth = ...
        {'1x','1x','1x','1x','1x'};
    gBottomLeft.RowHeight = {26};
    gBottomLeft.Padding = [0 0 0 0];
    gBottomLeft.ColumnSpacing = 8;
    
    S.ui.btnValidate = uibutton(gBottomLeft, ...
        'Text','Validate', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onValidate);
    
    S.ui.btnPrepare = uibutton(gBottomLeft, ...
        'Text','Load basins', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onPrepareBasins, ...
        'fontweight','bold');
    
    S.ui.btnRun = uibutton(gBottomLeft, ...
        'Text','Run SITE', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onRun, ...
        'fontweight','bold');
    
    S.ui.btnStop = uibutton(gBottomLeft, ...
        'Text','Stop SITE', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onStop, ...
        'Enable','off', ...
        'fontweight','bold');
    
    S.ui.btnExportScript = uibutton(gBottomLeft, ...
        'Text','Export script', ...
        'fontsize',fontsizeButton, ...
        'ButtonPushedFcn', ...
        @onExportScript, ...
        'Enable','off', ...
        'fontweight','bold');
    
    %% RIGHT SIDE ---------------------------------------------------------
    pRight = uipanel(gMain,'Title','');
    pRight.Layout.Row = 1;
    pRight.Layout.Column = 2;
    
    gRight = uigridlayout(pRight,[2 1]);
    gRight.RowHeight = {28,'1x'};     % was {24,'1x'}
    gRight.ColumnWidth = {'1x'};
    gRight.Padding = [10 12 10 10];   % add a little extra top padding
    gRight.RowSpacing = 8;            % was 6
    
    gRightHdr = uigridlayout(gRight,[1 5]);
    gRightHdr.Layout.Row = 1;
    gRightHdr.Layout.Column = 1;
    gRightHdr.RowHeight = {24};
    % Dedicated spacer adds about two spaces before the flag, while
    % keeping the flag and resolution icon in their existing positions.
    gRightHdr.ColumnWidth = {'1x',539,6,36,36};
    gRightHdr.Padding = [0 2 0 0];    % tiny top offset
    gRightHdr.ColumnSpacing = 5;
    
    uilabel(gRightHdr, ...
        'Text','Output & Monitoring', ...
        'fontweight','bold', ...
        'fontsize',fontsizeSlice, ...
        'horizontalalignment','left');
    
    % Live iteration/basin progress belongs with the monitored output.
    % Keep the left header status available for the overall GUI state.
    S.ui.lblProgressStatus = uilabel(gRightHdr, ...
        'Text','', ...
        'fontsize',fontsizeGUI, ...
        'fontweight','bold', ...
        'FontColor',[0.25 0.25 0.25], ...
        'horizontalalignment','right');
    S.ui.lblProgressStatus.Layout.Row = 1;
    S.ui.lblProgressStatus.Layout.Column = 2;
    S.ui.imgProgressFlag = uiimage(gRightHdr,'ScaleMethod','fit');
    S.ui.imgProgressFlag.Layout.Column = 4;
    S.ui.imgResolutionIcon = uiimage(gRightHdr,'ScaleMethod','fit');
    S.ui.imgResolutionIcon.Layout.Column = 5;
    S.ui.imgResolutionIcon.Tooltip = 'Temporal resolution';
    
    S.ui.tgRight = uitabgroup(gRight);
    S.ui.tgRight.Layout.Row = 2;
    S.ui.tgRight.Layout.Column = 1;
    S.ui.tgRight.SelectionChangedFcn = ...
        @onRightTabChanged;
    
    tabSummary = uitab(S.ui.tgRight, ...
        'Title','Summary');
    tabPreview = uitab(S.ui.tgRight, ...
        'Title','Preview');
    tabChecks = uitab(S.ui.tgRight, ...
        'Title','Checks');
    tabQuality = uitab(S.ui.tgRight, ...
        'Title','Data quality');
    tabLog = uitab(S.ui.tgRight, ...
        'Title','Log');
    tabIter = uitab(S.ui.tgRight, ...
        'Title','Iter');
    tabRegionMap = uitab(S.ui.tgRight, ...
        'Title','Region');
    tabZones = uitab(S.ui.tgRight, ...
        'Title','Zones');
    tabParamMap = uitab(S.ui.tgRight, ...
        'Title','Map');
    tabBasinResults = uitab(S.ui.tgRight, ...
        'Title','Basin Results');
    tabStatistics = uitab(S.ui.tgRight, ...
        'Title','Model Comparison');
    tabZoneTable = uitab(S.ui.tgRight, ...
        'Title','Zone table');
    tabFeedback = uitab(S.ui.tgRight, ...
        'Title','Feedback');
    
    S.ui.tabSummary = tabSummary;
    S.ui.tabPreview = tabPreview;
    S.ui.tabLog = tabLog;
    S.ui.tabIter = tabIter;
    S.ui.tabFeedback = tabFeedback;
    S.ui.tabChecks = tabChecks;
    S.ui.tabQuality = tabQuality;
    S.ui.tabRegionMap = tabRegionMap;
    S.ui.tabZones = tabZones;
    S.ui.tabParamMap = tabParamMap;
    S.ui.tabBasinResults = tabBasinResults;
    S.ui.tabStatistics = tabStatistics;
    S.ui.tabZoneTable = tabZoneTable;
    
    % ----------------
    %  Build LEFT tabs
    % ----------------
    S.ui = build_notes_tab(S.ui,tabNotes,S.cfg.root, ...
        @onReferenceHtmlEvent,@(body)local_html_page(body,f.Color), ...
        @localDocsDir,@local_png_to_base64);
    % Replace the SAGE introduction with a SITE-specific benchmark overview
    % while retaining the shared Notes-tab infrastructure and run-notes box.
    site_customize_notes_tab(tabNotes,S.ui,fontsizeNotes,S.cfg.root);
    buildPathsTab(tabPaths);

    buildRegionTab(tabRegion);
    buildPeriodTab(tabPeriod);
    % The region tab is built before the Period tab creates edDt. Refresh
    % the temporal badge only after the resolution control exists.
    time_resolution_icon_ui(S.ui,double(S.ui.edDt.Value), ...
        S.cfg.SAGEhydro);
    buildMeteoTab(tabMeteo);
    buildBasinsTab(tabBasins);

    buildModelTab(tabModel);
    buildParsTab(tabPars);
    buildODETab(tabODE);

    % No Attributes tab is constructed for SITE.
    buildLossTab(tabLoss);
    buildTrainTab(tabTrain);

    buildPostTab(tabDiag);
    
    % -----------------
    %  Build RIGHT tabs
    % -----------------
    buildSummaryTab(tabSummary);
    S.ui = checks_dashboard_ui('build',S.ui,tabChecks, ...
        @(~,~)refreshReadiness(),@onShowFirstError, ...
        @onGoToSelectedCheck,@onCheckSelected, ...
        fontsizeButton,fontsizeChecks);
    buildDataQualityTab(tabQuality);
    S.ui = preview_dashboard_ui('build',S.ui, ...
        tabPreview,fontsizePreview);
    buildLogTab(tabLog);
    buildIterTab(tabIter);
    buildConusTab(tabRegionMap);
    buildZonesTab(tabZones);
    buildParamMapTab(tabParamMap);
    buildBasinResultsTab(tabBasinResults);
    buildStatisticsTab(tabStatistics);
    buildZoneTableTab(tabZoneTable);
    S.ui = build_feedback_tab(S.ui,tabFeedback, ...
        @onCopyLastError,fontsizeButton,fontsizeGUI);
    site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color);

    % SITE is an exact SAGE-ui fork. Build the complete control tree so all
    % shared helpers keep their expected handles, then hide only the surfaces
    % that have no SITE meaning.
    siteUi('configureVisibleTabs');
    

    % ------------------------------
    % Initialize controls from S.cfg
    % ------------------------------
    S.runtime.initializingUI = true;
    
    try
        % This already calls refreshResolutionControls and
        % refreshPeriodMethodControls.
        setUIFromConfig(S.cfg);    
        % Populate model-dependent controls once.
        refreshModelDropdown('hbv');    
        S.runtime.attrReady = false;
        syncRegionalAttributeDefaults();    
        refreshDerivedPaths();    
    catch ME
        S.runtime.initializingUI = false;
        rethrow(ME)
    end
    
    S.runtime.initializingUI = false;
    site_reorderRightTabs(S.ui.tgRight,{tabSummary, ...
        tabPreview,tabQuality, ...
            tabLog,tabIter,tabRegionMap, ...
            tabZones,tabParamMap, ...
            tabBasinResults,tabStatistics});
    % A fast user selection during startup used to be ignored because the
    % region callback returned while initializingUI was true.  Replay that
    % selection now, or synchronize whenever the dropdown and S.cfg differ.
    try
        selectedRegion = region_helpers('code', ...
            S.ui.ddRegion.Value);
        configuredRegion = region_helpers('code',S.cfg);
        replayRegion = S.runtime.pendingRegionChange ...
            || ~strcmpi(selectedRegion,configuredRegion);
    catch
        replayRegion = false;
    end
    S.runtime.pendingRegionChange = false;
    if replayRegion
        onRegionChanged([],[]);
    end
    
    toggleAdvancedMode(S.ui.cbAdvanced.Value);
    siteUi('configureVisibleTabs');
    % ------------------------------
    % Apply common visual formatting
    % ------------------------------
    fontMultiplier = 1.0;
    scaleGUIFonts(f,fontMultiplier);
    setAllDropdownFonts(f,fontsizeDropdown);
    setValueFieldFonts(f,fontsizeGUI);
    setTabValueFonts();
    site_center_buttons_ui(f);
    try
        resizeParameterTable();
    catch
    end
    
    % Recalculate text boxes once, after final font scaling.
    try
        refreshMeteoPETInfo();
    catch ME
        logmsg(['Initial Meteo/PET note resize failed: ' ...
            ME.message]);
    end    
    try
        refreshLossHelpText();
    catch ME
        logmsg(['Initial Loss note resize failed: ' ...
            ME.message]);
    end    
    try
        updateReferenceBlock_standalone(S.ui,fontsizeNotes);
    catch ME
        logmsg(['Initial Period note resize failed: ' ...
            ME.message]);
    end
    
    % The bundled Natural Earth 50 m map is resolved after the figure is
    % shown. GUI initialization never downloads map data.

    % ------------------------------
    % Initialize diagnostic visuals
    % ------------------------------
    try
        resetInitialDiagnosticAxisFonts();
    catch ME
        logmsg(['Initial diagnostic setup failed: ' ...
            ME.message]);
    end
    
    try
        clearConusAxes();
        clearZonesAxes();
        clearParamMapAxes();
        refreshEmptyMapTitles();
        styleMapGeoAxes(S.ui.axConus);
        styleMapGeoAxes(S.ui.axZones);
        styleMapGeoAxes(S.ui.axParamMap);
    catch ME
        logmsg(['Initial map setup failed: ' ...
            ME.message]);
    end
    
    try
        S.ui.txtPreview.FontSize = fontsizePreview;
    catch
    end    
    try
        S.ui.txtLog.FontSize = fontsizePreview;
    catch
    end
    
    % ---------------------
    % Final essential state
    % ---------------------
    refreshDataStatus();
    refreshReadiness();
    refreshSummary();
    refreshLogView();
    setGuiState('idle');
    
    logmsg('SITE_ui ready.');
    if isdeployed
        cleanupTimer=timer('ExecutionMode','fixedSpacing','Period',300,'StartDelay',30,'BusyMode','drop','TimerFcn',@cleanupSavedSubmissions);
        setappdata(f,'SITEBenchmarkCleanupTimer',cleanupTimer);
        cleanupListener=addlistener(f,'ObjectBeingDestroyed',@(~,~)delete(cleanupTimer));
        setappdata(f,'SITEBenchmarkCleanupListener',cleanupListener);start(cleanupTimer);
    end
    drawnow
    % Optimizer-note sizing is deferred until the Training tab is opened.
    % Switching hidden tabs and forcing several full drawnow calls here was
    % a substantial startup cost.

    function cleanupSavedSubmissions(~,~)
        if ~isgraphics(f)||S.runtime.isRunning,return,end
        pending=dir(fullfile(S.cfg.dirres,'**','*_submission.mat'));
        for p=1:numel(pending)
            if S.runtime.isRunning,return,end
            site_benchmark_cleanup_ui(fullfile(pending(p).folder,pending(p).name),@logmsg);
        end
    end

    % -------------------------------------------------------------
    % Initialize hidden output tabs, then reveal on the Summary tab
    % -------------------------------------------------------------
    % The diagnostic tabs need one selected-state layout pass because
    % MATLAB does not provide reliable pixel geometry while a tab remains
    % unselected. Perform those temporary selections before the figure is
    % visible so startup never flashes the Information or plotting tabs.
    try
        S.ui.tgRight.SelectedTab = S.ui.tabSummary;
        settleOutputMonitoringPlotLayouts();
        S.ui.tgRight.SelectedTab = S.ui.tabSummary;
        drawnow nocallbacks;
        sage_apply_ui_theme(f,visualTheme);
        f.Visible = 'on';
        drawnow;
        if isequal(S.ui.tgLeft.SelectedTab,tabNotes)
            siteResizeNotesIntro(S.ui);
        end
        % A restored session may already have Training selected, so no tab
        % change event occurs after reveal. Size its notes with the real
        % visible width in that case.
        if isequal(S.ui.tgLeft.SelectedTab,S.ui.tabTrain)
            refreshOptHelpText();
            drawnow;
            refreshOptHelpText();
        elseif isequal(S.ui.tgLeft.SelectedTab,S.ui.tabMeteo)
            refreshMeteoPETInfo();
            drawnow;
            refreshMeteoPETInfo();
        elseif isequal(S.ui.tgLeft.SelectedTab,S.ui.tabLoss)
            refreshLossHelpText();
            drawnow;
            refreshLossHelpText();
        end
        localScheduleResponsiveNoteResize();
    catch ME
        try
            S.ui.tgRight.SelectedTab = S.ui.tabSummary;
            f.Visible = 'on';
            drawnow limitrate;
        catch
        end
        logmsg(['GUI reveal warning: ' ME.message]);
    end

    % Eligible default runs download shared benchmarks before training.

    % Resolve the packaged 50 m Natural Earth map immediately after the
    % figure is visible. This avoids a blank first Map/Region-tab opening
    % without delaying the initial GUI reveal or starting a download.
    try
        file50 = localFindMapFile( ...
            '50','ne_50m_admin_0_countries.shp');
        if isempty(file50)
            file50 = localFindMapFile( ...
                '','ne_50m_admin_0_countries.shp');
        end
        if ~isempty(file50)
            S.runtime.mapFile = file50;
            S.runtime.mapScale = '50m';
            S.runtime.mapDownloadMessage = '';
            S.runtime.mapInitialized = true;
            % Warm the Natural Earth geometry cache once. The cached shapes
            % are reused by Region and parameter Map redraws.
            try
                S.cache.naturalEarthFile = S.runtime.mapFile;
                S.cache.naturalEarthShapes = shaperead( ...
                    S.runtime.mapFile,'UseGeoCoords',true);
                S.cache.countryBoundary = struct();
            catch MEcache
                S.cache.naturalEarthFile = '';
                S.cache.naturalEarthShapes = [];
                logmsg(['Map cache warm-up warning: ' MEcache.message]);
            end
        end
    catch ME
        logmsg(['Initial map preload warning: ' ME.message]);
    end

    % Build the complete coverage map while startup work is still running.
    % It is then ready, including colors and key, on the first Paths click.
    try
        refreshWorldCoverageMap();
    catch ME
        logmsg(['Initial world coverage render warning: ' ME.message]);
    end

    % Draw the geographic backgrounds during initialization so the Region
    % and Map tabs are complete the first time they are opened. Basin and
    % parameter markers are added later when those data become available.
    try
        refreshMapDropdown();
        refreshRegion();
        refreshParamMapPlaceholder();
    catch ME
        logmsg(['Initial map render warning: ' ME.message]);
    end

    % Data/cache status is refreshed when the Region tab is first opened.
    S.runtime.dataStatusDirty = true;
    try
        localOfferRecoverySession();
    catch ME
        logmsg(['Recovery-session check failed: ' ME.message]);
        % A failed restore must not leave the interface in a partially
        % configured state. Rebuild dependent controls from their current
        % valid selections and return the GUI to an operable idle state.
        try
            refreshResolutionControls();
            S.runtime.lastStatus = 'Recovery restore failed';
            refreshAll();
        catch MErefresh
            logmsg(['Recovery-session fallback refresh failed: ' ...
                MErefresh.message]);
        end
    end
    % ==========================================
    function onMainFigureButtonDown(~,~)
    % ==========================================
        % MATLAB does not run a uifigure WindowButtonDownFcn for clicks in
        % an enabled uitable. Reaching this callback therefore means the
        % click was outside the table, so clear any stale cell selection.
        try
            tables = findall(f,'Type','uitable');
            for it = 1:numel(tables)
                try
                    if isprop(tables(it),'Selection')
                        tables(it).Selection = [];
                    end
                catch
                end
            end
            drawnow limitrate nocallbacks
        catch
        end
    end

    % ==========================================
    function onMainFigureResized(varargin)
    % ==========================================
        % Fill the entire drawable uifigure area after maximize, restore,
        % monitor changes, or manual Windows resizing.
        try
            if ~isgraphics(f) || ~isgraphics(gMain)
                return
            end

            try
                pos = f.InnerPosition;
            catch
                pos = f.Position;
            end

            w = max(1,double(pos(3)));
            h = max(1,double(pos(4)));

            try
                gMain.Units = 'pixels';
            catch
            end
            gMain.Position = [1 1 w h];

            drawnow nocallbacks;
            if isfield(S.ui,'tgLeft') ...
                    && isgraphics(S.ui.tgLeft)
                selected = S.ui.tgLeft.SelectedTab;
                if isequal(selected,tabNotes)
                    siteResizeNotesIntro(S.ui);
                elseif isequal(selected,tabPaths)
                    layoutWorldCoveragePanel();
                elseif isfield(S.ui,'tabTrain') ...
                        && isequal(selected,S.ui.tabTrain)
                    % The first figure callback can precede the nested tab
                    % grid's final width. Measure again after it settles.
                    drawnow nocallbacks
                    refreshOptHelpText();
                    drawnow nocallbacks
                    refreshOptHelpText();
                elseif isfield(S.ui,'tabMeteo') ...
                        && isequal(selected,S.ui.tabMeteo)
                    refreshMeteoPETInfo();
                elseif isfield(S.ui,'tabModel') ...
                        && isequal(selected,S.ui.tabModel)
                    refreshModelDiagram();
                    resize_model_configuration_tables_ui(S.ui);
                elseif isfield(S.ui,'tabLoss') ...
                        && isequal(selected,S.ui.tabLoss)
                    refreshLossHelpText();
                elseif isfield(S.ui,'tabPars') ...
                        && isequal(selected,S.ui.tabPars)
                    resizeParameterTable();
                elseif isequal(selected,tabPeriod)
                    drawnow limitrate nocallbacks
                    refreshSplitTimeline();
                end
            end
            if isfield(S.ui,'tgRight') ...
                    && isgraphics(S.ui.tgRight) ...
                    && isfield(S.ui,'tabChecks') ...
                    && isequal(S.ui.tgRight.SelectedTab, ...
                    S.ui.tabChecks)
                resizeChecksTable();
            end
            layoutSelectedOutputMonitoringTab();
            % The browser-backed tables can retain their previous pixel
            % width through the first layout pass after maximize/restore.
            drawnow nocallbacks
            layoutSelectedOutputMonitoringTab();
            if isfield(S.ui,'tabStatistics') ...
                    && isequal(S.ui.tgRight.SelectedTab, ...
                    S.ui.tabStatistics)
                site_model_statistics_ui('resize',S.ui);
            end
            localScheduleResponsiveNoteResize();
        catch
            % Figure resizing must never interrupt the GUI.
        end
    end

    function localScheduleResponsiveNoteResize()

        try
            oldTimer = [];
            if isfield(S.runtime,'noteResizeTimer')
                oldTimer = S.runtime.noteResizeTimer;
            end
            S.runtime.noteResizeTimer = ...
                responsive_note_resize_timer(oldTimer,f, ...
                S.ui.tgLeft,S.ui.tabTrain,S.ui.tabLoss, ...
                S.ui.tabMeteo,@refreshOptHelpText, ...
                @refreshLossHelpText,@refreshMeteoPETInfo);
        catch
        end
    end

    % ============================================
    % SITE-specific UI state layered on SAGE_ui
    % ============================================
    function varargout = siteUi(action,varargin)
    %SITEUI Dispatch SITE-only GUI actions through one nested function.
    % Keeping a single SITE dispatcher avoids adding many nested functions to
    % the already large SAGE_ui parent function, which can exceed MATLAB's
    % nested-function parser complexity limit.

        action = lower(char(string(action)));
        switch action
            case 'configurevisibletabs'
                siteHideTab(tabDiag);

                hidden = {tabChecks,tabZoneTable,tabFeedback};
                for ii = 1:numel(hidden)
                    siteHideTab(hidden{ii});
                end
                try
                    S.ui.tabRegionMap.Title = ...
                        localRegionPanelName(getCurrentRegion());
                catch
                end

                % SITE never has evaluation basins. Collapse the inherited
                % evaluation-basin input row and give the training-basin table
                % the complete vertical space previously shared by train/eval.
                try
                    S.ui.spKe.Value = 0;
                    S.ui.spKe.Enable = 'off';
                    S.ui.spKe.Visible = 'off';
                catch
                end
                try 
                    updateBasinTableLayout(0);
                catch
                end
                try 
                    site_configure_basin_layout(S.ui,tabBasins);
                catch
                end
                try 
                    site_reorderRightTabs(S.ui.tgRight, ...
                        {tabSummary,tabPreview,tabQuality, ...
                        tabLog,tabIter,tabRegionMap, ...
                        tabZones,tabParamMap, ...
                        tabBasinResults,tabStatistics}); 
                catch
                end

            case 'optimizerchanged'
                oldMethod = [];
                try 
                    oldMethod = S.runtime.siteLastOptMethod; 
                catch
                end
                if ~isempty(oldMethod)
                    siteUi('saveoptsformethod',oldMethod);
                end
                method = double(S.ui.ddSiteOpt.Value);
                siteUi('loadoptimizer',method,false);
                S.runtime.siteLastOptMethod = method;
                siteUi('trainingedited');

            case 'finisherchanged'
                siteUi('savecurrentopts');
                siteUi('loadoptimizer',7,false);
                siteUi('trainingedited');

            case 'synccalc'
                % SITE uses the local parallel profile when parfeval is selected.
                % Worker count and pending-future limits are intentionally not
                % exposed in the GUI.

            case 'trainingedited'
                siteUi('savecurrentopts');
                setGuiState('edited');
                try refreshPreview(); 
                catch
                end
                try refreshSummary(); 
                catch
                end

            case 'opttableedited'
                if ~siteValidateOptEdit(varargin{1},varargin{2})
                    return
                end
                siteUi('savecurrentopts');
                siteUi('trainingedited');

            case 'optdefaults'
                method = double(S.ui.ddSiteOpt.Value);
                key = siteOptimizerKey(method);
                if isfield(S.store.siteOptByMethod,key)
                    S.store.siteOptByMethod = ...
                        rmfield(S.store.siteOptByMethod,key);
                end
                siteUi('loadoptimizer',method,true);
                siteUi('trainingedited');

            case 'savecurrentopts'
                if isfield(S.ui,'ddSiteOpt') ...
                        && ~isempty(S.ui.ddSiteOpt)
                    siteUi('saveoptsformethod', ...
                        double(S.ui.ddSiteOpt.Value));
                end

            case 'saveoptsformethod'
                method = varargin{1};
                key = siteOptimizerKey(method);
                try
                    opts = siteMergeOptsTables( ...
                        S.ui.tblSiteOpts.Data, ...
                        S.ui.tblSiteSharedOpts.Data, ...
                        S.ui.tblSiteOpts.UserData, ...
                        S.ui.tblSiteSharedOpts.UserData);
                    if method == 7
                        opts.finisher = ...
                            char(S.ui.ddSiteFinisher.Value);
                    end
                    S.store.siteOptByMethod.(key) = opts;
                catch ME
                    try
                        S.ui.lblSiteTrainStatus.Text = ...
                            ['opts edit: ' ME.message];
                    catch
                    end
                end

            case 'loadoptimizer'
                method = varargin{1};
                forceDefaults = false;
                if numel(varargin) >= 2
                    forceDefaults = logical(varargin{2});
                end
                key = siteOptimizerKey(method);
                if ~forceDefaults ...
                        && isfield(S.store.siteOptByMethod,key) ...
                        && isstruct(S.store.siteOptByMethod.(key)) ...
                        && ~isempty(fieldnames( ...
                        S.store.siteOptByMethod.(key)))
                    opts = S.store.siteOptByMethod.(key);
                    source = 'session / edited values';
                else
                    [opts,source] = siteOptimizerDefaults( ...
                        method,char(S.ui.edRoot.Value));
                    S.store.siteOptByMethod.(key) = opts;
                end
                opts = siteNormalizeOptimizerOpts( ...
                    opts,method,char(S.ui.edRoot.Value));
                isHybrid = method == 7;
                if isHybrid
                    if ~isfield(opts,'finisher') ...
                            || ~any(strcmpi(string(opts.finisher), ...
                            ["lbfgsb","pgd"]))
                        opts.finisher = 'lbfgsb';
                    end
                end
                S.store.siteOptByMethod.(key) = opts;
                [methodOpts,sharedOpts] = siteSplitOpts(opts);
                if isHybrid
                    S.ui.ddSiteFinisher.Value = ...
                        char(lower(string(opts.finisher)));
                    methodOpts = rmfield(methodOpts,'finisher');
                    S.ui.lblSiteFinisher.Layout.Row = 2;
                    S.ui.ddSiteFinisher.Layout.Row = 2;
                    S.ui.spSiteStarts.Layout.Row = 3;
                    S.ui.spSiteIMax.Layout.Row = 4;
                    S.ui.spSiteSaveEvery.Layout.Row = 5;
                    S.ui.lblSiteStarts.Layout.Row = 3;
                    S.ui.lblSiteIMax.Layout.Row = 4;
                    S.ui.lblSiteSaveEvery.Layout.Row = 5;
                    S.ui.gSiteTrainTop.RowHeight = ...
                        repmat({rowHValueTraining},1,5);
                else
                    S.ui.lblSiteFinisher.Layout.Row = 5;
                    S.ui.ddSiteFinisher.Layout.Row = 5;
                    S.ui.spSiteStarts.Layout.Row = 2;
                    S.ui.spSiteIMax.Layout.Row = 3;
                    S.ui.spSiteSaveEvery.Layout.Row = 4;
                    S.ui.lblSiteStarts.Layout.Row = 2;
                    S.ui.lblSiteIMax.Layout.Row = 3;
                    S.ui.lblSiteSaveEvery.Layout.Row = 4;
                    S.ui.gSiteTrainTop.RowHeight = ...
                        [repmat({rowHValueTraining},1,4),{0}];
                end
                S.ui.lblSiteFinisher.Visible = tern(isHybrid,'on','off');
                S.ui.ddSiteFinisher.Visible = tern(isHybrid,'on','off');
                S.ui.tblSiteOpts.UserData = fieldnames(methodOpts);
                S.ui.tblSiteSharedOpts.UserData = fieldnames(sharedOpts);
                finisher = '';
                if isHybrid
                    finisher = char(opts.finisher);
                end
                S.ui.tblSiteOpts.Data = siteOptsToTable( ...
                    methodOpts,method,char(S.ui.edRoot.Value), ...
                    finisher);
                S.ui.tblSiteSharedOpts.Data = siteOptsToTable( ...
                    sharedOpts,method,char(S.ui.edRoot.Value));
                trainHeight = uitable_content_height_ui(S.ui.tblSiteOpts);
                sharedHeight = uitable_content_height_ui(S.ui.tblSiteSharedOpts);
                % Keep table viewports fitted to their rows, just as on
                % Model; panel/button space must not stretch the tables.
                S.ui.tblSiteOpts.Parent.RowHeight = {trainHeight,34};
                S.ui.tblSiteSharedOpts.Parent.RowHeight = {sharedHeight};
                panelHeader = ceil(1.4*fontsizeNotes)+4;
                S.ui.gSiteTrain.RowHeight = ...
                    {166+38*double(isHybrid), ...
                    panelHeader+16+trainHeight+5+34, ...
                    panelHeader+16+sharedHeight,20,155};
                try
                    if isempty(source)
                        source = ['optimizer source: ' ...
                            'no opts defaults detected'];
                    end
                    S.ui.lblSiteOptSource.Text = '';
                    S.ui.lblSiteOptHelp.Value = cellstr(splitlines( ...
                        string(siteOptimizerHelp(method,source))));
                catch
                end

            case 'restoretraining'
                C = varargin{1};
                if ~isfield(C,'site') ...
                        || ~isstruct(C.site)
                    return
                end
                X = C.site;
                try
                    if isfield(X,'optsByMethod') ...
                            && isstruct(X.optsByMethod)
                        S.store.siteOptByMethod = X.optsByMethod;
                    end
                catch
                end
                try 
                    S.ui.ddSiteOpt.Value = double(X.alg.method);
                catch
                end
                try 
                    S.ui.spSiteStarts.Value = double(X.alg.n);
                catch
                end
                try 
                    S.ui.spSiteIMax.Value = double(X.alg.i_max); 
                catch
                end
                try 
                    S.ui.spSiteSaveEvery.Value = double(X.saveEvery);
                catch
                end
                try
                    if isfield(X.alg,'opts')
                        key = siteOptimizerKey(X.alg.method);
                        S.store.siteOptByMethod.(key) = X.alg.opts;
                        siteUi('loadoptimizer', ...
                            X.alg.method,false);
                    else
                        siteUi('loadoptimizer', ...
                            S.ui.ddSiteOpt.Value,false);
                    end
                catch
                end
                try
                    S.runtime.siteLastOptMethod = ...
                        double(S.ui.ddSiteOpt.Value);
                catch
                end
                siteUi('synccalc');

            case 'buildrunconfig'
                cfg = varargin{1};
                C = struct();
                C.root = cfg.root;
                C.SAGEhydro = cfg.SAGEhydro;
                C.region = cfg.region;
                C.dirD = cfg.dirD;
                C.dirM = cfg.dirM;
                C.dirQ = cfg.dirQ;
                C.file_univ = local_basin_absolute_file( ...
                    cfg,cfg.file_univ);
                if local_is_gchm_ode(cfg.mdl)
                    C.model = 'gchm_ode';
                else
                    C.model = cfg.mdl.model;
                end
                C.mcode = cfg.mdl.mcode;
                C.prd = cfg.prd;
                C.meteo = cfg.misc.meteo;
                C.loss = cfg.misc.loss;
                C.loss.observed = {'Q'};
                C.alg = cfg.site.alg;
                C.ode = cfg.ode;
                if isfield(cfg.mdl,'config'),C.modelConfig=cfg.mdl.config;end
                if cfg.mdl.model==99,C.user_model_folder=local_user_model_dir(cfg.root);end
                C.parallel = strcmpi(char(cfg.site.calc),'parfeval');
                C.numWorkers = [];
                C.maxPending = [];
                C.saveEvery = max(1,round(double(cfg.site.saveEvery)));
                C.resultDir = cfg.dirres;
                [~,resultLeaf] = fileparts(C.resultDir);
                if ~strcmpi(resultLeaf,char(C.region))
                    C.resultDir = fullfile(C.resultDir,char(C.region));
                end
                C.parOverride = S.store.parOverride;
                C.basinNumbers = sitePreparedBasinNumbers( ...
                    C.file_univ,S.runtime.preparedBasins);
                C.ui = struct( ...
                    'logFcn',@logmsg, ...
                    'logProgressFcn',@logprogress, ...
                    'iterFcn',@itermsg, ...
                    'progressFcn',@(message,k,K) ...
                        siteUi('progressupdate',message,k,K), ...
                    'activeBasinsFcn',@(gauges)siteUi('activebasinsupdate',gauges), ...
                    'qualityFcn',@(q)qualityDashboard('update',q), ...
                    'resultFcn',@(k,result,store,mdl,bas,ids) ...
                        siteUi('basinresultupdate', ...
                        k,result,store,mdl,bas,ids), ...
                    'storeFcn',@(store,bas) ...
                        siteUi('basinresultstoreupdate',store,bas), ...
                    'timingFcn',@(phase,value) ...
                        siteUi('sitetimingupdate',phase,value), ...
                    'guiTimeFcn',@(k,value,K) ...
                        siteUi('siteguiruntimeupdate',k,value,K), ...
                    'confirmSchemaChangeFcn', ...
                        @confirmModelResultReplacement, ...
                    'shouldStop',@shouldStop);
                varargout{1} = C;

            case 'activebasinsupdate'
                S.runtime.siteActiveGaugeIds = string(varargin{1});
                refreshSiteActiveBasins();
                localRendererYield(false);

            case 'progressupdate'
                message = varargin{1};
                k = [];
                K = [];
                if numel(varargin) >= 2
                    k = varargin{2}; 
                end
                if numel(varargin) >= 3
                    K = varargin{3}; 
                end
                try
                    if isempty(k) || isempty(K)
                        setProgressStatus(char(string(message)));
                    else
                        setProgressStatus(sprintf( ...
                            '%s | basin %d/%d', ...
                            char(string(message)),k,K));
                    end
                    localRendererYield(false);
                catch
                end

            case 'basinresultupdate'
                k = varargin{1};
                result = varargin{2};
                mdl = varargin{4};
                ids = varargin{6};
                try
                    currentStore = varargin{3};
                    previousStore = [];
                    if isfield(S.runtime,'siteResultStore')
                        previousStore = S.runtime.siteResultStore;
                    end
                    nChanged = 0;
                    if isstruct(previousStore) ...
                            && isfield(previousStore,'train') ...
                            && k <= size(previousStore.train,1)
                        old = previousStore.train(k,:);
                        new = currentStore.train(k,:);
                        if ~isfield(S.runtime,'siteResultUpdated') ...
                                || ~isequal(size( ...
                                S.runtime.siteResultUpdated), ...
                                size(currentStore.train))
                            S.runtime.siteResultUpdated = ...
                                false(size(currentStore.train));
                        end
                        for jj = 1:min(numel(old),numel(new))
                            if ~isfinite(new(jj)) ...
                                    || isequaln(old(jj),new(jj))
                                continue
                            end
                            metric = char(string( ...
                                currentStore.metricNames{jj}));
                            if isfinite(old(jj))
                                itermsg(sprintf( ...
                                    '    Improved %s: %.6g -> %.6g', ...
                                    metric,old(jj),new(jj)));
                            else
                                itermsg(sprintf( ...
                                    '    First stored %s: %.6g', ...
                                    metric,new(jj)));
                            end
                            S.runtime.siteResultUpdated(k,jj) = true;
                            nChanged = nChanged + 1;
                        end
                        if nChanged == 0
                            itermsg('    No better stored score.');
                        end
                    end
                catch ME
                    logmsg(['SITE result ' ...
                        'comparison warning: ' ME.message]);
                end
                S.runtime.siteResultStore = varargin{3};
                S.runtime.siteResultBas = varargin{5};
                if isequal(S.ui.tgRight.SelectedTab, ...
                        S.ui.tabBasinResults) && siteLiveRefreshDue('results',3)
                    siteUi('refreshbasinresultstable');
                elseif isequal(S.ui.tgRight.SelectedTab, ...
                        S.ui.tabStatistics) && siteLiveRefreshDue('statistics',3)
                    refreshSiteStatistics(false);
                end
                try
                    K = varargin{5}.K;
                    if ~isfield(S.runtime,'siteBasinRuntime') ...
                            || numel(S.runtime.siteBasinRuntime) ~= K
                        S.runtime.siteBasinRuntime = nan(K,1);
                    end
                    S.runtime.siteBasinRuntime(k) = ...
                        double(result.calibrationRuntime);
                    S.runtime.siteBasinsFinished = ...
                        nnz(isfinite(S.runtime.siteBasinRuntime));

                catch ME
                    logmsg(['SITE runtime update warning: ' ME.message]);
                end
                try
                    d = numel(mdl.par_names);
                    Kp = S.runtime.preparedBasins.K;
                    if ~isfield(S.runtime,'latestNTheta') ...
                            || isempty(S.runtime.latestNTheta) ...
                            || ~isequal(size(S.runtime.latestNTheta), ...
                            [d Kp])
                        S.runtime.latestNTheta = nan(d,Kp);
                    end
                    theta = siteExtractTheta(result,d);
                    if ~isempty(theta)
                        gaugeRun = string(ids(k));
                        preparedKeys = siteGaugeKey(string( ...
                            S.runtime.preparedBasins.id_gauge(:)));
                        gaugeKey = siteGaugeKey(gaugeRun);
                        kp = find(preparedKeys==gaugeKey,1,'first');
                        if ~isempty(kp)
                            S.runtime.latestNTheta(:,kp) = theta(:);
                        end
                        if isequal(S.ui.tgRight.SelectedTab, ...
                                S.ui.tabParamMap) && siteLiveRefreshDue('parameters',3)
                            refreshMapDropdown();
                            refreshParamMap();
                            localRendererYield(false);
                        end
                    end
                catch ME
                    logmsg(['SITE live Map update warning: ' ME.message]);
                end

            case 'sitetimingupdate'
                phase = char(varargin{1});
                S.runtime.siteTiming.(phase) = double(varargin{2});
                refreshSiteTimingNumbers();
                if ~strcmp(phase,'train') ...
                        && isequal(S.ui.tgRight.SelectedTab,S.ui.tabSummary)
                    refreshSummary();
                end

            case 'siteguiruntimeupdate'
                summaryClock = tic;
                k = double(varargin{1});
                value = double(varargin{2});
                K = double(varargin{3});
                if ~isfield(S.runtime,'siteGuiRuntime') ...
                        || numel(S.runtime.siteGuiRuntime) ~= K
                    S.runtime.siteGuiRuntime = nan(K,1);
                end
                S.runtime.siteGuiRuntime(k) = value;
                S.runtime.siteTiming.gui = sum( ...
                    S.runtime.siteGuiRuntime,'omitnan');
                if isequal(S.ui.tgRight.SelectedTab,S.ui.tabSummary)
                    % Progress labels are cheap; configuration and the full
                    % Summary layout do not change for each finished basin.
                    S.ui.txtSumIter.Text = sprintf('%d / %d', ...
                        S.runtime.siteBasinsFinished,K);
                    if ~isempty(S.runtime.startTime)
                        S.ui.txtSumCpuTotal.Text = sprintf('%.1f s', ...
                            seconds(datetime('now')-S.runtime.startTime));
                    end
                    if siteLiveRefreshDue('summary',5)
                        refreshRuntimeSummaryPlot(K);
                        perfUpdateOnce(false);
                    end
                end
                % The summary redraw is GUI work too. Book it after the
                % refresh without triggering another figure rebuild.
                S.runtime.siteGuiRuntime(k) = value + toc(summaryClock);
                S.runtime.siteTiming.gui = sum( ...
                    S.runtime.siteGuiRuntime,'omitnan');
                refreshSiteTimingNumbers();
            case 'basinresultstoreupdate'
                S.runtime.siteResultStore = varargin{1};
                S.runtime.siteResultBas = varargin{2};
                if isequal(S.ui.tgRight.SelectedTab, ...
                        S.ui.tabBasinResults)
                    siteUi('refreshbasinresultstable');
                elseif isequal(S.ui.tgRight.SelectedTab, ...
                        S.ui.tabStatistics)
                    refreshSiteStatistics(false);
                end

            case 'refreshbasinresultstable'
                [store,bas,updated] = loadBasinResultsForCurrentUI();
                site_basin_results_ui('refresh',S.ui,store,bas,updated);

            otherwise
                error('SITE_ui:UnknownSiteAction', ...
                    'Unknown SITE GUI action: %s',action);
        end
    end

    function buildPathsTab(parent)
        callbacks = struct( ...
            'rootChanged',@onRootChanged, ...
            'browseRoot',@onBrowseRoot, ...
            'allowDeployedRoot',true, ...
            'siteChanged',@onSITEChanged, ...
            'browseSite',@(~,~)onBrowseLocation('site'), ...
            'sageChanged',@onSAGEChanged, ...
            'browseSage',@(~,~)onBrowseLocation('sage'), ...
            'dataChanged',@(~,~)onLocationChanged('data'), ...
            'browseData',@(~,~)onBrowseLocation('data'), ...
            'resultsChanged',@(~,~)onLocationChanged('results'), ...
            'browseResults',@(~,~)onBrowseLocation('results'), ...
            'installMap10',@onInstallMap10, ...
            'worldResized',@(~,~)layoutWorldCoveragePanel());
        fonts = struct( ...
            'gui',fontsizeGUI, ...
            'path',fontsizePathText, ...
            'button',fontsizeButton);
        S.ui = paths_region_tabs_ui( ...
            'paths',S.ui,parent,S.cfg,callbacks,fonts);
        refreshMapInstallStatus();
    end

    function buildRegionTab(parent)
        [registeredNames,regionCodes] = region_helpers('list');
        datasetNames = registeredNames;
        datasetCountries = cell(size(regionCodes));
        for ir = 1:numel(regionCodes)
            datasetCountries{ir} = ...
                localRegionPanelName(regionCodes{ir});
            datasetNames{ir} = localDatasetSelectorName( ...
                S.cfg.SAGEhydro,regionCodes{ir},registeredNames{ir});
        end
        countryNames = unique(datasetCountries,'stable');
        currentRegion = region_helpers('code',S.cfg);
        config = struct('root',S.cfg.root, ...
            'dirDroot',S.cfg.dirDroot,'dirD',S.cfg.dirD, ...
            'region',currentRegion, ...
            'country',localRegionPanelName(currentRegion));
        callbacks = struct('countryChanged',@onCountryChanged, ...
            'geographyChanged',@onCountryChanged, ...
            'regionChanged',@onRegionChanged, ...
            'download15min',@onDownload15min, ...
            'downloadHourly',@onDownloadHourly, ...
            'downloadDaily',@onDownloadDaily, ...
            'openDataFolder',@onOpenDataFolder, ...
            'runNoteChanged',@(~,~)onRunNoteChanged());
        fonts = struct('gui',fontsizeGUI,'path',fontsizePathText, ...
            'button',fontsizeButton,'dropdown',fontsizeDropdown, ...
            'notes',fontsizeNotes);
        S.ui = paths_region_tabs_ui('region',S.ui,parent,config, ...
            datasetNames,regionCodes,countryNames,datasetCountries, ...
            callbacks,fonts);
        S.ui.regionDatasetNames = datasetNames;
        S.ui.regionDatasetCodes = regionCodes;
        S.ui.regionDatasetCountries = datasetCountries;
        refreshRegionFlag();
    end

    function buildModelTab(parent)
        [modelNames,modelValues] = local_model_dropdown_items(S.cfg.root);
        callbacks = struct('modelChanged',@onModelChanged, ...
            'simpleRefresh',@onSimpleRefresh,'initialStateEdit',@onSimpleRefresh, ...
            'initialDefaults',@onSimpleRefresh,'modelValueEdit',@onSimpleRefresh, ...
            'modelValueSelected',@onSimpleRefresh,'modelValueDefaults',@onSimpleRefresh);
        fonts = struct('gui',fontsizeGUI,'dropdown',fontsizeDropdown,'button',fontsizeButton);
        if ~isdeployed
            sage_refresh_model_tab_builder_ui();
        end
        S.ui = model_parameters_tabs_ui('model',S.ui,parent, ...
            modelNames,modelValues,callbacks,fonts,false);
    end

    function buildParsTab(parent)
        callbacks = struct('defaults',@onParamDefaults, ...
            'copyBounds',@onCopyParameterBounds, ...
            'tableEdit',@onParamTableEdit, ...
            'cellSelected',@onParamCellSelected);
        fonts = struct('gui',fontsizeGUI,'button',fontsizeButton, ...
            'parameterTable',fontsizeParamtable);
        try
            backgroundColor = f.Color;
        catch
            backgroundColor = [0.94 0.94 0.94];
        end
        S.ui = model_parameters_tabs_ui('parameters',S.ui,parent, ...
            callbacks,fonts,backgroundColor);
        % The shared builder explicitly colors the warning/spacer panels.
        % Match every surrounding surface to the native Parameters layout.
        backgroundColor = S.ui.gParsMain.BackgroundColor;
        surfaces = findall(S.ui.gParsMain);
        for ii = 1:numel(surfaces)
            if isa(surfaces(ii),'matlab.ui.container.Panel') ...
                    || isa(surfaces(ii),'matlab.ui.container.GridLayout')
                surfaces(ii).BackgroundColor = backgroundColor;
            end
        end
        S.ui.lblParsWarning.FontColor = ...
            site_theme_foreground(backgroundColor);
    end

    function buildODETab(parent)
        callbacks = struct('simpleRefresh',@onSimpleRefresh, ...
            'maxIterationsChanged',@onMaxIterODEChanged, ...
            'defaults',@onODEDefaults);
        fonts = struct('gui',fontsizeGUI,'value',fontsizeValueODE, ...
            'dropdown',fontsizeDropdown,'button',fontsizeButton);
        S.ui = ode_solver_tab_ui(S.ui,parent,callbacks,fonts);
    end

    function buildBasinsTab(parent)
        callbacks = struct('setupChanged',@onBasinSetupChanged, ...
            'sampleChanged',@onSampleModeChanged, ...
            'prepareBasins',@onPrepareBasins, ...
            'pickFile',@onPickBasinFile, ...
            'locateTrain',@onPlotTrainBasinLocate, ...
            'locateEval',[], ... % SITE has no evaluation basins
            'searchChanged',@onBasinSearchChanged);
        fonts = struct('gui',fontsizeGUI,'value',fontsizeValueODE, ...
            'dropdown',fontsizeDropdown,'button',fontsizeButton, ...
            'notes',fontsizeNotes);
        S.ui = basins_tab_ui(S.ui,parent,callbacks,fonts, ...
            rowHValueBasins);
        S.ui.gtblBasins = S.ui.tblPlotTrain.Parent;
        S.ui.lblPlotTrain.Text = 'Selected basins';
        % SITE uses one basin population. Basin loading is zone-aware by
        % default, so the SAGE sampling-mode selector is not exposed.
        try S.ui.ddSample.Value = 'zone'; catch, end
        onSampleModeChanged([],[],true);
        try
            S.ui.spKe.Value = 0;
            S.ui.spKe.Enable = 'off';
            S.ui.spKe.Visible = 'off';
            updateBasinTableLayout(0);
            site_configure_basin_layout(S.ui,parent);
            applyRegionBasinDefaults();
        catch
        end
    end

    function onPostprocessTableEdit(~,~)
        updateBprtFromPostTables();
        onPostprocessRefresh();
    end

    function buildAttrTab(parent)
        callbacks = struct('selectAll',@onAttrAll, ...
            'selectNone',@onAttrNone, ...
            'selectDefault',@onAttrDefault, ...
            'cellSelected',@onAttrCellSelected);
        fonts = struct('gui',fontsizeGUI,'button',fontsizeButton);
        S.ui = attributes_tab_ui(S.ui,parent,callbacks,fonts);
    end

    function buildPeriodTab(parent)
        callbacks = struct('resolutionChanged',@onResolutionChanged, ...
            'simpleRefresh',@onSimpleRefresh, ...
            'methodChanged',@onPeriodMethodChanged, ...
            'referenceEvent',@onReferenceHtmlEvent);
        fonts = struct('gui',fontsizeGUI,'value',fontsizeValueODE, ...
            'dropdown',fontsizeDropdown,'notes',fontsizeNotes);
        try
            backgroundColor = f.Color;
        catch
            backgroundColor = [0.94 0.94 0.94];
        end
        panelHeight = localPeriodPanelHeight(4,rowHValuePeriod);
        S.ui = period_tab_ui(S.ui,parent,f,callbacks,fonts, ...
            rowHValuePeriod,panelHeight,backgroundColor);
        refreshPeriodMethodControls();
    end

    function buildMeteoTab(parent)
        fonts = struct('gui',fontsizeGUI,'dropdown',fontsizeDropdown, ...
            'notes',fontsizeNotes);
        S.ui = meteo_tab_ui(S.ui,parent,@onMeteoPETChanged,fonts);
        refreshMeteoPETInfo();
    end

    function buildLossTab(parent)
        callbacks = struct('helpRefresh',@onOptHelpRefresh, ...
            'windowChanged',@onJKGENwinChanged, ...
            'observationChanged',@onOptHelpRefresh);
        fonts = struct('gui',fontsizeGUI,'value',fontsizeValueODE, ...
            'dropdown',fontsizeDropdown,'notes',fontsizeNotes);
        S.ui = loss_tab_ui(S.ui,parent,callbacks,fonts);
        % SITE calibrates discharge only. Retain the shared handles for
        % configuration compatibility, but remove the entire multi-stream
        % objective section from SITE's visible Loss tab.
        S.ui.cbLossQ.Value = true;
        S.ui.cbLossQ.Enable = 'off';
        S.ui.spLossQWeight.Value = 1;
        S.ui.spLossQWeight.Enable = 'off';
        S.ui.cbLossSWE.Value = false;
        S.ui.cbLossSM.Value = false;
        S.ui.ddLossNormalization.Value = 'none';
        objectivePanel = S.ui.cbLossQ.Parent.Parent;
        objectivePanel.Visible = 'off';
        S.ui.pLossHelp.Layout.Row = 2;
        S.ui.gLossMain.RowHeight = {112,'1x',0,0,0};
        refreshLossHelpText();
        jkge_controls_ui(S.ui, ...
            @parseLeadingInt_local,@setVisibleSafe);
    end

    function buildTrainTab(parent)
        % Build the original SAGE Training controls into a hidden host. This
        % preserves handles used by shared SAGE callbacks/session code without
        % exposing neural-network optimizer settings in SITE.
        try
            S.ui.siteLegacyTrainingHost = uipanel(f,'Visible','off', ...
                'Position',[1 1 2 2],'BorderType','none');
            callbacksLegacy = struct('helpRefresh',@onOptHelpRefresh, ...
                'defaults',@onOptDefaults);
            fontsLegacy = struct('gui',fontsizeGUI, ...
                'value',fontsizeValueODE, ...
                'dropdown',fontsizeDropdown, ...
                'notes',fontsizeNotes);
            S.ui = training_tab_ui(S.ui,S.ui.siteLegacyTrainingHost, ...
                callbacksLegacy,fontsLegacy,rowHValueTraining,240);
        catch ME
            logmsg(['Hidden SAGE Training ' ...
                'control build warning: ' ME.message]);
        end

        % Visible SITE Training tab. Optimizer-specific fields are read from
        % each minimizer's opts defaults and shown as a parameter table.
        g = uigridlayout(parent,[5 1]);
        g.RowHeight = {166,242,175,20,155};
        g.ColumnWidth = {'1x'};
        g.Padding = [12 12 12 12];
        g.RowSpacing = 9;
        S.ui.gSiteTrain = g;

        pTop = uipanel(g,'Title','Calibration', ...
            'FontWeight','bold','FontSize',fontsizeNotes);
        pTop.Layout.Row = 1;
        gt = uigridlayout(pTop,[5 2]);
        gt.RowHeight = [repmat({rowHValueTraining},1,4),{0}];
        gt.ColumnWidth = {190,'1x'};
        gt.Padding = [10 8 10 8];
        gt.RowSpacing = 6;
        gt.ColumnSpacing = 8;
        S.ui.gSiteTrainTop = gt;

        siteTrainLabel(gt,1,1,'Calibration method',fontsizeGUI);
        S.ui.ddSiteOpt = uidropdown(gt, ...
            'Items',siteOptimizerItems(), ...
            'ItemsData',1:7, ...
            'Value',5, ...
            'fontsize',fontsizeDropdown, ...
            'ValueChangedFcn',@(~,~)siteUi('optimizerChanged'));
        S.ui.ddSiteOpt.Layout.Row = 1;
        S.ui.ddSiteOpt.Layout.Column = 2;

        S.ui.lblSiteFinisher = siteTrainLabel( ...
            gt,5,1,'Local method',fontsizeGUI);
        S.ui.lblSiteFinisher.Visible = 'off';
        S.ui.ddSiteFinisher = uidropdown(gt, ...
            'Items',{'L-BFGS-B','PGD'}, ...
            'ItemsData',{'lbfgsb','pgd'}, ...
            'Value','lbfgsb', ...
            'fontsize',fontsizeDropdown, ...
            'ValueChangedFcn',@(~,~)siteUi('finisherChanged'));
        S.ui.ddSiteFinisher.Layout.Row = 5;
        S.ui.ddSiteFinisher.Layout.Column = 2;
        S.ui.ddSiteFinisher.Visible = 'off';

        S.ui.lblSiteStarts = siteTrainLabel( ...
            gt,2,1,'Number of trials',fontsizeGUI);
        S.ui.spSiteStarts = uispinner(gt,'Limits',[1 Inf], ...
            'Step',1,'Value',10,'fontsize',fontsizeValueODE, ...
            'ValueChangedFcn',@(~,~)siteUi('trainingEdited'));
        S.ui.spSiteStarts.Layout.Row = 2;
        S.ui.spSiteStarts.Layout.Column = 2;

        S.ui.lblSiteIMax = siteTrainLabel( ...
            gt,3,1,'Maximum iterations',fontsizeGUI);
        S.ui.spSiteIMax = uispinner(gt,'Limits',[1 Inf], ...
            'Step',1,'Value',1000,'fontsize',fontsizeValueODE, ...
            'ValueChangedFcn',@(~,~)siteUi('trainingEdited'));
        S.ui.spSiteIMax.Layout.Row = 3;
        S.ui.spSiteIMax.Layout.Column = 2;

        S.ui.lblSiteSaveEvery = siteTrainLabel( ...
            gt,4,1,'Checkpoint every basins',fontsizeGUI);
        S.ui.spSiteSaveEvery = uispinner(gt,'Limits',[1 Inf], ...
            'Step',1,'Value',1,'fontsize',fontsizeValueODE, ...
            'ValueChangedFcn',@(~,~)siteUi('trainingEdited'));
        S.ui.spSiteSaveEvery.Layout.Row = 4;
        S.ui.spSiteSaveEvery.Layout.Column = 2;


        pOpts = uipanel(g,'Title','Algorithmic parameters (opts)', ...
            'FontWeight','bold','FontSize',fontsizeNotes);
        pOpts.Layout.Row = 2;
        go = uigridlayout(pOpts,[2 1]);
        go.RowHeight = {'1x',34};
        go.Padding = [8 8 8 8];
        go.RowSpacing = 5;
        gh = uigridlayout(go,[1 2]);
        gh.RowHeight = {28};
        gh.ColumnWidth = {'1x',150};
        gh.Padding = [0 0 0 0];
        gh.ColumnSpacing = 6;
        S.ui.lblSiteOptSource = uilabel(gh,'Text','');
        S.ui.lblSiteOptSource.Visible = 'off';
        S.ui.btnSiteOptDefaults = uibutton(gh,'Text', ...
            'Reset defaults', ...
            'fontsize',fontsizeButton, ...
            'ButtonPushedFcn',@(~,~)siteUi('optDefaults'));
        gh.Layout.Row = 2;

        S.ui.tblSiteOpts = uitable(go, ...
            'ColumnName',{'Symbol','Description', ...
            'Min','Max','Default value'}, ...
            'ColumnEditable',[false false false false true], ...
            'ColumnWidth',{175,'1x',80,80,110}, ...
            'RowName',[], ...
            'fontsize',fontsizeParamtable, ...
            'CellEditCallback',@(src,event) ...
            siteUi('optTableEdited',src,event));
        S.ui.tblSiteOpts.Layout.Row = 1;
        S.ui.siteOptSelectedRow = [];

        pShared = uipanel(g,'Title','Shared settings', ...
            'FontWeight','bold','FontSize',fontsizeNotes);
        pShared.Layout.Row = 3;
        gs = uigridlayout(pShared,[1 1]);
        gs.Padding = [8 8 8 8];
        S.ui.tblSiteSharedOpts = uitable(gs, ...
            'ColumnName',{'Symbol','Description', ...
            'Min','Max','Default value'}, ...
            'ColumnEditable',[false false false false true], ...
            'ColumnWidth',{175,'1x',80,80,110}, ...
            'RowName',[], ...
            'fontsize',fontsizeParamtable, ...
            'CellEditCallback',@(src,event) ...
            siteUi('optTableEdited',src,event));

        pHelp = uipanel(g,'Title','Algorithm notes', ...
            'FontWeight','bold','FontSize',fontsizeNotes);
        pHelp.Layout.Row = 5;
        hg = uigridlayout(pHelp,[1 1]);
        hg.Padding = [10 8 10 8];
        S.ui.lblSiteOptHelp = uitextarea(hg, ...
            'Editable','off', ...
            'Value',{' '}, ...
            'fontsize',fontsizeNotes);

        siteUi('loadOptimizer',5,true);
        S.runtime.siteLastOptMethod = 5;

    end

    function ok = siteValidateOptEdit(tbl,event)
        ok = true;
        if isempty(event) ...
                || isempty(event.Indices) ...
                || event.Indices(2) ~= 5
            return
        end
        row = event.Indices(1);
        data = tbl.Data;
        if ~iscell(tbl.UserData) ...
                || numel(tbl.UserData) < row
            data{row,5} = event.PreviousData;
            tbl.Data = data;
            ok = false;
            return
        end
        name = char(string(tbl.UserData{row}));
        value = str2double(string(data{row,5}));
        lo = siteParseLimit(data{row,3});
        hi = siteParseLimit(data{row,4});
        numericSetting = ~strcmpi(name,'finisher');
        if numericSetting
            ok = isfinite(value) ...
                && value >= lo ...
                && value <= hi;
        else
            ok = any(strcmpi(strtrim(string(data{row,5})), ...
                ["lbfgsb","pgd"]));
        end
        if ok
            return
        end
        [defaults,~] = siteOptimizerDefaults( ...
            double(S.ui.ddSiteOpt.Value),char(S.ui.edRoot.Value));
        if isfield(defaults,name)
            data{row,5} = siteOptionValueText(defaults.(name));
        else
            data{row,5} = event.PreviousData;
        end
        tbl.Data = data;
        try
            uialert(f,sprintf(['%s must be between %s and %s. ' ...
                'The default has been restored.'],name, ...
                string(data{row,3}),string(data{row,4})), ...
                'Invalid optimizer setting','Icon','warning');
        catch
            logmsg(['Invalid optimizer setting: ' name]);
        end
    end

    function buildPostTab(parent)
        callbacks = struct('refresh',@onPostprocessRefresh, ...
            'quickLook',@onQuickLookPreset, ...
            'trainingOnly',@onTrainingOnlyPreset, ...
            'evaluationOnly',@onEvalOnlyPreset, ...
            'allScenarios',@onAllScenarioPreset, ...
            'clearScenarios',@onClearScenarioPreset, ...
            'trainCountChanged',@onBprtChanged, ...
            'evalCountChanged',@onBprtChanged, ...
            'randomTrain',@(~,~)onRandomSelection('train'), ...
            'randomEval',@(~,~)onRandomSelection('eval'), ...
            'clearTrain',@(~,~)onClearSelection('train'), ...
            'clearEval',@(~,~)onClearSelection('eval'), ...
            'tableEdit',@onPostprocessTableEdit, ...
            'locateTrain',@onPostTrainBasinLocate, ...
            'locateEval',[], ... % SITE has no evaluation basins
            'attributionChanged',[]);
        fonts = struct('gui',fontsizeGUI,'value',fontsizeValueODE, ...
            'dropdown',fontsizeDropdown,'button',fontsizeButton, ...
            'notes',fontsizeNotes);
        S.ui = diagnostics_config_tab_ui(S.ui,parent,callbacks,fonts);
        % SITE has no evaluation basins. Make zero a legal value immediately
        % after the inherited SAGE diagnostics controls are constructed so
        % setUIFromConfig/session restore can never assign an out-of-range 0.
        try
            S.ui.spBprtEval.Limits = [0 200];
            S.ui.spBprtEval.Value = 0;
            S.ui.spBprtEval.Enable = 'off';
        catch
        end
        syncPostprocessScenarioControls();
    end

    function setTabValueFonts()
        % Apply tab-specific font sizes to editable numeric/date/text values.
        % This is intentionally explicit so important spinners/edit fields
        % are not missed by MATLAB's generic object search.

        setFontGroup(fontsizeValueODE, { ...
            'edInitStep','edMaxStep','edMinStep', ...
            'edRelTol','edAbsTol','spOrder','spMaxIterODE'});

        setFontGroup(fontsizeValueODE, { ...
            'spKt','spKe','spMinPerZone','spMaxZones', ...
            'spBasinSeed','txtBasinGenerator'});

        setFontGroup(fontsizeValueODE, { ...
            'edDt','spSpin', ...
            'edDts','edDte','edDes','edDee', ...
            'edDBlockStart','edDBlockEnd', ...
            'spDBlockSize','edDBlockFrac', ...
            'edRBlockStart','edRBlockEnd', ...
            'spRBlockSize','edRBlockFrac','edRBlockSeed', ...
            'edRndStart','edRndEnd', ...
            'edRndFrac','edRndSeed', ...
            'edDKFoldStart','edDKFoldEnd', ...
            'spDKFolds','spDKFold', ...
            'edRKFoldStart','edRKFoldEnd', ...
            'spRKFolds','spRKFold','edRKFoldSeed', ...
            'edRainBlockStart','edRainBlockEnd'});


        setFontGroup(fontsizeValueODE, { ...
            'spJKGENwin'});

        setFontGroup(fontsizeValueODE, { ...
            'spImax','edLR','edBeta1','edBeta2','edVarEps', ...
            'edLRmin','edLRhold','edWdec','spClipn'});

        setFontGroup(fontsizeValueODE, { ...
            'spBprtTrain','spBprtEval'});
    end

    function setFontGroup(fs,names)
        for kk = 1:numel(names)
            nm = names{kk};
            try
                if isfield(S.ui,nm) ...
                        && ~isempty(S.ui.(nm)) ...
                        && isvalid(S.ui.(nm)) ...
                        && isprop(S.ui.(nm),'fontsize')
                    S.ui.(nm).FontSize = fs;
                end
            catch
            end
        end
    end

    function buildSummaryTab(parent)
        fonts = struct('gui',fontsizeGUI, ...
            'button',fontsizeButton,'readiness',fontsizeReadiness,'site',true);
        S.ui = summary_dashboard_ui('build',S.ui,parent, ...
            @onSummaryRefresh,fonts);
    end
    function settleOutputMonitoringPlotLayouts()
        % SITE does not initialize removed SAGE diagnostic tabs.
        try
            data_quality_dashboard_ui('layout',S.ui);
        catch
        end
    end

    function layoutSelectedOutputMonitoringTab()
    % Reapply custom axes geometry after a window-size change.

        try
            selected = S.ui.tgRight.SelectedTab;
            if isequal(selected,S.ui.tabSummary)
                refreshRuntimeSummaryPlot();
            elseif isequal(selected,S.ui.tabQuality)
                data_quality_dashboard_ui('layout',S.ui);
                fitSiteQualityColumns();
            elseif isequal(selected,S.ui.tabBasinResults)
                site_basin_results_ui('resize',S.ui);
            end
        catch
        end
    end

    function fitSiteQualityColumns()
    % Use the visible quality-table grid, not the stale uitable width.

        tbl = S.ui.tblQuality;
        if ~isvalid(tbl), return, end
        base = getappdata(tbl,'QualityColumnWidths');
        if isempty(base) ...
                || numel(base) ~= numel(tbl.ColumnName)
            return
        end
        grid = tbl.Parent;
        padding = double(grid.Padding);
        available = floor(double(grid.Position(3)) ...
            - padding(1) - padding(3) - 4);
        if ~isfinite(available) ...
                || available <= 0
            return
        end
        widths = max(24,floor(base*available/sum(base)));
        if sum(widths) <= available
            widths(end) = widths(end) + available-sum(widths);
        end
        fitted = num2cell(widths);
        if ~isequal(tbl.ColumnWidth,fitted)
            tbl.ColumnWidth = fitted;
        end
    end

    function buildDataQualityTab(parent)
        S.ui = data_quality_dashboard_ui('build',S.ui,parent, ...
            @onQualityTableSelected, ...
            fontsizeGUI,fontsizeChecks, ...
            fontsizeDiagTickPlot+1,max(8,fontsizeDiagLabelPlot-5), ...
            max(8,fontsizeDiagTitlePlot-3),true);
    end

    function buildLogTab(parent)
        fonts = struct('button',fontsizeButton, ...
            'gui',fontsizeGUI,'dropdown',fontsizeDropdown, ...
            'text',fontsizePreview);
        S.ui = log_dashboard_ui('build',S.ui,parent, ...
            @onClearLog,@onCopyLog,@onCopyLog, ...
            @onLogFilterChanged,fonts);
    end

    function buildIterTab(parent)
        S.ui = iteration_dashboard_ui('build',S.ui,parent, ...
            @onFollowIterChanged,@onIterFilterChanged,@onCopyIter, ...
            fontsizeGUI,fontsizeButton,fontsizeIter);
    end

    function buildConusTab(parent)
        S.ui = geographic_dashboard_ui('build',S.ui,parent, ...
            'region',fontsizeGUI,@local_init_geoaxes,@currentMapLimits);
    end

    function buildZonesTab(parent)
        S.ui = geographic_dashboard_ui('build',S.ui,parent, ...
            'zones',fontsizeGUI,@local_init_geoaxes,@currentMapLimits);
        S.ui.lblZonesTip.Text = [ ...
            'Circles = training basins. Color denotes ' ...
            'hydroclimatic zone.'];
    end

    function [latitudeLimits,longitudeLimits] = currentMapLimits()
        [latitudeLimits,longitudeLimits] = getCurrentMapLimits();
    end

    function buildParamMapTab(parent)
        fonts = struct('gui',fontsizeGUI, ...
            'dropdown',fontsizeDropdown,'button',fontsizeButton);
        S.ui = parameter_map_dashboard_ui('build',S.ui,parent, ...
            @(~,~)refreshParamMap(),@local_init_geoaxes, ...
            @refreshMapFlag,@refreshParamMapPlaceholder, ...
            @hideParamMapAxes,fonts);
        controls = S.ui.ddMapBasins.Parent;
        delete(S.ui.ddMapBasins);
        controls.ColumnWidth = {80,185,95,200,85,'1x'};
        S.ui.lblSiteMapLoss = uilabel(controls, ...
            'Text','Loss function','FontSize',fontsizeGUI);
        S.ui.lblSiteMapLoss.Layout.Column = 3;
        S.ui.ddSiteMapLoss = uidropdown(controls, ...
            'Items',{'SAR','Generalized least squares', ...
            'NSE','KGE','Huber','FDC','JKGE'}, ...
            'ItemsData',{'SAR','RSS','NSE','KGE', ...
            'Huber','FDC','JKGE'}, ...
            'Value','RSS','FontSize',fontsizeDropdown, ...
            'ValueChangedFcn',@(~,~)refreshParamMap());
        S.ui.ddSiteMapLoss.Layout.Column = 4;
        S.ui.btnMapRefresh.Layout.Column = 5;
        S.ui.lblMapInfo.Layout.Column = 6;
        S.ui.lblMapTip.Text = [ ...
            'Color intensity shows the ' ...
            'best saved normalized parameter ' ...
            'value for the selected loss function. ' ...
            'Training basins with saved ' ...
            'results are colored circles; ' ...
            'basins without results are not shown.'];
    end

    function buildZoneTableTab(parent)
        S.ui = zone_table_dashboard_ui('build',S.ui,parent, ...
            @(~,~)refreshZoneSummaryTable(),fontsizeButton, ...
            fontsizeMapTitle,fontsizeGUI);
        refreshZoneSummaryTable();
    end

    function buildBasinResultsTab(parent)
        S.ui = site_basin_results_ui('build',S.ui,parent, ...
            @(~,~)siteUi('refreshbasinresultstable'), ...
            fontsizeGUI,fontsizeButton);
        siteUi('refreshbasinresultstable');
    end

    function buildStatisticsTab(parent)
        S.ui = site_model_statistics_ui('build',S.ui,parent, ...
            @(~,~)refreshSiteStatistics(true), ...
            fontsizeGUI,fontsizeButton);
    end

    function [store,bas,updated] = loadBasinResultsForCurrentUI()
        store = [];
        bas = [];
        updated = false(0,0);
        if isfield(S.runtime,'preparedBasins')
            bas = S.runtime.preparedBasins;
        end
        % This refresh is also called while the GUI is being constructed,
        % before the period edit fields receive their default dates.
        try
            [datesOK,~] = local_required_period_dates(S.ui);
        catch
            datesOK = false;
        end
        if ~datesOK
            return
        end
        cfg = getConfigFromUI();
        resultDir = char(cfg.dirres);
        [~,leaf] = fileparts(resultDir);
        if ~strcmpi(leaf,char(cfg.region))
            resultDir = fullfile(resultDir,char(cfg.region));
        end
        if local_is_gchm_ode(cfg.mdl)
            modelName = 'gchm_ode';
        else
            modelName = lower(char(sage_model_name(cfg.mdl.model)));
        end
        switch double(cfg.prd.dt)
            case 1, dtTag = 'daily';
            case 24, dtTag = 'hourly';
            case 96, dtTag = '15min';
            otherwise, dtTag = sprintf('dt_%g',cfg.prd.dt);
        end
        paths = site_result_store('paths',resultDir,modelName, ...
            dtTag,cfg.region,cfg.misc.meteo,cfg.prd);
        live = [];
        if isfield(S.runtime,'siteResultStore') ...
                && isstruct(S.runtime.siteResultStore) ...
                && isfield(S.runtime.siteResultStore,'fileBook') ...
                && strcmpi(char(S.runtime.siteResultStore.fileBook), ...
                paths.fileBook)
            live = S.runtime.siteResultStore;
        elseif isstruct(S.runtime.lastOut) ...
                && isfield(S.runtime.lastOut,'store') ...
                && isfield(S.runtime.lastOut.store,'fileBook') ...
                && strcmpi(char(S.runtime.lastOut.store.fileBook), ...
                paths.fileBook)
            live = S.runtime.lastOut.store;
        end
        if ~isempty(live)
            store = live;
            if isfield(S.runtime,'siteResultBas')
                bas = S.runtime.siteResultBas;
            elseif isstruct(S.runtime.lastOut) ...
                    && isfield(S.runtime.lastOut,'bas')
                bas = S.runtime.lastOut.bas;
            end
            if isfield(S.runtime,'siteResultUpdated') ...
                    && isequal(size(S.runtime.siteResultUpdated), ...
                    size(store.train))
                storedNames = string(store.metricNames);
                displayNames = ["NSE","KGE","SAR","RSS","Huber", ...
                    "S_fdc","S_p","S_logp","JKGE"];
                updated = false(size(store.train,1),numel(displayNames));
                for j = 1:numel(displayNames)
                    source = find(strcmpi(storedNames,displayNames(j)),1);
                    if ~isempty(source)
                        updated(:,j) = ...
                            S.runtime.siteResultUpdated(:,source);
                    end
                end
            end
            return
        end
        if ~isfile(paths.fileSummary)
            return
        end
        sheets = string(sheetnames(paths.fileSummary));
        sheet = sheets(find(strcmpi(sheets,modelName),1));
        if isempty(sheet)
            return
        end
        T = readtable(paths.fileSummary,'Sheet',char(sheet), ...
            'VariableNamingRule','preserve');
        if ~all(ismember({'BasinID','BasinNumber'}, ...
                T.Properties.VariableNames))
            return
        end
        basinNumber = double(T.BasinNumber);
        basinID = strip(string(T.BasinID));
        valid = isfinite(basinNumber) & strlength(basinID) > 0 ...
            & ~ismissing(basinID);
        T = T(valid,:);
        names = {'NSE','KGE','SAR','RSS','Huber', ...
            'S_fdc','S_p','S_logp','JKGE'};
        store = struct();
        store.ids = string(T.BasinID);
        store.metricNames = names;
        store.train = nan(height(T),numel(names));
        for j = 1:numel(names)
            column = [names{j} '_train'];
            if ismember(column,T.Properties.VariableNames)
                store.train(:,j) = double(T.(column));
            end
        end
    end

    function refreshSiteStatistics(force)
        if nargin < 1, force = false; end
        cfg = getConfigFromUI();
        resultDir = char(cfg.dirres);
        [~,leaf] = fileparts(resultDir);
        if ~strcmpi(leaf,char(cfg.region))
            resultDir = fullfile(resultDir,char(cfg.region));
        end
        if local_is_gchm_ode(cfg.mdl)
            modelName = 'gchm_ode';
        else
            modelName = lower(char(sage_model_name(cfg.mdl.model)));
        end
        switch double(cfg.prd.dt)
            case 1, dtTag = 'daily';
            case 24, dtTag = 'hourly';
            case 96, dtTag = '15min';
            otherwise
                dtTag = sprintf('dt_%g',cfg.prd.dt);
        end
        paths = site_result_store('paths',resultDir, ...
            modelName,dtTag,cfg.region,cfg.misc.meteo,cfg.prd);
        summaryFile = paths.fileSummary;
        live = [];
        if isfield(S.runtime,'siteResultStore') ...
                && isstruct(S.runtime.siteResultStore) ...
                && isfield(S.runtime.siteResultStore,'fileSummary') ...
                && strcmpi(char(S.runtime.siteResultStore.fileSummary), ...
                    summaryFile)
            live = S.runtime.siteResultStore;
        end
        selectedIds = strings(0,1);
        if isfield(S.runtime,'preparedBasins') ...
                && isstruct(S.runtime.preparedBasins) ...
                && isfield(S.runtime.preparedBasins,'id_gauge')
            selectedIds = string(S.runtime.preparedBasins.id_gauge(:));
        end
        site_model_statistics_ui('refresh',S.ui,summaryFile, ...
            live,double(cfg.prd.dt),force,selectedIds, ...
            string(S.ui.ddModel.ItemsData),char(cfg.root), ...
            modelName);
    end

    function mdl = getCachedModelForUI()

        cfg = getConfigFromUI();
    
        isUser = strcmpi(local_model_name_from_id( ...
            cfg.mdl.model),'user_model');
        
        infoStamp = 0;

        if isUser
            try
                udir = local_user_model_dir( ...
                    cfg.root);
                infoFile = fullfile(udir, ...
                    'user_model_info.mat');
                if isfile(infoFile)
                    D = dir(infoFile);
                    infoStamp = D.datenum;
                end
            catch
            end
        end

        key = sprintf('model_%d_user_%d_ode_%d_info_%.12g', ...
            cfg.mdl.model,isUser, ...
            local_is_gchm_ode(cfg.mdl),infoStamp);
    
        needReload = true;
        if ~isempty(S.cache.modelBase) ...
                && strlength(S.cache.modelBaseKey) > 0
            needReload = ~strcmp(char( ...
                S.cache.modelBaseKey),key);
        end
    
        if needReload
            prdDaily = cfg.prd;
            prdDaily.dt = 1;   % canonical daily master
            defaultModel=cfg.mdl;
            if isfield(defaultModel,'config'),defaultModel=rmfield(defaultModel,'config');end
    
            if isUser
                [mdl_base,~] = local_read_user_model_info( ...
                    defaultModel,prdDaily,cfg.root);
            else
                [mdl_base,~] = local_read_model_info( ...
                    defaultModel,prdDaily,false);
            end
    
            S.cache.modelBase = mdl_base;
            S.cache.modelBaseKey = key;
        end
    
        mdl = S.cache.modelBase;

        if cfg.prd.dt ~= 1
            if isUser
                [mdl,~] = local_read_user_model_info( ...
                    cfg.mdl,cfg.prd,cfg.root);
            else
                % Re-read at the selected resolution so read_model applies
                % subdaily scaling and resolution-specific overrides.
                [mdl,~] = local_read_model_info( ...
                    cfg.mdl,cfg.prd,false);
            end
        end
        if isfield(cfg.mdl,'config'),mdl.config=cfg.mdl.config;end
        mdl=apply_model_configuration(mdl,cfg.ode);
    end

    % =======================
    %  Core refresh functions
    % =======================
    function updateZoneSummary(zone)

        if isempty(zone) ...
                || ~isfield(zone,'num')
            return;
        end        
        u = unique(zone.num(~isnan(zone.num)));
        counts = arrayfun(@(x)sum(zone.num==x),u);        
        set(S.ui.lblZoneCount, ...
            'Text',sprintf('Zones: %d', ...
            numel(u)));        
        set(S.ui.lblBasinsPerZone, ...
            'Text',sprintf('Avg/zone: %.1f', ...
            mean(counts)));        
        [~,i] = max(counts);
        set(S.ui.lblDominantZone, ...
            'Text',sprintf('Dominant: %s', ...
            string(zone.codes(i))));        
        set(S.ui.lblZoneSpread, ...
            'Text',sprintf('Spread: %d', ...
            max(counts)-min(counts)));        
        cv = std(counts)/mean(counts);
        set(S.ui.lblZoneBalance, ...
            'Text',sprintf('CV: %.2f',cv));        
        if cv < 0.3
            note = 'Balanced';
        else
            note = 'Unbalanced';
        end        
        set(S.ui.lblZoneNote,'Text',note);
        
    end

    function refreshZoneSummaryTable()
        T = [];
        try
            if isfield(S.runtime,'lastOut') ...
                    && isstruct(S.runtime.lastOut) ...
                    && isfield(S.runtime.lastOut,'zoneTbl') ...
                    && ~isempty(S.runtime.lastOut.zoneTbl)
                T = S.runtime.lastOut.zoneTbl;
            end
            % Recover tables from runs stopped before table computation
            % was separated from optional postprocessing figures.
            if isempty(T) && ~S.runtime.isRunning ...
                    && isstruct(S.runtime.lastOut) ...
                    && isfield(S.runtime.lastOut,'bas') ...
                    && isfield(S.runtime.lastOut,'curr') ...
                    && isfield(S.runtime.lastOut,'prd') ...
                    && isstruct(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'mdl')
                T = zone_summary_SAGE(S.runtime.lastOut.bas, ...
                    S.runtime.lastOut.curr, ...
                    S.runtime.lastConfig.mdl, ...
                    S.runtime.lastOut.prd);
                S.runtime.lastOut.zoneTbl = T;
            end
        catch
            T = [];
        end

        modelTxt = '-';
        try
            if istable(T) && ismember('Model',T.Properties.VariableNames)
                modelTxt = char(string(T.Model(1)));
            else
                modelTxt = char(string(S.ui.ddModel.Value));
            end            
        catch
        end
        % Prefer the configuration that produced the displayed result. The
        % setup controls may already have returned to their defaults after a
        % run, which previously mislabeled a Germany table as CAMELS-US.
        regionCode = '';
        try
            if isfield(S.runtime,'lastConfig') ...
                    && isstruct(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'region')
                regionCode = char(string(S.runtime.lastConfig.region));
            end
        catch
        end
        if isempty(regionCode)
            regionCode = char(string(S.ui.ddRegion.Value));
        end
        try
            regionTxt = char(region_helpers('label',regionCode));
        catch
            regionTxt = regionCode;
        end
        try
            if isfield(S.runtime,'lastConfig') ...
                    && isstruct(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'misc') ...
                    && isfield(S.runtime.lastConfig.misc,'loss') ...
                    && isfield(S.runtime.lastConfig.misc.loss,'fnc')
                lossFnc = double(S.runtime.lastConfig.misc.loss.fnc);
            else
                lossFnc = parseLeadingInt_local(S.ui.ddLoss.Value);
            end
        catch
            lossFnc = NaN;
        end
        zone_table_dashboard_ui('refresh',S.ui,T,modelTxt, ...
            regionTxt,lossFnc);
    end

    function refreshAll()
        refreshDerivedPaths();
        refreshResolutionControls();
        time_resolution_icon_ui(S.ui,double(S.ui.edDt.Value), ...
            S.cfg.SAGEhydro);
        refreshPeriodMethodControls();
        updateReferenceBlock_standalone(S.ui,fontsizeNotes);
        refreshSplitPreview();
        refreshModelDiagram();
        refreshParamTable();
        syncRegionalAttributeDefaults();
        refreshPreview();
        refreshReadiness();
        refreshSummary();
        refreshDataStatus();
        refreshLogView();
        refreshIterView();
        refreshMapDropdown();
        site_reorderRightTabs(S.ui.tgRight,{tabSummary,tabPreview,tabQuality, ...
            tabLog,tabIter,tabRegionMap,tabZones,tabParamMap, ...
            tabBasinResults,tabStatistics});
        updateLockState();
        siteUi('configureVisibleTabs');
    end

    function refreshSplitPreview()

        if S.runtime.isRunning
            return
        end

        try
            cfg = getConfigFromUI();
            mdl_tmp = getCachedModelForUI();

            % Make sure split preview uses the mode selected in the GUI
            if isfield(cfg,'mdl') ...
                    && isfield(cfg.mdl,'mode') ...
                    && ~isempty(cfg.mdl.mode)
                mdl_tmp.mode = cfg.mdl.mode;
            end

            % Also keep the split method synchronized
            if isfield(cfg,'prd') ...
                    && isfield(cfg.prd,'method') ...
                    && ~isempty(cfg.prd.method)
                mdl_tmp.sp_method = cfg.prd.method;
            end

            [split_tmp,mdl_tmp] = build_split( ...
                mdl_tmp,cfg.prd,cfg.bas);           %#ok

            R = struct();
            if isfield(mdl_tmp,'tout')
                R.tout = mdl_tmp.tout;
            else
                R.tout = [];
            end
            if isfield(mdl_tmp,'id_train')
                R.id_train = mdl_tmp.id_train;
            else
                R.id_train = [];
            end
            if isfield(mdl_tmp,'id_eval')
                R.id_eval = mdl_tmp.id_eval;
            else
                R.id_eval = [];
            end
            if isfield(mdl_tmp,'idx')
                R.idx = mdl_tmp.idx;
            else
                R.idx = [];
            end
            if isfield(mdl_tmp,'mode')
                R.mode = mdl_tmp.mode;
            else
                R.mode = [];
            end
            if isfield(mdl_tmp,'sp_method')
                R.sp_method = mdl_tmp.sp_method;
            else
                R.sp_method = '';
            end
            S.runtime.previewRuntime = R;

        catch
            S.runtime.previewRuntime = struct( ...
                'tout',[], ...
                'id_train',[], ...
                'id_eval',[], ...
                'idx',[], ...
                'mode',[], ...
                'sp_method','');
        end
    end

    function refreshDerivedPaths()
        cfg = getConfigFromUI();
        try
            paths_region_tabs_ui('regionhelp',S.ui,cfg.region);
        catch
        end
        S.ui.edSAGE.Value = cfg.SAGEhydro;
        S.ui.edDataLocation.Value = cfg.dirDroot;
        S.ui.edRes.Value = cfg.dirres;
        if isfield(S.ui,'edDataRoot') ...
                && isvalid(S.ui.edDataRoot)
            S.ui.edDataRoot.Value = cfg.dirDroot;
        end
        if isfield(S.ui,'edData') ...
                && isvalid(S.ui.edData)
            S.ui.edData.Value = cfg.dirD;
        end

        try
            pngOverview = fullfile( ...
                localDocsDir(char(S.ui.edRoot.Value)), ...
                'SAGE_schematic.png');
            if isfile(pngOverview)
                S.ui.imgOverview.ImageSource = ...
                    pngOverview;
            else
                S.ui.imgOverview.ImageSource = '';
            end
        catch
        end
    end





    function applyMeteoControlsFromConfig(X)
    %APPLYMETEOCONTROLSFROMCONFIG Render config-driven forcing controls.

        if ~isfield(X,'meteo') || ~isstruct(X.meteo)
            error('SAGE_ui:MissingMeteoConfig', ...
                ['The selected regional resolution does not define ' ...
                 'X.meteo controls.']);
        end

        applyConfiguredDropdown( ...
            S.ui.ddMeteo,X.meteo.product,'product', ...
            X.meteo.product.default);
        applyConfiguredDropdown( ...
            S.ui.ddPrecip,X.meteo.precipitation,'precipitation', ...
            X.meteo.product.default);
        applyConfiguredDropdown( ...
            S.ui.ddTemp,X.meteo.temperature,'temperature', ...
            X.meteo.product.default);
        applyConfiguredDropdown( ...
            S.ui.ddPET,X.meteo.pet,'pet', ...
            X.meteo.product.default);

        applyLinkedMeteoControls(X);
        localRefreshMeteoChoicePresentation(S.ui);
    end


    function applyLinkedMeteoControls(X)
    %APPLYLINKEDMETEOCONTROLS Synchronize dependent component controls.

        if ~isfield(X,'meteo') ...
                || ~isfield(X.meteo,'linked') ...
                || isempty(X.meteo.linked)
            return
        end

        L = X.meteo.linked;
        if ~isfield(L,'source') ...
                || ~isfield(L,'labels') ...
                || ~isfield(L,'targets')
            return
        end

        sourceName = lower(char(string(L.source)));
        switch sourceName
            case 'product'
                sourceValue = S.ui.ddMeteo.Value;
            case 'precipitation'
                sourceValue = S.ui.ddPrecip.Value;
            case 'temperature'
                sourceValue = S.ui.ddTemp.Value;
            case 'pet'
                sourceValue = S.ui.ddPET.Value;
            otherwise
                return
        end

        idx = parseLeadingInt_local(sourceValue);
        labels = cellstr(string(L.labels));
        if isempty(labels)
            return
        end
        idx = max(1,min(numel(labels),idx));
        label = labels{idx};

        targets = cellstr(string(L.targets));
        for ii = 1:numel(targets)
            switch lower(targets{ii})
                case 'precipitation'
                    dd = S.ui.ddPrecip;
                case 'temperature'
                    dd = S.ui.ddTemp;
                case 'pet'
                    dd = S.ui.ddPET;
                case 'product'
                    dd = S.ui.ddMeteo;
                otherwise
                    continue
            end
            displayLabel = local_meteo_dropdown_labels( ...
                {label},targets{ii},S.ui.ddMeteo.Value);
            dd.ItemsData = {};
            dd.Items = displayLabel;
            dd.ItemsData = {label};
            dd.Value = label;
            dd.Enable = 'off';
        end
    end


    function C = getCurrentRegionConfig()
    %GETCURRENTREGIONCONFIG Load and cache the selected regional config.

        region = region_helpers('code',S.cfg);
        try
            region = region_helpers('code',S.ui.ddRegion.Value);
        catch
        end

        key = string(S.cfg.SAGEhydro) + "|" + string(region);

        if isempty(S.cache.regionConfig) ...
                || string(S.cache.regionConfigKey) ~= key
            C = region_helpers( ...
                'config',S.cfg.SAGEhydro,region);
            S.cache.regionConfig = C;
            S.cache.regionConfigKey = key;
        else
            C = S.cache.regionConfig;
        end
    end

    function X = getCurrentResolutionConfig()
    %GETCURRENTRESOLUTIONCONFIG Return the selected resolution block.

        C = getCurrentRegionConfig();
        X = region_helpers( ...
            'resolution',S.cfg.SAGEhydro, ...
            C.code,S.ui.ddRes.Value);
    end

    function refreshResolutionControls()

        C = getCurrentRegionConfig();
        oldResolution = "";
        try
            oldResolution = string(S.ui.ddRes.Value);
        catch
        end

        items = cellstr(string(C.resolutions));
        S.ui.ddRes.Items = items;

        keep = find(strcmpi(char(oldResolution),items),1);
        if ~isempty(keep)
            S.ui.ddRes.Value = items{keep};
        else
            S.ui.ddRes.Value = char(string(C.default_resolution));
        end
        S.ui.ddRes.Enable = tern(numel(items) > 1,'on','off');

        X = getCurrentResolutionConfig();
        S.ui.edDt.Value = X.dt;

        % Meteo/PET controls are declared by region_config_XX.m.
        applyMeteoControlsFromConfig(X);

        updateReferenceBlock_standalone(S.ui,fontsizeNotes);
        updateDefaultBasinSplitFile();
        refreshDataTabVisibility();
    end

    function refreshDataTabVisibility()
        % Keep all resolution rows visible in a fixed order:
        %   row 1 = 15-minute
        %   row 2 = hourly
        %   row 3 = daily
        %   row 4 = gauge metadata
        %
        % For unsupported resolutions, retain the row and status text,
        % but hide the install button completely.

        try
            cfg = getConfigFromUI();
            dailyOK = data_helpers('supports', ...
                cfg.region,'daily');
            hourlyOK = data_helpers('supports', ...
                cfg.region,'hourly');
            min15OK = data_helpers('supports', ...
                cfg.region,'15min');

            regionNow = region_helpers('code',cfg.region);
            if any(strcmp(regionNow,{'CAMELS_IL','CAMELS_PE'}))
                dailyOK = true;
                hourlyOK = false;
                min15OK = false;
            elseif any(strcmp(regionNow, ...
                    {'CAMELS_CZ','CAMELS_GB','CAMELS_IS'}))
                dailyOK = true;
                hourlyOK = true;
                min15OK = false;
            end
        catch
            dailyOK = true;
            hourlyOK = true;
            min15OK = false;
        end

        % Resolution names and status fields always remain visible.
        S.ui.lbl15minStatusName.Visible = 'on';
        S.ui.txt15minStatus.Visible = 'on';
        S.ui.lblHourlyStatusName.Visible = 'on';
        S.ui.txtHourlyStatus.Visible = 'on';
        S.ui.lblDailyStatusName.Visible = 'on';
        S.ui.txtDailyStatus.Visible = 'on';

        % Buttons exist only for supported data packages.
        S.ui.btn15min.Visible = tern(min15OK,'on','off');
        S.ui.btnHourly.Visible = tern(hourlyOK,'on','off');
        S.ui.btnDaily.Visible = tern(dailyOK,'on','off');
    end

    function refreshDataStatus()
        cfg = getConfigFromUI();
        fonts = struct('gui',fontsizeGUI,'button',fontsizeButton);
        helpers = struct( ...
            'tern',@tern, ...
            'countFiles',@local_count_files, ...
            'statusText',@localDataStatusText, ...
            'resolveCZ',@localResolveCZTimeseries, ...
            'isGRDC',@localIsGRDCRegion, ...
            'grdcInfo',@localGRDCRegionInfo);
        [S.ui,S.runtime] = region_data_status_ui( ...
            S.ui,S.runtime,cfg,fonts,helpers);
        refreshDataTabVisibility();
        updateLockState();
    end
    function refreshLossHelpText()

        lossID = parseLeadingInt_local( ...
            S.ui.ddLoss.Value);
        fdcFormulation = 1;
        try
            fdcFormulation = double(S.ui.ddFDCFormulation.Value);
        catch
        end
        txt = localLossHelpLatex(lossID,fdcFormulation);

        try
            S.ui.lblLossEq.Text = txt;
            S.ui.lblLossEq.Interpreter = 'latex';
            localResizeLossNotes(txt);
        catch
        end
    end

    function refreshOptHelpText()

        optMethod = parseLeadingInt_local( ...
            S.ui.ddOpt.Value);
        lrSchedule = char(S.ui.ddLRSchedule.Value);
        txt = localOptHelpLatex(optMethod,lrSchedule);
        try
            S.ui.lblOptEq.Text = txt;
            S.ui.lblOptEq.Interpreter = 'latex';
            localResizeOptNotes(txt);
        catch
        end

    end

    function refreshModelDiagram()
    
        modelName = string(S.ui.ddModel.Value);
    
        displayName=modelName;
        if strcmpi(modelName,'user_model'),displayName=sage_user_model_display_name_ui(local_user_model_dir(S.cfg.root));end
        S.ui.txtParModel.Text = ...
            prettyModelName(displayName);
    
        svgPath = site_modelSvgPath(modelName,char(S.ui.edRoot.Value));
        pngPath = site_modelPngPath(modelName,char(S.ui.edRoot.Value));
        
        if isfile(svgPath)
            S.ui.imgDiag.ImageSource = svgPath;
        elseif isfile(pngPath)
            S.ui.imgDiag.ImageSource = pngPath;
        else
            S.ui.imgDiag.ImageSource = '';
            logmsg(['No model diagram found for ' ...
                char(modelName) ': ' svgPath]);
        end
    
        % The image is managed by a 1x1 grid that already fills the diagram
        % panel. ScaleMethod='fit' preserves the SVG aspect ratio without a
        % first-open pixel resize or a second rendering pass.
        try
            S.ui.imgDiag.ScaleMethod = 'fit';
        catch
        end

    end

    function refreshPeriodMethodControls()

        method = char(S.ui.ddSplitMethod.Value);

        allPanels = {S.ui.pPeriodManual, ...
            S.ui.pPeriodDetBlock, ...
            S.ui.pPeriodRndBlock, ...
            S.ui.pPeriodRandom, ...
            S.ui.pPeriodDKFold, ...
            S.ui.pPeriodRKFold, ...
            S.ui.pPeriodRainBlock};

        for ii = 1:numel(allPanels)
            try
                allPanels{ii}.Visible = 'off';
            catch
            end
        end
        switch lower(method)
            case 'manual'
                S.ui.pPeriodManual.Visible = 'on';
                nRowsActive = 4;
                %refH = 350;
            case 'deterministic_block'
                S.ui.pPeriodDetBlock.Visible = 'on';
                nRowsActive = 4;
                %refH = 10;
            case 'random_block'
                S.ui.pPeriodRndBlock.Visible = 'on';
                nRowsActive = 5;
                %refH = 245;
            case 'random'
                S.ui.pPeriodRandom.Visible = 'on';
                nRowsActive = 4;
                %refH = 230;
            case 'deterministic_kfold'
                S.ui.pPeriodDKFold.Visible = 'on';
                nRowsActive = 4;
                %refH = 230;
            case 'random_kfold'
                S.ui.pPeriodRKFold.Visible = 'on';
                nRowsActive = 5;
                %refH = 230;
            case 'rainfall_block'
                S.ui.pPeriodRainBlock.Visible = 'on';
                nRowsActive = 2;
                %refH = 250;
            otherwise
                S.ui.pPeriodManual.Visible = 'on';
                nRowsActive = 4;
                %refH = 200;
        end
        refH = 10;
        try
            S.ui.gPeriodMethod.RowHeight = ...
                {localPeriodPanelHeight( ...
                nRowsActive,rowHValuePeriod)};
            S.ui.gPeriodMain.RowHeight = ...
                {102,'fit',120,refH,'1x'};
            S.ui.pPeriodRef.Visible = 'on';
        catch
        end
        
        if ~S.runtime.initializingUI
            drawnow limitrate nocallbacks
        end
        
        refreshSplitTimeline();
        refreshSplitTimeline();
    end

    function clampKfoldControls()
        % Keep held-out fold controls consistent with the number of folds.
        % This is intentionally lightweight because it is called from
        % ordinary UI refresh callbacks.
        try
            n = max(2,round(double(S.ui.spDKFolds.Value)));
            held = max(1,min(n,round(double(S.ui.spDKFold.Value))));
            S.ui.spDKFolds.Value = n;
            S.ui.spDKFold.Value = held;
            S.ui.spDKFold.Limits = [1 n];
        catch
        end
        try
            n = max(2,round(double(S.ui.spRKFolds.Value)));
            held = max(1,min(n,round(double(S.ui.spRKFold.Value))));
            S.ui.spRKFolds.Value = n;
            S.ui.spRKFold.Value = held;
            S.ui.spRKFold.Limits = [1 n];
        catch
        end
    end

    function refreshSplitTimeline()

        clampKfoldControls();

        if ~isfield(S.ui,'axSplitTimeline') ...
                || isempty(S.ui.axSplitTimeline) ...
                || ~isvalid(S.ui.axSplitTimeline)
            return
        end

        try
            ax = S.ui.axSplitTimeline;

            T = struct();
            T.method = char(S.ui.ddSplitMethod.Value);
            T.spinup = round(double(S.ui.spSpin.Value));

            % Manual dates
            T.dts = parseDMYOrEmpty_local(S.ui.edDts.Value);
            T.dte = parseDMYOrEmpty_local(S.ui.edDte.Value);
            T.des = parseDMYOrEmpty_local(S.ui.edDes.Value);
            T.dee = parseDMYOrEmpty_local(S.ui.edDee.Value);

            % Deterministic block
            T.dblock_ds = parseDMYOrEmpty_local(S.ui.edDBlockStart.Value);
            T.dblock_de = parseDMYOrEmpty_local(S.ui.edDBlockEnd.Value);
            T.dblock_size = round(double(S.ui.spDBlockSize.Value));
            T.dblock_frac = double(S.ui.edDBlockFrac.Value);

            % Random block
            T.rblock_ds = parseDMYOrEmpty_local(S.ui.edRBlockStart.Value);
            T.rblock_de = parseDMYOrEmpty_local(S.ui.edRBlockEnd.Value);
            T.rblock_size = round(double(S.ui.spRBlockSize.Value));
            T.rblock_frac = double(S.ui.edRBlockFrac.Value);
            T.rblock_seed = round(double(S.ui.edRBlockSeed.Value));

            % Random day split
            T.random_ds = parseDMYOrEmpty_local(S.ui.edRndStart.Value);
            T.random_de = parseDMYOrEmpty_local(S.ui.edRndEnd.Value);
            T.random_frac = double(S.ui.edRndFrac.Value);
            T.random_seed = round(double(S.ui.edRndSeed.Value));

            % Deterministic k-fold
            T.dkfold_ds = parseDMYOrEmpty_local(S.ui.edDKFoldStart.Value);
            T.dkfold_de = parseDMYOrEmpty_local(S.ui.edDKFoldEnd.Value);
            T.dkfold_n = round(double(S.ui.spDKFolds.Value));
            T.dkfold_held = round(double(S.ui.spDKFold.Value));

            % Random k-fold
            T.rkfold_ds = parseDMYOrEmpty_local(S.ui.edRKFoldStart.Value);
            T.rkfold_de = parseDMYOrEmpty_local(S.ui.edRKFoldEnd.Value);
            T.rkfold_n = round(double(S.ui.spRKFolds.Value));
            T.rkfold_held = round(double(S.ui.spRKFold.Value));
            T.rkfold_seed = round(double(S.ui.edRKFoldSeed.Value));

            % Rainfall block
            T.rain_ds = parseDMYOrEmpty_local(S.ui.edRainBlockStart.Value);
            T.rain_de = parseDMYOrEmpty_local(S.ui.edRainBlockEnd.Value);

            timeline_helpers(ax,T);
            % Keep timeline background consistent after every redraw
            try
                ax.Color = f.Color;
                ax.XColor = site_theme_foreground(f.Color);
                labels = findall(ax,'Type','text');
                for ii = 1:numel(labels)
                    if labels(ii).Position(2) >= 0.85
                        labels(ii).Color = ax.XColor;
                    else
                        labels(ii).Color = [0.1 0.1 0.1];
                    end
                end
                ax.Box = 'off';
            catch
            end
        catch ME
            try
                cla(S.ui.axSplitTimeline,'reset');
                try
                    S.ui.axSplitTimeline.Color = f.Color;
                    S.ui.axSplitTimeline.XAxis.Visible = 'off';
                    S.ui.axSplitTimeline.YAxis.Visible = 'off';
                    S.ui.axSplitTimeline.Box = 'off';
                    S.ui.axSplitTimeline.XTick = [];
                    S.ui.axSplitTimeline.YTick = [];
                catch
                end
                text(S.ui.axSplitTimeline,0.02,0.5, ...
                    ['Timeline error: ' ME.message], ...
                    'Units','normalized', ...
                    'horizontalalignment','left', ...
                    'verticalalignment','middle', ...
                    'fontsize',fontsizeGUI, ...
                    'color',site_theme_foreground(f.Color), ...
                    'interpreter','none');
                    % 'fontsize',11);
                axis(S.ui.axSplitTimeline,'off');
            catch
            end
        end
    end

    function refreshParamTable()
        try
            cfg = getConfigFromUI();
            mdl_tmp = getCachedModelForUI();
            model_configuration_ui('refresh',S.ui,mdl_tmp,cfg,S.runtime.isRunning,f,S.store.modelOptions,[]);

            names = string(mdl_tmp.par_names(:));
            if isfield(mdl_tmp,'par_desc')
                desc = string(mdl_tmp.par_desc(:));
            else
                desc = repmat("",size(names));
            end
            if isfield(mdl_tmp,'par_units')
                units = string(mdl_tmp.par_units(:));
                % Shared model metadata can contain UTF-8 decoded as Latin-1.
                % Use character codes so this repair is source-encoding safe.
                degree = string(char(176));
                units = replace(units,string(char([194 176])),degree);
            else
                units = repmat("",size(names));
            end

            mins = double(mdl_tmp.th_min(:));
            maxs = double(mdl_tmp.th_max(:));

            % Store the original model defaults before applying any
            % user overrides. These defaults determine whether a
            % parameter is allowed to have negative bounds.
            defaultMins = mins;
            defaultMaxs = maxs;
            allowNegative = (defaultMins < 0) | (defaultMaxs < 0);
            allowNegative = allowNegative(:);

            % Explicit safety net for model files whose metadata may
            % not yet expose the signed range correctly.
            % Explicit safety net for signed parameters.
            try
                modelName = lower(string(mdl_tmp.model));
                pnames = lower(strtrim(string(names(:))));
                pclean = regexprep(pnames,'[^a-z0-9]','');
            
                allowNegative = allowNegative ...
                    | strcmp(pclean,"ttr") ...
                    | (strcmp(modelName,"hmodel") ...
                       & strcmp(pclean,"af")) ...
                    | (contains(modelName,"xinanjiang") ...
                       & strcmp(pclean,"a")) ...
                    | ((strcmp(modelName,"gr4j") ...
                       | contains(modelName,"user_model")) ...
                       & strcmp(pclean,"x2"));
            catch
            end

            key = overrideKey(cfg.mdl,cfg.prd.dt);
            if isfield(S.store.parOverride,key)
                O = S.store.parOverride.(key);
                if numel(O.min)==numel(mins) ...
                        && numel(O.max)==numel(maxs)
                    mins = double(O.min(:));
                    maxs = double(O.max(:));
                end
            end

            S.ui.tblPars.Data = [cellstr(names), ...
                cellstr(desc),cellstr(units), ...
                num2cell(mins),num2cell(maxs)];

            try
                S.ui.tblPars.UserData = struct( ...
                    'names',names(:), ...
                    'defaultMin',defaultMins(:), ...
                    'defaultMax',defaultMaxs(:), ...
                    'allowNegative',allowNegative(:));
            catch
            end

            S.ui.lblParsWarning.Text = '';

        catch ME
            S.ui.tblPars.Data = cell(0,5);
            S.ui.lblParsWarning.Text = ...
                ['Parameter table refresh ' ...
                'error: ' ME.message];
        end
        resizeParameterTable();
    end

    function resizeParameterTable()
        try
            resize_parameter_table_ui(S.ui.tblPars, ...
                S.ui.gParsMain,fontsizeParamtable);
            drawnow limitrate nocallbacks
            layout_parameter_table_host_ui(S.ui.tblPars, ...
                S.ui.pnlParsTableHost);
        catch
        end
    end

    function syncRegionalAttributeDefaults()
        % SITE does not expose an attribute-selection table. Regional default
        % attributes are retained internally because read_attr and zone-based
        % basin sampling use the same SAGE data infrastructure.
        S.runtime.attrReady = false;
        S.runtime.attrError = '';
        try
            cfgNow = getConfigFromUI();
            ids = site_default_attribute_ids(cfgNow.region);
            if isempty(ids)
                error('SITE_ui:NoDefaultAttributes', ...
                    'No default regional attributes are available.');
            end
            S.cfg.bas.id_attr = ids;
            S.cfg.bas.pr_attr = 0;
            S.cfg.r = numel(ids);
            S.runtime.attrReady = true;
        catch ME
            S.runtime.attrReady = false;
            S.runtime.attrError = ME.message;
            try
                logmsg(['Could not load regional default attributes: ' ...
                    ME.message]);
            catch
            end
        end
        try refreshReadiness(); catch, end
    end

    function refreshPreview()
        preview_dashboard_ui('refresh',S.ui,@getConfigFromUI, ...
            S.runtime.prepared,S.runtime.preparedBasins, ...
            S.runtime.previewRuntime,@formatSITEPreview);
    end


    function onValidate(~,~)
        refreshDataStatus();
        refreshReadiness();
    end

    function refreshReadiness()
        [rows,okAll] = validateCurrentConfig();
        summaryChecks = checks_dashboard_ui( ...
            'render',S.ui,rows,okAll);

        S.runtime.checksOK = logical(okAll);
        try
            if isfield(S.ui,'btnRun') ...
                    && isgraphics(S.ui.btnRun)
                % Run activation is based on the two required workflow
                % steps: a compiled/available model and prepared basins.
                % The complete Checks table is still validated in onRun,
                % where unresolved items produce a clear alert.
                coreReady = S.runtime.prepared ...
                    && ~isempty(S.runtime.preparedBasins) ...
                    && ~S.runtime.isRunning;
                S.ui.btnRun.Enable = tern(coreReady,'on','off');

                if ~S.runtime.prepared ...
                        || isempty(S.runtime.preparedBasins)
                    S.ui.btnRun.Tooltip = ...
                        'Load basins before running SITE.';
                elseif ~okAll
                    S.ui.btnRun.Tooltip = ...
                        ['Run is available, but unresolved Checks-tab ' ...
                        'items must be corrected before execution starts.'];
                else
                    S.ui.btnRun.Tooltip = 'Run SITE.';
                end
            end
        catch
        end
        try
            S.ui.txtSummaryChecks.Value = summaryChecks;
        catch
        end
        updateLockState();
    end

    function refreshSummary()
        site_center_buttons_ui(f);
        cfg = getConfigFromUI();
        snapshot = struct();
        modelInfo = getCachedModelForUI();
        snapshot.modelParameters = numel(modelInfo.th_min);
        % SITE calibrates basin parameters directly without a regional FFN.
        snapshot.networkParameters = 0;
        snapshot.model = prettyModelName( ...
            local_model_name_from_mdl(cfg.mdl));
        try
            regionConfig = getCurrentRegionConfig();
            snapshot.region = localRegionPanelName(cfg.region);
            snapshot.dataset = '-';
            if isfield(regionConfig,'dataset')
                datasetName = strtrim(char(string(regionConfig.dataset)));
                if ~isempty(datasetName)
                    snapshot.dataset = datasetName;
                end
            end
        catch
            snapshot.region = region_helpers('name',cfg.region);
            snapshot.dataset = '-';
        end
        snapshot.resolution = localResolutionName(cfg.prd.dt);
        snapshot.trainingBasins = cfg.bas.K_t;
        snapshot.evaluationBasins = cfg.bas.K_e;
        requestedBasins = snapshot.trainingBasins;
        % Keep the requested count visible, while run progress uses the
        % screened population that actually participates in SITE.
        try
            if isfield(S.runtime,'quality') ...
                    && isstruct(S.runtime.quality) ...
                    && isfield(S.runtime.quality,'active_bas') ...
                    && ~isempty(S.runtime.quality.active_bas)
                if isfield(S.runtime.quality,'gauge')
                    requestedBasins = numel(S.runtime.quality.gauge);
                end
                snapshot.trainingBasins = ...
                    S.runtime.quality.active_bas.K_t;
                snapshot.evaluationBasins = ...
                    S.runtime.quality.active_bas.K_e;
            end
        catch
        end
        snapshot.status = S.runtime.lastStatus;
        snapshot.compileOK = S.runtime.compileOK;
        snapshot.prepared = S.runtime.prepared;
        snapshot.maxIterations = cfg.misc.alg.i_max;
        snapshot.startTime = S.runtime.startTime;
        snapshot.endTime = S.runtime.endTime;
        snapshot.isRunning = S.runtime.isRunning;
        snapshot.out = S.runtime.lastOut;
        snapshot.informationTimeTotal = NaN;
        try
            valuesInfo = double(S.runtime.informationTime(:));
            valuesInfo = valuesInfo(isfinite(valuesInfo) & valuesInfo >= 0);
            if ~isempty(valuesInfo) || S.runtime.isRunning
                snapshot.informationTimeTotal = sum(valuesInfo);
            end
        catch
        end
        snapshot.traceIteration = 0;
        summary_dashboard_ui('values',S.ui,snapshot);
        if requestedBasins ~= snapshot.trainingBasins
            S.ui.txtSumBasins.Text = sprintf( ...
                '%d (%d after data quality)', ...
                requestedBasins,snapshot.trainingBasins);
        else
            S.ui.txtSumBasins.Text = sprintf('%d',requestedBasins);
        end
        displayCfg = cfg;
        if isfield(S.runtime,'lastConfig') ...
                && isstruct(S.runtime.lastConfig) ...
                && ~isempty(fieldnames(S.runtime.lastConfig)) ...
                && (S.runtime.isRunning ...
                    || isstruct(S.runtime.lastOut))
            displayCfg = S.runtime.lastConfig;
        end
        try
            S.ui.txtSiteSummaryLoss.Text = ...
                lossName(double(displayCfg.misc.loss.fnc));
        catch
            S.ui.txtSiteSummaryLoss.Text = '-';
        end
        try
            S.ui.txtSiteSummaryMethod.Text = ...
                optName(double(displayCfg.site.alg.method));
        catch
            S.ui.txtSiteSummaryMethod.Text = '-';
        end
        rangeID = NaN;
        try
            if S.runtime.isRunning ...
                    && isfield(S.runtime,'siteResultStore') ...
                    && isstruct(S.runtime.siteResultStore)
                rangeID = double( ...
                    S.runtime.siteResultStore.currentRangeID);
            else
                % Show the ID implied by the bounds currently displayed in
                % the model table. Registration itself still occurs only
                % when a run starts.
                rangeID = prospectiveRangeID(cfg);
            end
        catch
        end
        if isscalar(rangeID) && isfinite(rangeID)
            S.ui.txtSiteSummaryRange.Text = sprintf('ID %d',rangeID);
        else
            S.ui.txtSiteSummaryRange.Text = '-';
        end
        completed = 0;
        if isfield(S.runtime,'siteBasinsFinished')
            completed = S.runtime.siteBasinsFinished;
        end
        S.ui.txtSumIter.Text = sprintf('%d / %d', ...
            completed,snapshot.trainingBasins);
        if isfield(S.runtime,'siteTiming')
            timing = S.runtime.siteTiming;
            fields = {'data','init','train','gui'};
            controls = {'txtSumData','txtSumInit', ...
                'txtSumTrain','txtSumCpuGUI'};
            for jj = 1:numel(fields)
                value = NaN;
                if isfield(timing,fields{jj})
                    value = timing.(fields{jj});
                end
                if isfinite(value)
                    S.ui.(controls{jj}).Text = sprintf('%.1f s',value);
                end
            end
        end

        refreshRuntimeSummaryPlot(requestedBasins);
        perfUpdateOnce(false);
        refreshSiteTimingNumbers();

        try
            S.ui.txtLastError.Value = ...
                {S.runtime.lastError};
        catch
        end
        S.ui.txtCompileStatus.Value = ...
            S.runtime.compileMessage;
        setRunStatus(S.runtime.lastStatus)
    end

    function rangeID = prospectiveRangeID(cfg)
        rangeID = NaN;
        mdlRange = getCachedModelForUI();
        names = string(mdlRange.par_names(:));
        lowerBounds = double(mdlRange.th_min(:));
        upperBounds = double(mdlRange.th_max(:));
        key = overrideKey(cfg.mdl,cfg.prd.dt);
        if isfield(S.store.parOverride,key)
            override = S.store.parOverride.(key);
            if numel(override.min) == numel(lowerBounds) ...
                    && numel(override.max) == numel(upperBounds)
                lowerBounds = double(override.min(:));
                upperBounds = double(override.max(:));
            end
        end
        if numel(names) ~= numel(lowerBounds) ...
                || numel(names) ~= numel(upperBounds)
            return
        end
        resultDir = char(cfg.dirres);
        [~,leaf] = fileparts(resultDir);
        if ~strcmpi(leaf,char(cfg.region))
            resultDir = fullfile(resultDir,char(cfg.region));
        end
        if local_is_gchm_ode(cfg.mdl)
            modelName = 'gchm_ode';
        else
            modelName = lower(char(sage_model_name(cfg.mdl.model)));
        end
        switch double(cfg.prd.dt)
            case 1, dtTag = 'daily';
            case 24, dtTag = 'hourly';
            case 96, dtTag = '15min';
            otherwise, dtTag = sprintf('dt_%g',cfg.prd.dt);
        end
        rangeFile = fullfile(resultDir,sprintf( ...
            'param_ranges_%s_%s.csv',modelName,dtTag));
        if ~isfile(rangeFile)
            rangeID = 1;
            return
        end
        T = readtable(rangeFile,'TextType','string');
        required = {'range_id','n_par','symbol','th_min','th_max'};
        if isempty(T) || ~all(ismember(required,T.Properties.VariableNames))
            rangeID = 1;
            return
        end
        ids = unique(double(T.range_id(:))).';
        schemaFound = false;
        for rid = ids
            Ti = T(double(T.range_id) == rid,:);
            [~,order] = sort(double(Ti.n_par));
            Ti = Ti(order,:);
            sameSchema = height(Ti) == numel(names) ...
                && isequal(string(Ti.symbol(:)),names);
            schemaFound = schemaFound || sameSchema;
            if sameSchema ...
                    && all(abs(double(Ti.th_min(:))-lowerBounds) <= 1e-12) ...
                    && all(abs(double(Ti.th_max(:))-upperBounds) <= 1e-12)
                rangeID = rid;
                return
            end
        end
        if schemaFound
            rangeID = max(ids) + 1;
        else
            % The registrar archives obsolete schemas and restarts at ID 1.
            rangeID = 1;
        end
    end

    function refreshRuntimeSummaryPlot(requestedK)
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));
        ax = S.ui.axRuntimeSummary;
        yyaxis(ax,'right');
        cla(ax);
        yyaxis(ax,'left');
        cla(ax);
        % Apply runtime-axis styling even when no basin has finished yet.
        ax.TickDir = 'out';
        ax.TickLength = [0.005 0.005];
        ax.Box = 'off';
        grid(ax,'off');
        core = [];
        gui = [];
        if isfield(S.runtime,'siteBasinRuntime')
            core = double(S.runtime.siteBasinRuntime(:));
        end
        if isfield(S.runtime,'siteGuiRuntime')
            gui = double(S.runtime.siteGuiRuntime(:));
        end
        if nargin < 1 || ~isfinite(requestedK)
            requestedK = 0;
            try
                cfgNow = getConfigFromUI();
                requestedK = double(cfgNow.bas.K_t);
            catch
            end
        end
        K = max([1,round(requestedK),numel(core),numel(gui)]);
        xlim(ax,[0.5 K+0.5]);
        ax.XTick = siteRuntimeXTicks(K,double(ax.Position(3)));
        ax.XTickLabel = compose('%d',ax.XTick);
        ax.TickLength = [0.005 0.005];
        idx = find(isfinite(core) & core >= 0);
        if isempty(idx)
            text(ax,0.5,0.5, ...
                'Runtime appears after the first basin completes.', ...
                'Units','normalized','HorizontalAlignment','center');
            ax.YTick = [];
            return
        end
        bar(ax,idx,core(idx),0.82, ...
            'FaceColor',[0.00 0.45 0.74], ...
            'EdgeColor','none');
        [coreScale,coreExponent,coreTicks] = ...
            siteRuntimeScale(max(core(idx)));
        ylim(ax,[0 coreTicks(end)*coreScale]);
        ax.YTick = coreTicks*coreScale;
        ax.YTickLabel = compose('%g',coreTicks);
        ax.YColor = [0.00 0.45 0.74];
        ylabel(ax,siteRuntimeUnitLabel( ...
            'Basin runtime',coreExponent));

        yyaxis(ax,'right');
        if numel(gui) < K
            gui(end+1:K,1) = NaN;
        end
        guiIdx = find(isfinite(gui) & gui >= 0);
        if ~isempty(guiIdx)
            bar(ax,guiIdx,-gui(guiIdx),0.58, ...
                'FaceColor',[0.58 0.58 0.58], ...
                'EdgeColor','none');
            guiMax = max(gui(guiIdx));
        else
            guiMax = 1;
        end
        [guiScale,guiExponent,guiTicks] = ...
            siteRuntimeScale(guiMax);
        ylim(ax,[-guiTicks(end)*guiScale 0]);
        ax.YTick = -fliplr(guiTicks)*guiScale;
        ax.YTickLabel = compose('%g',fliplr(guiTicks));
        ax.YColor = [0.45 0.45 0.45];
        ylabel(ax,siteRuntimeUnitLabel('GUI runtime',guiExponent));

        yyaxis(ax,'left');
        xlim(ax,[0.5 K+0.5]);
        ax.XTick = siteRuntimeXTicks(K,double(ax.Position(3)));
        ax.XTickLabel = compose('%d',ax.XTick);
        xlabel(ax,'Basin number');
        title(ax,'Per-basin runtime');
        ax.FontSize = fontsizeDiagText;
        ax.TickDir = 'out';
        ax.TickLength = [0.005 0.005];
        ax.Box = 'off';
        grid(ax,'off');
    end

    function [scale,exponent,ticks] = siteRuntimeScale(maxSeconds)
        maxSeconds = max(1,double(maxSeconds));
        exponent = floor(log10(maxSeconds));
        scale = 10^exponent;
        scaledMax = maxSeconds/scale;
        if scaledMax <= 1.5
            step = 0.25;
        elseif scaledMax <= 2.5
            step = 0.5;
        else
            step = 1;
        end
        top = max(step,ceil(scaledMax/step)*step);
        ticks = 0:step:top;
    end

    function label = siteRuntimeUnitLabel(name,exponent)
        if exponent == 0
            label = [name ' (s)'];
        else
            label = [name ' (\times10^{' num2str(exponent) '} s)'];
        end
    end

    function ticks = siteRuntimeXTicks(K,width)
        if K <= 1
            ticks = 1;
            return
        end
        width = max(300,width);
        maxTicks = max(3,floor(width/85));
        steps = [1 2 5 10 20 25 50 100 200 250 500 1000];
        step = steps(end);
        for tickStepCandidate = steps
            if numel(1:tickStepCandidate:K)+1 <= maxTicks
                step = tickStepCandidate;
                break
            end
        end
        interior = step:step:(K-1);
        minGap = max(1,ceil(42*K/width));
        interior = interior(interior > 1+minGap ...
            & interior < K-minGap);
        ticks = unique([1 interior K]);
    end

    function iMaxAxis = summaryRuntimeIMax(nData)
        % Best estimate of the requested maximum iteration count.
        % Falls back to current data length only when no configured
        % value is available.
        iMaxAxis = max(1,double(nData));
        try
            if isfield(S.runtime,'lastConfig') ...
                    && ~isempty(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'misc') ...
                    && isfield(S.runtime.lastConfig.misc,'alg') ...
                    && isfield(S.runtime.lastConfig.misc.alg,'i_max') ...
                    && ~isempty(S.runtime.lastConfig.misc.alg.i_max)
                iMaxAxis = max(iMaxAxis, ...
                    double(S.runtime.lastConfig.misc.alg.i_max));
                return
            end
        catch
        end
        try
            cfgNow = getConfigFromUI();
            if isfield(cfgNow,'misc') ...
                    && isfield(cfgNow.misc,'alg') ...
                    && isfield(cfgNow.misc.alg,'i_max') ...
                    && ~isempty(cfgNow.misc.alg.i_max)
                iMaxAxis = max(iMaxAxis, ...
                    double(cfgNow.misc.alg.i_max));
                return
            end
        catch
        end
        try
            if isfield(S.ui,'spMaxIter') ...
                    && ~isempty(S.ui.spMaxIter) ...
                    && isgraphics(S.ui.spMaxIter)
                iMaxAxis = max(iMaxAxis, ...
                    double(S.ui.spMaxIter.Value));
            end
        catch
        end
        if ~isfinite(iMaxAxis) || iMaxAxis < 1
            iMaxAxis = max(1,double(nData));
        end
        iMaxAxis = max(1,round(iMaxAxis));
    end

    function txt = runtimeModelLatexTitle()
        txt = 'SAGE';
        try
            if isfield(S.runtime,'lastConfig') ...
                    && ~isempty(S.runtime.lastConfig)
                txt = perfModelLatexTitle( ...
                    S.runtime.lastConfig);
                return
            end
        catch
        end
        try
            raw = char(string(S.ui.ddModel.Value));
            if strcmpi(raw,'xinanjiang')
                raw = 'Xinanjiang';
            end
            txt = strrep(raw,'_','\_');
        catch
        end
    end


    function mode = inferPerfModeForUI()
        %mode = 1;

        try
            if isfield(S.runtime,'lastOut') ...
                    && ~isempty(S.runtime.lastOut) ...
                    && isfield(S.runtime.lastOut,'prf') ...
                    && isstruct(S.runtime.lastOut.prf) ...
                    && isfield(S.runtime.lastOut.prf,'mode') ...
                    && ~isempty(S.runtime.lastOut.prf.mode)
                mode = double(S.runtime.lastOut.prf.mode);
                if ismember(mode,[1 2 3 4])
                    return
                end
            end
        catch
        end

        try
            if isfield(S.runtime,'lastConfig') ...
                    && ~isempty(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'mdl') ...
                    && isfield(S.runtime.lastConfig.mdl,'mode') ...
                    && ~isempty(S.runtime.lastConfig.mdl.mode)
                mode = double(S.runtime.lastConfig.mdl.mode);
                if ismember(mode,[1 2 3 4])
                    return
                end
            end
        catch
        end

        try
            if isfield(S.runtime,'previewRuntime') ...
                    && ~isempty(S.runtime.previewRuntime) ...
                    && isfield(S.runtime.previewRuntime,'mode') ...
                    && ~isempty(S.runtime.previewRuntime.mode)
                mode = double(S.runtime.previewRuntime.mode);
                if ismember(mode,[1 2 3 4])
                    return
                end
            end
        catch
        end

        try
            Ke = double(S.ui.spKe.Value);
        catch
            Ke = 0;
        end

        try
            splitMethod = lower(string(S.ui.ddSplitMethod.Value));
        catch
            splitMethod = "manual";
        end

        if splitMethod == "manual"
            try
                hasEval = ~isempty(strtrim(char(S.ui.edDes.Value))) ...
                    && ~isempty(strtrim(char(S.ui.edDee.Value)));
            catch
                hasEval = false;
            end
            if Ke > 0
                mode = 3 + double(hasEval);
            else
                mode = 1 + double(hasEval);
            end
        else
            if Ke > 0
                mode = 4;
            else
                mode = 2;
            end
        end
    end

    function refreshLogView()
        lines = filterLines(S.store.logAll, ...
            S.ui.edLogSearch.Value, ...
            S.ui.ddLogFilter.Value);
        log_dashboard_ui('refresh',S.ui,lines, ...
            S.runtime.maxVisibleLogLines);
    end

    function refreshIterView()
        lines = filterLines( ...
            S.store.iterAll,S.ui.edIterSearch.Value,'All');
        iteration_dashboard_ui('refresh',S.ui,lines, ...
            S.runtime.maxVisibleIterLines);
    end

    function refreshMapDropdown()
        parameter_map_dashboard_ui('menu',S.ui,S.ui.tblPars.Data);
    end

    function refreshRegion()
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));
        geographic_dashboard_ui('refresh',S.ui,'region', ...
            S.runtime.prepared,S.runtime.preparedLatLon, ...
            S.runtime.preparedBasins,@conusPlotPlain, ...
            @clearConusAxes,@refreshEmptyMapTitles,fontsizeGUI);
    end

    function refreshZones()
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));
        geographic_dashboard_ui('refresh',S.ui,'zones', ...
            S.runtime.prepared,S.runtime.preparedLatLon, ...
            S.runtime.preparedBasins,@zonesPlotPlain, ...
            @clearZonesAxes,@refreshEmptyMapTitles,fontsizeGUI);
    end

    function clearZonesAxes()
        geographic_dashboard_ui('clear',S.ui.axZones, ...
            @currentMapLimits,@deleteGeoTopRightBorder, ...
            @drawGeoTopRightBorder);
    end

    function zonesPlotPlain(latlon,bas)
        cfg = struct( ...
            'clearFcn',@clearZonesAxes, ...
            'limitsFcn',@getCurrentMapLimits, ...
            'backgroundFcn',@drawRegionLandBackground, ...
            'namesFcn',@local_zone_names_for_numbers, ...
            'colorsFcn',@local_zone_colors, ...
            'dataTipFcn',@local_add_zone_datatips, ...
            'labelFcn',@local_zone_legend_label, ...
            'noninteractiveFcn',@local_make_noninteractive, ...
            'drawBorderFcn',@drawGeoTopRightBorder, ...
            'capitalFcn',@(gx)site_plotRegionCapital(gx,getCurrentRegion()), ...
            'region',region_helpers('code',S.ui.ddRegion.Value), ...
            'titleFont',fontsizeMapTitle);
        message = geographic_dashboard_ui( ...
            'renderzones',S.ui,latlon,bas,cfg);
        site_scaleBasinMarkers(S.ui.axZones);
        title(S.ui.axZones,sprintf( ...
            '%s hydroclimatic zones: $K = %d$', ...
            localRegionPanelName(cfg.region),bas.K_t), ...
            'Interpreter','latex','FontSize',fontsizeMapTitle, ...
            'FontWeight','normal');
        S.ui.lblZonesInfo.Text = sprintf( ...
            'Hydroclimatic zones shown for %d basins.',bas.K_t);
        try
            oldLegend = S.ui.axZones.Legend;
            labels = string(oldLegend.String);
            labels(labels == "evaluation basin") = [];
            children = S.ui.axZones.Children;
            handles = gobjects(numel(labels),1);
            for jj = 1:numel(labels)
                for hh = 1:numel(children)
                    if isprop(children(hh),'DisplayName') ...
                            && strcmp(string(children(hh).DisplayName), ...
                            labels(jj))
                        handles(jj) = children(hh);
                        break
                    end
                end
            end
            handles = handles(isgraphics(handles));
            labels = labels(1:numel(handles));
            legend(S.ui.axZones,handles,cellstr(labels), ...
                'Location',oldLegend.Location,'Box','off', ...
                'Interpreter','latex','FontSize',14);
        catch
        end
        if ~isempty(message)
            logmsg(['Could not plot regional capital: ' message]);
        end
    end
    function due = siteLiveRefreshDue(key,period)
        due = true;
        if ~S.runtime.isRunning, return; end
        if ~isfield(S.runtime,'siteLiveRefreshClocks')
            S.runtime.siteLiveRefreshClocks = struct();
        end
        clocks = S.runtime.siteLiveRefreshClocks;
        if isfield(clocks,key)
            due = toc(clocks.(key)) >= period;
        end
        if due
            S.runtime.siteLiveRefreshClocks.(key) = tic;
        end
    end

    function refreshSiteActiveBasins()
        ax = S.ui.axConus;
        if isempty(ax) || ~isgraphics(ax), return; end
        existing = findall(ax,'Tag','SITEActiveTraining','Type','Scatter');
        handles = getappdata(ax,'SITEBaseLegendHandles');
        labels = getappdata(ax,'SITEBaseLegendLabels');
        if isempty(handles) || ~all(isgraphics(handles)), return; end
        active = strings(0,1);
        if isfield(S.runtime,'siteActiveGaugeIds')
            active = S.runtime.siteActiveGaugeIds;
        end
        if isempty(active) && isempty(existing), return; end
        selected = false(0,1);
        if ~isempty(active) && S.runtime.prepared
            bas = S.runtime.preparedBasins;
            coords = S.runtime.preparedLatLon;
            % Normalize numeric gauge strings to preserve leading-zero matches.
            gauges = regexprep(strtrim(string(bas.id_gauge(:))),'^0+(?=\d)','');
            active = regexprep(strtrim(string(active(:))),'^0+(?=\d)','');
            selected = ismember(gauges,active);
            selected = selected & all(isfinite(coords(:,1:2)),2);
            if any(selected)
                if ~isempty(existing)
                    % Reuse the scatter and legend; only coordinates change.
                    existing(1).LatitudeData = coords(selected,1);
                    existing(1).LongitudeData = coords(selected,2);
                    return
                end
                [latitudeLimits,longitudeLimits] = geolimits(ax);
                wasHeld = ishold(ax);
                hold(ax,'on');
                h = geoscatter(ax,coords(selected,1),coords(selected,2), ...
                    58*0.7,'o','filled','MarkerFaceColor',[1 0.65 0.1], ...
                    'MarkerEdgeColor',[1 0.65 0.1],'LineWidth',1, ...
                    'Tag','SITEActiveTraining','HandleVisibility','off', ...
                    'DisplayName','currently training');
                % Use the same line-marker proxy as the training-basins
                % entry so MATLAB aligns all legend text and marker centers.
                markerSize = 8*sqrt(0.7);
                if isprop(handles(1),'MarkerSize')
                    markerSize = handles(1).MarkerSize;
                end
                proxy = plot(ax,nan,nan,'o','LineStyle','none', ...
                    'MarkerSize',markerSize,'MarkerFaceColor',[1 0.65 0.1], ...
                    'MarkerEdgeColor',[1 0.65 0.1],'LineWidth',1, ...
                    'Tag','SITEActiveTraining','HandleVisibility','on', ...
                    'PickableParts','none','HitTest','off');
                geolimits(ax,latitudeLimits,longitudeLimits);
                if ~wasHeld, hold(ax,'off'); end
                handles = [handles(:);proxy];
                labels = [cellstr(string(labels(:))); ...
                    {'\color[rgb]{1 0.65 0.1}currently training'}];
            end
        end
        if isempty(active) || (~isempty(active) && ~any(selected))
            delete(findall(ax,'Tag','SITEActiveTraining'));
        end
        lg = ax.Legend;
        location = lg.Location;
        fontSize = lg.FontSize;
        interpreter = lg.Interpreter;
        fontName = lg.FontName;
        fontWeight = lg.FontWeight;
        lg = legend(ax,handles,labels,'Location',location,'Box','off', ...
            'FontSize',fontSize,'FontName',fontName,'FontWeight',fontWeight, ...
            'Interpreter',interpreter,'NumColumns',1);
        lg.AutoUpdate = 'off';
    end

    function refreshParamMap()
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));
        refreshMapFlag();
        if ~S.runtime.prepared ...
                || isempty(S.runtime.preparedBasins) ...
                || isempty(S.runtime.preparedLatLon)
            refreshParamMapPlaceholder();
            return
        end
        bas = S.runtime.preparedBasins;
        latlon = S.runtime.preparedLatLon;
        parameterTable = S.ui.tblPars.Data;
        parameter = double(S.ui.ddMapPar.Value);
        if isempty(parameterTable) ...
                || parameter < 1 ...
                || parameter > size(parameterTable,1)
            refreshParamMapPlaceholder();
            return
        end
        metric = char(S.ui.ddSiteMapLoss.Value);
        safeNames = site_parameter_names( ...
            string(parameterTable(:,1)));
        values = nan(bas.K,1);
        source = 'saved workbook';
        try
            live = [];
            if isfield(S.runtime,'siteResultStore') ...
                    && isstruct(S.runtime.siteResultStore)
                live = S.runtime.siteResultStore;
            end
            if S.runtime.isRunning && ~isempty(live)
                metricIndex = find(strcmp(string(live.metricNames), ...
                    metric),1);
                if ~isempty(metricIndex) ...
                        && parameter <= size(live.nTheta,2)
                    [found,location] = ismember( ...
                        siteGaugeKey(string(bas.id_gauge(:))), ...
                        siteGaugeKey(string(live.ids(:))));
                    values(found) = live.nTheta( ...
                        location(found),parameter,metricIndex);
                end
                source = 'live results';
            else
                cfg = getConfigFromUI();
                resultDir = char(cfg.dirres);
                [~,leaf] = fileparts(resultDir);
                if ~strcmpi(leaf,char(cfg.region))
                    resultDir = fullfile(resultDir,char(cfg.region));
                end
                if local_is_gchm_ode(cfg.mdl)
                    modelName = 'gchm_ode';
                else
                    modelName = lower(char( ...
                        sage_model_name(cfg.mdl.model)));
                end
                switch double(cfg.prd.dt)
                    case 1, dtTag = 'daily';
                    case 24, dtTag = 'hourly';
                    case 96, dtTag = '15min';
                    otherwise
                        dtTag = sprintf('dt_%g',cfg.prd.dt);
                end
                paths = site_result_store('paths',resultDir, ...
                    modelName,dtTag,cfg.region,cfg.misc.meteo,cfg.prd);
                values = site_parameter_map_values( ...
                    paths.fileBook,metric,safeNames(parameter), ...
                    bas.id_gauge(:));
                if ~isfile(paths.fileBook) && ~isempty(live)
                    metricIndex = find(strcmp( ...
                        string(live.metricNames),metric),1);
                    if ~isempty(metricIndex) ...
                            && parameter <= size(live.nTheta,2)
                        [found,location] = ismember( ...
                            siteGaugeKey(string(bas.id_gauge(:))), ...
                            siteGaugeKey(string(live.ids(:))));
                        values(found) = live.nTheta( ...
                            location(found),parameter,metricIndex);
                        source = 'checkpoint';
                    end
                end
            end
        catch ME
            refreshParamMapPlaceholder();
            S.ui.lblMapInfo.Text = ['Map data: ' ME.message];
            return
        end
        if ~any(isfinite(values))
            refreshParamMapPlaceholder();
            S.ui.lblMapInfo.Text = ...
                sprintf('No saved %s values for this parameter.',metric);
            return
        end
        nTheta = nan(size(parameterTable,1),bas.K);
        nTheta(parameter,:) = values(:).';
        paramMapPlotCountry(latlon,bas,nTheta,parameter,'train');
        S.ui.lblMapInfo.Text = sprintf( ...
            '%d/%d basins | %s | %s', ...
            nnz(isfinite(values)),bas.K,metric,source);
        S.ui.lblMapTip.Text = [ ...
            'Color intensity shows the best saved normalized parameter ' ...
            'value for the selected loss function. ' ...
            'Training basins are blue circles; gray = no saved result.'];
        hideParamMapAxes();
    end

    function refreshMapFlag()
        message = parameter_map_dashboard_ui('flag',S.ui, ...
            getCurrentRegion(),S.cfg.SAGEhydro,@localRegionFlagFile);
        if ~isempty(message)
            logmsg(['Could not refresh Map flag: ' message]);
        end
    end

    function resetInitialDiagnosticAxisFonts()

    
    
        try
            perfStyleFcn(S.ui.axPerf);
        catch 
        end
    
    
    end

    function styleInitialDiagnosticAxis(ax)

        if isempty(ax) ...
                || ~isgraphics(ax)
            return
        end
    
        try
            diagStyleFcn(ax);
            ax.FontSize = fontsizeDiagFontPlot;
            ax.TickLabelInterpreter = 'latex';
            ax.XLabel.Interpreter = 'latex';
            ax.YLabel.Interpreter = 'latex';
            ax.Title.Interpreter = 'latex';
            ax.XLabel.FontSize = fontsizeDiagLabelPlot;
            ax.YLabel.FontSize = fontsizeDiagLabelPlot;
            ax.Title.FontSize = fontsizeDiagFontPlot;
            ax.XLabel.FontWeight = 'normal';
            ax.YLabel.FontWeight = 'normal';
            ax.Title.FontWeight = 'normal';
        catch
        end
    end

    function refreshMeteoPETInfo()
        refreshMeteoPETInfo_standalone(S.ui,S.cfg,fontsizeNotes);
    end


    function localResizeLossNotes(~)
    %LOCALRESIZELOSSNOTES Keep one viewport size for every loss.
    % The panel fills the space below the controls; only the text scrolls.
        try
            S.ui.gLossMain.RowHeight = {112,'1x',0};
            S.ui.gLossHelpGrid.RowHeight = {'fit'};
            S.ui.gLossHelpGrid.Scrollable = 'on';
            S.ui.pLossHelp.Scrollable = 'off';
            S.ui.pLossHelp.AutoResizeChildren = 'on';
            drawnow limitrate nocallbacks
            scroll(S.ui.gLossHelpGrid,'top');
        catch
        end
    end
    function localResizeOptNotes(txt)

        if nargin < 1 || isempty(txt)
            txt = {''};
        end
        txt = localCompactNoteSpacing(txt);
        try
            fs = S.ui.lblOptEq.FontSize;
        catch
            fs = fontsizeNotes;
        end
        localFitResponsiveNotePanel( ...
            S.ui.gOptMain,S.ui.pOptHelp, ...
            S.ui.gOptHelpGrid,S.ui.lblOptEq, ...
            txt,localTrainingTopHeight(),fs);
        try
            S.ui.lblOptEq.VerticalAlignment = 'top';
            % Content or width changes can retain the old scroll offset.
            % Always present the refreshed optimizer notes from line one.
            scroll(S.ui.gOptHelpGrid,'top');
        catch
        end
    end

    function localFitResponsiveNotePanel( ...
            mainGrid,panel,helpGrid,label,txt,topHeight,fontSize, ...
            correctionLines)
    %LOCALFITRESPONSIVENOTEPANEL Fit wrapped LaTeX at the current width.
    % A conservative first pass gives the label room to wrap. The second
    % pass uses MATLAB's rendered Extent and therefore remains valid after
    % maximize, restore, monitor changes, and font scaling.

        try
            drawnow;
            labelWidth = max(120,double(label.Position(3)));
        catch
            try
                labelWidth = max(120,double(panel.Position(3)) - 20);
            catch
                labelWidth = 600;
            end
        end

        if nargin < 9 || isempty(correctionLines)
            correctionLines = 0;
        end

        % Use the tighter wrapped-line estimator for the transient startup
        % state. The generic notes-box estimate is intentionally more
        % conservative and left several empty visual lines on this tab.
        nLines = local_estimate_wrapped_lines( ...
            txt,labelWidth,fontSize);
        fallbackHeight = localNoteHeightFromLineCount( ...
            nLines,fontSize,40,3000);

        panelChrome = 26;
        gridPadding = helpGrid.Padding;
        try
            mainHeight = double(mainGrid.Position(4));
            mainPadding = double(mainGrid.Padding);
            mainSpacing = double(mainGrid.RowSpacing);
            availableHeight = mainHeight - topHeight - ...
                2*mainSpacing - mainPadding(2) - mainPadding(4);
        catch
            availableHeight = 420;
        end

        % First pass: never clip while the new width is being laid out.
        requiredHeight = fallbackHeight + gridPadding(2) + ...
            gridPadding(4) + panelChrome;
        visibleHeight = min(requiredHeight,max(100,availableHeight));
        try
            mainGrid.RowHeight = { ...
                topHeight,round(visibleHeight),'1x'};
            helpGrid.RowHeight = {round(fallbackHeight)};
            drawnow;
        catch
        end

        % Second pass: tighten to the actual wrapped LaTeX extent.
        contentHeight = localFittedNoteLabelHeight( ...
            label,txt,fontSize,fallbackHeight,40,3000);
        lineHeight = max(16,1.40*double(fontSize));
        contentHeight = contentHeight + ...
            correctionLines*lineHeight;
        contentHeight = max(40,contentHeight);
        requiredHeight = contentHeight + gridPadding(2) + ...
            gridPadding(4) + panelChrome;
        visibleHeight = min(requiredHeight,max(100,availableHeight));
        try
            mainGrid.RowHeight = { ...
                topHeight,round(visibleHeight),'1x'};
            helpGrid.RowHeight = {round(contentHeight)};
            drawnow limitrate nocallbacks;
            actualHeight = double(panel.Position(4));
            helpGrid.Scrollable = localOnOff( ...
                requiredHeight > actualHeight + 1);
            panel.Scrollable = 'off';
            panel.AutoResizeChildren = 'on';
        catch
        end
    end

    function value = localOnOff(condition)
        if condition
            value = 'on';
        else
            value = 'off';
        end
    end
    function hTop = localTrainingTopHeight()
    
        % Constant schedules hide the two schedule-specific rows.
        try
            rowH = rowHValueTraining;
        catch
            rowH = max(28,round(1.8*fontsizeValueODE));
        end
        nRows = 11;
        try
            isAdam = parseLeadingInt_local(S.ui.ddOpt.Value) == 2;
            nRows = nRows - 4*double(~isAdam);
            schedule = lower(char(S.ui.ddLRSchedule.Value));
            if strcmp(schedule,'constant')
                nRows = nRows - 2;
            elseif strcmp(schedule,'cosine')
                nRows = nRows - 1;
            end
        catch
        end
        hTop = nRows*rowH + (nRows-1)*8;
        % Keep a safe lower bound for laptop screens
        hTop = max(180,round(hTop));
    end

    function resizeChecksTable()
        checks_dashboard_ui('layout',S.ui);
    end

    function resizeZoneTable()
        zone_table_dashboard_ui('layout',S.ui);
    end

    function refreshRegionFlag()
    
        if ~isfield(S.ui,'imgRegionFlag') ...
                || isempty(S.ui.imgRegionFlag) ...
                || ~isgraphics(S.ui.imgRegionFlag)
            return
        end
    
        region = getCurrentRegion();
        try
            S.ui.lblRegionFlagName.Text = ...
                localRegionPanelName(region);
        catch
            S.ui.lblRegionFlagName.Text = '';
        end
    
        try
            flagFile = localRegionFlagFile(region, ...
                S.cfg.SAGEhydro);
            if ~isempty(flagFile)
                S.ui.imgRegionFlag.ImageSource = flagFile;
                S.ui.imgRegionFlag.Visible = 'on';
            else
                S.ui.imgRegionFlag.ImageSource = '';
                S.ui.imgRegionFlag.Visible = 'off';
            end
        catch ME
            S.ui.imgRegionFlag.ImageSource = '';
            S.ui.imgRegionFlag.Visible = 'off';
            logmsg(['Could not refresh Region flag: ' ...
                ME.message]);
        end
    end

    function [tf,details] = local_postprocess_scenario_status()

        try
            tt = logical(S.ui.cbScenTT.Value);
            te = logical(S.ui.cbScenTE.Value);
            et = logical(S.ui.cbScenET.Value);
            ee = logical(S.ui.cbScenEE.Value);
            nActive = sum([tt te et ee]);
            tf = nActive > 0;
            if ~tf
                details = ['Select at least one ' ...
                    'postprocess scenario'];
                return
            end
            if tt ...
                    && te ...
                    && et ...
                    && ee
                details = ['Training and evaluation ' ...
                    'basin scenarios are active'];
            elseif tt ...
                    && ~te ...
                    && ~et ...
                    && ~ee
                details = ['Only training basins ' ...
                    '| training period is active'];
            elseif ~tt ...
                    && te ...
                    && ~et ...
                    && ~ee
                details = ['Only training basins ' ...
                    '| evaluation period is active'];
            elseif ~tt ...
                    && ~te ...
                    && et ...
                    && ~ee
                details = ['Only evaluation basins ' ...
                    '| training period is active'];
            elseif ~tt ...
                    && ~te ...
                    && ~et ...
                    && ee
                details = ['Only evaluation basins ' ...
                    '| evaluation period is active'];
            else
                details = sprintf(['%d postprocess ' ...
                    'scenarios are active'],nActive);
            end
        catch
            tf = true;
            details = ['Postprocess scenario ' ...
                'controls available'];
        end
    end

    function updateLockState()
        site_center_buttons_ui(f);
        lock = S.runtime.isRunning;
        if lock
            applyGlobalButtonLock(true);
        else
            applyGlobalButtonLock(false);
        end
        % Enable Run after basin preparation. The selected CRR backend is
        % checked and, in MATLAB mode, compiled automatically by the run
        % preparation path. Full readiness is checked again inside onRun.
        readyForRun = ~lock ...
            && S.runtime.prepared ...
            && ~isempty(S.runtime.preparedBasins);
        setEnable(S.ui.btnRun,readyForRun);
        setEnable(S.ui.btnStop,lock);
        setEnable(S.ui.btnValidate,~lock);

        prepareNeeded = ~S.runtime.prepared ...
            || isempty(S.runtime.preparedBasins);
        setEnable(S.ui.btnPrepare,~lock ...
            && prepareNeeded && S.runtime.dataReady);
        if S.runtime.dataReady
            S.ui.btnPrepare.Tooltip = ...
                'Load the selected training basins.';
        else
            S.ui.btnPrepare.Tooltip = ...
                ['Install the selected data and attribute files ' ...
                'before loading basins.'];
        end
        if prepareNeeded
            S.ui.btnPrepare.Text = ...
                'Load basins';
        else
            S.ui.btnPrepare.Text = ...
                'Basins loaded';
        end
        setEnable(S.ui.btnSaveSession,~lock);
        setEnable(S.ui.btnLoadSession,~lock);
        % An exported script must contain the basin division actually
        % prepared by the GUI.  A split-file path alone is insufficient:
        % attribute reading or basin preparation may still have failed.
        setEnable(S.ui.btnExportScript,readyForRun);

        controlsToLock = { ...
            S.ui.edRoot,S.ui.btnBrowseRoot, ...                           % Paths
            S.ui.edSAGE,S.ui.btnBrowseSAGE, ...
            S.ui.edDataLocation,S.ui.btnBrowseData, ...
            S.ui.edRes,S.ui.btnBrowseResults, ...
            S.ui.ddRegion, ...                                          % Region
            S.ui.ddModel,S.ui.ddMcode,S.ui.ddCalc, ...                  % Model
            S.ui.tblInitialStates,S.ui.tblModelValues, ...
            S.ui.btnInitialDefaults,S.ui.btnModelValueDefaults, ...
            S.ui.edCfeGiuhValues, ...
            S.ui.ddRes,S.ui.ddSplitMethod,S.ui.spSpin, ...              % Period
            S.ui.edDts,S.ui.edDte,S.ui.edDes,S.ui.edDee, ...
            S.ui.edDBlockStart,S.ui.edDBlockEnd,S.ui.spDBlockSize, ...
            S.ui.edDBlockFrac,S.ui.edRBlockStart,S.ui.edRBlockEnd, ...
            S.ui.spRBlockSize,S.ui.edRBlockFrac,S.ui.edRBlockSeed, ...
            S.ui.edRndStart,S.ui.edRndEnd,S.ui.edRndFrac, ...
            S.ui.edRndSeed,S.ui.edDKFoldStart,S.ui.edDKFoldEnd, ...
            S.ui.spDKFolds,S.ui.spDKFold,S.ui.edRKFoldStart, ...
            S.ui.edRKFoldEnd,S.ui.spRKFolds,S.ui.spRKFold, ...
            S.ui.edRKFoldSeed, ...
            S.ui.ddKcns,S.ui.spKt,S.ui.spKe,S.ui.ddSample, ...          % Basins
            S.ui.btnPickBasinFile,S.ui.btnNewRandomSplit, ...
            S.ui.tblPars,S.ui.btnParDefaults,S.ui.btnParExport, ...     % Parameters
            S.ui.edInitStep,S.ui.edMaxStep,S.ui.edMinStep, ...          % ODE
            S.ui.edRelTol,S.ui.edAbsTol,S.ui.spOrder, ...
            S.ui.spMaxIterODE,S.ui.ddMem,S.ui.btnODEDefaults, ...
            S.ui.ddMeteo,S.ui.ddPrecip,S.ui.ddTemp,S.ui.ddPET, ...      % Meteo
            S.ui.ddLoss,S.ui.ddJKGEMethod,S.ui.ddJKGEM, ...
            S.ui.spJKGENwin, ...                                        % Loss/optim
            S.ui.ddOpt,S.ui.spImax,S.ui.edLR, ...
            S.ui.edBeta1,S.ui.edBeta2,S.ui.edVarEps, ...
            S.ui.ddLRSchedule,S.ui.edLRmin,S.ui.edLRhold, ...
            S.ui.edWdec,S.ui.spClipn, ...
            S.ui.ddSiteOpt,S.ui.ddSiteFinisher, ...
            S.ui.spSiteStarts,S.ui.spSiteIMax, ...
            S.ui.spSiteSaveEvery,S.ui.tblSiteOpts, ...
            S.ui.tblSiteSharedOpts,S.ui.btnSiteOptDefaults, ...
            S.ui.cbAttr, ...                                            % Postprocessor controls to lock
            S.ui.tblPostTrain,S.ui.tblPostEval, ...
            S.ui.spBprtTrain,S.ui.spBprtEval, ...                       % basin tables in basin and postprocessor
            S.ui.cbScenTT,S.ui.cbScenTE,S.ui.cbScenET,S.ui.cbScenEE};
        for ii = 1:numel(controlsToLock)
            try
                controlsToLock{ii}.Enable = tern(~lock,'on','off');
            catch
            end
        end
        % These inherited SAGE controls are derived in SITE, not editable.
        try S.ui.ddKcns.Enable = 'off'; catch, end
        try S.ui.spKt.Enable = 'off'; catch, end
        try S.ui.spKe.Enable = 'off'; catch, end
        if ~lock
        end
    end


    function markDependencyChange(reason,detail,resetBasins,resetCompile)
        % Centralized dependency bookkeeping.  This keeps the GUI honest:
        % if a user changes something that invalidates a prepared split or
        % compiled MEX state, the status, Checks tab, and log all say so.
        if nargin < 2 ...
                || isempty(detail)
            detail = reason;
        end
        if nargin < 3 ...
                || isempty(resetBasins)
            resetBasins = false;
        end
        if nargin < 4 ...
                || isempty(resetCompile)
            resetCompile = false;
        end

        if resetBasins
            S.runtime.filePreparedLocked = false;
            S.runtime.prepared = false;
            S.runtime.preparedBasins = [];
            S.runtime.preparedLatLon = [];
            S.runtime.lastConfig = [];
            S.runtime.previewRuntime = struct( ...
                'tout',[], ...
                'id_train',[], ...
                'id_eval',[], ...
                'idx',[], ...
                'mode',[], ...
                'sp_method','');
            try
                S.ui.tblPlotTrain.Data = cell(0,4);
                S.ui.tblPlotEval.Data = cell(0,4);
                S.ui.tblPostTrain.Data = cell(0,6);
                S.ui.tblPostEval.Data = cell(0,6);
                S.ui.lblEvalLegend.Text = ...
                    ['Basin split cleared. Click ' ...
                    'Load basins to prepare ' ...
                    'basins for the selected data set.'];
                updateBasinTableLayout(0);                
            catch
            end
            S.runtime.quality = [];
            S.runtime.qualityRow = 1;
            try
                data_quality_dashboard_ui('reset',S.ui);
            catch
            end
            try applyRegionBasinDefaults(); catch, end
        end

        if resetCompile
            S.runtime.compileOK = false;
            S.runtime.compileMessage = ...
                [reason '; CRR backend status reset'];
        end

        S.runtime.lastOut = [];
        S.runtime.siteBasinRuntime = [];
        S.runtime.siteGuiRuntime = [];
        S.runtime.siteBasinsFinished = 0;
        S.runtime.siteLiveRefreshClocks = struct();
        S.runtime.siteTiming = struct('data',NaN, ...
            'init',NaN,'train',NaN,'gui',NaN);
        S.runtime.stopRequestTime = [];
        S.runtime.userSelectedRightTabDuringRun = false;
        % Clear live diagnostic products from the previous region/run.
        try
            S.runtime.latestNTheta = [];
        catch
        end
        try
            S.runtime.latestBas = [];
        catch
        end
        try
            S.runtime.latestLatLon = [];
        catch
        end
        try
            S.runtime.attr = struct('At',[], ...
                'An',[],'iter',[], ...
                'names',strings(0,1),'last_i',0);
        catch
        end
        S.runtime.dependencyNotice = detail;
        try
            logmsg(['Dependency update: ' detail]);
        catch
        end
        S.runtime.lastStatus = reason;
    end


    function safeGuiCall(context,fun)
        try
            fun();
        catch ME
            try
                logmsg([char(string(context)) ': ' ME.message]);
            catch
                warning('SAGE_ui:guiCall','%s: %s', ...
                    char(string(context)),ME.message);
            end
        end
    end

    % ==========
    %  Callbacks
    % ==========
    function onSimpleRefresh(src,event)
        if nargin < 1, src = []; end
        if nargin < 2, event = []; end
        if isfield(S.ui,'tblInitialStates') && any(cellfun(@(h)isequal(src,h), ...
                {S.ui.tblInitialStates,S.ui.tblModelValues,S.ui.btnInitialDefaults,S.ui.btnModelValueDefaults, ...
                S.ui.edCfeGiuhValues}))
            cfg=getConfigFromUI();mdl=getCachedModelForUI();
            [options,edited]=model_configuration_ui('change',S.ui,mdl,cfg,S.runtime.isRunning,f,S.store.modelOptions,event,src);
            S.store.modelOptions=options;
            if ~edited
                if ~isequal(src,S.ui.tblModelValues) || (isstruct(event) && isfield(event,'NewData')) || (isobject(event) && isprop(event,'NewData'))
                    refreshParamTable();
                end
                return
            end
            refreshParamTable();
        end
        [restored,fieldName] = local_restore_required_period_date( ...
            S.ui,src,event);
        if restored
            refreshSplitTimeline();
            uialert(f,sprintf(['%s cannot be empty. The previous valid ' ...
                'date has been restored.'],fieldName), ...
                'Date required');
            return
        end

        clampKfoldControls();
        S.runtime.lastOut = [];
        setGuiState('edited');
        try siteUi('syncCalc'); catch, end
        S.runtime.dependencyNotice = ...
            ['Settings edited; press ' ...
            'Validate to refresh checks.'];
        refreshSplitTimeline();

        [datesOK,~] = local_required_period_dates(S.ui);
        if ~datesOK
            return
        end

        syncPostScenariosFromPeriod();
        refreshSummary();

        if S.ui.tgRight.SelectedTab == S.ui.tabPreview
            refreshPreview();
        end
    end

    function onBasinSetupChanged(src,~)
        try
            if isequal(src,S.ui.ddKcns)
                applyBasinUniverseDefaults();
            end
        catch
        end
        markDependencyChange('basin selection changed', ...
            ['Basin settings changed; ' ...
            'existing prepared basins ' ...
            'were cleared. Click Load basins.'], ...
            true,false);
        syncPostScenariosFromPeriod();
        updateDefaultBasinSplitFile();
        refreshAll();
    end

    function onPostprocessRefresh(~,~)
        setGuiState('edited');
        syncPostprocessScenarioControls();
        refreshPreview();
        refreshSummary();
        refreshPostSelectionViews();
        refreshReadiness();
    end

    function refreshPostSelectionViews()
        try
            refreshMapDropdown();
        catch
        end
        try
            refreshRegion();
        catch
        end
        try
            refreshZones();
        catch
        end
        drawnow limitrate nocallbacks;
    end

    function onMaxIterODEChanged(~,~)
        S.ui.spMaxIterODE.Value = ...
            round(S.ui.spMaxIterODE.Value);
        onSimpleRefresh();
    end

    function onLeftTabChanged(~,evt)
        if isequal(evt.NewValue,tabNotes)
            drawnow nocallbacks;
            siteResizeNotesIntro(S.ui);
        end
        try
            if isequal(evt.NewValue,tabPaths)
                refreshWorldCoverageMap();
            end
        catch ME
            logmsg(['World coverage map refresh failed: ' ...
                ME.message]);
        end
        % existing code
        try
            if isequal(evt.NewValue,S.ui.tabRegion)
                refreshDataStatus();
                S.runtime.dataStatusDirty = false;
            end
        catch ME
            logmsg(['Data-status refresh failed: ' ME.message]);
        end
        try
            if isequal(evt.NewValue,tabDiag)
                % Do not resynchronize/destructively reset visualization
                % scenario selections during a run.
                if S.runtime.isRunning
                    refreshPreview();
                    refreshSummary();
                    return
                end
                syncPostScenariosFromPeriod();
                refreshPreview();
                refreshSummary();
            end
        catch
        end
        try
            if isequal(S.ui.tgLeft.SelectedTab, ...
                    S.ui.tabPars)
                drawnow limitrate
                resizeParameterTable();
            elseif isequal(S.ui.tgLeft.SelectedTab, ...
                    S.ui.tabTrain)
                % The Training tab has no reliable width while inactive.
                % Measure optimizer notes only after the tab becomes visible,
                % then repeat once after MATLAB applies the new row height.
                drawnow
                refreshOptHelpText();
                drawnow
                refreshOptHelpText();
            elseif isequal(S.ui.tgLeft.SelectedTab, ...
                    S.ui.tabMeteo)
                drawnow
                refreshMeteoPETInfo();
                drawnow
                refreshMeteoPETInfo();
            elseif isequal(S.ui.tgLeft.SelectedTab, ...
                    S.ui.tabModel)
                % The grid-managed image already has the final panel size
                % when the tab becomes visible; one source refresh suffices.
                drawnow limitrate nocallbacks
                refreshModelDiagram();
            elseif isequal(S.ui.tgLeft.SelectedTab,tabPeriod)
                drawnow limitrate nocallbacks
                refreshSplitTimeline();
            elseif isequal(S.ui.tgLeft.SelectedTab, ...
                    S.ui.tabLoss)
                drawnow
                refreshLossHelpText();
                drawnow
                refreshLossHelpText();
            end
        catch
        end
        localScheduleResponsiveNoteResize();
    end

    function localReleaseOptResizeGuard()
        S.runtime.resizingOptNotes = false;
    end

    function onPeriodMethodChanged(~,~)
        markDependencyChange('period split changed', ...
            ['Period/split settings changed; ' ...
            'Validate checks and ' ...
            'reload basins if the split ' ...
            'or available dates changed.'], ...
            true,false);
        refreshPeriodMethodControls();
        jkge_controls_ui(S.ui, ...
            @parseLeadingInt_local,@setVisibleSafe);
        syncPostScenariosFromPeriod();
        refreshSplitTimeline();
        refreshAll();
    end

    function onOptDefaults(~,~)

        choice = uiconfirm(f, ...
            ['Reset loss | optimizer settings ' ...
            'to defaults?'], ...
            'Reset optimizer defaults', ...
            'Options',{'Reset','Cancel'}, ...
            'DefaultOption',2, ...
            'CancelOption',2);

        if ~strcmp(choice,'Reset')
            return
        end

        try
            S.ui.ddLoss.Value = ...
                '2 Generalized Least Squares';
            S.ui.ddFDCFormulation.Value = 1;
            S.ui.ddJKGEMethod.Value = ...
                '1 Moving-average mean';
            S.ui.spJKGENwin.Value = 7;
            S.ui.ddOpt.Value = ...
                '2 Adam/AdamW';
            S.ui.spImax.Value = 250;
            S.ui.edLR.Value = 1e-2;
            S.ui.edBeta1.Value = 0.9;
            S.ui.edBeta2.Value = 0.999;
            S.ui.edVarEps.Value = 1e-8;
            S.ui.ddLRSchedule.Value = 'constant';
            S.ui.edLRmin.Value = 1e-4;
            S.ui.edLRhold.Value = 0.20;
            S.ui.edWdec.Value = 1e-4;
            S.ui.spClipn.Value = 1;

            logmsg(['Loss | optimizer settings ' ...
                'reset to defaults.']);

            onOptHelpRefresh();

        catch ME
            logErrorStack(['Optimizer default ' ...
                'reset error:'],ME);
        end
    end

    function onAdvancedModeChanged(~,~)
        toggleAdvancedMode(S.ui.cbAdvanced.Value);
    end

    function onRootChanged(~,~)
        oldRoot = char(S.cfg.root);
        newRoot = strtrim(char(S.ui.edRoot.Value));
        if isempty(newRoot)
            S.ui.edRoot.Value = oldRoot;
            return
        end
        if strcmp(char(S.ui.edDataLocation.Value), ...
                fullfile(oldRoot,'Data'))
            S.ui.edDataLocation.Value = fullfile(newRoot,'Data');
        end
        if strcmp(char(S.ui.edSITE.Value), ...
                fullfile(oldRoot,'SITEhydrology'))
            S.ui.edSITE.Value = fullfile(newRoot,'SITEhydrology');
        end
        if strcmp(char(S.ui.edRes.Value), ...
                fullfile(oldRoot,'SAGEhydrology','results'))
            S.ui.edRes.Value = fullfile( ...
                newRoot,'SAGEhydrology','results');
        end
        if strcmp(char(S.ui.edSAGE.Value), ...
                fullfile(oldRoot,'SAGEhydrology'))
            S.ui.edSAGE.Value = fullfile(newRoot,'SAGEhydrology');
        end
        S.cfg.root = newRoot;
        S.cfg.SITEhydro = char(S.ui.edSITE.Value);
        S.cfg.SAGEhydro = char(S.ui.edSAGE.Value);
        S.cache.regionConfig = [];
        S.cache.regionConfigKey = "";
        S.cache.worldInstallStatus = struct();
        S.runtime.worldCoverageDrawn = false;
        sageParent = fileparts(S.cfg.SAGEhydro);
        ensureInstallerOnPath(sageParent);
        ensureSAGEpath(sageParent);
        refreshModelDropdown();
        markDependencyChange('software root changed', ...
            'Load basins again.',true,false);
        S.runtime.dataReady = false;
        refreshAll();
    end

    function onBrowseRoot(~,~)
        onBrowseLocation('root');
    end

    function onSAGEChanged(~,~)
        oldSAGE = char(S.cfg.SAGEhydro);
        newSAGE = strtrim(char(S.ui.edSAGE.Value));
        if ~isfolder(newSAGE) ...
                || ~isfolder(fullfile(newSAGE,'regions')) ...
                || ~isfolder(fullfile(newSAGE,'maps'))
            S.ui.edSAGE.Value = oldSAGE;
            uialert(f, ...
                'Select a SAGEhydrology folder containing regions and maps.', ...
                'Invalid SAGEhydrology folder');
            return
        end
        S.cfg.SAGEhydro = newSAGE;
        S.cfg.SAGEdir = newSAGE;
        try setpref('SITEhydrology','SAGEhydro',newSAGE); catch, end
        if ~isdeployed
            ensureInstallerOnPath(fileparts(newSAGE));
            ensureSAGEpath(fileparts(newSAGE));
        end
        S.cache.regionConfig = [];
        S.cache.regionConfigKey = "";
        S.cache.worldInstallStatus = struct();
        S.runtime.worldCoverageDrawn = false;
        markDependencyChange('SAGEhydrology location changed', ...
            'Load basins again.',true,false);
        S.runtime.dataReady = false;
        refreshAll();
    end

    function onSITEChanged(~,~)
        oldSITE = char(S.cfg.SITEhydro);
        newSITE = strtrim(char(S.ui.edSITE.Value));
        if ~isfolder(newSITE) ...
                || ~isfile(fullfile(newSITE,'gui','SITE_ui.m')) ...
                || ~isfile(fullfile(newSITE,'src','run_SITE.m'))
            S.ui.edSITE.Value = oldSITE;
            uialert(f,['Select the SITEhydrology folder containing ' ...
                'gui/SITE_ui.m and src/run_SITE.m.'], ...
                'Invalid SITEhydrology folder');
            return
        end
        S.cfg.SITEhydro = newSITE;
        S.cfg.root = fileparts(newSITE);
        S.ui.edRoot.Value = S.cfg.root;
        try setpref('SITEhydrology','SITEhydro',newSITE); catch, end
        markDependencyChange('SITEhydrology location changed', ...
            'Load basins again.',true,false);
        S.runtime.dataReady = false;
        refreshAll();
    end

    function onLocationChanged(kind)
        if strcmp(kind,'data')
            field = S.ui.edDataLocation;
            previous = S.cfg.dirDroot;
        else
            field = S.ui.edRes;
            previous = S.cfg.dirres;
        end
        value = strtrim(char(field.Value));
        if isempty(value)
            field.Value = previous;
            uialert(f,'Select a folder.','Location required');
            return
        end
        if strcmp(kind,'data')
            S.cfg.dirDroot = value;
            try setpref('SITEhydrology','DataRoot',value); catch, end
            % Installation colors are relative to dirDroot. A Paths-tab
            % redraw must recompute them against the newly chosen folder.
            S.cache.worldInstallStatus = struct();
            S.runtime.worldCoverageDrawn = false;
            markDependencyChange('data location changed', ...
                'Load basins again.',true,false);
            S.runtime.dataReady = false;
            refreshAll();
            try
                if isequal(S.ui.tgLeft.SelectedTab,tabPaths)
                    refreshWorldCoverageMap();
                end
            catch ME
                logmsg(['World coverage map refresh failed: ' ...
                    ME.message]);
            end
        else
            S.cfg.dirres = value;
            try setpref('SITEhydrology','ResultsRoot',value); catch, end
            onSimpleRefresh();
            refreshDerivedPaths();
            refreshSummary();
        end
    end

    function onBrowseLocation(kind)
        switch kind
            case 'root'
                field = S.ui.edRoot;
            case 'site'
                field = S.ui.edSITE;
            case 'sage'
                field = S.ui.edSAGE;
            case 'data'
                field = S.ui.edDataLocation;
            otherwise
                field = S.ui.edRes;
        end
        startDir = char(field.Value);
        if ~isfolder(startDir), startDir = pwd; end
        folder = uigetdir(startDir,'Select folder');
        if ~ischar(folder) || isequal(folder,0), return, end
        field.Value = folder;
        if strcmp(kind,'root')
            onRootChanged();
        elseif strcmp(kind,'site')
            onSITEChanged();
        elseif strcmp(kind,'sage')
            onSAGEChanged();
        else
            onLocationChanged(kind);
        end
    end
    function onInstallMap10(~,~)
        try
            setEnable(S.ui.btnInstallMap10,false);
            S.ui.btnInstallMap10.Text = 'Installing 10 m map ...';
            drawnow

            uiMap = struct();
            uiMap.logFcn = @(msg)logmsg(char(string(msg)));
            result = data_helpers('ensuremap',getConfigFromUI(),uiMap);

            if ~isstruct(result) ...
                    || ~isfield(result,'ok') ...
                    || ~result.ok ...
                    || ~isfield(result,'scale') ...
                    || ~strcmpi(char(string(result.scale)),'10m')
                message = 'The optional Natural Earth 10 m map was not installed.';
                if isstruct(result) ...
                        && isfield(result,'message') ...
                        && ~isempty(result.message)
                    message = sprintf('%s\n\n%s',message, ...
                        char(string(result.message)));
                end
                uialert(f,message,'Map installation failed');
            end
        catch ME
            logErrorStack('10 m map installation error:',ME);
            uialert(f,ME.message,'Map installation failed');
        end
        refreshMapInstallStatus();
    end

    function refreshMapInstallStatus()
        try
            mapCfg = S.cfg;
            mapCfg.root = char(S.ui.edRoot.Value);
            mapCfg.SAGEhydro = char(S.ui.edSAGE.Value);
            result = data_helpers('mapstatus',mapCfg);
            has10 = isstruct(result) ...
                && isfield(result,'scale') ...
                && strcmpi(char(string(result.scale)),'10m');
            if has10
                S.ui.edMapStatus.Value = '50 m bundled | 10 m installed';
                S.ui.btnInstallMap10.Text = '10 m map installed';
                setEnable(S.ui.btnInstallMap10,false);
            else
                S.ui.edMapStatus.Value = '50 m bundled | 10 m not installed';
                S.ui.btnInstallMap10.Text = 'Install 10 m map';
                setEnable(S.ui.btnInstallMap10,true);
            end
        catch
            S.ui.edMapStatus.Value = '50 m bundled';
            S.ui.btnInstallMap10.Text = 'Install 10 m map';
            setEnable(S.ui.btnInstallMap10,true);
        end
    end


    function onModelChanged(~,~)
        markDependencyChange('model changed', ...
            ['Model changed; CRR backend status reset. ' ...
            'Availability will be checked automatically. Existing basin ' ...
            'selection is retained.'],false,true);
        try
            if S.runtime.prepared ...
                    && ~isempty(S.runtime.preparedBasins)
                logmsg(['Model changed; existing ' ...
                    'basin split is retained. ' ...
                    'You do not need to press Load ' ...
                    'basins again unless ' ...
                    'you want a different split.']);
            end
        catch
        end
        S.cache.modelBase = [];
        S.cache.modelBaseKey = "";
        
        modelKey = char(S.ui.ddModel.Value);
        S.cfg.mdl.model = ...
            local_model_id_from_key(modelKey);
        S.cfg.mdl = local_model_variant( ...
            S.cfg.mdl,modelKey);
        site_reorderRightTabs(S.ui.tgRight,{tabSummary,tabPreview,tabQuality, ...
            tabLog,tabIter,tabRegionMap,tabZones,tabParamMap, ...
            tabBasinResults,tabStatistics});
        
        setRunStatus('idle');

        % Apply the intended execution defaults whenever a model is
        % selected. Without this explicit assignment, newly created
        % dropdowns retain their first items: MATLAB RK and Sequential.
        isUserModel = strcmpi(char(S.ui.ddModel.Value), ...
            'user_model');

        % Default for all models: compiled C++ implementation and the
        % efficient basin-parallel execution path.
        S.ui.ddMcode.Value = ...
            '4 Runge Kutta (C++)';
        S.ui.ddCalc.Value = 'parfeval';

        % Keep the synchronized configuration consistent immediately;
        % getConfigFromUI will read these same values later.
        S.cfg.mdl.mcode = 4;
        S.cfg.mdl.calc = 'parfeval';

        if isUserModel && ~isfile(fullfile(local_user_model_dir(S.cfg.root),'user_model_matlab.m'))
            S.ui.ddMcode.Enable = 'off';

            S.ui.ddMem.Value = '0 (no)';
            S.ui.ddMem.Enable = 'off';
        else
            S.ui.ddMcode.Enable = 'on';
            S.ui.ddMem.Enable = 'on';
        end

        refreshModelDiagram();
        refreshParamTable();
        refreshPreview();
        refreshReadiness();
        refreshSummary();
        refreshSiteStatistics(false);
        refreshMapDropdown();
        refreshRegion();
        refreshZones();
        updateLockState();
    end

    function onOptHelpRefresh(~,~)
        setGuiState('edited');
        enforceJKGENwinOdd();
        jkge_controls_ui(S.ui, ...
            @parseLeadingInt_local,@setVisibleSafe);
        updateLearningRateControlState();
        refreshLossHelpText();
        refreshOptHelpText();
        refreshPreview();
        refreshSummary();
        refreshReadiness();
    end

    function updateLearningRateControlState()
        try
            isAdam = parseLeadingInt_local(S.ui.ddOpt.Value) == 2;
        catch
            isAdam = true;
        end
        try
            isHold = strcmpi(char(S.ui.ddLRSchedule.Value), ...
                'hold_cosine');
        catch
            isHold = false;
        end
        try
            isConstant = strcmpi(char(S.ui.ddLRSchedule.Value), ...
                'constant');
        catch
            isConstant = true;
        end
        holdEnable = tern(isHold,'on','off');
        scheduleVisible = ~isConstant;
        try
            % All optimizers use the learning-rate schedule and Clipn.
            % Moment settings, epsilon, and weight decay are Adam-only.
            S.ui.ddLRSchedule.Enable = 'on';
            S.ui.edLRmin.Enable = 'on';
            S.ui.edLRhold.Enable = holdEnable;
            % Restore normal black text after returning from gradient
            % descent, where this AdamW-only control is unavailable.
            S.ui.lblBeta1.Enable = tern(isAdam,'on','off');
            S.ui.edBeta1.Enable = tern(isAdam,'on','off');
            S.ui.lblBeta2.Enable = tern(isAdam,'on','off');
            S.ui.edBeta2.Enable = tern(isAdam,'on','off');
            S.ui.lblVarEps.Enable = tern(isAdam,'on','off');
            S.ui.edVarEps.Enable = tern(isAdam,'on','off');
            S.ui.lblWdec.Enable = tern(isAdam,'on','off');
            S.ui.edWdec.Enable = tern(isAdam,'on','off');
            setVisibleSafe(S.ui.lblBeta1,isAdam);
            setVisibleSafe(S.ui.edBeta1,isAdam);
            setVisibleSafe(S.ui.lblBeta2,isAdam);
            setVisibleSafe(S.ui.edBeta2,isAdam);
            setVisibleSafe(S.ui.lblVarEps,isAdam);
            setVisibleSafe(S.ui.edVarEps,isAdam);
            setVisibleSafe(S.ui.lblWdec,isAdam);
            setVisibleSafe(S.ui.edWdec,isAdam);

            % Remove the four Adam-only rows for gradient descent and move
            % following controls up, leaving no empty rows in the grid.
            shift = 4*double(~isAdam);
            S.ui.lblClipn.Layout.Row = 8-shift;
            S.ui.spClipn.Layout.Row = 8-shift;
            S.ui.lblLRSchedule.Layout.Row = 9-shift;
            S.ui.ddLRSchedule.Layout.Row = 9-shift;
            S.ui.lblLRmin.Layout.Row = 10-shift;
            S.ui.edLRmin.Layout.Row = 10-shift;
            S.ui.lblLRhold.Layout.Row = 11-shift;
            S.ui.edLRhold.Layout.Row = 11-shift;
            S.ui.btnOptDefaults.Layout.Row = 8-shift;

            setVisibleSafe(S.ui.lblLRmin,scheduleVisible);
            setVisibleSafe(S.ui.edLRmin,scheduleVisible);
            setVisibleSafe(S.ui.lblLRhold,isHold);
            setVisibleSafe(S.ui.edLRhold,isHold);

            % Constant needs neither schedule-specific row; cosine needs
            % only minimum LR; hold + cosine needs both rows.
            nRows = 11-shift-double(~scheduleVisible)-double(~isHold);
            S.ui.gOptControls.RowHeight = ...
                [repmat({rowHValueTraining},1,nRows), ...
                repmat({0},1,11-nRows)];
            mainRows = S.ui.gOptMain.RowHeight;
            mainRows{1} = localTrainingTopHeight();
            S.ui.gOptMain.RowHeight = mainRows;
        catch
        end
    end

    function onJKGENwinChanged(src,~)
        setGuiState('edited');
        enforceJKGENwinOdd(src);
        jkge_controls_ui(S.ui, ...
            @parseLeadingInt_local,@setVisibleSafe);
        refreshLossHelpText();
        refreshOptHelpText();
        refreshPreview();
        refreshSummary();
        refreshReadiness();
    end

    function enforceJKGENwinOdd(src)
        if ~isfield(S.ui,'spJKGENwin') ...
                || isempty(S.ui.spJKGENwin)
            return;
        end
        try
            if nargin < 1 || isempty(src)
                src = S.ui.spJKGENwin;
            end
            v = round(double(src.Value));
            v = max(3,v);
            prev = 7;
            try
                if isfield(src,'UserData') ...
                        && ~isempty(src.UserData) ...
                        && isstruct(src.UserData) ...
                        && isfield(src.UserData,'lastValue')
                    prev = double(src.UserData.lastValue);
                end
            catch
            end
            if mod(v,2) == 0
                if v < prev
                    v = v - 1;
                else
                    v = v + 1;
                end
            end
            v = max(3,v);
            S.ui.spJKGENwin.Value = v;
            try
                src.UserData = struct('lastValue',v);
            catch
            end
        catch
        end
    end

    function onResolutionChanged(~,~)
        site_applyResolutionDefaults(S.ui,getCurrentResolutionConfig(), ...
            @applyRegionBasinDefaults,@updateDefaultBasinSplitFile);
        time_resolution_icon_ui(S.ui,double(S.ui.edDt.Value), ...
            S.cfg.SAGEhydro);
        refreshDerivedPaths();

        % Rebuild parameter metadata immediately because bounds and units
        % depend on the number of model time steps per day.
        try
            refreshParamTable();
        catch ME
            logmsg(['Parameter-table refresh failed after ' ...
                'resolution change: ' ME.message]);
        end

        % Rebuild Meteo/PET notes because units depend on resolution
        try
            refreshMeteoPETInfo();
        catch ME
            logmsg(['Meteo/PET note refresh ' ...
                'failed after resolution change: ' ...
                ME.message]);
        end

        updateReferenceBlock_standalone(S.ui,fontsizeNotes);
        markDependencyChange('resolution changed', ...
            ['Data resolution changed; ' ...
            'basin availability, ' ...
            'forcing folders, and split ' ...
            'files may differ. Click ' ...
            'Load basins again.'],true,false);
        syncPostScenariosFromPeriod();
        updateDefaultBasinSplitFile();
        refreshAll();
        refreshMeteoPETInfo();
    end

    function onSampleModeChanged(~,~,restoring)
        if nargin < 3, restoring = false; end

        % SITE exposes a single, zone-aware basin-loading workflow. Keep the
        % inherited SAGE sampling control internally for compatibility, but
        % always use zone sampling and expose only Min/Zone and Max Zones.
        try S.ui.ddSample.Value = 'zone'; catch, end
        try
            S.ui.lblBasinFile.Visible = 'off';
            S.ui.edBasinFile.Visible = 'off';
            S.ui.btnPickBasinFile.Visible = 'off';
        catch
        end
        try
            S.ui.lblBasinSeed.Visible = 'off';
            S.ui.spBasinSeed.Visible = 'off';
            S.ui.lblBasinGenerator.Visible = 'off';
            S.ui.txtBasinGenerator.Visible = 'off';
        catch
        end
        try
            S.ui.lblMinZone.Visible = 'on';
            S.ui.spMinPerZone.Visible = 'on';
            S.ui.lblMaxZones.Visible = 'on';
            S.ui.spMaxZones.Visible = 'on';
            S.ui.spMinPerZone.Enable = tern(~S.runtime.isRunning,'on','off');
            S.ui.spMaxZones.Enable = tern(~S.runtime.isRunning,'on','off');
        catch
        end
        try
            S.ui.btnNewRandomSplit.Text = 'Load basins';
            S.ui.btnNewRandomSplit.Visible = 'on';
            S.ui.btnNewRandomSplit.Enable = tern(~S.runtime.isRunning,'on','off');
        catch
        end
        try
            S.ui.lblZoneSummary.Visible = 'on';
        catch
        end
        try
            site_configure_basin_layout(S.ui,tabBasins);
        catch
        end

        if ~S.runtime.initializingUI && ~restoring
            S.runtime.filePreparedLocked = false;
            S.runtime.prepared = false;
            S.runtime.preparedBasins = [];
            S.runtime.preparedLatLon = [];
            S.runtime.lastOut = [];
            S.runtime.lastStatus = 'Basin settings changed';
        end

        syncPostScenariosFromPeriod();
        updateDefaultBasinSplitFile();

        if ~restoring && isfield(S,'runtime') ...
                && isfield(S.runtime,'uiReady') ...
                && S.runtime.uiReady
            refreshAll();
        end
    end

    function onBprtChanged(~,~)
        try
            S.ui.spBprtTrain.Value = round(S.ui.spBprtTrain.Value);
            try
                S.ui.spBprtEval.Limits = [0 200];
            catch
            end
            S.ui.spBprtEval.Value = 0;
            isRandom = false;
            try
                isRandom = isfield(S.runtime, ...
                    'postSelectionIsRandom') ...
                    && logical(S.runtime.postSelectionIsRandom);
            catch
            end
            if isRandom
                postprocess_basin_selection_ui('random',S.ui, ...
                    @local_adjust_selection_mask_random, ...
                    @local_available_table_rows);
            else
                postprocess_basin_selection_ui('stable',S.ui, ...
                    @local_adjust_selection_mask, ...
                    @local_available_table_rows,@local_column_selection);
            end
            onPostprocessRefresh();
        catch ME
            logErrorStack('Bprt update error:',ME);
        end
    end

    function onPickBasinFile(~,~)

        regionsDir = fullfile(char(S.ui.edSAGE.Value),'regions');
        startDir = regionsDir;

        % Open in the selected dataset's basin-file directory. An
        % existing external split keeps its own directory.
        try
            regionCode = region_helpers('code',S.ui.ddRegion.Value);
            datasetDir = char(region_helpers('regiondir', ...
                char(S.ui.edSAGE.Value),regionCode));
            if isfolder(datasetDir)
                startDir = datasetDir;
            end
            selectedFile = strtrim(char(S.ui.edBasinFile.Value));
            if isfile(selectedFile)
                [selectedDir,~,~] = fileparts(selectedFile);
                if isfolder(selectedDir)
                    startDir = selectedDir;
                end
            end
        catch
        end
        if ~isfolder(startDir)
            startDir = char(S.ui.edRoot.Value);
        end

        [fn,pn] = uigetfile( ...
            {'*.txt;*.csv;*.*','Basin split files'}, ...
            'Select basin split file', ...
            startDir);

        if isequal(fn,0) ...
                || isequal(pn,0)
            return
        end

        S.ui.edBasinFile.Value = fullfile(pn,fn);
        S.ui.ddSample.Value = 'file';

        onSimpleRefresh();   % clears old prepared state

        try
            onPrepareBasins();   % prepares basins from selected file

            % lock the prepared state for file mode
            S.runtime.filePreparedLocked = true;
            S.runtime.prepared = true;
            S.runtime.lastStatus = 'Basins loaded from file';

            refreshAll();

        catch ME
            S.runtime.filePreparedLocked = false;
            S.runtime.prepared = false;
            S.runtime.preparedBasins = [];
            S.runtime.preparedLatLon = [];
            S.runtime.lastError = ME.message;
            S.runtime.lastStatus = ['File ' ...
                'prepare error'];
            logErrorStack(['ERROR during ' ...
                'basin preparation:'],ME);
            refreshAll();
        end
    end

    function onPrepareBasins(~,~)
        refreshDataStatus();
        if ~S.runtime.dataReady
            uialert(f, ...
                ['The selected dataset and resolution need installed ' ...
                'data and attribute files before basins can be loaded. ' ...
                'Check the Region tab for details.'], ...
                'Dataset not installed');
            S.ui.tgLeft.SelectedTab = S.ui.tabRegion;
            return
        end
        [datesOK,dateMessage] = local_required_period_dates(S.ui);
        if ~datesOK
            uialert(f,dateMessage,'Period dates required');
            try
                S.ui.tgLeft.SelectedTab = tabPeriod;
            catch
            end
            return
        end

        S.runtime.filePreparedLocked = false;

        % Disable Run and Export immediately.  They are enabled again only
        % after the complete attribute-read and basin-preparation path has
        % succeeded.
        S.runtime.prepared = false;
        S.runtime.preparedBasins = [];
        S.runtime.preparedLatLon = [];
        S.runtime.lastOut = [];
        updateLockState();

        % Basin preparation starts a new data selection. Quality flags
        % from an earlier run or region are invalid until the selected
        % basins' meteorological and discharge data have been summarized.
        S.runtime.quality = [];
        S.runtime.qualityRow = 1;
        try
            data_quality_dashboard_ui('reset',S.ui);
        catch
        end

        try
            % A previous quality screen may display only retained basins.
            % Resolve the full regional list again before reloading it.
            applyRegionBasinDefaults();
            cfg = getConfigFromUI();

            % ======================================
            % FORCE GUI → BAS CONFIG SYNCHRONIZATION
            % ======================================
            if ~isfield(cfg,'bas') ...
                    || isempty(cfg.bas)
                cfg.bas = struct();
            end
            mode = "zone";
            if mode == "zone"
                cfg.bas.min_per_zone = S.ui.spMinPerZone.Value;
                cfg.bas.max_zones = S.ui.spMaxZones.Value;
                cfg.bas.seed = [];
                cfg.bas.rng_type = '';
            elseif mode == "random"
                cfg.bas.min_per_zone = [];
                cfg.bas.max_zones = [];
                cfg.bas.seed = round(double(S.ui.spBasinSeed.Value));
                cfg.bas.rng_type = 'twister';
            else
                cfg.bas.min_per_zone = [];
                cfg.bas.max_zones = [];
                cfg.bas.seed = [];
                cfg.bas.rng_type = '';
            end

            % ======================================
            % FORCE ATTRIBUTE ID FROM GUI SELECTION
            % ======================================
            if ~isfield(S.runtime,'attrReady') ...
                    || ~S.runtime.attrReady
                if isfield(S.runtime,'attrError') ...
                        && ~isempty(S.runtime.attrError)
                    logmsg(['Cannot load basins: attribute catalog ' ...
                        'failed to load. ' S.runtime.attrError]);
                else
                    logmsg(['Cannot load basins yet: ' ...
                        'attributes are still loading.']);
                end
                return
            end
            if ~isfield(cfg.bas,'id_attr') ...
                    || isempty(cfg.bas.id_attr)
                error(['No attribute IDs found ' ...
                    'in cfg.bas.id_attr.']);
            end
            
            % Reassert resolution metadata immediately before any regional
            % attribute reader is called.
            try
                Xactive = getCurrentResolutionConfig();
                cfg.bas.dt = double(Xactive.dt);
                cfg.bas.resolution = char(S.ui.ddRes.Value);
                switch lower(strtrim(cfg.bas.resolution))
                    case 'hourly'
                        cfg.bas.stream = 'hourly';
                    case {'15 minutes','15-minute','15min'}
                        cfg.bas.stream = '15min';
                    otherwise
                        cfg.bas.stream = 'daily';
                end
                if isfield(Xactive,'basins') ...
                        && isfield(Xactive.basins,'file') ...
                        && ~isempty(Xactive.basins.file)
                    cfg.file_univ = char(string(Xactive.basins.file));
                    cfg.bas.file_univ = cfg.file_univ;
                end
            catch
            end

            ensureSAGEpath(cfg.root);

            % Every sampling mode needs the basin-universe file. In a
            % deployed application, first materialize its packaged copy
            % in the writable regional directory. Previously this happened
            % only inside the random-sampling branch, which made random
            % sampling an accidental prerequisite for zone and file modes.
            cfg.file_univ = local_materialize_basin_universe(cfg);
            cfg.bas.file_univ = cfg.file_univ;
            listCount = site_basin_list_count(cfg.file_univ);
            if listCount < 1
                error('SITE_ui:EmptyBasinList', ...
                    'The selected basin list contains no gauge IDs.');
            end
            cfg.bas.K = listCount;
            cfg.bas.K_t = listCount;
            cfg.bas.K_e = 0;
            siteSetBasinCount(listCount);

            % Random sampling is materialized as a reproducible split file
            % before sample_basins is called. The file is written to the
            % user's writable SAGEhydrology/regions/<region> directory.
            if mode == "random"
                [cfg.file_univ,cfg.file_split,splitFull] = ...
                    local_generate_random_basin_split(cfg);
                S.ui.edBasinFile.Value = cfg.file_split;
                S.cfg.file_univ = cfg.file_univ;
                S.cfg.file_split = cfg.file_split;
                S.cfg.bas.seed = cfg.bas.seed;
                S.cfg.bas.rng_type = cfg.bas.rng_type;
                logmsg(sprintf(['Generated random basin split: ' ...
                    'seed = %d, generator = twister, file = %s'], ...
                    cfg.bas.seed,splitFull));
            end

            logmsg('Loading basin selection ...');

            % =========================
            % HARD RESET BASIN STATE
            % =========================
            S.runtime.prepared = false;
            S.runtime.preparedBasins = [];
            S.runtime.preparedLatLon = [];
            S.runtime.lastOut = [];
            S.runtime.lastStatus = '';

            [A_reg,ID,gname,zone] = read_attr(cfg.region, ...
                cfg.dirD,cfg.bas);

            % Resolve basin files to absolute paths before calling
            % sample_basins. This avoids dependence on sample_basins'
            % internal folder guesses, which still reflect the previous
            % SAGEhydrology/SAGE/src layout.
            if isfield(cfg,'file_univ') ...
                    && ~isempty(cfg.file_univ)
                cfg.file_univ = local_basin_absolute_file( ...
                    cfg,cfg.file_univ);
            end

            if mode == "file" ...
                    && isfield(cfg,'file_split') ...
                    && ~isempty(cfg.file_split)
                cfg.file_split = local_basin_absolute_file( ...
                    cfg,cfg.file_split);
            elseif mode ~= "random"
                cfg.file_split = '';
            end
            if isfield(cfg,'bas') ...
                    && isfield(cfg.bas,'file_univ') ...
                    && ~isempty(cfg.bas.file_univ)
                cfg.bas.file_univ = cfg.file_univ;
            end
            if isfield(cfg,'bas') ...
                    && isfield(cfg.bas,'file_split') ...
                    && ~isempty(cfg.bas.file_split)
                cfg.bas.file_split = cfg.file_split;
            end
            cfg.bas.sort_by_gauge = true;
            % Call: bas, prd, gname, dirD, universe file, split file
            [~,basins_sel,latlon] = ...
                sample_basins(A_reg,ID, ...
                cfg.bas,cfg.prd,gname,zone,cfg.dirD, ...
                cfg.file_univ,cfg.file_split);
            % only the selected basins
            updateZoneSummary(basins_sel.zone);
            drawnow;
            S.ui.pnlZoneSummary.Visible = 'on';

            S.runtime.prepared = true;
            S.runtime.preparedBasins = basins_sel;
            S.runtime.preparedLatLon = latlon;
            S.runtime.lastStatus = 'Basins loaded';
            siteSetBasinCount(basins_sel.K);

            populatePlotTablesFromBasins(basins_sel);
            populatePostTablesFromBasins(basins_sel);
            % Basins and Diagnostics are two views of this same prepared
            % split. Realize the period-compatible scenarios immediately;
            % do not wait for a later Diagnostics tab-selection event.
            syncPostScenariosFromPeriod();
            refreshZones();

            logmsg(sprintf('Loaded basins: %d.',basins_sel.K));

            refreshAll();
            S.runtime.prepared = true;
            % Reassert table visibility after the global refresh. This
            % guarantees an evaluation-basin block whenever K_e > 0 and
            % the selected temporal method exposes an evaluation period.
            syncPostScenariosFromPeriod();
            drawnow limitrate nocallbacks

            refreshReadiness();

            try
                % Force CONUS tab to show the plain train/eval basin map,
                % not a previous parameter map from an earlier run.
                S.ui.tgRight.SelectedTab = S.ui.tabRegionMap;
                drawnow limitrate nocallbacks
                refreshRegion();
            catch MEconus
                logmsg(['Could not switch to ' ...
                    'CAMELS map: ' MEconus.message]);
            end

        catch ME
            S.runtime.prepared = false;
            S.runtime.preparedBasins = [];
            S.runtime.preparedLatLon = [];
            S.runtime.lastOut = [];
            S.runtime.lastError = ME.message;
            S.runtime.lastStatus = 'Load basins error';
            logErrorStack(['ERROR during basin ' ...
                'preparation:'],ME);
            refreshAll();
        end
    end

    function onCompile(~,~)

        cfg = getConfigFromUI();
        isUserModel = strcmpi(S.ui.ddModel.Value,'user_model');
    
        % ---------------------------------------------------------
        % Deployed app: cannot compile; only verify precompiled MEX
        % ---------------------------------------------------------
        if isdeployed
    
            if isUserModel
                udir = local_user_model_dir(cfg.root);
                if ~isdeployed
                    addpath(udir);
                end
   
                mexFile = fullfile(udir,['crr_user_model.' mexext]);
                mexOK = isfile(mexFile);
    
                if mexOK
                    msg = ['Existing precompiled crr_user_model.' ...
                        mexext ' file was found and will be used.'];
                else
                    msg = ['Required precompiled crr_user_model.' ...
                        mexext ' file was not found.'];
                end
            else
                [mexOK,msg] = local_check_mex_available(cfg);
            end
    
            if mexOK
                uialert(f, ...
                    ['This deployed version cannot ' ...
                    'recompile the model. ' ...
                    msg ' Run SITE is now enabled.'], ...
                    'Using existing MEX files');
    
                S.runtime.compileOK = true;
                S.runtime.compileMessage = msg;
                setGuiState('compiled');
            else
                uialert(f, ...
                    ['This deployed version cannot ' ...
                    'recompile the model, and the required ' ...
                    'precompiled MEX file was not found. ' ...
                    msg ' Run SITE will remain disabled.'], ...
                    'Missing MEX files');
    
                S.runtime.compileOK = false;
                S.runtime.compileMessage = msg;
                S.ui.btnRun.Enable = 'off';
            end
    
            refreshAll();
            return
        end
    
        % -----------------------------------
        % MATLAB mode: compile selected model
        % -----------------------------------
        try
            ensureSAGEpath(cfg.root);
            logmsg('Compiling selected model ...');
    
            if isUserModel
                udir = local_user_model_dir(cfg.root);
                if ~isdeployed
                    addpath(udir);
                end
    
                mexFile = fullfile(udir,['crr_user_model.' mexext]);
                sourceFiles = { ...
                    'crr_user_model_mex.cpp', ...
                    'user_model_prepare.cpp', ...
                    'user_model_prepare.hpp', ...
                    'user_model.cpp', ...
                    'user_model.hpp', ...
                    'delta_n.hpp', ...
                    'log_fail_params.hpp'};
                sourceFiles = fullfile(udir,sourceFiles);
                sourceFiles = sourceFiles(cellfun( ...
                    @isfile,sourceFiles));

                mexIsCurrent = isfile(mexFile);
                if mexIsCurrent ...
                        && ~isempty(sourceFiles)
                    mexTime = dir(mexFile).datenum;
                    sourceTime = cellfun( ...
                        @(file)dir(file).datenum,sourceFiles);
                    mexIsCurrent = mexTime >= max(sourceTime);
                end
    
                if mexIsCurrent
                    txt = ['Existing crr_user_model.' mexext ...
                        ' found; skipping compilation.'];
                else
                    oldDir = pwd;
                    cleanup = onCleanup(@() cd(oldDir));
                    cd(udir);
                    txt = evalc('user_model_compile(1);');
                end
            else
                txt = evalc('compile_model(cfg.mdl);');
            end
    
            if ~isempty(strtrim(txt))
                for line = string(splitlines(string(txt))).'
                    if strlength(strtrim(line)) > 0
                        logmsg(char(line));
                    end
                end
            end
    
            S.runtime.compileOK = true;
            S.runtime.compileMessage = ...
                'Compilation finished successfully.';
            setGuiState('compiled');
    
            try
                if S.runtime.prepared ...
                        && ~isempty(S.runtime.preparedBasins)
                    logmsg(['Compilation does not ' ...
                        'invalidate the prepared ' ...
                        'basin split. ' ...
                        'You only need to press ' ...
                        'Load basins again when you want ' ...
                        'to change the basin assignment.']);
                end
            catch
            end
    
        catch ME
            S.runtime.compileOK = false;
            S.runtime.compileMessage = ...
                ['Compile failed: ' ME.message];
            S.runtime.lastError = ME.message;
            S.runtime.lastStatus = 'Compile error';
            logErrorStack('Compile error:',ME);
        end
    
        refreshAll();
    end

    function resetRunOutputState()
        S.store.logAll = strings(0,1);
        S.store.iterAll = strings(0,1);
        % Clear the visible text independently of other diagnostic tabs.
        % A stale or unavailable plot must not leave the previous run's
        % iteration output on screen until the first new basin finishes.
        try
            refreshLogView();
        catch
        end
        try
            refreshIterView();
        catch
        end
        drawnow nocallbacks
        S.runtime.lastError = '';
        S.runtime.lastOut = [];
        S.runtime.siteResultStore = [];
        S.runtime.siteResultBas = [];
        S.runtime.siteResultUpdated = false(0,0);
        S.runtime.siteBasinRuntime = [];
        S.runtime.siteGuiRuntime = [];
        S.runtime.siteBasinsFinished = 0;
        S.runtime.siteLiveRefreshClocks = struct();
        S.runtime.siteTiming = struct('data',NaN, ...
            'init',NaN,'train',NaN,'gui',NaN);
        S.runtime.informationSnapshot = [];
        S.runtime.informationCache = struct();
        S.runtime.informationTime = zeros(1,0);
        S.runtime.quality = [];
        S.runtime.qualityRow = 1;
        try
            data_quality_dashboard_ui('basins',S.ui,[]);
            data_quality_dashboard_ui('refresh',S.ui,[],1);
        catch
        end
        S.runtime.stopRequestTime = [];
        S.runtime.userSelectedRightTabDuringRun = false;

        try
            if isappdata(0,'SAGE_zone_summary_table')
                rmappdata(0,'SAGE_zone_summary_table');
            end
        catch
        end
        S.runtime.summaryAutoShown = false;
        S.runtime.attr = struct('At',[], ...
            'An',[],'iter',[], ...
            'names',strings(0,1),'last_i',0);
        try
            S.ui.txtLastError.Value = {};
            S.ui.tblZoneSummary.Data = cell(0,12);
            resizeZoneTable();
            S.ui.lblZoneTableStatus.Text = ...
                ['Zone summary is populated ' ...
                'after postprocessing.'];
            S.ui.tblQuality.Data = cell(0,18);
            S.ui.lblQualityStatus.Text = ...
                'Available after meteo and discharge are read.';
            cla(S.ui.axQualityBasin);
            cla(S.ui.axQualityRegion);
            cla(S.ui.axQualityHydrology);
        catch
        end
        try
            refreshRuntimeSummaryPlot();
        catch
        end
    end

    function onRetrySavedBenchmark(~,~)
        if S.runtime.isRunning
            uialert(f,'Wait until the current run finishes before retrying saved results.', ...
                'Run in progress');
            return
        end
        [name,folder]=uigetfile('*_submission.mat','Select saved SITE contribution');
        if isequal(name,0),return,end
        pendingFile=fullfile(folder,name);
        safeGuiCall('Shared benchmark retry', ...
            @()site_benchmark_github_ui(f,pendingFile,@logmsg));
    end

    function onRun(~,~)
        [datesOK,dateMessage] = local_required_period_dates(S.ui);
        if ~datesOK
            uialert(f,dateMessage,'Period dates required');
            try S.ui.tgLeft.SelectedTab=tabPeriod; catch, end
            return
        end
        if ~S.runtime.prepared || isempty(S.runtime.preparedBasins)
            uialert(f,'Please load the training basins first.', ...
                'Run blocked');
            return
        end

        resetRunOutputState();
        S.runtime.isRunning=true;
        S.runtime.stopRequested=false;
        S.runtime.elapsedClock=tic;
        S.runtime.elapsedFinal=NaN;
        S.runtime.startTime=datetime('now');
        S.runtime.endTime=[];
        S.runtime.lastError='';
        setGuiState('running','Starting SITE ...');
        updateLockState();
        try S.ui.tgRight.SelectedTab=S.ui.tabLog; catch, end
        logmsg(['=== New SITE run started: ' ...
            char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ===']);
        localRendererYield(true);

        try
            cfg=getConfigFromUI();
            jkgeDefault = cfg.misc.loss.M == 2 ...
                && cfg.misc.loss.method == 1 ...
                && cfg.misc.loss.n_win == 31;
            if ~jkgeDefault
                uialert(f,[ ...
                    'Non-default JKGE settings are active. The run may ' ...
                    'continue, but its JKGE score and JKGE completed-run ' ...
                    'count will not update the version 1 result files. ' ...
                    'Those files currently retain only the default ' ...
                    'JKGE definition: M = 2, moving-average mean, and ' ...
                    'a 31-day window. A future release will support ' ...
                    'separate JKGE configurations.'], ...
                    'JKGE results use default settings only', ...
                    'Icon','warning');
            end
            mapLossSheets = {'SAR','RSS','NSE','KGE', ...
                'Huber','FDC','JKGE'};
            selectedLoss = double(cfg.misc.loss.fnc);
            if isfinite(selectedLoss) && selectedLoss >= 1 ...
                    && selectedLoss <= numel(mapLossSheets)
                S.ui.ddSiteMapLoss.Value = mapLossSheets{selectedLoss};
            end
            cfg.bas=S.runtime.preparedBasins;
            S.runtime.lastConfig=cfg;
            C=siteUi('buildRunConfig',cfg);
            C.ui.sharedBenchmarkFcn=@(store,inputs) ...
                site_benchmark_seed_ui(f,store,C,@logmsg,inputs);
            % Reload independently edited runner/result helpers between GUI
            % runs. Long-lived SITE_ui sessions can otherwise retain an old
            % function body after an on-disk hotfix.
            clear run_SITE site_result_store calibrate_basin_SITE
            rehash path
            siteOut=run_SITE(C);
            S.runtime.lastOut=rmfield(siteOut,'referenceInputs');
            % GUI-only end-of-run contribution, including graceful Stop.
            % run_SITE has drained active basin jobs and saved checkpoints.
            % Synchronization failures must not turn a completed run into
            % a training error or change the locally saved results.
            safeGuiCall('Shared benchmark preparation', ...
                @()site_benchmark_finish_ui(f,siteOut,C,@logmsg));
            S.runtime.elapsedFinal=toc(S.runtime.elapsedClock);
            S.runtime.endTime=datetime('now');
            setGuiState('finished','Finished');
            logmsg(['=== SITE run finished: ' ...
                char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')) ' ===']);
            try assignin('base','SITE_lastConfig',C); catch, end
            siteOut=rmfield(siteOut,'referenceInputs');
            try assignin('base','SITE_lastOut',siteOut); catch, end
        catch ME
            S.runtime.elapsedFinal=toc(S.runtime.elapsedClock);
            S.runtime.endTime=datetime('now');
            if strcmp(ME.identifier,'SITE:RunCancelled')
                setGuiState('stopped','Run cancelled');
                S.runtime.lastError='';
                logmsg(ME.message);
            else
                setGuiState('error','Run error');
                S.runtime.lastError=getReport(ME,'extended','hyperlinks','off');
                logErrorStack('ERROR during SITE run:',ME);
            end
        end
        S.runtime.isRunning=false;
        S.runtime.stopRequested=false;
        applyGuiStateControls();
        siteUi('configureVisibleTabs');
        safeGuiCall('Post-run readiness refresh',@refreshReadiness);
        safeGuiCall('Post-run Summary refresh',@refreshSummary);
        if isequal(S.ui.tgRight.SelectedTab,S.ui.tabBasinResults)
            safeGuiCall('Post-run basin results refresh', ...
                @()siteUi('refreshbasinresultstable'));
        elseif isequal(S.ui.tgRight.SelectedTab,S.ui.tabStatistics)
            safeGuiCall('Post-run statistics refresh', ...
                @()refreshSiteStatistics(true));
        elseif isequal(S.ui.tgRight.SelectedTab,S.ui.tabParamMap)
            safeGuiCall('Post-run parameter map refresh',@refreshParamMap);
        end
        safeGuiCall('Post-run lock-state refresh',@updateLockState);
        try
            if strcmpi(S.runtime.lastStatus,'Run error')
                S.ui.tgRight.SelectedTab=S.ui.tabLog;
            else
                S.ui.tgRight.SelectedTab=S.ui.tabSummary;
            end
        catch
        end
        localRendererYield(true);
    end

    function proceed = confirmModelResultReplacement(details)
        choice = uiconfirm(f,[details.message newline newline ...
            'Choose Abort run if you want to preserve the old results.'], ...
            'Replace existing model results?', ...
            'Options',{'Replace results','Abort run'}, ...
            'DefaultOption',2,'CancelOption',2,'Icon','warning');
        proceed = strcmp(choice,'Replace results');
    end

    function setGuiState(state,progressText)
        % Centralized run-state controller. This is the only helper that
        % should coordinate the Configuration status, progress text,
        % status color, and Run/Stop button state.
        if nargin < 2
            progressText = '';
        end
        key = lower(strtrim(char(string(state))));
        switch key
            case 'idle'
                statusText = 'Idle';
            case 'edited'
                statusText = 'Configuration modified';
            case 'prepared'
                statusText = 'Basins loaded';
            case 'compiled'
                statusText = 'Compiled';
            case 'running'
                statusText = 'Running';
            case 'stopping'
                statusText = 'Stopping';
            case 'postprocessing'
                statusText = 'Postprocessing';
            case 'finished'
                statusText = 'Finished';
            case 'stopped'
                statusText = 'Stopped';
            case 'error'
                statusText = 'Run error';
            case 'missing_mex'
                statusText = 'Missing MEX';
            otherwise
                statusText = char(string(state));
        end
        S.runtime.lastStatus = statusText;
        if ~isempty(progressText)
            S.runtime.lastProgressText = char(string(progressText));
        end
        applyGuiStateControls();
        setRunStatus(statusText);
        if ~isempty(progressText)
            setProgressStatus(progressText);
        end
    end

    function applyGuiStateControls()
        statusText = char(string(S.runtime.lastStatus));
        key = lower(strtrim(statusText));
        color = [0.25 0.25 0.25];
        if contains(key,'run error') ...
                || contains(key,'missing mex') ...
                || contains(key,'error')
            color = [0.75 0.10 0.10];
        elseif contains(key,'stopping')
            color = [0.85 0.45 0.05];
        elseif contains(key,'postprocessing')
            color = [0.45 0.20 0.65];
        elseif contains(key,'running')
            color = [0.05 0.35 0.75];
        elseif contains(key,'finished') ...
                || contains(key,'stopped') ...
                || contains(key,'prepared') ...
                || contains(key,'compiled')
            color = [0.10 0.50 0.20];
        end
        try
            S.ui.lblRunStatus.FontColor = color;
            S.ui.lblRunStatus.Tooltip = statusText;
        catch
        end
        try
            if S.runtime.isRunning
                S.ui.btnRun.Enable = 'off';
                if S.runtime.stopRequested
                    S.ui.btnStop.Enable = 'off';
                    S.ui.btnStop.Text = 'Stopping ...';
                else
                    S.ui.btnStop.Enable = 'on';
                    S.ui.btnStop.Text = 'Stop SITE';
                end
            else
                S.ui.btnStop.Enable = 'off';
                S.ui.btnStop.Text = 'Stop SITE';
            end
        catch
        end
    end

    function setRunStatus(txt)
        txt = lower(char(string(txt)));
        key = lower(strtrim(txt));
        color = [0.25 0.25 0.25];
        if contains(key,'error') ...
                || contains(key,'missing mex')
            color = [0.75 0.10 0.10];
        elseif contains(key,'stopping')
            color = [0.85 0.45 0.05];
        elseif contains(key,'postprocessing')
            color = [0.45 0.20 0.65];
        elseif contains(key,'running')
            color = [0.05 0.35 0.75];
        elseif contains(key,'finished') ...
                || contains(key,'stopped') ...
                || contains(key,'prepared') ...
                || contains(key,'compiled')
            color = [0.10 0.50 0.20];
        end
        tip = txt;
        try
            if contains(key,'stopping') ...
                    && ~isempty(S.runtime.stopRequestTime)
                tip = sprintf('%s; requested at %s',txt, ...
                    char(S.runtime.stopRequestTime,'HH:mm:ss'));
            end
        catch
        end
        try
            S.ui.lblRunStatus.Text = txt;
            S.ui.lblRunStatus.FontSize = fontsizeGUI;
            S.ui.lblRunStatus.FontWeight = 'bold';
            S.ui.lblRunStatus.HorizontalAlignment = 'right';
            S.ui.lblRunStatus.FontColor = color;
            S.ui.lblRunStatus.Tooltip = tip;
        catch
        end
    end

    function setProgressStatus(txt)
        % Live iteration/basin progress shown in the Output & Monitoring
        % header, with compact elapsed runtime when a run has started.
        txt = char(string(txt));
        refreshSiteTimingNumbers();
        elapsed = localElapsedClockText();
        if ~isempty(elapsed)
            txt = sprintf('%s | elapsed %s',txt,elapsed);
        end
        try
            S.ui.lblProgressStatus.Text = txt;
            S.ui.lblProgressStatus.Tooltip = txt;
        catch
        end
    end

    function value = localElapsedSeconds()
        value = NaN;
        if isempty(S.runtime.startTime), return; end
        if isfield(S.runtime,'elapsedFinal') && isfinite(S.runtime.elapsedFinal)
            value = S.runtime.elapsedFinal;
        elseif S.runtime.isRunning && isfield(S.runtime,'elapsedClock') ...
                && ~isempty(S.runtime.elapsedClock)
            % A monotonic clock agrees with the pipeline's tic/toc timers.
            value = toc(S.runtime.elapsedClock);
        elseif ~isempty(S.runtime.endTime)
            value = seconds(S.runtime.endTime-S.runtime.startTime);
        else
            value = seconds(datetime('now')-S.runtime.startTime);
        end
        value = max(0,value);
    end

    function refreshSiteTimingNumbers()
        % Keep cheap timing labels current even while another tab is open.
        if isfield(S.runtime,'siteTiming')
            fields = {'init','train','gui'};
            controls = {'txtSumInit','txtSumTrain','txtSumCpuGUI'};
            for jj = 1:numel(fields)
                if isfield(S.runtime.siteTiming,fields{jj})
                    value = S.runtime.siteTiming.(fields{jj});
                    if isscalar(value) && isfinite(value)
                        S.ui.(controls{jj}).Text = sprintf('%.1f s',value);
                    end
                end
            end
        end
        elapsed = localElapsedSeconds();
        if isfinite(elapsed)
            S.ui.txtSumCpuTotal.Text = sprintf('%.1f s',elapsed);
        end
    end

    function txt = localElapsedClockText()
        txt = '';
        try
            if isempty(S.runtime.startTime)
                return
            end
            sec = max(0,floor(localElapsedSeconds()));
            hh = floor(sec/3600);
            mm = floor(mod(sec,3600)/60);
            ss = mod(sec,60);
            txt = sprintf('%02d:%02d:%02d',hh,mm,ss);
        catch
            txt = '';
        end
    end

    function sageGuiYield(iter,k,K)
        % parfor and parfeval can both return progress in bursts. Limit
        % renderer traffic by time rather than by completed-basin count.
        doUpdate = (k == 1) ...
            || (k == K);

        try
            if toc(S.runtime.lastYieldClock) >= ...
                    S.runtime.yieldPeriod
                doUpdate = true;
            end
        catch
            doUpdate = false;
        end

        if ~doUpdate
            return
        end
        try
            S.runtime.lastYieldClock = tic;
            [lrNow,lrDecreasing] = localDisplayedLearningRate(iter);
            lrText = sprintf('learn rate %.2e',lrNow);
            if lrDecreasing
                lrText = [lrText ' ' char(8595)];
            end
            S.runtime.lastProgressText = sprintf( ...
                'iter %d | basin %d/%d | %s',iter,k,K,lrText);
            % Change only the dedicated Output & Monitoring progress label.
            setProgressStatus(S.runtime.lastProgressText);
            localRendererYield(false);
        catch
        end
    end

    function [lr,isDecreasing] = localDisplayedLearningRate(iter)
        % Mirror descent.m so the header reports the rate used by the
        % current network proposal. Scientific notation keeps its width
        % stable as the rate crosses decimal orders of magnitude.
        lr0 = double(S.ui.edLR.Value);
        lrMin = double(S.ui.edLRmin.Value);
        schedule = lower(char(S.ui.ddLRSchedule.Value));
        maxUpdates = max(double(S.ui.spImax.Value)-1,1);
        t = max(double(iter)-1,1);
        progress = (t-1)/max(maxUpdates-1,1);
        progress = min(max(progress,0),1);
        hasDecayRange = lr0 > lrMin;
        isDecreasing = false;

        switch schedule
            case 'cosine'
                lr = lrMin + 0.5*(lr0-lrMin)*(1+cos(pi*progress));
                isDecreasing = hasDecayRange ...
                    && progress > 0 ...
                    && progress < 1;
            case 'hold_cosine'
                hold = double(S.ui.edLRhold.Value);
                if progress <= hold
                    lr = lr0;
                else
                    q = (progress-hold)/max(1-hold,eps);
                    q = min(max(q,0),1);
                    lr = lrMin + 0.5*(lr0-lrMin)*(1+cos(pi*q));
                    isDecreasing = hasDecayRange ...
                        && q > 0 ...
                        && q < 1;
                end
            otherwise
                lr = lr0;
        end
    end

    function onStop(~,~)
        if ~S.runtime.isRunning || S.runtime.stopRequested, return, end
        S.runtime.stopRequested=true;
        S.runtime.stopRequestTime=datetime('now');
        setGuiState('stopping','Stopping after active SITE basin jobs ...');
        logmsg('     SITE stop requested: no new basin calibrations will be submitted.');
        localRendererYield(true);
    end

    function tf = shouldStop()
        tf = S.runtime.stopRequested;
    end

    function tf = shouldPostprocessStoppedRun()
        tf = true;
        if S.runtime.stopRequested ...
                && isfield(S.runtime,'postprocessAfterStop')
            tf = logical(S.runtime.postprocessAfterStop);
        end
    end

    function onSaveSession(~,~)
        try
            session = localBuildSession();
            [fn,pn] = uiputfile({'*.mat', ...
                'MAT-file (*.mat)'},'Save GUI session', ...
                fullfile(getConfigFromUI().dirres, ...
                'SITE_ui_session.mat'));
            if isequal(fn,0) ...
                    || isequal(pn,0)
                return
            end
            save(fullfile(pn,fn), ...
                'session','-v7.3');
            logmsg(['Saved GUI session to: ' ...
                fullfile(pn,fn)]);
        catch ME
            logErrorStack('Save session error:',ME);
        end
    end

    function onLoadSession(~,~)
        try
            [fn,pn] = uigetfile({'*.mat', ...
                'MAT-file (*.mat)'}, ...
                'Load GUI session', ...
                getConfigFromUI().dirres);
            if isequal(fn,0) ...
                    || isequal(pn,0)
                return
            end
            X = load(fullfile(pn,fn),'session');
            if ~isfield(X,'session')
                error(['Selected MAT-file does ' ...
                    'not contain variable "session".']);
            end
            session = localMigrateSession(X.session);
            localRestoreSession(session,fullfile(pn,fn),'Session loaded');
        catch ME
            logErrorStack('Load session error:',ME);
        end
    end


    function onCheckSelected(~,event)
        try
            if isempty(event.Indices)
                return
            end
            S.runtime.selectedCheckRow = event.Indices(1,1);
        catch
        end
    end

    function onGoToSelectedCheck(~,~)
        row = [];
        try row = S.runtime.selectedCheckRow; catch, end
        row = checks_dashboard_ui('selected',S.ui,row);
        localNavigateToCheck(row);
    end

    function localNavigateToCheck(row)
        target = checks_dashboard_ui('target',S.ui,row);
        if isempty(target)
            return
        end
        try
            switch target
                case 'paths'
                    S.ui.tgLeft.SelectedTab = tabPaths;
                case 'region'
                    S.ui.tgLeft.SelectedTab = tabRegion;
                case 'basins'
                    S.ui.tgLeft.SelectedTab = tabBasins;
                case 'period'
                    S.ui.tgLeft.SelectedTab = tabPeriod;
                case 'ode'
                    S.ui.tgLeft.SelectedTab = tabODE;
                case 'model'
                    S.ui.tgLeft.SelectedTab = tabModel;
                case 'diagnostics'
                    S.ui.tgLeft.SelectedTab = tabDiag;
                otherwise
                    S.ui.tgRight.SelectedTab = S.ui.tabChecks;
            end
        catch
        end
    end

    function session = localBuildSession()
        session = struct();
        session.schemaVersion = S.runtime.sessionSchemaVersion;
        session.guiVersion = S.runtime.guiVersion;
        session.createdAt = datetime('now');
        session.createdWithMATLAB = version;
        session.cfg = getConfigFromUI();
        session.parOverride = S.store.parOverride;
        session.odeOverride = S.store.odeOverride;
        session.runtimePrepared = S.runtime.prepared;
        session.preparedBasins = S.runtime.preparedBasins;
        session.preparedLatLon = S.runtime.preparedLatLon;
        session.runNote = S.store.runNotes;
        try 
            session.selectedLeftTab = S.ui.tgLeft.SelectedTab.Title; 
        catch
        end
        try 
            session.selectedRightTab = S.ui.tgRight.SelectedTab.Title; 
        catch
        end
        session = localSessionHelper('enrich',session);
    end

    function session = localMigrateSession(session)
        oldVersion = 1;
        if isfield(session,'schemaVersion')
            oldVersion = double(session.schemaVersion);
        end
        session = localSessionHelper('migrate',session, ...
            S.runtime.sessionSchemaVersion);
        if oldVersion < S.runtime.sessionSchemaVersion
            logmsg(sprintf('Migrating session schema %d to %d.', ...
                oldVersion,S.runtime.sessionSchemaVersion));
        end
    end

    function localRestoreSession(session,sourceLabel,statusText)
        if ~isfield(session,'cfg') ...
                || ~isstruct(session.cfg)
            error(['Session does not contain ' ...
                'a valid configuration structure.']);
        end

        report = localSessionHelper('validate',session);
        for kk = 1:numel(report.warnings)
            logmsg(['Session warning: ' char(report.warnings(kk))]);
        end

        setUIFromConfig(session.cfg);
        % Programmatic dropdown assignments do not execute their
        % ValueChangedFcn callbacks. Synchronize the internal configuration
        % explicitly after every dependent menu has been restored.
        S.cfg = getConfigFromUI();
        if isfield(session,'parOverride')
            S.store.parOverride = session.parOverride;
        end
        if isfield(session,'odeOverride')
            S.store.odeOverride = session.odeOverride;
        end

        restorePrepared = report.preparedCompatible;
        if restorePrepared && isfield(session,'preparedBasins') ...
                && isstruct(session.preparedBasins) ...
                && isfield(session.preparedBasins,'K') ...
                && isfield(session.cfg,'bas') ...
                && isfield(session.cfg.bas,'K') ...
                && session.preparedBasins.K < session.cfg.bas.K
            restorePrepared = false;
            logmsg(['Older session contains only a subset of its basin ' ...
                'list. Click Load basins to use all available basins.']);
        end
        if restorePrepared && isfield(session,'runtimePrepared')
            S.runtime.prepared = logical(session.runtimePrepared);
        else
            S.runtime.prepared = false;
        end
        if restorePrepared ...
                && isfield(session,'preparedBasins')
            S.runtime.preparedBasins = session.preparedBasins;
        else
            S.runtime.preparedBasins = [];
        end
        if restorePrepared ...
                && isfield(session,'preparedLatLon')
            S.runtime.preparedLatLon = session.preparedLatLon;
        else
            S.runtime.preparedLatLon = [];
        end
        if ~restorePrepared ...
                && isfield(session,'runtimePrepared') ...
                && logical(session.runtimePrepared)
            if report.preparedCompatible
                logmsg('Prepared basin subset was not restored. Reload all basins.');
            else
                logmsg(['Prepared basin division was not restored: ' ...
                    char(report.preparedReason)]);
            end
        end

        if isfield(session,'runNote')
            S.store.runNotes = string(session.runNote);
            S.ui.txtRunNote.Value = cellstr(S.store.runNotes);
        end
        S.runtime.lastStatus = statusText;
        refreshAll();
        if S.runtime.prepared && ~isempty(S.runtime.preparedBasins)
            % Refresh may rebuild tab layouts. Populate their tables last.
            basSaved = S.runtime.preparedBasins;
            populatePlotTablesFromBasins(basSaved);
            populatePostTablesFromBasins(basSaved);
            updateZoneSummary(basSaved.zone);
            syncPostScenariosFromPeriod();
            S.runtime.filePreparedLocked = ...
                strcmp(char(S.ui.ddSample.Value),'file');
            if size(S.ui.tblPlotTrain.Data,1) ~= basSaved.K_t ...
                    || size(S.ui.tblPlotEval.Data,1) ~= basSaved.K_e ...
                    || size(S.ui.tblPostTrain.Data,1) ~= basSaved.K_t ...
                    || size(S.ui.tblPostEval.Data,1) ~= basSaved.K_e
                error('Saved basin tables did not restore correctly.');
            end
            refreshReadiness();
        else
            S.runtime.filePreparedLocked = false;
        end
        logmsg([statusText ' from: ' char(sourceLabel)]);
    end

    function localSaveRecoverySession(reason)
        try
            session = localBuildSession();
            session.recoveryReason = char(reason);
            session.recoverySavedAt = datetime('now');
            save(S.runtime.recoveryFile,'session','-v7.3');
        catch ME
            try 
                logmsg(['Recovery save warning: ' ME.message]); 
            catch
            end
        end
    end

    function localDeleteRecoverySession()
        try
            if isfile(S.runtime.recoveryFile)
                delete(S.runtime.recoveryFile);
            end
        catch
        end
    end

    function localOfferRecoverySession()
        if ~isfile(S.runtime.recoveryFile)
            return
        end
        choice = uiconfirm(f, ...
            ['A recovery session from an interrupted SITE run was found. ' ...
             'Restore its configuration and prepared basin division?'], ...
            'Restore recovery session', ...
            'Options',{'Restore','Discard','Later'}, ...
            'DefaultOption',1,'CancelOption',3);
        if strcmp(choice,'Discard')
            localDeleteRecoverySession();
            return
        elseif ~strcmp(choice,'Restore')
            return
        end
        X = load(S.runtime.recoveryFile,'session');
        if ~isfield(X,'session')
            error('Recovery file does not contain a session variable.');
        end
        session = localMigrateSession(X.session);
        localRestoreSession(session,S.runtime.recoveryFile,'Recovery restored');
    end

    function onCloseRequest(~,~)
        if S.runtime.isClosing
            return
        end
        S.runtime.isClosing = true;
        if S.runtime.isRunning
            choice = uiconfirm(f, ...
                ['SAGE is still running. Request a graceful stop, save a ' ...
                 'recovery session, and close the GUI?'], ...
                'Close SITE GUI','Options',{'Stop and close','Cancel'}, ...
                'DefaultOption',2,'CancelOption',2);
            if strcmp(choice,'Cancel')
                S.runtime.isClosing = false;
                return
            end
            S.runtime.stopRequested = true;
            localSaveRecoverySession('closed-during-run');
            try f.Visible = 'off'; catch, end
            return
        else
            localDeleteRecoverySession();
        end
        localCleanupAndDeleteFigure();
    end

    function localCleanupAndDeleteFigure()
        try
            if isfield(S.runtime,'noteResizeTimer') ...
                    && localIsValidObject(S.runtime.noteResizeTimer)
                stop(S.runtime.noteResizeTimer);
                delete(S.runtime.noteResizeTimer);
            end
        catch
        end
        try
            if isfield(S.perf,'timer') ...
                    && localIsValidObject(S.perf.timer)
                stop(S.perf.timer);
                delete(S.perf.timer);
            end
        catch
        end
        try 
            delete(f); 
        catch
        end
    end

    function localWriteRunManifest(cfg,status,errorText)
        try
            fn = S.runtime.runManifestFile;
            if isempty(fn)
                fn = fullfile(cfg.dirres,'SAGE_run_manifest.txt');
            end
            fid = fopen(fn,'w');
            if fid < 0, return, end
            c = onCleanup(@()fclose(fid));
            fprintf(fid,'SITE RUN MANIFEST\n');
            fprintf(fid,'=================\n');
            fprintf(fid,'status              : %s\n', ...
                char(status));
            fprintf(fid,'gui version         : %s\n', ...
                S.runtime.guiVersion);
            fprintf(fid,'session schema      : %d\n', ...
                S.runtime.sessionSchemaVersion);
            fprintf(fid,'MATLAB              : %s\n', ...
                version);
            fprintf(fid,'created/updated     : %s\n', ...
                char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
            fprintf(fid,'region              : %s\n', ...
                char(string(cfg.region)));
            fprintf(fid,'resolution          : %s\n', ...
                localResolutionName(cfg.prd.dt));
            fprintf(fid,'model               : %s\n', ...
                local_model_name_from_mdl(cfg.mdl));
            fprintf(fid,'training basins     : %d\n', ...
                cfg.bas.K_t);
            fprintf(fid,'evaluation basins   : %d\n', ...
                cfg.bas.K_e);
            fprintf(fid,'iterations          : %d\n', ...
                cfg.misc.alg.i_max);
            fprintf(fid,'calculation         : %s\n', ...
                char(string(cfg.mdl.calc)));
            fprintf(fid,'results directory   : %s\n', ...
                cfg.dirres);
            fprintf(fid,'period method       : %s\n', ...
                char(string(cfg.prd.method)));
            if isfield(cfg.prd,'seed') ...
                    && ~isempty(cfg.prd.seed)
                fprintf(fid,'period random seed  : %.0f\n', ...
                    double(cfg.prd.seed));
            else
                fprintf(fid,['period random seed  : ' ...
                    'not applicable\n']);
            end
            if isfield(cfg,'runtime') ...
                    && isfield(cfg.runtime,'rngState') ...
                    && isstruct(cfg.runtime.rngState)
                try 
                    fprintf(fid,'MATLAB RNG type     : %s\n', ...
                        cfg.runtime.rngState.Type); 
                catch
                end
                try 
                    fprintf(fid,'MATLAB RNG seed     : %.0f\n', ...
                        double(cfg.runtime.rngState.Seed)); 
                catch
                end
            end
            fprintf(fid,'loaded basins       : %s\n', ...
                tern(S.runtime.prepared,'yes','no'));
            if nargin >= 3 ...
                    && ~isempty(errorText)
                fprintf(fid,'\nERROR\n-----\n%s\n', ...
                    char(string(errorText)));
            end
            clear c
            logmsg(['Run manifest updated: ' fn]);
        catch ME
            try 
                logmsg(['Manifest warning: ' ME.message]); 
            catch
            end
        end
    end

    function onMeteoPETChanged(~,~)

        % Synchronize any config-declared dependent meteo controls.
        try
            applyLinkedMeteoControls(getCurrentResolutionConfig());
        catch ME
            logmsg(['Meteo control synchronization warning: ' ...
                ME.message]);
        end
        localRefreshMeteoChoicePresentation(S.ui);

        markDependencyChange('forcing changed', ...
            ['Meteo/PET product changed; ' ...
            'Validate checks before ' ...
            'running. Existing basin ' ...
            'split is retained.'],false,false);
        syncPostScenariosFromPeriod();
        refreshMeteoPETInfo();
        refreshAll();
    end

    function onExportScript(~,~)
        % Export the exact SITE configuration represented by this GUI.
        try
            if ~S.runtime.prepared ...
                    || isempty(S.runtime.preparedBasins)
                updateLockState();
                uialert(f, ...
                    ['Load basins successfully before exporting ' ...
                     'the SITE experiment script.'], ...
                    'Basins not prepared');
                return
            end

            cfg = getConfigFromUI();
            cfg.bas = S.runtime.preparedBasins;
            C = siteUi('buildRunConfig',cfg);
            if isfield(C,'ui')
                C = rmfield(C,'ui');
            end

            exDir = fullfile(cfg.SITEhydro,'examples');
            if ~exist(exDir,'dir')
                mkdir(exDir);
            end
            exportType = uiconfirm(f, ...
                'Choose the reproducible SITE code format.', ...
                'Export SITE code', ...
                'Options',{'MATLAB script','Live Script','Cancel'}, ...
                'DefaultOption',1,'CancelOption',3);
            if strcmp(exportType,'Cancel')
                return
            end
            isLiveScript = strcmp(exportType,'Live Script');
            if isLiveScript
                fileFilter = {'*.mlx','MATLAB Live Script (*.mlx)'};
                defaultFile = fullfile(exDir,'run_SITE_export_live.mlx');
                dialogTitle = 'Save exported SITE Live Script as';
            else
                fileFilter = {'*.m','MATLAB script (*.m)'};
                defaultFile = fullfile(exDir,'run_SITE_export.m');
                dialogTitle = 'Save exported SITE run script as';
            end
            [fn,pn] = uiputfile(fileFilter,dialogTitle,defaultFile);
            if isequal(fn,0) ...
                    || isequal(pn,0)
                return
            end

            fpath = fullfile(pn,fn);
            openEditorDocument = [];
            if isLiveScript && ~isdeployed
                try
                    %#exclude matlab.desktop.editor.findOpenDocument
                    openEditorDocument = ...
                        matlab.desktop.editor.findOpenDocument(fpath);
                    if ~isempty(openEditorDocument) ...
                            && openEditorDocument.Modified
                        replaceChoice = uiconfirm(f, ...
                            ['This Live Script is open with unsaved changes.' ...
                             newline 'Replace it with the SITE export?'], ...
                            'Replace open Live Script', ...
                            'Options',{'Replace','Cancel'}, ...
                            'DefaultOption',2,'CancelOption',2);
                        if strcmp(replaceChoice,'Cancel')
                            return
                        end
                    end
                catch
                    openEditorDocument = [];
                end
            end
            if isLiveScript
                siteWriteLiveScript(fpath,C);
            else
                siteWriteRunScript(fpath,C);
            end
            if ~isempty(openEditorDocument)
                try
                    openEditorDocument.reload();
                    openEditorDocument.makeActive();
                catch ME
                    logmsg(['Live Script exported, but its open Editor ' ...
                        'view could not be refreshed: ' ME.message]);
                end
            end
            logmsg(['Exported SITE code to: ' fpath]);

            if ~isdeployed
                choice = uiconfirm(f, ...
                    sprintf(['Exported SITE MATLAB code:' newline ...
                    '%s' newline newline ...
                    'Open it now in the MATLAB Editor?'],fpath), ...
                    'Run script exported', ...
                    'Options',{'Open','Close'}, ...
                    'DefaultOption',1,'CancelOption',2);
                if strcmp(choice,'Open')
                    try
                        open(fpath);
                    catch ME
                        logmsg(['Could not open exported script: ' ME.message]);
                    end
                end
            else
                uialert(f,sprintf(['Exported SITE MATLAB code:' ...
                    newline '%s'],fpath),'Export complete','Icon','success');
            end
        catch ME
            logErrorStack('Export SITE run script error:',ME);
        end
    end

    function onParamDefaults(~,~)
    
        choice = questdlg( ...
            ['Reset parameter bounds to ' ...
            'read_model defaults?'], ...
            'Reset defaults', ...
            'Reset','Cancel','Cancel');
    
        if isempty(choice) ...
                || ~strcmp(choice,'Reset')
            return
        end
    
        try
            cfg = getConfigFromUI();
    
            % remove user override for current (model,dt)
            key = overrideKey(cfg.mdl,cfg.prd.dt);
            if isfield(S.store.parOverride,key)
                S.store.parOverride = ...
                    rmfield(S.store.parOverride,key);
            end
    
            % clear cached model so GUI rebuilds from canonical defaults
            S.cache.modelBase = [];
            S.cache.modelBaseKey = "";
    
            logmsg(['Parameter ranges ' ...
                'reset to read_model defaults.']);
    
            refreshAll();
    
        catch ME
            logErrorStack(['Parameter default ' ...
                'reset error:'],ME);
        end
    end

    function onODEDefaults(~,~)
        choice = uiconfirm(f,['Reset ODE | solver ' ...
            'settings to defaults?'], ...
            'Reset ODE defaults', ...
            'Options',{'Reset','Cancel'}, ...
            'DefaultOption',2,'CancelOption',2);
        if ~strcmp(choice,'Reset')
            return
        end
        try
            ode0 = read_numsettings();
            if isfield(ode0,'InitStep')
                S.ui.edInitStep.Value = double(ode0.InitStep);
            end
            if isfield(ode0,'MaxStep')
                S.ui.edMaxStep.Value = double(ode0.MaxStep);
            end
            if isfield(ode0,'MinStep')
                S.ui.edMinStep.Value = double(ode0.MinStep);
            end
            if isfield(ode0,'RelTol')
                S.ui.edRelTol.Value = double(ode0.RelTol);
            end
            if isfield(ode0,'AbsTol')
                S.ui.edAbsTol.Value = double(ode0.AbsTol);
            end
            if isfield(ode0,'Order')
                S.ui.spOrder.Value = double(ode0.Order);
            end
            if isfield(ode0,'maxiter')
                S.ui.spMaxIterODE.Value = double(ode0.maxiter);
            end
            if isfield(ode0,'mem')
                S.ui.ddMem.Value = ...
                    tern(double(ode0.mem)==1, ...
                    '1 (yes)','0 (no)');
            end
            logmsg(['ODE | solver settings reset ' ...
                'to read_numsettings defaults.']);
            refreshAll();
        catch ME
            logErrorStack(['ODE default ' ...
                'reset error:'],ME);
        end
    end

    % --> this can move to below?
    function onParamTableEdit(src,evt)
        D = src.Data;
        if isempty(D)
            return
        end
        row = evt.Indices(1);
        col = evt.Indices(2);

        try
            % Only the Min and Max columns are editable. If MATLAB calls
            % this callback for another reason, ignore it safely.
            if col ~= 4 ...
                    && col ~= 5
                clearTableSelection(src);
                return
            end

            name = string(D{row,1});
            unit = string(D{row,3});
            minv = D{row,4}; 
            maxv = D{row,5};

            allowNegative = false;
            try
                UD = src.UserData;
                if isstruct(UD) ...
                        && isfield(UD,'allowNegative') ...
                        && numel(UD.allowNegative) >= row
                    allowNegative = logical(UD.allowNegative(row));
                end
            catch
            end

            [ok,msg,minv,maxv] = ...
                validateParamBoundsLocal(char(unit), ...
                minv,maxv,allowNegative);
            if ~ok
                logmsg(sprintf(['Parameter edit ' ...
                    'rejected for %s: %s'], ...
                    char(name),msg));
                try
                    S.ui.lblParsWarning.Text = ...
                        sprintf('%s: %s',char(name),msg);
                catch
                end
                refreshParamTable();
                clearTableSelection(src);
                return
            end

            D{row,4} = minv; 
            D{row,5} = maxv;
            src.Data = D;

            try
                S.ui.lblParsWarning.Text = '';
            catch
            end

            cfg = getConfigFromUI();
            key = overrideKey(cfg.mdl,cfg.prd.dt);
            S.store.parOverride.(key) = struct( ...
                'names',string(D(:,1)), ...
                'min',cell2mat(D(:,4)), ...
                'max',cell2mat(D(:,5)));
            refreshPreview();
            clearTableSelection(src);
        catch ME
            logErrorStack(['Parameter ' ...
                'table edit error:'],ME);
        end
    end



    function onCopyParameterBounds(~,~)
        try
            D = S.ui.tblPars.Data;
            if isempty(D), return, end
            lines = strings(size(D,1),1);
            for ii = 1:size(D,1)
                lines(ii) = ...
                    sprintf('%s\t%s\t%s\t%.8g\t%.8g', ...
                    string(D{ii,1}),string(D{ii,2}), ...
                    string(D{ii,3}),D{ii,4},D{ii,5});
            end
            clipboard('copy', ...
                strjoin(cellstr(lines),newline));
            logmsg(['Copied parameter ' ...
                'bounds to clipboard.']);
        catch ME
            logErrorStack(['Copy parameter ' ...
                'bounds error:'],ME);
        end
    end

    function onAttrAll(~,~)
        D = S.ui.tblAttr.Data;
        if isempty(D)
            return
        end
    
        selectable = true(size(D,1),1);
        if isfield(S.runtime, ...
                'attrSelectable')
            selectable = logical( ...
                S.runtime.attrSelectable(:));
        end
    
        for ii = 1:size(D,1)
            if ii <= numel(selectable) ...
                    && selectable(ii)
                D{ii,1} = '✓';
            else
                D{ii,1} = 'X'; %×
            end
        end    
        S.ui.tblAttr.Data = D;
        onAttrTableEdit();
    end
    
    function onAttrNone(~,~)
        D = S.ui.tblAttr.Data;
        if isempty(D)
            return
        end
    
        selectable = true(size(D,1),1);
        if isfield(S.runtime, ...
                'attrSelectable')
            selectable = logical( ...
                S.runtime.attrSelectable(:));
        end
    
        for ii = 1:size(D,1)
            if ii <= numel(selectable) ...
                    && ~selectable(ii)
                D{ii,1} = 'X'; %×
            else
                D{ii,1} = '☐';
            end
        end    
        S.ui.tblAttr.Data = D;
        onAttrTableEdit();
    end

    function onAttrDefault(~,~)

        region = region_helpers('code', ...
            S.ui.ddRegion.Value);
        ATTR = attr_catalog(region);
        D = S.ui.tblAttr.Data;
        if isempty(D)
            return
        end
        sel = false(size(D,1),1);
        selectable = true(size(D,1),1);
        if isfield(ATTR,'selectable') ...
                && ~isempty(ATTR.selectable)
            selectable = logical(ATTR.selectable(:));
            selectable = selectable(1: ...
                min(numel(selectable),size(D,1)));
        end
        if isfield(ATTR,'default_ids') ...
                && ~isempty(ATTR.default_ids)
            id0 = ATTR.default_ids(:).';
        else
            id0 = local_default_attr_ids();
        end
        id0 = id0(id0 >= 1 ...
            & id0 <= numel(sel));
        id0 = id0(selectable(id0));
        sel(id0) = true;
        for ii = 1:size(D,1)
            if ii <= numel(selectable) ...
                    && ~selectable(ii)
                D{ii,1} = '×';
            elseif sel(ii)
                D{ii,1} = '✓';
            else
                D{ii,1} = '☐';
            end
        end
        S.ui.tblAttr.Data = D;
        onAttrTableEdit();
    end

    function onAttrTableEdit()

        D = S.ui.tblAttr.Data;
        if ~isempty(D) ...
                && isfield(S.runtime, ...
                'attrSelectable')
            selectable = logical( ...
                S.runtime.attrSelectable(:));
            for ii = 1:min(size(D,1), ...
                    numel(selectable))
                if ~selectable(ii)
                    D{ii,1} = false;
                end
            end
            S.ui.tblAttr.Data = D;
        end
        site_syncIdAttrField(S.ui.tblAttr,S.ui.edAttr);
        refreshPreview();
    end

    function onAttrCellSelected(~,event)

        if isempty(event.Indices)
            return
        end    
        row = event.Indices(1);
        col = event.Indices(2);    
        if col ~= 1
            return
        end
        D = S.ui.tblAttr.Data;
        if isempty(D) ...
                || row < 1 ...
                || row > size(D,1)
            return
        end   
        selectable = true(size(D,1),1);
        if isfield(S.runtime, ...
                'attrSelectable') ...
                && ~isempty( ...
                S.runtime.attrSelectable)
            selectable = logical( ...
                S.runtime.attrSelectable(:));
        end
    
        if row <= numel(selectable) ...
                && ~selectable(row)
            D{row,1} = '×';
            S.ui.tblAttr.Data = D;
            return
        end
    
        if strcmp(string(D{row,1}),"✓")
            D{row,1} = '☐';
        else
            D{row,1} = '✓';
        end    
        S.ui.tblAttr.Data = D;
        site_syncIdAttrField(S.ui.tblAttr,S.ui.edAttr);

        S.runtime.prepared = false;
        S.runtime.preparedBasins = [];
        S.runtime.preparedLatLon = [];

        setRunStatus('basin selection invalid');
        refreshReadiness();
    end

    function onRunNoteChanged()
        try
            S.store.runNotes = ...
                string(strjoin(string( ...
                S.ui.txtRunNote.Value),newline));
        catch
            S.store.runNotes = "";
        end
    end

    function syncDataActionRunNotes(actionNote)
    % Keep generated registry notes visible without duplicating user text.
        beginMarker = "Automatic data actions";
        endMarker = "----------------------------------------";
        current = strjoin(string(S.store.runNotes),newline);
        pattern = "(?s)\s*" ...
            + regexptranslate('escape',beginMarker) ...
            + ".*?" ...
            + regexptranslate('escape',endMarker) ...
            + "\s*";
        current = strip(regexprep(current,pattern,""));
        actionNote = strip(string(actionNote));
        if strlength(actionNote) > 0
            generated = beginMarker + newline ...
                + actionNote + newline + endMarker;
            if strlength(current) > 0
                current = current + newline + newline;
            end
            current = current + generated;
        end
        S.store.runNotes = current;
        try
            S.ui.txtRunNote.Value = cellstr(splitlines(current));
        catch
        end
    end

    function syncQualityScreeningRunNotes(quality)
    % Show run-specific screening separately from curated data actions.
        if ~isstruct(quality) || ~isfield(quality,'eligible') ...
                || ~isfield(quality,'gauge') ...
                || ~isfield(quality,'exclusion_reason')
            return
        end
        beginMarker = "Automatic data-quality screening";
        endMarker = "----------------------------------------";
        current = strjoin(string(S.store.runNotes),newline);
        pattern = "(?s)\s*" ...
            + regexptranslate('escape',beginMarker) ...
            + ".*?" ...
            + regexptranslate('escape',endMarker) ...
            + "\s*";
        current = strip(regexprep(current,pattern,""));

        eligible = logical(quality.eligible(:));
        documented = false(size(eligible));
        if isfield(quality,'documented_exclusion')
            documented = logical(quality.documented_exclusion(:));
        end
        automatic = ~eligible & ~documented;
        gauges = string(quality.gauge(:));
        reasons = string(quality.exclusion_reason(:));
        lines = strings(0,1);
        lines(end+1) = sprintf(['%d of %d basins excluded by ' ...
            'run-specific screening.'],nnz(automatic),numel(eligible));
        uniqueReasons = unique(reasons(automatic & reasons ~= ""), ...
            'stable');
        for ir = 1:numel(uniqueReasons)
            count = nnz(automatic & reasons == uniqueReasons(ir));
            lines(end+1) = sprintf('Reason (%d): %s.', ...
                count,uniqueReasons(ir)); %#ok<AGROW>
        end
        excludedGauge = gauges(automatic);
        nShow = min(10,numel(excludedGauge));
        if nShow > 0
            gaugeText = strjoin(excludedGauge(1:nShow),', ');
            if numel(excludedGauge) > nShow
                gaugeText = gaugeText + ", ...";
            end
            lines(end+1) = "Gauges: " + gaugeText;
        end
        if nnz(documented) > 0
            lines(end+1) = sprintf(['%d additional basin(s) excluded ' ...
                'by documented data actions.'],nnz(documented));
        end
        % SITE reports screening directly; its calibration queue is filtered
        % in run_SITE and does not supply SAGE's active_bas structure.
        lines(end+1) = sprintf( ...
            'Final eligible population: %d basins.',nnz(eligible));
        summary = strjoin(lines,newline);
        generated = beginMarker + newline + summary + newline + endMarker;
        if strlength(current) > 0
            current = current + newline + newline;
        end
        S.store.runNotes = current + generated;
        try
            S.ui.txtRunNote.Value = cellstr( ...
                splitlines(S.store.runNotes));
        catch
        end
    end

    function onRandomSelection(group)
        try
            if nargin < 1
                group = 'both';
            end
            Dtr0 = S.ui.tblPostTrain.Data;
            Dev0 = S.ui.tblPostEval.Data;
            Btr = min(round(S.ui.spBprtTrain.Value),size(Dtr0,1));
            Bev = min(round(S.ui.spBprtEval.Value),size(Dev0,1));
            tt = logical(S.ui.cbScenTT.Value);
            te = logical(S.ui.cbScenTE.Value);
            et = logical(S.ui.cbScenET.Value);
            ee = logical(S.ui.cbScenEE.Value);

            Dtr = S.ui.tblPostTrain.Data;
            Dev = S.ui.tblPostEval.Data;

            % Full redraw from scratch each time Random selection pressed
            if ~isempty(Dtr) ...
                    && any(strcmp(group,{'train','both'}))
                if tt || te
                    sel = local_full_random_selection(size(Dtr,1),Btr);
                    for ii = 1:size(Dtr,1)
                        Dtr{ii,2} = tt && sel(ii);
                        Dtr{ii,3} = te && sel(ii);
                    end
                else
                    for ii = 1:size(Dtr,1)
                        Dtr{ii,2} = false;
                        Dtr{ii,3} = false;
                    end
                end
                S.ui.tblPostTrain.Data = Dtr;
            end

            if ~isempty(Dev) ...
                    && any(strcmp(group,{'eval','both'}))
                if et ...
                        || ee
                    sel = local_full_random_selection(size(Dev,1),Bev);
                    for ii = 1:size(Dev,1)
                        Dev{ii,2} = et && sel(ii);
                        Dev{ii,3} = ee && sel(ii);
                    end
                else
                    for ii = 1:size(Dev,1)
                        Dev{ii,2} = false;
                        Dev{ii,3} = false;
                    end
                end
                S.ui.tblPostEval.Data = Dev;
            end

            S.runtime.postSelectionIsRandom = true;
            logmsg(sprintf(['Random %s-basin selection applied: ' ...
                '%d training and %d evaluation basins requested.'], ...
                group,Btr,Bev));
            refreshPreview();
            refreshPostSelectionViews();
            try
                S.ui.tgRight.SelectedTab = tabRegionMap;
            catch
            end
        catch ME
            logErrorStack('Random selection error:',ME);
        end
    end

    function onClearSelection(group)
        try
            if nargin < 1
                group = 'both';
            end
            Dtr = S.ui.tblPostTrain.Data;
            Dev = S.ui.tblPostEval.Data;
            if ~isempty(Dtr) ...
                    && any(strcmp(group,{'train','both'}))
                for ii = 1:size(Dtr,1)
                    Dtr{ii,2}=false;
                    Dtr{ii,3}=false;
                end
                S.ui.tblPostTrain.Data = Dtr;
            end
            if ~isempty(Dev) ...
                    && any(strcmp(group,{'eval','both'}))
                for ii = 1:size(Dev,1)
                    Dev{ii,2}=false;
                    Dev{ii,3}=false;
                end
                S.ui.tblPostEval.Data = Dev;
            end
            try
                S.runtime.postSelectionIsRandom = false;
            catch
            end
            logmsg(sprintf('Cleared %s postprocess basin selections.',group));
            refreshPreview();
            refreshPostSelectionViews();
        catch ME
            logErrorStack('Clear selection error:',ME);
        end
    end

    function onBasinSearchChanged(~,~)
        q = lower(strtrim(char( ...
            S.ui.edBasinSearch.Value)));
        nMatch = countTableMatches( ...
            S.ui.tblPlotTrain,q) + ...
            countTableMatches(S.ui.tblPlotEval,q);
        if isempty(q)
            S.ui.lblBasinFilterInfo.Text = '';
        else
            S.ui.lblBasinFilterInfo.Text = ...
                sprintf('Search matched %d row(s).', ...
                nMatch);
        end
    end

    function onQuickLookPreset(~,~)
        try
            S.ui.cbScenTT.Value = true;
            S.ui.cbScenTE.Value = true;
            S.ui.cbScenET.Value = false;
            S.ui.cbScenEE.Value = false;
            S.ui.spBprtTrain.Value = 5;
            try
                S.ui.spBprtEval.Limits = [0 200];
            catch
            end
            S.ui.spBprtEval.Value = 0;
            syncPostprocessScenarioControls();
            onRandomSelection('both');
            onPostprocessRefresh();
        catch
        end
    end

    function onTrainingOnlyPreset(~,~)
        S.ui.cbScenTT.Value = true;
        S.ui.cbScenTE.Value = true;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;
        onPostprocessRefresh();
    end

    function onEvalOnlyPreset(~,~)
        % SITE has no evaluation basins. Here "evaluation only" means the
        % evaluation period applied to the training basins.
        S.ui.cbScenTT.Value = false;
        S.ui.cbScenTE.Value = true;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;
        onPostprocessRefresh();
    end

    function onAllScenarioPreset(~,~)
        % The complete SITE scenario set contains only the two training-basin
        % period combinations: train|train and train|evaluation.
        S.ui.cbScenTT.Value = true;
        S.ui.cbScenTE.Value = true;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;
        onPostprocessRefresh();
    end

    function onClearScenarioPreset(~,~)
        S.ui.cbScenTT.Value = false;
        S.ui.cbScenTE.Value = false;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;
        onPostprocessRefresh();
    end

    function onLogFilterChanged(~,~)
        refreshLogView(); 
    end

    function onIterFilterChanged(~,~)
        refreshIterView(); 
    end

    function onFollowIterChanged(~,~)
        S.flags.followIterTail = ...
            logical(S.ui.cbFollowIter.Value);
    end

    function onClearLog(~,~)
        S.store.logAll = ...
            strings(0,1); refreshLogView();
    end

    function onCopyLog(~,~)
        try clipboard('copy', ...
                strjoin(cellstr( ...
                S.store.logAll),newline));
            logmsg('Copied log to clipboard.');
        catch
        end
    end

    function onCopyIter(~,~)
        try clipboard('copy', ...
                strjoin(cellstr( ...
                S.store.iterAll),newline));
            logmsg(['Copied iteration ' ...
                'output to clipboard.']);
        catch
        end
    end

    function onShowFirstError(~,~)
        D = S.ui.tblChecks.Data;
        if isempty(D)
            return
        end
        idx = checks_dashboard_ui('firsterror',S.ui);
        if isempty(idx)
            uialert(f,['No ERROR rows in ' ...
                'current checks table.'],'Checks');
        else
            localNavigateToCheck(idx);
            uialert(f,char(D{idx,3}),char(D{idx,2}));
        end
    end

    function onCopyLastError(~,~)
        try
            if ~isfield(S.runtime,'lastError') ...
                    || isempty(S.runtime.lastError)
                txt = ['No recent ' ...
                    'errors or warnings.'];
            else
                txt = char(string( ...
                    S.runtime.lastError));
            end
    
            clipboard('copy',txt);
            logmsg(['Copied last error ' ...
                'to clipboard.']);
        catch
        end
    end

    function onExportCurrentView(~,~)
        try
            tab = S.ui.tgRight.SelectedTab;
            titleText = char(tab.Title);
            [fn,pn] = uiputfile({'*.png', ...
                'PNG image (*.png)'}, ...
                'Export current view', ...
                fullfile(getConfigFromUI().dirres, ...
                [titleText '.png']));
            if isequal(fn,0) ...
                    || isequal(pn,0)
                return
            end
            exportapp(f,fullfile(pn,fn));
            logmsg(['Exported current view ' ...
                'to: ' fullfile(pn,fn)]);
        catch ME
            logErrorStack('Export current view error:',ME);
        end
    end

    function onExportPreview(~,~)
        try
            [fn,pn] = uiputfile({'*.txt', ...
                'Text file (*.txt)'}, ...
                'Export preview text', ...
                fullfile(getConfigFromUI().dirres, ...
                'SITE_preview.txt'));
            if isequal(fn,0) ...
                    || isequal(pn,0)
                return
            end
            fid = fopen(fullfile(pn,fn),'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'%s\n', ...
                S.ui.txtPreview.Value{:});
            logmsg(['Exported preview text ' ...
                'to: ' fullfile(pn,fn)]);
        catch ME
            logErrorStack('Export preview error:',ME);
        end
    end

    function onExportLogs(~,~)
        try
            [fn,pn] = uiputfile({'*.txt', ...
                'Text file (*.txt)'}, ...
                'Export logs', ...
                fullfile(getConfigFromUI().dirres, ...
                'SITE_log.txt'));
            if isequal(fn,0) || isequal(pn,0)
                return
            end
            fid = fopen(fullfile(pn,fn),'w');
            c = onCleanup(@() fclose(fid));
            fprintf(fid,'%s\n', ...
                S.store.logAll);
            fprintf(fid,'\n\n=== ITER OUTPUT ===\n');
            fprintf(fid,'%s\n', ...
                S.store.iterAll);
            logmsg(['Exported logs ' ...
                'to: ' fullfile(pn,fn)]);
        catch ME
            logErrorStack('Export logs error:',ME);
        end
    end

    function onReferenceHtmlEvent(~,evt)

        persistent lastOpenURL lastOpenTime

        try
            act = '';
            D = struct();
            try
                if isprop(evt,'HTMLEventName') ...
                        && ~isempty(evt.HTMLEventName)
                    act = lower(char(string(evt.HTMLEventName)));
                end
            catch
            end
            try
                if isprop(evt,'HTMLEventData') ...
                        && ~isempty(evt.HTMLEventData)
                    D = evt.HTMLEventData;
                end
            catch
            end
            switch act
                case 'open'
                    if isfield(D,'url') ...
                            && ~isempty(D.url)

                        url = char(string(D.url));
                        % Prevent repeated uihtml click
                        % events from opening
                        % the same reference many times.
                        if ~isempty(lastOpenURL) ...
                                && strcmp(url,lastOpenURL)
                            try
                                dt = toc(lastOpenTime);
                                if dt < 1.0
                                    return
                                end
                            catch
                            end
                        end
                        lastOpenURL = url;
                        lastOpenTime = tic;
                        localOpenExternal(url);
                    end

                case 'defaults'
                    site_applyResolutionDefaults(S.ui,getCurrentResolutionConfig(), ...
            @applyRegionBasinDefaults,@updateDefaultBasinSplitFile);
                    refreshAll();
                    logmsg(['Applied default settings for ' ...
                        lower(char(S.ui.ddRes.Value)) ...
                        ' data resolution ' ...
                        'from reference link.']);
            end
        catch ME
            logmsg(['Reference HTML ' ...
                'event error: ' ME.message]);
        end
    end

    function ok = localOpenExternal(target)
        %LOCALOPENEXTERNAL Open URL or local file in MATLAB and deployed apps.
        % This avoids MATLAB's open/web edge cases in compiled executables.

        ok = false;
        try
            target = char(string(target));
            target = strtrim(target);
            if isempty(target)
                return
            end

            isUrl = startsWith(lower(target),'http://') || ...
                startsWith(lower(target),'https://');

            if isUrl
                if ispc
                    system(['start "" "' target '"']);
                elseif ismac
                    system(['open "' target '" &']);
                else
                    system(['xdg-open "' target '" &']);
                end
                ok = true;
                return
            end

            filePath = target;
            if ~isfile(filePath)
                w = which(filePath);
                if ~isempty(w)
                    filePath = w;
                elseif isdeployed
                    ctfPath = fullfile(ctfroot,filePath);
                    if isfile(ctfPath)
                        filePath = ctfPath;
                    end
                end
            end

            if ~isfile(filePath)
                logmsg(['External file not found: ' filePath]);
                return
            end

            if ispc
                winopen(filePath);
            elseif ismac
                system(['open "' filePath '" &']);
            else
                system(['xdg-open "' filePath '" &']);
            end
            ok = true;
        catch ME
            try
                logmsg(['Could not open external ' ...
                    'target: ' ME.message]);
            catch
                warning('%s', ...
                    ['Could not open external ' ...
                    'target: ' ME.message]);
            end
        end
    end

    function onCountryChanged(source,~)
        if S.runtime.isRunning
            try
                paths_region_tabs_ui('geography',S.ui,localRegionPanelName(S.cfg.region));
            catch
            end
            logmsg(['Region change ignored ' ...
                'while SAGE is running.']);
            return
        end
        if isequal(source,S.ui.ddGeography)
            paths_region_tabs_ui('geography',S.ui);
        end
        refreshDatasetSelector('',true);
    end

    function refreshDatasetSelector(preferredRegion,applyChange)
        if nargin < 1
            preferredRegion = '';
        end
        if nargin < 2
            applyChange = false;
        end
        if ~isfield(S.ui,'ddCountry') ...
                || ~isfield(S.ui,'ddRegion') ...
                || ~isfield(S.ui,'regionDatasetCodes')
            return
        end
        country = char(string(S.ui.ddCountry.Value));
        mask = strcmp(S.ui.regionDatasetCountries,country);
        names = S.ui.regionDatasetNames(mask);
        codes = S.ui.regionDatasetCodes(mask);
        if isempty(codes)
            return
        end
        target = char(string(preferredRegion));
        if isempty(target) || ~any(strcmp(codes,target))
            try
                current = char(string(S.ui.ddRegion.Value));
            catch
                current = '';
            end
            if any(strcmp(codes,current))
                target = current;
            else
                target = codes{1};
            end
        end
        S.ui.ddRegion.Items = names;
        S.ui.ddRegion.ItemsData = codes;
        S.ui.ddRegion.Value = target;
        if numel(codes) > 1
            S.ui.ddRegion.Enable = 'on';
        else
            S.ui.ddRegion.Enable = 'off';
        end
        if applyChange
            onRegionChanged([],[]);
        end
    end
    function onRegionChanged(~,~)

        if isfield(S.runtime,'initializingUI') ...
                && S.runtime.initializingUI
            % Do not discard a user selection made during startup.  The
            % complete region refresh is replayed immediately after the
            % initialization block has finished.
            S.runtime.pendingRegionChange = true;
            % The flag can already be updated safely because it reads the
            % current dropdown value rather than the old configuration.
            try
                refreshRegionFlag();
                drawnow limitrate nocallbacks
            catch
            end
            return
        end

        if S.runtime.isRunning
            logmsg(['Region change ignored ' ...
                'while SAGE is running.']);
            return
        end

        % Commit the newly selected region immediately.
        % Otherwise some refresh routines still see the previous S.cfg
        % region during this first callback.
        try
            newRegion = region_helpers('code', ...
                S.ui.ddRegion.Value);
            S.cfg.region = newRegion;
            S.cfg.regionName = region_helpers( ...
                'name',newRegion);
            S.cfg.dirDroot = char(S.ui.edDataLocation.Value);
            S.cfg.dirD = fullfile( ...
                S.cfg.dirDroot,newRegion);
        catch ME
            logmsg(['Could not commit region change: ' ...
                ME.message]);
        end

        % Histories belong to the previous region and must disappear as
        % soon as the new region is selected.

        % Immediately invalidate visibly stale data-status text.
        try
            S.ui.txt15minStatus.Text = '— checking';
            S.ui.txtHourlyStatus.Text = '— checking';
            S.ui.txtDailyStatus.Text = '— checking';
            S.ui.txtGaugeStatus.Text = '— checking';
            S.ui.txtCacheStatus.Text = ...
                'Checking the selected region data folders ...';
        
            refreshDataTabVisibility();
            drawnow limitrate nocallbacks;
        catch
        end

        % Update visible region identity immediately, before heavier
        % refresh routines that may fail or take time.
        try
            refreshRegionFlag();
        catch ME
            logmsg(['Region flag refresh failed: ' ME.message]);
        end

        try
            S.ui.tabRegionMap.Title = ...
                localRegionPanelName(S.cfg.region);
        catch
            S.ui.tabRegionMap.Title = 'Region';
        end

        try
            refreshEmptyMapTitles();
            % Remove the visibly stale parameter map immediately. The new
            % detailed map is drawn lazily when the Map tab is selected.
            refreshParamMapPlaceholder();
        catch
        end

        drawnow limitrate nocallbacks;

        markDependencyChange('Region changed', ...
            ['Data region changed; basin ' ...
            'universe, forcing folders, ' ...
            'split files, and prepared ' ...
            'basins were reset.'], ...
            true,false);

        % markDependencyChange clears the prepared basins and coordinates,
        % but it does not redraw geographic axes. Refresh all geographic
        % views now so markers and zone colors from the previous region
        % disappear immediately. The empty views retain the selected
        % region's limits, boundary, flag, and title until Load basins is
        % used to prepare the new basin sample.
        try
            refreshRegion();
        catch ME
            logmsg(['Region-map reset failed: ' ME.message]);
        end
        try
            refreshZones();
        catch ME
            logmsg(['Zone-map reset failed: ' ME.message]);
        end
        try
            refreshParamMapPlaceholder();
        catch ME
            logmsg(['Parameter-map reset failed: ' ME.message]);
        end
        try
            refreshZoneSummaryTable();
        catch ME
            logmsg(['Zone-summary reset failed: ' ME.message]);
        end
        drawnow limitrate nocallbacks;

        try
            S.cache.regionConfig = [];
            S.cache.regionConfigKey = "";

            refreshResolutionControls();
            site_applyResolutionDefaults(S.ui,getCurrentResolutionConfig(), ...
            @applyRegionBasinDefaults,@updateDefaultBasinSplitFile);
            refreshDerivedPaths();

            S.cfg = getConfigFromUI();

            S.runtime.dataStatusDirty = true;
            try
                if isequal(S.ui.tgLeft.SelectedTab, ...
                        S.ui.tabRegion)
                    refreshDataStatus();
                    % The currently selected region has now been checked.
                    S.runtime.dataStatusDirty = false;
                end
            catch MEstatus
                logmsg(['Data-status refresh ' ...
                    'failed: ' MEstatus.message]);
            end

            refreshRegionFlag();
            refreshPeriodMethodControls();
            updateReferenceBlock_standalone(S.ui,fontsizeNotes);
            refreshMeteoPETInfo();
            updateDefaultBasinSplitFile();

            S.ui.tabRegionMap.Title = ...
                localRegionPanelName(S.cfg.region);

            % Disk scans and map redraws are tab-specific and can be slow.
            % Mark them stale now and refresh only when the user opens the
            % corresponding tab.
            % S.runtime.dataStatusDirty = true;
            S.cache.paramMapRenderKey = "";
            syncRegionalAttributeDefaults();
            refreshPreview();
            refreshParamTable();
            refreshReadiness();
            refreshSummary();
            refreshMapFlag();
            refreshEmptyMapTitles();

        catch ME
            logErrorStack('Region change refresh error:',ME);

            % Still force the most visible identity fields to the dropdown.
            try
                S.cfg.region = region_helpers('code', ...
                    S.ui.ddRegion.Value);
                S.cfg.regionName = region_helpers('name',S.cfg.region);
                S.cfg.dirDroot = char(S.ui.edDataLocation.Value);
                S.cfg.dirD = fullfile(S.cfg.dirDroot,S.cfg.region);
                refreshRegionFlag();
                refreshDerivedPaths();
                refreshEmptyMapTitles();
            catch
            end
        end
        refreshWorldCoverageSelection();
        
        updateLockState();
    end

    function onDownloadDaily(~,~)
        cfg = getConfigFromUI();
        ui = struct('fig',f,'logFcn',@logmsg);

        S.ui.btnDaily.Enable = 'off';
        f.Pointer = 'watch';
        drawnow;

        try
            out = data_helpers('download', ...
                cfg,'daily',ui);
        catch ME
            logmsg('Daily data download failed:');
            logmsg(ME.message);
            out = struct('ok',false);
        end

        f.Pointer = 'arrow';
        drawnow;

        if isstruct(out) && isfield(out,'ok') && out.ok
            S.cache.worldInstallStatus = struct();
            S.runtime.worldCoverageDrawn = false;
        end
        refreshDataStatus();
        refreshPreview();
        refreshParamTable();

        if ~(isstruct(out) ...
                && isfield(out,'ok') ...
                && out.ok)
            try
                if data_helpers('supports', ...
                        cfg.region,'daily')
                    S.ui.btnDaily.Enable = 'on';
                end
            catch
            end
        end
    end

    function onDownloadHourly(~,~)
        cfg = getConfigFromUI();
        ui = struct('fig',f,'logFcn',@logmsg);

        if ~data_helpers('supports', ...
                cfg.region,'hourly')
            logmsg(['Hourly data are ' ...
                'not available for ' ...
                char(string(cfg.region)) '.']);
            return
        end

        S.ui.btnHourly.Enable = 'off';
        f.Pointer = 'watch';
        drawnow;

        try
            out = data_helpers('download', ...
                cfg,'hourly',ui);
        catch ME
            logmsg('Hourly data download failed:');
            logmsg(ME.message);
            out = struct('ok',false);
        end

        f.Pointer = 'arrow';
        drawnow;

        if isstruct(out) && isfield(out,'ok') && out.ok
            S.cache.worldInstallStatus = struct();
            S.runtime.worldCoverageDrawn = false;
        end
        refreshDataStatus();
        refreshPreview();
        refreshParamTable();

        if ~(isstruct(out) ...
                && isfield(out,'ok') ...
                && out.ok)
            try
                if data_helpers('supports', ...
                        cfg.region,'hourly')
                    S.ui.btnHourly.Enable = 'on';
                end
            catch
            end
        end
    end

    function onDownload15min(~,~)
        cfg = getConfigFromUI();
        ui = struct('fig',f,'logFcn',@logmsg);

        if ~data_helpers('supports', ...
                cfg.region,'15min')
            logmsg(['15-minute data are not available for ' ...
                char(string(cfg.region)) '.']);
            return
        end

        S.ui.btn15min.Enable = 'off';
        f.Pointer = 'watch';
        drawnow;

        try
            out = data_helpers('download', ...
                cfg,'15min',ui);
        catch ME
            logmsg('15-minute data download failed:');
            logmsg(ME.message);
            out = struct('ok',false);
        end

        f.Pointer = 'arrow';
        drawnow;

        if isstruct(out) && isfield(out,'ok') && out.ok
            S.cache.worldInstallStatus = struct();
            S.runtime.worldCoverageDrawn = false;
        end
        refreshDataStatus();
        refreshPreview();
        refreshParamTable();

        if ~(isstruct(out) ...
                && isfield(out,'ok') ...
                && out.ok)
            try
                if data_helpers('supports', ...
                        cfg.region,'15min')
                    S.ui.btn15min.Enable = 'on';
                end
            catch
            end
        end
    end

    function onOpenDataFolder(~,~)
    
        cfg = getConfigFromUI();    
        try
            d = char(string(cfg.dirD));
        catch
            d = '';
        end
    
        if isempty(d) ...
                || ~isfolder(d)
            uialert(f, ...
                ['Regional data folder ' ...
                'not found:' newline d], ...
                'Missing data folder');
            return
        end    
        try
            if ispc
                winopen(d);
            elseif ismac
                system(sprintf('open "%s" &',d));
            else
                system(sprintf('xdg-open "%s" &',d));
            end
        catch ME
            uialert(f, ...
                ['Could not open data folder:' newline ...
                 d newline newline ME.message], ...
                'Open folder failed');
        end
    end
    
    function onRightTabChanged(~,evt)
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));

        try
            if S.runtime.isRunning
                S.runtime.userSelectedRightTabDuringRun = true;
            end
        catch
        end

        try
            switch evt.NewValue

                case S.ui.tabSummary
                    refreshSummary();

                case S.ui.tabLog
                    refreshLogView();

                case S.ui.tabIter
                    refreshIterView();

                case S.ui.tabRegionMap
                    if ~S.runtime.mapInitialized
                        try
                            localInitializeNaturalEarthMap();
                        catch ME
                            logmsg(['Map initialization warning: ' ...
                                ME.message]);
                        end
                        S.runtime.mapInitialized = true;
                    end
                    refreshMapDropdown();
                    refreshRegion();
    
                case S.ui.tabZones
                    refreshZones();
    
                case S.ui.tabParamMap
                    % Refresh immediately when the tab is opened. Previously
                    % the old-region map remained visible until a later live
                    % iteration or another callback happened to redraw it.
                    refreshMapDropdown();
                    refreshParamMap();
                    hideParamMapAxes();
    
                case S.ui.tabZoneTable
                    refreshZoneSummaryTable();

                case S.ui.tabBasinResults
                    siteUi('refreshbasinresultstable');

                case S.ui.tabStatistics
                    refreshSiteStatistics(true);
    
                case S.ui.tabChecks
                    refreshReadiness();

                case S.ui.tabQuality
                    qualityDashboard('refresh',[]);
                    data_quality_dashboard_ui('layout',S.ui);
                    drawnow nocallbacks
                    fitSiteQualityColumns();

                case S.ui.tabPreview
                    refreshPreview();

                case S.ui.tabFeedback
                    updateFeedbackTab();
            end
    
        catch ME
            logmsg(['Tab refresh error: ' ...
                ME.message]);
        end
    end

    % ==============================
    %  Logging / iteration utilities
    % ==============================
    function logmsg(s)
        if isstring(s)
            s = char(s);
        end

        % Verification percentages replace one row, also when Log is hidden.
        progress = regexp(strtrim(s), ...
            '^Shared benchmarks: checking results \.\.\. \[(\d+)% Done\]$', ...
            'tokens','once');
        if ~isempty(progress)
            idx = [];
            if isfield(S.runtime,'benchmarkProgressIdx')
                idx = S.runtime.benchmarkProgressIdx;
            end
            t = string(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
            line = string(sprintf('[%s] %s',t,s));
            if isempty(idx) || idx > numel(S.store.logAll)
                S.store.logAll(end+1,1) = line;
                S.runtime.benchmarkProgressIdx = numel(S.store.logAll);
            else
                S.store.logAll(idx,1) = line;
            end
            if str2double(progress{1}) == 100
                S.runtime.benchmarkProgressIdx = [];
            end
            refreshLogView();localRendererYield(false);return
        end
        % A summary or failure closes an interrupted progress block.
        S.runtime.benchmarkProgressIdx = [];

        % The run callback reports the exact transition into
        % postprocessing through this callback. Use that event to keep the
        % Configuration status synchronized with the real pipeline phase.
        try
            sLower = lower(strtrim(s));
            beginsPostprocessing = ...
                ~isempty(regexp(sLower, ...
                '^\(\d+\)\s+postprocessing\s*\(', 'once'));
            if S.runtime.isRunning && beginsPostprocessing
                setGuiState('postprocessing','Postprocessing ...');
                refreshSummary();
                localRendererYield(true);
            end
        catch
        end

        t = string(datetime('now', ...
            'Format','yyyy-MM-dd HH:mm:ss'));
        line = sprintf('[%s] %s',t,s);
        S.store.logAll(end+1,1) = string(line);

        % Keep the Log view current even while another tab is selected.
        % The dashboard caps visible rows; rendering remains rate limited.
        refreshLogView();
        localRendererYield(false);
    end

    function logprogress(s,resetLine)

        if nargin < 2 ...
                || isempty(resetLine)
            resetLine = false;
        end
    
        finishLine = false;
        if ischar(resetLine) ...
                || isstring(resetLine)
            finishLine = strcmpi(char(resetLine),'finish');
            resetLine = false;
        end
    
        if isstring(s)
            s = char(s);
        end    
        t = string(datetime('now', ...
            'Format','yyyy-MM-dd HH:mm:ss'));
        line = sprintf('[%s] %s',t,s);    
        if resetLine ...
                || ~isfield(S.runtime,'logProgressIdx') ...
                || isempty(S.runtime.logProgressIdx) ...
                || S.runtime.logProgressIdx > numel(S.store.logAll)
    
            S.store.logAll(end+1,1) = string(line);
            S.runtime.logProgressIdx = numel(S.store.logAll);    
        else
            S.store.logAll(S.runtime.logProgressIdx,1) = string(line);
        end    
        % This makes the current progress row permanent.
        % The next progress block will start a new row.
        if finishLine
            S.runtime.logProgressIdx = [];
        end    
        refreshLogView();
        safeDrawnow();
    end

    function safeDrawnow()
        if S.runtime.isRunning
            drawnow limitrate nocallbacks
        else
            drawnow limitrate
        end    
    end
    function itermsg(s)
        if isstring(s)
            s = char(s);
        end

        lines = splitlines(string(s));
        lines(lines=="") = [];

        % Align print_SAGE separator lines with the printed table header.
        % print_SAGE creates a somewhat longer separator dynamically; in
        % the Iter tab, end the separator exactly beneath the final S_IB
        % character instead. This adapts automatically when the table
        % columns or loss-function label change.
        isSeparator = ~cellfun('isempty',regexp( ...
            cellstr(lines),'^\s*-{20,}\s*$','once'));
        if any(isSeparator)
            headerIdx = find(contains(lines,"S_IB"),1,'first');
            if ~isempty(headerIdx)
                separatorWidth = strlength(lines(headerIdx));
                lines(isSeparator) = string(repmat('-', ...
                    1,double(separatorWidth)));
            end
        end

        if isempty(lines)
            return
        end

        S.store.iterAll = [S.store.iterAll; lines(:)];

        % Store all iteration output, but render it only when the Iter tab
        % is visible. This prevents repeated transfer of a growing text
        % array to Chromium during every optimization iteration.
        try
            iterVisible = isequal( ...
                S.ui.tgRight.SelectedTab,S.ui.tabIter);
        catch
            iterVisible = false;
        end

        if S.flags.followIterTail ...
                && iterVisible
            refreshIterView();
            localRendererYield(false);
        end
    end

    function logErrorStack(prefix,ME)
        logmsg(prefix);
        logExceptionCause(ME,0);
    end

    function logExceptionCause(ME,depth)
        indent = repmat('  ',1,depth);

        if depth == 0
            logmsg(ME.message);
        else
            logmsg(sprintf('%sCaused by: %s',indent,ME.message));
        end

        for ii = 1:numel(ME.stack)
            logmsg(sprintf('%s  at %s (line %d)', ...
                indent,ME.stack(ii).name,ME.stack(ii).line));
        end

        causes = ME.cause;
        for ii = 1:numel(causes)
            logExceptionCause(causes{ii},depth + 1);
        end
    end

    function parameterLiveUpdate(i,nTheta,bas) %#ok<INUSD>
        % Store latest parameter estimates for live diagnostics.
        % Do not redraw Region/Country here: that information is fixed.
        % Do not redraw Map here either; runtimeUpdate() handles live refreshes
        % once per completed iteration, avoiding duplicate redraws.
        S.runtime.latestNTheta = nTheta;
        S.runtime.latestBas = bas;
    end

    function informationLiveUpdate(i,A,H,nTheta,net,mdl,bas)
        snapshot = struct('i',i,'A',A,'H',{H},'nTheta',nTheta, ...
            'net',net,'mdl',mdl,'bas',bas);
        S.runtime.informationSnapshot = snapshot;
    end

    function localRecordInformationTime(elapsed,iteration)
        % Record only the actual, uncached information-theory calculation.
        % This helper is used irrespective of whether the calculation was
        % requested by a tab callback or by the completed-iteration update.
        try
            elapsed = double(elapsed);
            iteration = max(1,round(double(iteration)));
            if ~isscalar(elapsed) || ~isfinite(elapsed) || elapsed < 0
                return
            end
            if numel(S.runtime.informationTime) < iteration
                S.runtime.informationTime(iteration) = 0;
            end
            S.runtime.informationTime(iteration) = ...
                S.runtime.informationTime(iteration) + elapsed;
            if isstruct(S.runtime.lastOut) ...
                    && isfield(S.runtime.lastOut,'prf')
                S.runtime.lastOut.prf.cpuT_info = ...
                    S.runtime.informationTime;
                S.runtime.lastOut.prf.wallT_info = sum( ...
                    S.runtime.informationTime,'omitnan');
            end
        catch
        end
    end

    function qualityDashboard(action,payload)
        themeCleanup = onCleanup(@() ...
            site_styleOutputMonitoringBackgrounds(S.ui.tgRight,f.Color));

        if strcmp(action,'update')
            S.runtime.quality = payload;
            S.runtime.qualityRow = 1;
            if isstruct(payload) && isfield(payload,'active_bas') ...
                    && ~isempty(payload.active_bas)
                applyActiveBasinScreening(payload);
            end
            syncQualityScreeningRunNotes(payload);
        elseif strcmp(action,'select')
            % MATLAB can emit an empty CellSelection event while the user
            % drags a uitable scrollbar. Rebuilding tblQuality in response
            % resets its horizontal scroll position and makes it jump back
            % to the left. It can also repeat the previously selected cell
            % during a scrollbar drag. Neither event should redraw the
            % dashboard or disturb the table viewport.
            if isempty(payload.Indices)
                return
            end
            selectedRow = payload.Indices(1,1);
            if isfield(S.runtime,'qualityRow') ...
                    && isequal(S.runtime.qualityRow,selectedRow)
                return
            end
            S.runtime.qualityRow = selectedRow;
            action = 'plots';
        end
        quality = [];
        row = 1;
        if isfield(S.runtime,'quality')
            quality = S.runtime.quality;
        end
        if isfield(S.runtime,'qualityRow')
            row = S.runtime.qualityRow;
        end
        if strcmp(action,'plots')
            data_quality_dashboard_ui('plots',S.ui,quality,row);
        else
            data_quality_dashboard_ui('refresh',S.ui,quality,row);
            data_quality_dashboard_ui('basins',S.ui,quality);
        end
        if strcmp(action,'update')
            % Show screening colors and Run Notes before run_SITE proceeds
            % to result setup or starts the parallel pool.
            localRendererYield(true);
        end
    end

    function applyActiveBasinScreening(quality)
        % Preserve the Basins-tab rows and their original numbering. Only
        % the postprocessing tables need active-population indices.

        activeBas = quality.active_bas;
        S.runtime.activeBasins = activeBas;
        if isfield(quality,'active_latlon')
            S.runtime.activeLatLon = quality.active_latlon;
        end

        idTrainActive = activeBas.id_gauge(1:activeBas.K_t);
        idEvalActive = activeBas.id_gauge( ...
            activeBas.K_t+1:activeBas.K_t+activeBas.K_e);

        reindexScreenedTable(S.ui.tblPostTrain,idTrainActive,4,[2 3],0);
        reindexScreenedTable(S.ui.tblPostEval,idEvalActive,4,[2 3], ...
            activeBas.K_t);

        % The filtered basin structure now matches the active row indices
        % used by maps, diagnostics, postprocessing, and exported scripts.
        S.runtime.preparedBasins = activeBas;
        if isfield(quality,'active_latlon')
            S.runtime.preparedLatLon = quality.active_latlon;
        end
        updateZoneSummary(activeBas.zone);
        try
            refreshSummary();
        catch
        end

        function reindexScreenedTable(tbl,activeGaugeIds, ...
                gaugeColumn,selectionColumns,offset)
            if ~isgraphics(tbl) || isempty(tbl.Data)
                return
            end
            D = tbl.Data;
            tableGauge = localQualityGaugeKey(D(:,gaugeColumn));
            activeGauge = localQualityGaugeKey(activeGaugeIds);
            [active,index] = ismember(tableGauge,activeGauge);
            for row = 1:size(D,1)
                if active(row)
                    D{row,1} = offset + index(row);
                else
                    D{row,1} = [];
                    for column = selectionColumns
                        D{row,column} = false;
                    end
                end
            end
            tbl.Data = D;
        end

        function key = localQualityGaugeKey(values)
            key = upper(strip(string(values(:))));
            key = regexprep(key,'[^A-Z0-9]','');
            numericOnly = ~cellfun('isempty', ...
                regexp(cellstr(key),'^[0-9]+$','once'));
            key(numericOnly) = regexprep( ...
                key(numericOnly),'^0+(?=[0-9])','');
            key(key == "") = "0";
        end
    end

    function onQualityTableSelected(~,event)
        qualityDashboard('select',event);
    end

    function runtimeUpdate(outLive)

        runtimeUpdateTimer = tic;

        % The live pipeline snapshot does not own GUI diagnostic timings.
        % Reattach the history retained by the GUI before exposing outLive
        % to any dashboard.  Otherwise the Summary briefly sees no
        % cpuT_info field at the start of every iteration and displays 0 s.
        try
            if isfield(outLive,'prf')
                outLive.prf.cpuT_info = S.runtime.informationTime;
                outLive.prf.wallT_info = sum( ...
                    S.runtime.informationTime,'omitnan');
            end
        catch
        end
        S.runtime.lastOut = outLive;

        % Completed iterations available in live output
        try
            nDone = runtimeCompletedIterations(outLive);
        catch
            nDone = 0;
        end

        if nDone >= 1
            S.runtime.summaryAutoRefreshed = true;
        end

        % The configuration is locked while SAGE is running. Therefore,
        % Preview and Checks do not need to be rebuilt each iteration.
        % Log and Iter views are already refreshed by logmsg/itermsg.
        try
            activeTab = S.ui.tgRight.SelectedTab;
        catch
            activeTab = [];
        end

        % The detailed Summary is refreshed at the end of this callback,
        % after all diagnostic timings for the iteration have been booked.

        % Refresh expensive diagnostics only when visible and only at their
        % configured cadence. Opening a tab still forces an immediate refresh
        % through onRightTabChanged().
        if isequal(activeTab,S.ui.tabZoneTable) ...
                && localRefreshDue(nDone,S.perf.refreshEvery.zoneTable)
            try
                refreshZoneSummaryTable();
                S.runtime.lastZoneTableUpdate = tic;
            catch ME
                logmsg(['Zone table refresh warning: ' ME.message]);
            end
        end

        if nDone >= 1 ...
                && isequal(activeTab,S.ui.tabParamMap) ...
                && localRefreshDue(nDone,S.perf.refreshEvery.paramMap)
            try
                refreshMapDropdown();
                refreshParamMap();
                S.runtime.lastParamMapUpdate = tic;
            catch ME
                logmsg(['Parameter map refresh warning: ' ME.message]);
            end
        end

        if isequal(activeTab,S.ui.tabFeedback)
            try
                updateFeedbackTab();
            catch ME
                logmsg(['Feedback refresh warning: ' ME.message]);
            end
        end

        % Region and Zones are fixed after basin preparation. Trace and
        % Attribution retain their dedicated visible-tab update cadences.
        % Do not issue an unconditional DRAWNOW here: runtimeUpdate can be
        % called after every completed iteration and would otherwise add
        % renderer pressure even when no visible object changed.
        localRendererYield(false);

        % Charge completed-iteration dashboard work to GUI time. This is
        % especially important for deferred Excess MI, which is evaluated
        % here only after CAMELS has released the basin workers. Adding the
        % same elapsed time to cpuT_gui and cpuT_total leaves hydrologic
        % model time (cpuT) unchanged.
        runtimeUpdateElapsed = toc(runtimeUpdateTimer);
        try
            if nDone >= 1 ...
                    && isfield(outLive,'prf')
                outLive.prf.cpuT_info = S.runtime.informationTime;
                outLive.prf.wallT_info = sum( ...
                    S.runtime.informationTime,'omitnan');
                if isfield(outLive.prf,'cpuT_gui') ...
                        && numel(outLive.prf.cpuT_gui) >= nDone
                    outLive.prf.cpuT_gui(nDone) = ...
                        outLive.prf.cpuT_gui(nDone) + runtimeUpdateElapsed;
                end
                if isfield(outLive.prf,'cpuT_total') ...
                        && numel(outLive.prf.cpuT_total) >= nDone
                    outLive.prf.cpuT_total(nDone) = ...
                        outLive.prf.cpuT_total(nDone) + runtimeUpdateElapsed;
                end
                if isfield(outLive.prf,'cpuT_gui')
                    outLive.prf.wallT_gui = max(0,sum( ...
                        outLive.prf.cpuT_gui(1:nDone),'omitnan') ...
                        - outLive.prf.wallT_info);
                end
                try
                    outLive.prf.wallT_total = seconds( ...
                        datetime('now')-S.runtime.startTime);
                catch
                end
                S.runtime.lastOut = outLive;
            end
        catch
        end

        % The first Summary refresh above occurs before the diagnostic work
        % for this completed iteration is timed.  Refresh it once more after
        % booking that time so the displayed Information theory value is the
        % cumulative total through nDone and never falls back to zero.
        if isequal(activeTab,S.ui.tabSummary)
            try
                perfUpdateOnce(false);
            catch ME
                logmsg(['Summary timing refresh warning: ' ME.message]);
            end
        end

    end


    function nDone = runtimeCompletedIterations(outLive)
        nDone = 0;
        try
            if isfield(outLive,'lastIter') ...
                    && isfinite(double(outLive.lastIter))
                nDone = max(0,round(double(outLive.lastIter)));
                return
            end
        catch
        end
        try
            if isfield(outLive,'prf') ...
                    && isfield(outLive.prf,'iter') && isfield(outLive.prf.iter,'cpuT')
                nDone = max(nDone, ...
                    numel(outLive.prf.iter.cpuT));
            end
        catch
        end
        try
            if isfield(outLive,'prf') ...
                    && isfield(outLive.prf,'cpuT_gui')
                nDone = max(nDone, ...
                    numel(outLive.prf.cpuT_gui));
            end
        catch
        end
        try
            if isfield(S.runtime,'attr') ...
                    && isfield(S.runtime.attr,'last_i')
                nDone = max(nDone,double( ...
                    S.runtime.attr.last_i));
            end
        catch
        end
    end

    function toggleAdvancedMode(isAdvanced)

        S.flags.advancedMode = logical(isAdvanced);

        % -----------------------
        % Tab titles / visibility
        % -----------------------
        if S.flags.advancedMode
            S.ui.tabODE.Title = ...
                'ODE | Solver';
        else
            S.ui.tabODE.Title = ...
                'Solver';
        end
        S.ui.tabLoss.Title = 'Loss function';
        S.ui.tabTrain.Title = 'Training';
        try
            if S.flags.advancedMode
                S.ui.tabTrain.Visible = 'on';
            else
                if isequal(S.ui.tgLeft.SelectedTab, ...
                        S.ui.tabTrain)
                    S.ui.tgLeft.SelectedTab = ...
                        S.ui.tabLoss;
                end
                S.ui.tabTrain.Visible = 'off';
            end
        catch
        end

        % --------------------------
        % ODE tab
        % simple mode: keep only mem
        % --------------------------
        setVisibleSafe(S.ui.edInitStep, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edMaxStep, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edMinStep, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edRelTol, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edAbsTol, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.spOrder, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.spMaxIterODE, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.btnODEDefaults, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.txtODEHelp, ...
            S.flags.advancedMode);

        % keep mem always visible
        setVisibleSafe(S.ui.ddMem,true);

        % ------------------------
        % Loss / Training tabs
        % ------------------------
        setVisibleSafe(S.ui.ddOpt, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.spImax, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edLR, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.ddLRSchedule, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edLRmin, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edLRhold, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edBeta1, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edBeta2, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edVarEps, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.edWdec, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.spClipn, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.btnOptDefaults, ...
            S.flags.advancedMode);

        % notes panels
        setVisibleSafe(S.ui.pLossHelp,true);
        setVisibleSafe(S.ui.lblLossEq,true);
        setVisibleSafe(S.ui.pOptHelp, ...
            S.flags.advancedMode);
        setVisibleSafe(S.ui.lblOptEq, ...
            S.flags.advancedMode);

        refreshLossHelpText();
        refreshOptHelpText();
    end


    function syncPostprocessScenarioControls()

        % During a run, updateLockState disables these controls only to
        % prevent editing.  Their checked values still describe the
        % requested scenarios and must not be interpreted as inactive.
        runLocked = isfield(S.runtime,'isRunning') ...
            && logical(S.runtime.isRunning);
        tt = logical(S.ui.cbScenTT.Value) ...
            && (runLocked || strcmp(S.ui.cbScenTT.Enable,'on'));
        te = logical(S.ui.cbScenTE.Value) ...
            && (runLocked || strcmp(S.ui.cbScenTE.Enable,'on'));
        et = logical(S.ui.cbScenET.Value) ...
            && (runLocked || strcmp(S.ui.cbScenET.Enable,'on'));
        ee = logical(S.ui.cbScenEE.Value) ...
            && (runLocked || strcmp(S.ui.cbScenEE.Enable,'on'));

        showTrain = tt ...
            || te;
        showEval = et ...
            || ee;

        % ------------------------------------
        % Show/hide training basin table block
        % ------------------------------------
        try
            S.ui.lblPostTrain.Visible = ...
                tern(showTrain,'on','off');
            S.ui.tblPostTrain.Visible = ...
                tern(showTrain,'on','off');
        catch
        end

        % --------------------------------------
        % Show/hide evaluation basin table block
        % --------------------------------------
        try
            S.ui.lblPostEval.Visible = ...
                tern(showEval,'on','off');
            S.ui.tblPostEval.Visible = ...
                tern(showEval,'on','off');
        catch
        end

        % Give the visible basin table(s) the full selection panel.  Merely
        % hiding the evaluation table leaves its two grid rows behind and
        % makes the training table appear to occupy only half the panel.
        try
            if isfield(S.ui,'gPostBasins') ...
                    && isgraphics(S.ui.gPostBasins)
                if showTrain && showEval
                    S.ui.gPostBasins.RowHeight = ...
                        {20,'1x',20,'1x'};
                elseif showTrain
                    S.ui.gPostBasins.RowHeight = ...
                        {20,'1x',0,0};
                elseif showEval
                    S.ui.gPostBasins.RowHeight = ...
                        {0,0,20,'1x'};
                else
                    S.ui.gPostBasins.RowHeight = ...
                        {0,0,0,'1x'};
                end
            end
        catch
        end

        % ------------------------------------------------
        % Enable/disable Train/Eval columns in train table
        % ------------------------------------------------
        try
            S.ui.tblPostTrain.ColumnEditable = ...
                [false tt te false false false];
        catch
        end

        % -----------------------------------------------
        % Enable/disable Train/Eval columns in eval table
        % -----------------------------------------------
        try
            S.ui.tblPostEval.ColumnEditable = ...
                [false et ee false false false];
        catch
        end

        % ---------------------------------------------------
        % If a scenario is off, clear its corresponding flags
        % ---------------------------------------------------
        try
            D = S.ui.tblPostTrain.Data;
            if ~isempty(D)
                colTT = cell2mat(D(:,2));
                colTE = cell2mat(D(:,3));
                if ~tt
                    for ii = 1:size(D,1)
                        D{ii,2} = false;
                    end
                    colTT = false(size(colTT));
                end
                if ~te
                    for ii = 1:size(D,1)
                        D{ii,3} = false;
                    end
                    colTE = false(size(colTE));
                end
                % if TT is enabled and empty, inherit from TE
                if tt ...
                        && ~any(colTT) ...
                        && any(colTE)
                    for ii = 1:size(D,1)
                        D{ii,2} = D{ii,3};
                    end
                end
                % if TE is enabled and empty, inherit from TT
                if te ...
                        && ~any(colTE) ...
                        && any(colTT)
                    for ii = 1:size(D,1)
                        D{ii,3} = D{ii,2};
                    end
                end
                S.ui.tblPostTrain.Data = D;
            end
        catch
        end

        try
            D = S.ui.tblPostEval.Data;
            if ~isempty(D)
                colET = cell2mat(D(:,2));
                colEE = cell2mat(D(:,3));
                if ~et
                    for ii = 1:size(D,1)
                        D{ii,2} = false;
                    end
                    colET = false(size(colET));
                end
                if ~ee
                    for ii = 1:size(D,1)
                        D{ii,3} = false;
                    end
                    colEE = false(size(colEE));
                end
                % if ET is enabled and empty, inherit from EE
                if et && ~any(colET) && any(colEE)
                    for ii = 1:size(D,1)
                        D{ii,2} = D{ii,3};
                    end
                end
                % if EE is enabled and empty, inherit from ET
                if ee && ~any(colEE) && any(colET)
                    for ii = 1:size(D,1)
                        D{ii,3} = D{ii,2};
                    end
                end
                S.ui.tblPostEval.Data = D;
            end
        catch
        end

        % -----------------
        % Helpful hint text
        % -----------------
        try
            if ~showTrain ...
                    && ~showEval
                S.ui.lblPostHint.Text = ...
                    'No scenarios selected.';
            elseif showTrain ...
                    && ~showEval
                if tt ...
                        && ~te
                    S.ui.lblPostHint.Text = ...
                        ['Only training basins ' ...
                        '| training period is active.'];
                elseif ~tt ...
                        && te
                    S.ui.lblPostHint.Text = ...
                        ['Only training basins ' ...
                        '| evaluation period is active.'];
                else
                    S.ui.lblPostHint.Text = ...
                        ['Only training-basin ' ...
                        'scenarios are active.'];
                end
            elseif ~showTrain ...
                    && showEval
                if et ...
                        && ~ee
                    S.ui.lblPostHint.Text = ...
                        ['Only evaluation basins ' ...
                        '| training period is active.'];
                elseif ~et ...
                        && ee
                    S.ui.lblPostHint.Text = ...
                        ['Only evaluation basins ' ...
                        '| evaluation period is active.'];
                else
                    S.ui.lblPostHint.Text = ...
                        ['Only evaluation-basin ' ...
                        'scenarios are active.'];
                end
            else
                S.ui.lblPostHint.Text = ...
                    ['Training and evaluation basin ' ...
                    'scenarios are active.'];
            end
        catch
        end

        % Scenario synchronization may clear an inactive column, but the
        % requested spinner counts remain authoritative. Re-realize those
        % counts in the active columns instead of shrinking the spinners.
        postprocess_basin_selection_ui('stable',S.ui, ...
            @local_adjust_selection_mask, ...
            @local_available_table_rows,@local_column_selection);
    end

    function syncPostScenariosFromPeriod()

        if isfield(S.runtime,'isRunning') ...
                && S.runtime.isRunning
            return
        end

        try
            cfg = getConfigFromUI();
        catch
            return
        end
        Ke = 0;
        try
            Ke = double(cfg.bas.K_e);
        catch
        end
        % start from everything off and disabled
        S.ui.cbScenTT.Value = false;
        S.ui.cbScenTE.Value = false;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;

        S.ui.cbScenTT.Enable = 'off';
        S.ui.cbScenTE.Enable = 'off';
        S.ui.cbScenET.Enable = 'off';
        S.ui.cbScenEE.Enable = 'off';

        % Use the configuration just read from the current controls. This
        % prevents a previous run from leaving evaluation-period columns
        % active after both manual evaluation dates are cleared.
        if isfield(cfg.mdl,'mode') ...
                && ~isempty(cfg.mdl.mode)
            mode = double(cfg.mdl.mode);
        elseif Ke > 0
            mode = 4;
        else
            mode = 2;
        end

        switch mode
            case 1
                % train basins | train period only
                S.ui.cbScenTT.Value = true;
                S.ui.cbScenTT.Enable = 'on';
            case 2
                % train basins | train + eval period
                S.ui.cbScenTT.Value = true;
                S.ui.cbScenTE.Value = true;

                S.ui.cbScenTT.Enable = 'on';
                S.ui.cbScenTE.Enable = 'on';
            case 3
                % train + eval basins | training period only
                S.ui.cbScenTT.Value = true;
                S.ui.cbScenTT.Enable = 'on';
                if Ke > 0
                    S.ui.cbScenET.Value = true;
                    S.ui.cbScenET.Enable = 'on';
                end
            case 4
                % all four scenarios available
                S.ui.cbScenTT.Value = true;
                S.ui.cbScenTE.Value = true;
                S.ui.cbScenTT.Enable = 'on';
                S.ui.cbScenTE.Enable = 'on';
                if Ke > 0
                    S.ui.cbScenET.Value = true;
                    S.ui.cbScenEE.Value = true;
                    S.ui.cbScenET.Enable = 'on';
                    S.ui.cbScenEE.Enable = 'on';
                end
            otherwise
                % safe fallback
                S.ui.cbScenTT.Value = true;
                S.ui.cbScenTT.Enable = 'on';
                if Ke > 0
                    S.ui.cbScenET.Value = true;
                    S.ui.cbScenET.Enable = 'on';
                end
        end
        syncPostprocessScenarioControls();
    end

    % =======================================
    %  Runtime update callbacks from pipeline
    % =======================================
    function logbannerOrConus(payload,bas)
        if isnumeric(payload)
            conusPlotPlain(payload,bas);
            return
        end
        if isstring(payload)
            payload = cellstr(payload);
        end
        if ischar(payload)
            payload = {payload};
        end
        if iscell(payload)
            for iLine = 1:numel(payload)
                logmsg(char(payload{iLine}));
            end
        end
    end

    function conusLiveUpdate(i,nTheta,bas)

        if mod(i,5) ~= 0
            return
        end    
        if isempty(S.runtime.preparedLatLon)
            return
        end    
        S.runtime.latestNTheta = nTheta;
        S.runtime.latestBas = bas;    
        refreshParamMap();    
    end

    function updatePreviewRuntime(R)
        S.runtime.previewRuntime = R;
        refreshPreview();
    end

    function updateFeedbackTab()
        if ~isfield(S.ui,'txtLastError') ...
                || isempty(S.ui.txtLastError)
            return
        end
    
        if ~isfield(S.runtime,'lastError') ...
                || isempty(S.runtime.lastError)
            lines = {['No recent errors ' ...
                'or warnings.']};
        else
            lines = cellstr(splitlines( ...
                string(S.runtime.lastError)));
            lines = lines(~cellfun( ...
                @isempty,lines));
            if isempty(lines)
                lines = {['No recent ' ...
                    'errors or warnings.']};
            end
        end
        S.ui.txtLastError.Value = lines;
        n = numel(lines);
        h = min(420,max(70,22*n + 24));    
        try
            S.ui.gFeedback.RowHeight = ...
                {28,h,'1x'};
        catch
        end
    end

    function applyBasinUniverseDefaults()
        % SITE trains every basin in its active universe.
        Kcns = str2double(char(S.ui.ddKcns.Value));
        if ~isfinite(Kcns) || Kcns < 1, Kcns = 1; end
        S.ui.spKt.Value = round(Kcns);
        S.ui.spKe.Value = 0;
        updateDefaultBasinSplitFile();
    end

    function siteSetBasinCount(K)
        % The sole SITE count follows the selected or quality-screened list.
        K = max(0,round(double(K)));
        item = sprintf('%d',K);
        S.ui.ddKcns.Items = {item};
        S.ui.ddKcns.Value = item;
        S.ui.ddKcns.Enable = 'off';
        try
            display = findobj(S.ui.ddKcns.Parent, ...
                'Tag','SITEAvailableBasinCount');
            if ~isempty(display), display(1).Value = K; end
        catch
        end
        S.ui.spKt.Value = K;
        S.ui.spKe.Value = 0;
    end

    function applyRegionBasinDefaults()
    %APPLYREGIONBASINDEFAULTS Apply SITE training-basin defaults.

        X = getCurrentResolutionConfig();
        K = double(X.basins.universe(:)');
        try
            regionCfg = S.cfg;
            regionCfg.region = region_helpers('code',S.ui.ddRegion.Value);
            regionCfg.root = char(S.ui.edRoot.Value);
            regionCfg.SAGEhydro = char(S.ui.edSAGE.Value);
            fileName = char(string(X.basins.file));
            listFile = local_basin_absolute_file(regionCfg,fileName);
            Klist = site_basin_list_count(listFile);
            if Klist > 0, K = Klist; end
        catch
        end

        items = arrayfun(@(v)sprintf('%d',round(v)), ...
            K,'UniformOutput',false);
        oldValue = "";
        try
            oldValue = string(S.ui.ddKcns.Value);
        catch
        end

        S.ui.ddKcns.Items = items;
        hit = find(strcmp(char(oldValue),items),1);
        if isempty(hit)
            S.ui.ddKcns.Value = items{1};
        else
            S.ui.ddKcns.Value = items{hit};
        end

        S.ui.ddKcns.Enable = 'off';
        Kselected = str2double(char(S.ui.ddKcns.Value));
        siteSetBasinCount(Kselected);
        updateDefaultBasinSplitFile();
    end

    function updateDefaultBasinSplitFile()

        K_t = str2double(char(S.ui.ddKcns.Value));
        K = str2double(char(S.ui.ddKcns.Value));
        region = region_helpers('code', ...
            S.ui.ddRegion.Value);
        tag = region_helpers('short',region);
        % SITE uses every basin in its selected list; there is no held-out
        % evaluation-basin population in its split-file name.
        splitKt = K_t;
        splitKe = max(0,round(K-K_t));

        % Prefer the explicit resolution-specific universe file declared
        % by region_config_XX.m. This prevents daily/hourly products with
        % different basin populations from accidentally sharing a file.
        universeFile = '';
        try
            X = getCurrentResolutionConfig();
            if isfield(X,'basins') ...
                    && isfield(X.basins,'file') ...
                    && ~isempty(X.basins.file)
                universeFile = char(string(X.basins.file));
            end
        catch
        end

        if isempty(universeFile)
            universeFile = sprintf('%s_%d_basins.txt',tag,K);
        end
        S.cfg.file_univ = universeFile;

        seed = 1;
        try
            seed = round(double(S.ui.spBasinSeed.Value));
        catch
        end
        S.cfg.file_split = sprintf( ...
            'split_%s_%d_%d_%d_%d.txt', ...
            tag,K,splitKt,splitKe,seed);
        S.cfg.bas.seed = seed;
        S.cfg.bas.rng_type = 'twister';
        S.ui.edBasinFile.Value = S.cfg.file_split;

    end

    function updateBprtFromPostTables()

        % Empty tables mean that basins have not yet been prepared. Keep
        % the configured defaults instead of replacing them with zero.
        if isempty(S.ui.tblPostTrain.Data) ...
                && isempty(S.ui.tblPostEval.Data)
            return
        end

        nTrain = 0;
        nEval = 0;
        try
            D = S.ui.tblPostTrain.Data;
            if ~isempty(D)
                sel = false(size(D,1),1);
                if size(D,2) >= 3
                    sel = logical(cell2mat(D(:,2))) ...
                        | logical(cell2mat(D(:,3)));
                end
                nTrain = nnz(sel);
            end
        catch
        end
        try
            D = S.ui.tblPostEval.Data;
            if ~isempty(D)
                sel = false(size(D,1),1);
                if size(D,2) >= 3
                    sel = logical(cell2mat(D(:,2))) ...
                        | logical(cell2mat(D(:,3)));
                end
                nEval = nnz(sel);
            end
        catch
        end
        try
            nTrain = min(max(nTrain,S.ui.spBprtTrain.Limits(1)), ...
                S.ui.spBprtTrain.Limits(2));
            nEval = min(max(nEval,S.ui.spBprtEval.Limits(1)), ...
                S.ui.spBprtEval.Limits(2));
            S.ui.spBprtTrain.Value = nTrain;
            S.ui.spBprtEval.Value = nEval;
        catch
        end
    end

    % ==================
    %  Performance timer
    % ==================
    function startPerfTimer()

        if isfield(S.perf,'timer') ...
                && localIsValidObject(S.perf.timer)
            return
        end
        S.perf.timer = timer( ...
            'ExecutionMode','fixedSpacing', ...
            'Period',60, ...
            'BusyMode','drop', ...
            'TimerFcn',@(~,~)safePerfTimerUpdate());
        start(S.perf.timer);
    end

    function safePerfTimerUpdate()

        if isempty(f) ...
                || ~isgraphics(f)
            return
        end    
        % Do not allow timer-driven UI updates while SAGE is running.
        if S.runtime.isRunning
            return
        end    
    end

    function perfUpdateOnce(forceFixed)
        if nargin < 1
            forceFixed = false;
        end
        if isempty(f) ...
                || ~isgraphics(f)
            return
        end
        forceFixed = forceFixed || ~S.perf.fixedReady;
        if isempty(S.perf.cache.matlab)
            try
                S.perf.cache.matlab = matlab_release_label_ui();
            catch
                S.perf.cache.matlab = 'MATLAB';
            end
            try S.perf.cache.arch = computer('arch');
            catch
                S.perf.cache.arch = '';
            end
            try
                S.perf.cache.machine = ...
                    char(getenv('COMPUTERNAME'));
                if isempty(S.perf.cache.machine)
                    S.perf.cache.machine = ...
                        char(java.net.InetAddress. ...
                        getLocalHost.getHostName);
                end
            catch
                S.perf.cache.machine = '-';
            end
            try
                S.perf.cache.ncores = ...
                    feature('numcores');
            catch
                S.perf.cache.ncores = [];
            end
        end
        S.ui.txtMatlab.Text = ...
            sprintf('%s (%s)', ...
            S.perf.cache.matlab, ...
            S.perf.cache.arch);
        S.ui.txtMachine.Text = ...
            S.perf.cache.machine;
        S.ui.txtCores.Text = ...
            localPrettyCoreCount( ...
            S.perf.cache.ncores);
        try
            p = gcp('nocreate');
            if isempty(p)
                S.ui.txtPool.Text = 'none';
            else
                S.ui.txtPool.Text = ...
                    sprintf('%d workers', ...
                    p.NumWorkers);
            end
        catch
            S.ui.txtPool.Text = '-';
        end
        try
            S.ui.txtMem.Text = ...
                localMatlabMemoryString();
        catch
            S.ui.txtMem.Text = '-';
        end

        % CPU is live but sampled at a bounded cadence because the Windows
        % query starts an external process. Pool and MATLAB memory above
        % are inexpensive enough to refresh on every Summary update.
        cpuDue = forceFixed;
        try
            cpuDue = cpuDue ...
                || toc(S.perf.tCPU) >= S.perf.cpuEvery;
        catch
            cpuDue = true;
        end
        if cpuDue
            try
                S.ui.txtCPU.Text = ...
                    localCpuUsageEstimate();
            catch
                S.ui.txtCPU.Text = '-';
            end
            S.perf.tCPU = tic;
        end

        % Disk space and recursive Data-folder size are fixed snapshots
        % during a run. Recompute only at run start or explicit Refresh.
        if forceFixed
            try
                S.ui.txtDisk.Text = ...
                    localDiskFreeString(pwd);
            catch
                if isprop(S.ui.txtDisk,'Text')
                    S.ui.txtDisk.Text = '-';
                end
            end
            try
                S.ui.txtDataStorage.Text = ...
                    localDataStorageString( ...
                        getConfigFromUI().dirDroot);
            catch
                S.ui.txtDataStorage.Text = '-';
            end
            S.perf.tHeavy = tic;
            S.perf.fixedReady = true;
        end
    end

    function onSummaryRefresh(~,~)
        perfUpdateOnce(true);
    end

    function localRendererYield(force)
        % Throttled gateway for all run-time access to the uifigure
        % renderer. Keep callbacks enabled so tab changes, refresh buttons,
        % and Stop requests remain responsive while basin futures arrive.
        if nargin < 1
            force = false;
        end

        if isempty(f) ...
                || ~isgraphics(f)
            return
        end

        due = force;
        try
            due = due ...
                || toc(S.runtime.lastGuiDrawClock) >= ...
                S.runtime.guiDrawPeriod;
        catch
            due = true;
        end

        if ~due
            return
        end

        try
            S.runtime.lastGuiDrawClock = tic;
            if force
                % Explicit feedback boundaries must not be skipped by
                % drawnow's rate limiter (for example before parpool).
                drawnow
            else
                drawnow limitrate
            end
        catch
        end
    end

    % =====================
    %  UI setters / getters
    % =====================
    function setUIFromConfig(C)
        if isfield(C,'model_options'),S.store.modelOptions=C.model_options;end
        % paths
        if ~isdeployed
            S.ui.edRoot.Value = char(C.root);
        end
        if isfield(C,'SITEhydro') && isfolder(C.SITEhydro)
            S.ui.edSITE.Value = char(C.SITEhydro);
        else
            S.ui.edSITE.Value = fullfile( ...
                char(S.ui.edRoot.Value),'SITEhydrology');
        end
        if isfield(C,'SAGEhydro') && isfolder(C.SAGEhydro)
            S.ui.edSAGE.Value = char(C.SAGEhydro);
        else
            S.ui.edSAGE.Value = fullfile( ...
                char(S.ui.edRoot.Value),'SAGEhydrology');
        end
        if isfield(C,'dirDroot') ...
                && ~isempty(C.dirDroot)
            S.ui.edDataLocation.Value = char(C.dirDroot);
        else
            S.ui.edDataLocation.Value = fullfile(char(C.root),'Data');
        end
        S.ui.edRes.Value = char(C.dirres);
        if isfield(S.ui,'ddRegion') ...
                && isvalid(S.ui.ddRegion)
            region = region_helpers('code',C);
            try
                if isfield(S.ui,'ddCountry') ...
                        && isvalid(S.ui.ddCountry)
                    paths_region_tabs_ui('geography',S.ui,localRegionPanelName(region));
                end
                refreshDatasetSelector(region,false);
                S.ui.ddRegion.Value = region;
                S.ui.tabRegionMap.Title = ...
                    localRegionPanelName(region);
            catch
                S.ui.tabRegionMap.Title = 'Unknown';
            end
        end
        if isfield(S.ui,'edDataRoot') ...
                && isvalid(S.ui.edDataRoot)
            S.ui.edDataRoot.Value = ...
                char(S.ui.edDataLocation.Value);
        end
        if isfield(S.ui,'edData') ...
                && isvalid(S.ui.edData)
            S.ui.edData.Value = char(C.dirD);
        end

        % model
        modelValue = local_model_name_from_id(C.mdl.model);
        if local_is_gchm_ode(C.mdl)
            modelValue = 'gchm_ode';
        end
        if local_user_model_available(C.root) ...
                && C.mdl.model == 99
            modelValue = 'user_model';
            S.cfg.mdl.model = 99;
        end
        if any(strcmp(S.ui.ddModel.ItemsData, ...
                modelValue))
            S.ui.ddModel.Value = ...
                modelValue;
        else
            S.ui.ddModel.Value = ...
                S.ui.ddModel.ItemsData{1};
        end

        itemsMcode = S.ui.ddMcode.Items;
        pick = find(startsWith( ...
            string(itemsMcode), ...
            string(C.mdl.mcode)), ...
            1,'first');
        if ~isempty(pick)
            S.ui.ddMcode.Value = ...
                itemsMcode{pick};
        end
        % Older sessions may contain calc = 'par' (parfor). The GUI now
        % exposes parfeval as the single parallel implementation because it
        % provides better load balancing and responsiveness for basin-wise
        % SAGE calculations.
        calcValue = char(C.mdl.calc);
        if strcmpi(calcValue,'par')
            calcValue = 'parfeval';
            C.mdl.calc = 'parfeval';
        end
        if ~ismember(calcValue,S.ui.ddCalc.ItemsData)
            calcValue = 'parfeval';
            C.mdl.calc = 'parfeval';
        end
        S.ui.ddCalc.Value = calcValue;

        % Resolution menus are region dependent. Rebuild Items for the
        % restored region before assigning the saved Value. In particular,
        % an hourly recovery session may be loaded while the startup region
        % exposes only Daily; assigning Hourly before this rebuild causes
        % MATLAB to reject the Value and abort the entire restore.
        if C.prd.dt == 96
            savedResolution = '15 minutes';
        elseif C.prd.dt == 24
            savedResolution = 'Hourly';
        else
            savedResolution = 'Daily';
        end
        refreshResolutionControls();
        resolutionItems = string(S.ui.ddRes.Items);
        resolutionHit = find(strcmpi(savedResolution, ...
            resolutionItems),1);
        if ~isempty(resolutionHit)
            S.ui.ddRes.Value = char(resolutionItems(resolutionHit));
        else
            logmsg(sprintf([ ...
                'Session resolution %s is not supported for %s; ' ...
                'using %s.'],savedResolution, ...
                char(string(S.ui.ddRegion.Value)), ...
                char(string(S.ui.ddRes.Value))));
        end
        refreshResolutionControls();

        % basins
        S.ui.spKt.Value = C.bas.K;
        S.ui.spKe.Value = 0;
        %S.ui.ddKcns.Value = sprintf('%d',C.bas.K);
        kStr = sprintf('%d',C.bas.K);
        % MATLAB requires Value to be present in Items before assignment.
        % This prevents startup/load crashes for CAMELS-DE daily K = 1484
        % or any user-defined basin universe.
        if ~ismember(kStr,S.ui.ddKcns.Items)
            S.ui.ddKcns.Items = [{kStr}, S.ui.ddKcns.Items];
        end
        
        S.ui.ddKcns.Value = kStr;

        % SITE has one basin-loading mode: zone-aware selection.
        sampleValue = 'zone';
        try
            S.ui.ddSample.Value = sampleValue;
        catch
        end

        if isfield(C.bas,'seed') ...
                && ~isempty(C.bas.seed) ...
                && isfinite(double(C.bas.seed(1)))
            S.ui.spBasinSeed.Value = max(0,min(4294967295, ...
                round(double(C.bas.seed(1)))));
        else
            S.ui.spBasinSeed.Value = 1;
        end

        if isfield(C.bas,'min_per_zone') ...
                && ~isempty(C.bas.min_per_zone)
            S.ui.spMinPerZone.Value = double(C.bas.min_per_zone(1));
        end
        if isfield(C.bas,'max_zones') ...
                && ~isempty(C.bas.max_zones)
            S.ui.spMaxZones.Value = double(C.bas.max_zones(1));
        end

        if isfield(C,'file_split') ...
                && ~isempty(C.file_split)
            S.ui.edBasinFile.Value = char(C.file_split);
        else
            S.ui.edBasinFile.Value = '';
        end
        onSampleModeChanged([],[],true);

        % period
        S.ui.edDt.Value = C.prd.dt;

        if isfield(C.prd,'method') ...
                && ~isempty(C.prd.method)
            if ismember(char(C.prd.method), ...
                    S.ui.ddSplitMethod.ItemsData)
                S.ui.ddSplitMethod.Value = ...
                    char(C.prd.method);
            else
                S.ui.ddSplitMethod.Value = 'manual';
            end
        else
            S.ui.ddSplitMethod.Value = 'manual';
        end

        % manual
        S.ui.edDts.Value = fmtDMY(C.prd.dts);
        S.ui.edDte.Value = fmtDMY(C.prd.dte);
        S.ui.edDes.Value = fmtDMY(C.prd.des);
        S.ui.edDee.Value = fmtDMY(C.prd.dee);

        % automatic-method fields if present
        if isfield(C.prd,'ds')
            s0 = fmtDMY(C.prd.ds);
        else
            s0 = fmtDMY(C.prd.des);
        end
        if isfield(C.prd,'de')
            s1 = fmtDMY(C.prd.de);
        else
            s1 = fmtDMY(C.prd.dte);
        end

        S.ui.edDBlockStart.Value = s0;
        S.ui.edDBlockEnd.Value = s1;
        S.ui.edRBlockStart.Value = s0;
        S.ui.edRBlockEnd.Value = s1;
        S.ui.edRndStart.Value = s0;
        S.ui.edRndEnd.Value = s1;
        S.ui.edDKFoldStart.Value = s0;
        S.ui.edDKFoldEnd.Value = s1;
        S.ui.edRKFoldStart.Value = s0;
        S.ui.edRKFoldEnd.Value = s1;

        if isfield(C.prd,'block_size')
            S.ui.spDBlockSize.Value = ...
                C.prd.block_size;
            S.ui.spRBlockSize.Value = ...
                C.prd.block_size;
        end
        if isfield(C.prd,'train_frac')
            S.ui.edDBlockFrac.Value = ...
                C.prd.train_frac;
            S.ui.edRBlockFrac.Value = ...
                C.prd.train_frac;
            S.ui.edRndFrac.Value = ...
                C.prd.train_frac;
        end
        if isfield(C.prd,'seed')
            S.ui.edRBlockSeed.Value = ...
                C.prd.seed;
            S.ui.edRndSeed.Value = ...
                C.prd.seed;
            S.ui.edRKFoldSeed.Value = ...
                C.prd.seed;
        end
        if isfield(C.prd,'n_folds')
            S.ui.spDKFolds.Value = ...
                C.prd.n_folds;
            S.ui.spRKFolds.Value = ...
                C.prd.n_folds;
        end
        if isfield(C.prd,'fold')
            S.ui.spDKFold.Value = ...
                C.prd.fold;
            S.ui.spRKFold.Value = ...
                C.prd.fold;
        end
        clampKfoldControls();

        S.ui.spSpin.Value = ...
            C.prd.spinup;
        refreshPeriodMethodControls();

        % meteo
        if isfield(C,'misc') ...
                && isfield(C.misc,'meteo')
        
            if isfield(C.misc.meteo,'data')
                localSetDropdownByLeadingInt( ...
                    S.ui.ddMeteo, ...
                    C.misc.meteo.data);
            end
        
            if isfield(C.misc.meteo,'precip')
                localSetDropdownByLeadingInt( ...
                    S.ui.ddPrecip, ...
                    C.misc.meteo.precip);
            end
        
            if isfield(C.misc.meteo,'temp')
                localSetDropdownByLeadingInt( ...
                    S.ui.ddTemp, ...
                    C.misc.meteo.temp);
            end
        
            if isfield(C.misc.meteo,'pet')
                localSetDropdownByLeadingInt( ...
                    S.ui.ddPET, ...
                    C.misc.meteo.pet);
            end
        end

        % A loaded CAMELS-ES session may select ERA5-Land through
        % misc.meteo.data. Refresh the three read-only component fields
        % after restoring the Meteo product dropdown.
        try
            regionNow = region_helpers('code',S.ui.ddRegion.Value);
            if strcmp(regionNow,'CAMELS_ES')
                esData = parseLeadingInt_local(S.ui.ddMeteo.Value);
                if esData == 2
                    esLabel = '2 ERA5-Land';
                else
                    esLabel = '1 EMO-1';
                end
                controls = {S.ui.ddPrecip,S.ui.ddTemp,S.ui.ddPET};
                roles = {'precipitation','temperature','pet'};
                for kk = 1:numel(controls)
                    labels = local_meteo_dropdown_labels( ...
                        {esLabel},roles{kk},S.ui.ddMeteo.Value);
                    controls{kk}.ItemsData = {};
                    controls{kk}.Items = labels;
                    controls{kk}.ItemsData = {esLabel};
                    controls{kk}.Value = esLabel;
                end
            end
        catch
        end
        localRefreshMeteoChoicePresentation(S.ui);

        lossCfg = normalizeLossStruct_local( ...
            C.misc.loss);
        S.ui.ddLoss.Value = sprintf('%d %s', ...
            lossCfg.fnc,lossName(lossCfg.fnc));
        S.ui.ddJKGEMethod.Value = sprintf('%d %s', ...
            lossCfg.method, ...
            jkgeMethodName(lossCfg.method));
        S.ui.ddFDCFormulation.Value = double(lossCfg.fdc.formulation);
        S.ui.spJKGENwin.Value = double(lossCfg.n_win);
        if isfield(S.ui,'ddJKGEM') ...
                && ~isempty(S.ui.ddJKGEM)
            S.ui.ddJKGEM.Value = double(lossCfg.M);
        end
        jkge_controls_ui(S.ui, ...
            @parseLeadingInt_local,@setVisibleSafe);
        refreshLossHelpText();
        % Hidden legacy SAGE optimizer control.  SITE has its own
        % seven-method dropdown (ddSiteOpt); ddOpt exists only because shared
        % SAGE session/preview helpers still reference the original two-item
        % Training control.  Restore ddOpt from its actual Items rather than
        % rebuilding a label with SITE's optName(), which would produce e.g.
        % '2 Gauss-Newton' instead of the legacy '2 Adam/AdamW'.
        try
            legacyMethod = round(double(C.misc.alg.method));
            if ~ismember(legacyMethod,[1 2])
                legacyMethod = 2;
            end
            legacyItems = cellstr(string(S.ui.ddOpt.Items));
            legacyPrefix = sprintf('%d ',legacyMethod);
            legacyIndex = find(startsWith(string(legacyItems), ...
                legacyPrefix),1,'first');
            if isempty(legacyIndex)
                legacyIndex = min(max(1,legacyMethod),numel(legacyItems));
            end
            S.ui.ddOpt.Value = legacyItems{legacyIndex};
        catch
            % The legacy control is hidden in SITE.  If a future SAGE helper
            % changes its labels, retain whatever valid value the control
            % was constructed with rather than blocking GUI startup.
        end
        S.ui.spImax.Value = C.misc.alg.i_max;
        S.ui.edLR.Value = C.misc.alg.lr;
        if isfield(C.misc.alg,'lr_scheme') ...
                && ~isempty(C.misc.alg.lr_scheme)
            S.ui.ddLRSchedule.Value = char(string(C.misc.alg.lr_scheme));
        else
            S.ui.ddLRSchedule.Value = 'constant';
        end
        if isfield(C.misc.alg,'lr_min') && ~isempty(C.misc.alg.lr_min)
            S.ui.edLRmin.Value = double(C.misc.alg.lr_min);
        else
            S.ui.edLRmin.Value = double(C.misc.alg.lr);
        end
        if isfield(C.misc.alg,'lr_hold') && ~isempty(C.misc.alg.lr_hold)
            S.ui.edLRhold.Value = double(C.misc.alg.lr_hold);
        else
            S.ui.edLRhold.Value = 0.20;
        end
        S.ui.edBeta1.Value = double(C.misc.alg.beta_1);
        S.ui.edBeta2.Value = double(C.misc.alg.beta_2);
        S.ui.edVarEps.Value = double(C.misc.alg.vareps);
        S.ui.edWdec.Value = C.misc.alg.wdecay;
        if isfield(C.misc.alg,'clipn')
            S.ui.spClipn.Value = C.misc.alg.clipn;
        else
            S.ui.spClipn.Value = 1;
        end
        updateLearningRateControlState();
        refreshOptHelpText();
        % ODE defaults from read_numsettings if possible
        try
            ode0 = read_numsettings();
            if isfield(ode0,'InitStep')
                S.ui.edInitStep.Value = ...
                    double(ode0.InitStep);
            end
            if isfield(ode0,'MaxStep')
                S.ui.edMaxStep.Value = ...
                    double(ode0.MaxStep);
            end
            if isfield(ode0,'MinStep')
                S.ui.edMinStep.Value = ...
                    double(ode0.MinStep);
            end
            if isfield(ode0,'RelTol')
                S.ui.edRelTol.Value = ...
                    double(ode0.RelTol);
            end
            if isfield(ode0,'AbsTol')
                S.ui.edAbsTol.Value = ...
                    double(ode0.AbsTol);
            end
            if isfield(ode0,'Order')
                S.ui.spOrder.Value = ...
                    double(ode0.Order);
            end
            if isfield(ode0,'maxiter')
                S.ui.spMaxIterODE.Value = ...
                    double(ode0.maxiter);
            end
            if isfield(ode0,'mem')
                S.ui.ddMem.Value = ...
                    tern(double(ode0.mem)==1, ...
                    '1 (yes)','0 (no)');
            end
        catch
        end

        % postprocess defaults
        S.ui.spBprtTrain.Value = 5;
        try
            S.ui.spBprtEval.Limits = [0 200];
        catch
        end
        S.ui.spBprtEval.Value = 0;
        S.ui.cbAttr.Value = false;
        S.ui.cbScenTT.Value = true;
        S.ui.cbScenTE.Value = true;
        S.ui.cbScenET.Value = false;
        S.ui.cbScenEE.Value = false;
        try
            S.ui.spKe.Value = 0;
            siteUi('restoreTraining',C);
            siteUi('configureVisibleTabs');
        catch
        end
    end

    function cfg = getConfigFromUI()
        cfg = local_default_config();
        cfg.root = char(S.ui.edRoot.Value);
        cfg.SITEhydro = char(S.ui.edSITE.Value);
        cfg.SAGEhydro = char(S.ui.edSAGE.Value);
        sageParent = fileparts(cfg.SAGEhydro);
        if local_gchm_available(sageParent) && ~isdeployed
            addpath(local_gchm_dir(sageParent));
        end
        if local_gchm_ode_available(sageParent) ...
                && ~isdeployed
            addpath(local_gchm_ode_dir(sageParent));
        end
        if local_user_model_available(cfg.root) ...
                && ~isdeployed
            addpath(local_user_model_dir(cfg.root));
        end
        % Flat project layout: gui, src, examples, and results live
        % directly beneath SAGEhydrology.
        cfg.SAGEdir = cfg.SAGEhydro;
        if isfield(S.ui,'ddRegion') ...
                && isvalid(S.ui.ddRegion)
            cfg.region = char(string( ...
                S.ui.ddRegion.Value));
        else
            cfg.region = 'CAMELS_US';
        end
        cfg.region = ...
            region_helpers('code',cfg.region);
        cfg.regionName = ...
            region_helpers('name',cfg.region);
        cfg.dirDroot = strtrim(char(string( ...
            S.ui.edDataLocation.Value)));
        cfg.dirD = fullfile(cfg.dirDroot,cfg.region);
        cfg.dirres = strtrim(char(string(S.ui.edRes.Value)));
        Kcns = str2double(char(S.ui.ddKcns.Value));

        % Use the active resolution's explicit basin-universe file when
        % supplied by the regional config. Fall back to the legacy naming
        % convention for regions that do not declare X.basins.file.
        cfg.file_univ = '';
        try
            Creg = getCurrentRegionConfig();
            Xreg = region_helpers('resolution', ...
                cfg.SAGEhydro,Creg.code,S.ui.ddRes.Value);
            if isfield(Xreg,'basins') ...
                    && isfield(Xreg.basins,'file') ...
                    && ~isempty(Xreg.basins.file)
                cfg.file_univ = char(string(Xreg.basins.file));
            end
        catch
        end
        if isempty(cfg.file_univ)
            cfg.file_univ = sprintf('%s_%d_basins.txt', ...
                region_helpers('short',cfg.region),Kcns);
        end

        file_split = strtrim(char(string( ...
            S.ui.edBasinFile.Value)));
        if isempty(file_split)
            cfg.file_split = '';
        else
            [~,name,ext] = fileparts( ...
                file_split);
            cfg.file_split = [name ext];
        end
        resValue = char(S.ui.ddRes.Value);

        % Regional runtime paths are declared in region_config_XX.m.
        % Every X.paths entry is relative to Data/<C.data_root>.
        Cregion = getCurrentRegionConfig();
        Xresolution = region_helpers( ...
            'resolution',cfg.SAGEhydro, ...
            Cregion.code,resValue);
        Pregion = region_helpers( ...
            'resolvepaths',Cregion,Xresolution,cfg.dirDroot);

        cfg.dirD = Pregion.dirD;
        cfg.dirM = Pregion.dirM;
        cfg.dirQ = Pregion.dirQ;
        cfg.prd.dt = Pregion.dt;

        % Carry the active data resolution into the basin/attribute reader.
        % This is required for regions whose daily, hourly, or 15-minute
        % products have different gauge populations and metadata files.
        cfg.bas.dt = cfg.prd.dt;
        cfg.bas.resolution = resValue;
        switch lower(strtrim(resValue))
            case 'hourly'
                cfg.bas.stream = 'hourly';
            case {'15 minutes','15-minute','15min'}
                cfg.bas.stream = '15min';
            otherwise
                cfg.bas.stream = 'daily';
        end
        cfg.bas.file_univ = cfg.file_univ;
        [cfg.bas.data_actions,cfg.bas.data_action_note] = ...
            load_hydrologic_data_actions(Cregion.code,resValue);
        syncDataActionRunNotes(cfg.bas.data_action_note);
        % Optional, region-specific exclusions remain part of the complete
        % inventory but are removed by check_basins with a documented
        % reason. This is preferable to silently omitting their IDs.
        if isfield(Xresolution,'basins') ...
                && isfield(Xresolution.basins,'excluded_gauges')
            cfg.bas.excluded_gauges = ...
                Xresolution.basins.excluded_gauges;
            if isfield(Xresolution.basins,'exclusion_reason')
                cfg.bas.exclusion_reason = ...
                    Xresolution.basins.exclusion_reason;
            end
        else
            cfg.bas.excluded_gauges = {};
            cfg.bas.exclusion_reason = {};
        end
        for ia = 1:numel(cfg.bas.data_actions)
            action = cfg.bas.data_actions(ia);
            if strcmpi(action.action,'exclude') ...
                    && ~any(strcmpi(string( ...
                    cfg.bas.excluded_gauges),action.gauge_id))
                cfg.bas.excluded_gauges{end+1,1} = action.gauge_id;
                cfg.bas.exclusion_reason{end+1,1} = action.reason;
            end
        end

        if isfield(S.ui,'ddModel') ...
                && ~isempty(S.ui.ddModel)
            mdlName = char(S.ui.ddModel.Value);
        else
            mdlName = 'hbv';    % or S.cfg default model
        end
        cfg.mdl.model = ...
            local_model_id_from_key(mdlName);
        cfg.mdl = local_model_variant(cfg.mdl,mdlName);
        if cfg.mdl.model==99,cfg.mdl.name=char(sage_user_model_display_name_ui(local_user_model_dir(cfg.root)));end

        cfg.mdl.calc = char(S.ui.ddCalc.Value);
        cfg.mdl.mcode = parseLeadingInt_local( ...
            S.ui.ddMcode.Value);

        cfg.bas.K = str2double( ...
            S.ui.ddKcns.Value);
        cfg.bas.K_t = cfg.bas.K;
        cfg.bas.K_e = 0;
        try S.ui.spKe.Value = 0; catch, end
        % SITE uses zone-aware basin loading; the SAGE sampling selector is
        % retained only as a hidden compatibility handle.
        cfg.bas.sample = 'zone';
        if strcmpi(cfg.bas.sample,'zone')
            cfg.bas.min_per_zone = ...
                double(S.ui.spMinPerZone.Value);
            cfg.bas.max_zones = ...
                double(S.ui.spMaxZones.Value);
            cfg.bas.seed = [];
            cfg.bas.rng_type = '';
        elseif strcmpi(cfg.bas.sample,'random')
            cfg.bas.min_per_zone = [];
            cfg.bas.max_zones = [];
            cfg.bas.seed = round(double(S.ui.spBasinSeed.Value));
            cfg.bas.rng_type = 'twister';
            splitKt = round(cfg.bas.K_t);
            splitKe = max(0,round(cfg.bas.K-cfg.bas.K_t));
            cfg.file_split = sprintf( ...
                'split_%s_%d_%d_%d_%d.txt', ...
                region_helpers('short',cfg.region), ...
                round(cfg.bas.K),splitKt,splitKe, ...
                round(cfg.bas.seed));
        else
            cfg.bas.min_per_zone = [];
            cfg.bas.max_zones = [];
            cfg.bas.seed = [];
            cfg.bas.rng_type = '';
        end
        cfg.bas.id_attr = site_default_attribute_ids(cfg.region);
        cfg.bas.pr_attr = 0;
        cfg.r = numel(cfg.bas.id_attr);
        cfg.prd.spinup = S.ui.spSpin.Value;
        cfg.prd.method = char(S.ui.ddSplitMethod.Value);

        switch lower(cfg.prd.method)

            case 'manual'
                cfg.prd.dts = forceDMYRow_local( ...
                    parseDMY_local(S.ui.edDts.Value));
                cfg.prd.dte = forceDMYRow_local( ...
                    parseDMY_local(S.ui.edDte.Value));

                txtDes = strtrim(char(S.ui.edDes.Value));
                txtDee = strtrim(char(S.ui.edDee.Value));

                if isempty(txtDes) ...
                        && isempty(txtDee)
                    % No separate evaluation period supplied
                    cfg.prd.des = cfg.prd.dts;
                    cfg.prd.dee = cfg.prd.dte;
                    cfg.prd.eval_was_empty = true;
                    cfg.prd.eval_partial = false;

                    if cfg.bas.K_e > 0
                        cfg.mdl.mode = 3;   % train+eval basins|train prd
                    else
                        cfg.mdl.mode = 1;   % train basins | train period
                    end

                elseif isempty(txtDes) ...
                        || isempty(txtDee)
                    % Incomplete edit state: keep GUI alive,
                    % let evaluation complain
                    cfg.prd.des = cfg.prd.dts;
                    cfg.prd.dee = cfg.prd.dte;
                    cfg.prd.eval_was_empty = false;
                    cfg.prd.eval_partial = true;

                    if cfg.bas.K_e > 0
                        cfg.mdl.mode = 3;
                    else
                        cfg.mdl.mode = 1;
                    end

                else
                    % Separate evaluation period supplied
                    cfg.prd.des = forceDMYRow_local( ...
                        parseDMY_local(txtDes));
                    cfg.prd.dee = forceDMYRow_local( ...
                        parseDMY_local(txtDee));
                    cfg.prd.eval_was_empty = false;
                    cfg.prd.eval_partial = false;

                    if cfg.bas.K_e > 0
                        cfg.mdl.mode = 4;   % train+eval basins|eval period
                    else
                        cfg.mdl.mode = 2;   % train basins | eval period
                    end
                end
                cfg.prd.ds = cfg.prd.dts;
                cfg.prd.de = cfg.prd.dte;

            case 'deterministic_block'
                cfg.prd.ds = ...
                    parseDMY_local(S.ui.edDBlockStart.Value);
                cfg.prd.de = ...
                    parseDMY_local(S.ui.edDBlockEnd.Value);
                cfg.prd.block_size = ...
                    double(S.ui.spDBlockSize.Value);
                cfg.prd.train_frac = ...
                    double(S.ui.edDBlockFrac.Value);
                cfg.prd.seed = [];
                cfg.prd.dts = ...
                    cfg.prd.ds;
                cfg.prd.dte = ...
                    cfg.prd.de;
                cfg.prd.des = ...
                    cfg.prd.ds;
                cfg.prd.dee = ...
                    cfg.prd.de;

            case 'random_block'
                cfg.prd.ds = ...
                    parseDMY_local(S.ui.edRBlockStart.Value);
                cfg.prd.de = ...
                    parseDMY_local(S.ui.edRBlockEnd.Value);
                cfg.prd.block_size = ...
                    double(S.ui.spRBlockSize.Value);
                cfg.prd.train_frac = ...
                    double(S.ui.edRBlockFrac.Value);
                cfg.prd.seed = ...
                    double(S.ui.edRBlockSeed.Value);
                cfg.prd.dts = ...
                    cfg.prd.ds;
                cfg.prd.dte = ...
                    cfg.prd.de;
                cfg.prd.des = ...
                    cfg.prd.ds;
                cfg.prd.dee = ...
                    cfg.prd.de;

            case 'random'
                cfg.prd.ds = ...
                    parseDMY_local(S.ui.edRndStart.Value);
                cfg.prd.de = ...
                    parseDMY_local(S.ui.edRndEnd.Value);
                cfg.prd.train_frac = ...
                    double(S.ui.edRndFrac.Value);
                cfg.prd.seed = ...
                    double(S.ui.edRndSeed.Value);
                cfg.prd.block_size = [];
                cfg.prd.dts = ...
                    cfg.prd.ds;
                cfg.prd.dte = ...
                    cfg.prd.de;
                cfg.prd.des = ...
                    cfg.prd.ds;
                cfg.prd.dee = ...
                    cfg.prd.de;

            case 'deterministic_kfold'
                cfg.prd.ds = ...
                    parseDMY_local(S.ui.edDKFoldStart.Value);
                cfg.prd.de = ...
                    parseDMY_local(S.ui.edDKFoldEnd.Value);
                clampKfoldControls();
                cfg.prd.n_folds = ...
                    double(S.ui.spDKFolds.Value);
                cfg.prd.fold = ...
                    double(S.ui.spDKFold.Value);
                cfg.prd.seed = [];
                cfg.prd.block_size = [];
                cfg.prd.dts = ...
                    cfg.prd.ds;
                cfg.prd.dte = ...
                    cfg.prd.de;
                cfg.prd.des = ...
                    cfg.prd.ds;
                cfg.prd.dee = ...
                    cfg.prd.de;

            case 'random_kfold'
                cfg.prd.ds = ...
                    parseDMY_local(S.ui.edRKFoldStart.Value);
                cfg.prd.de = ...
                    parseDMY_local(S.ui.edRKFoldEnd.Value);
                clampKfoldControls();
                cfg.prd.n_folds = ...
                    double(S.ui.spRKFolds.Value);
                cfg.prd.fold = ...
                    double(S.ui.spRKFold.Value);
                cfg.prd.seed = ...
                    double(S.ui.edRKFoldSeed.Value);
                cfg.prd.block_size = [];
                cfg.prd.dts = ...
                    cfg.prd.ds;
                cfg.prd.dte = ...
                    cfg.prd.de;
                cfg.prd.des = ...
                    cfg.prd.ds;
                cfg.prd.dee = ...
                    cfg.prd.de;

            case 'rainfall_block'


                cfg.prd.ds = ...
                    parseDMY_local( ...
                    S.ui.edRainBlockStart.Value);
                cfg.prd.de = ...
                    parseDMY_local( ...
                    S.ui.edRainBlockEnd.Value);

                cfg.prd.dts = cfg.prd.ds;
                cfg.prd.dte = cfg.prd.de;
                cfg.prd.des = cfg.prd.ds;
                cfg.prd.dee = cfg.prd.de;

                cfg.prd.block_size = [];
                cfg.prd.train_frac = [];
                cfg.prd.seed = [];
                cfg.prd.local = 1;

                if cfg.bas.K_e > 0
                    cfg.mdl.mode = 4;
                else
                    cfg.mdl.mode = 2;
                end

            otherwise
                error(['Unknown train/eval ' ...
                    'method: %s'], ...
                    cfg.prd.method);
        end

        % All non-manual split methods provide both training and
        % evaluation time masks over their common date range. Assign the
        % assessment mode here so every branch returns a complete model
        % configuration.
        if ~isfield(cfg.mdl,'mode') ...
                || isempty(cfg.mdl.mode)
            if cfg.bas.K_e > 0
                cfg.mdl.mode = 4;
            else
                cfg.mdl.mode = 2;
            end
        end

        cfg.misc.meteo.data = ...
            siteMeteoChoiceCode(S.ui.ddMeteo);

        if isfield(S.ui,'ddPrecip') ...
                && isvalid(S.ui.ddPrecip)
            cfg.misc.meteo.precip = ...
                parseLeadingInt_local( ...
                S.ui.ddPrecip.Value);
        else
            cfg.misc.meteo.precip = ...
                cfg.misc.meteo.data;
        end

        if isfield(S.ui,'ddTemp') ...
                && isvalid(S.ui.ddTemp)
            cfg.misc.meteo.temp = ...
                parseLeadingInt_local( ...
                S.ui.ddTemp.Value);
        else
            cfg.misc.meteo.temp = ...
                cfg.misc.meteo.data;
        end
        cfg.misc.meteo.pet = ...
            siteMeteoChoiceCode(S.ui.ddPET);

        selectedSchema = resolve_hydro_schema( ...
            meteo_schema(cfg.region), ...
            struct('dt',cfg.prd.dt),cfg.misc.meteo);
        cfg.misc.meteo.source = selectedSchema.name;
        if isfield(selectedSchema,'selected_profile')
            cfg.misc.meteo.profile = ...
                selectedSchema.selected_profile;
        end

        % Preserve the exact user-facing meteorological selections in the
        % run configuration. Exporters and reports should consume this
        % metadata instead of maintaining separate region-specific lookup
        % tables that can become outdated when the GUI is extended.
        cfg.misc.meteo.display = local_meteo_display_metadata( ...
            S.ui.ddMeteo,S.ui.ddPrecip,S.ui.ddTemp,S.ui.ddPET, ...
            cfg.prd.dt);

        cfg.misc.loss = struct( ...
            'fnc',parseLeadingInt_local( ...
            S.ui.ddLoss.Value), ...
            'method',parseLeadingInt_local( ...
            S.ui.ddJKGEMethod.Value), ...
            'n_win',round(double( ...
            S.ui.spJKGENwin.Value)));
        cfg.misc.loss.fdc = struct('formulation', ...
            double(S.ui.ddFDCFormulation.Value));
        cfg.misc.loss.M = 2;
        cfg.misc.loss.observed = {'Q'};
        if isfield(S.ui,'ddJKGEM') ...
                && ~isempty(S.ui.ddJKGEM)
            cfg.misc.loss.M = ...
                double(S.ui.ddJKGEM.Value);
        end
        cfg.misc.alg.method = ...
            parseLeadingInt_local( ...
            S.ui.ddOpt.Value);
        cfg.misc.alg.i_max = ...
            S.ui.spImax.Value;
        cfg.misc.alg.lr = ...
            S.ui.edLR.Value;
        cfg.misc.alg.beta_1 = S.ui.edBeta1.Value;
        cfg.misc.alg.beta_2 = S.ui.edBeta2.Value;
        cfg.misc.alg.vareps = S.ui.edVarEps.Value;
        cfg.misc.alg.lr_scheme = char(S.ui.ddLRSchedule.Value);
        cfg.misc.alg.lr_min = S.ui.edLRmin.Value;
        cfg.misc.alg.lr_hold = S.ui.edLRhold.Value;
        cfg.misc.alg.wdecay = ...
            S.ui.edWdec.Value;
        cfg.misc.alg.clipn = ...
            S.ui.spClipn.Value;

        % SITE calibration configuration. The legacy misc.alg fields above
        % remain populated only because shared SAGE preview/session helpers
        % expect them; run_SITE consumes cfg.site instead.
        siteUi('saveCurrentOpts');
        cfg.site = struct();
        cfg.site.calc = char(string(cfg.mdl.calc));
        cfg.site.numWorkers = 0;
        cfg.site.maxPending = 0;
        cfg.site.saveEvery = double(S.ui.spSiteSaveEvery.Value);
        cfg.site.optsByMethod = S.store.siteOptByMethod;
        cfg.site.alg = struct();
        cfg.site.alg.method = double(S.ui.ddSiteOpt.Value);
        cfg.site.alg.n = max(1,round(double(S.ui.spSiteStarts.Value)));
        cfg.site.alg.i_max = max(1,round(double(S.ui.spSiteIMax.Value)));
        keySite = siteOptimizerKey(cfg.site.alg.method);
        if isfield(S.store.siteOptByMethod,keySite)
            cfg.site.alg.opts = S.store.siteOptByMethod.(keySite);
        else
            cfg.site.alg.opts = siteMergeOptsTables( ...
                S.ui.tblSiteOpts.Data,S.ui.tblSiteSharedOpts.Data, ...
                S.ui.tblSiteOpts.UserData, ...
                S.ui.tblSiteSharedOpts.UserData);
            if cfg.site.alg.method == 7
                cfg.site.alg.opts.finisher = ...
                    char(S.ui.ddSiteFinisher.Value);
            end
        end
        % Mirror common SITE values into misc.alg so Summary/Preview display
        % the correct method and iteration budget.
        cfg.misc.alg.method = cfg.site.alg.method;
        cfg.misc.alg.n = cfg.site.alg.n;
        cfg.misc.alg.i_max = cfg.site.alg.i_max;
        cfg.misc.attr = double( ...
            S.ui.cbAttr.Value);
        cfg.misc.attr_view = char( ...
            S.ui.ddAttribView.Value);

        cfg.ode = struct();
        cfg.ode.InitStep = ...
            S.ui.edInitStep.Value;
        cfg.ode.MaxStep = ...
            S.ui.edMaxStep.Value;
        cfg.ode.MinStep = ...
            S.ui.edMinStep.Value;
        cfg.ode.RelTol = ...
            S.ui.edRelTol.Value;
        cfg.ode.AbsTol = ...
            S.ui.edAbsTol.Value;
        cfg.ode.Order = ...
            S.ui.spOrder.Value;
        cfg.ode.maxiter = ...
            S.ui.spMaxIterODE.Value;
        cfg.ode.mem = ...
            parseLeadingInt_local( ...
            S.ui.ddMem.Value);

        if strcmpi(char(S.ui.ddModel.Value), ...
                'user_model') && ~isfile(fullfile(local_user_model_dir(cfg.root),'user_model_matlab.m'))
            cfg.mdl.mcode = 4;
            cfg.ode.mem = 0;
        end

        cfg.model_options=S.store.modelOptions;
        optionKey=sprintf('model_%d',cfg.mdl.model);
        if isfield(S.store.modelOptions,optionKey)
            options=S.store.modelOptions.(optionKey);
            if isfield(options,'config'),cfg.mdl.config=options.config;end
            if isfield(options,'y0'),cfg.ode.y0=options.y0;end
        end
        cfg.par_override = ...
            S.store.parOverride;
        cfg.preview_runtime = ...
            S.runtime.previewRuntime;
        cfg.runNote = char(strjoin( ...
            string(S.store.runNotes),newline));
    end

    function [rows,okAll] = validateCurrentConfig()
        [datesOK,dateMessage] = local_required_period_dates(S.ui);
        if ~datesOK
            rows = {'ERROR','Period dates',dateMessage};
            okAll = false;
            return
        end

        try
            cfg = getConfigFromUI();
        catch ME
            rows = {'ERROR','Build config',ME.message};
            okAll = false;
            return
        end
        snapshot = struct();
        snapshot.cfg = cfg;
        snapshot.regionCode = region_helpers('code',cfg);
        snapshot.resolutionValue = char(S.ui.ddRes.Value);
        snapshot.sampleValue = 'zone';
        snapshot.sampleText = 'Zone-aware loading';
        snapshot.dependencyNotice = S.runtime.dependencyNotice;
        if isdeployed
            snapshot.sageOK = isfolder(fullfile(ctfroot,'SAGEhydrology')) ...
                || isfolder(fullfile(ctfroot,'SAGE_ui','SAGEhydrology')) ...
                || isfolder(cfg.SAGEhydro);
            snapshot.sageName = 'SAGEhydrology files';
            snapshot.sageDetails = ...
                'Packaged SAGEhydrology files found in deployed app';
        else
            snapshot.sageOK = isfolder(cfg.SAGEhydro);
            snapshot.sageName = 'SAGEhydrology path';
            snapshot.sageDetails = cfg.SAGEhydro;
        end
        snapshot.scenarioOK = true;
        snapshot.scenarioDetails = ...
            'SITE uses training basins only; evaluation period is optional.';
        snapshot.preparedOK = S.runtime.prepared ...
            && ~isempty(S.runtime.preparedBasins) ...
            && isstruct(S.runtime.preparedBasins) ...
            && isfield(S.runtime.preparedBasins,'K_t') ...
            && isfield(S.runtime.preparedBasins,'K_e');
        if strcmp(snapshot.sampleValue,'file')
            preparedText = 'Prepared from selected split file';
        else
            preparedText = 'Click "Load basins" before running';
        end
        snapshot.preparedDetails = [preparedText ...
            '. Action: click Load basins ' ...
            'after period/basin changes.'];
        snapshot.compileOK = true;
        snapshot.compileName = 'CRR backend';
        snapshot.compileDetails = [ ...
            'Selected automatically when ' ...
            'Run SITE starts: unified MEX, ' ...
            'standalone model MEX, or ' ...
            'MATLAB RK2 fallback.'];
        S.runtime.compileOK = true;
        [rows,okAll] = checks_dashboard_ui('validate',snapshot);
        names = string(rows(:,2));
        rows(ismember(names,["Evaluation basins", ...
            "Postprocess scenarios"]),:) = [];
        for kk = 1:size(rows,1)
            switch string(rows{kk,2})
                case "Training basins"
                    rows{kk,2} = 'Basins';
                    rows{kk,3} = 'At least one basin is required.';
                case "Basin counts"
                    rows{kk,3} = [ ...
                        'Selected basin count must not exceed the ' ...
                        'available basin universe.'];
                case "Data region"
                    rows{kk,3} = ['Select an available ' ...
                        'regional dataset.'];
            end
        end
    end
    % =====================
    %  Basin / plot helpers
    % =====================
    function updateBasinTableLayout(K_e)
        try
            hasEval = K_e > 0;
            if hasEval
                S.ui.gtblBasins.RowHeight = {20,'1x',20,'1x',80};
                S.ui.lblPlotTrain.Visible = 'on';
                S.ui.tblPlotTrain.Visible = 'on';
                S.ui.lblPlotEval.Visible = 'on';
                S.ui.tblPlotEval.Visible = 'on';
                S.ui.lblEvalLegend.Visible = 'on';
            else
                % SITE has no evaluation-basin block. Give the training table
                % all remaining space down to the Zone summary.
                S.ui.gtblBasins.RowHeight = {20,'1x',0,0,80};
                S.ui.lblPlotTrain.Visible = 'on';
                S.ui.tblPlotTrain.Visible = 'on';
                S.ui.lblPlotEval.Visible = 'off';
                S.ui.tblPlotEval.Visible = 'off';
                S.ui.lblEvalLegend.Visible = 'off';
            end
        catch
        end
    end

    function populatePlotTablesFromBasins(bas)

        K_t = bas.K_t;
        K_e = bas.K_e;
        updateBasinTableLayout(K_e);

        % A newly prepared split has no data-quality classification yet.
        % Remove row styles before replacing the basin-table contents so
        % rules indexed to a previous region cannot color the new rows.
        try
            data_quality_dashboard_ui('basins',S.ui,[]);
        catch
        end

        gaugeT = local_region_gauge_id( ...
            bas.id_gauge(1:K_t), ...
            region_helpers('code',S.ui.ddRegion.Value));
        gnameT = local_display_basin_names(bas.gname(1:K_t));
        idxT = (1:K_t).';
        zT = local_zone_table_values(bas,1:K_t);

        % -------------------------
        % Basins tab: no train/eval
        % -------------------------
        S.ui.tblPlotTrain.Data = [ ...
            num2cell(idxT), ...
            cellstr(gaugeT), ...
            cellstr(zT), ...
            cellstr(gnameT)];

        % -------------------------------
        % Postprocessor tab: with columns
        % -------------------------------
        trainSelT = false(K_t,1);
        evalSelT = false(K_t,1);

        S.ui.tblPostTrain.Data = [ ...
            num2cell(idxT), ...
            num2cell(trainSelT), ...
            num2cell(evalSelT), ...
            cellstr(gaugeT), ...
            cellstr(zT), ...
            cellstr(gnameT)];

        if K_e > 0
            idEglob = K_t+1:K_t+K_e;
            gaugeE = local_region_gauge_id( ...
                bas.id_gauge(idEglob), ...
                region_helpers('code', ...
                S.ui.ddRegion.Value));
            gnameE = local_display_basin_names( ...
                bas.gname(idEglob));
            idxE = (1:K_e).';
            zE = local_zone_table_values(bas,idEglob);

            S.ui.tblPlotEval.Data = [ ...
                num2cell(idxE), ...
                cellstr(gaugeE), ...
                cellstr(zE), ...
                cellstr(gnameE)];

            trainSelE = false(K_e,1);
            evalSelE = false(K_e,1);

            S.ui.tblPostEval.Data = [ ...
                num2cell(idxE), ...
                num2cell(trainSelE), ...
                num2cell(evalSelE), ...
                cellstr(gaugeE), ...
                cellstr(zE), ...
                cellstr(gnameE)];
        else
            S.ui.tblPlotEval.Data = cell(0,4);
            S.ui.tblPostEval.Data = cell(0,6);
        end
        % Centering entries Table in columns 1, 2 and 3
        try
            stCenter = uistyle('horizontalalignment', ...
                'center');
            addStyle(S.ui.tblPlotTrain,stCenter, ...
                'column',[1 2 3]);
            addStyle(S.ui.tblPlotEval, stCenter, ...
                'column',[1 2 3]);
            addStyle(S.ui.tblPostTrain,stCenter, ...
                'column',[1 2 3 4 5]);
            addStyle(S.ui.tblPostEval, stCenter, ...
                'column',[1 2 3 4 5]);
        catch
        end
        try
            stLeft = ...
                uistyle('horizontalalignment', ...
                'left');
            addStyle(S.ui.tblPlotTrain, ...
                stLeft,'column',4);
            addStyle(S.ui.tblPlotEval, ...
                stLeft,'column',4);
            addStyle(S.ui.tblPostTrain, ...
                stLeft,'column',6);
            addStyle(S.ui.tblPostEval, ...
                stLeft,'column',6);
        catch
        end

        try
            S.ui.lblEvalLegend.Text = ...
                local_zone_legend_text(bas);
        catch
        end
        try
            if isfield(S.runtime,'quality') ...
                    && ~isempty(S.runtime.quality)
                data_quality_dashboard_ui( ...
                    'basins',S.ui,S.runtime.quality);
            end
        catch
        end
    end

    function populatePostTablesFromBasins(bas)
        K_t = bas.K_t;
        K_e = bas.K_e;

        gaugeT = local_region_gauge_id( ...
            bas.id_gauge(1:K_t), ...
            region_helpers('code',S.ui.ddRegion.Value));
        gnameT = local_display_basin_names(bas.gname( ...
            1:K_t));
        idxT = (1:K_t).';
        zT = local_zone_table_values(bas,1:K_t);

        selTT = false(K_t,1);
        selTE = false(K_t,1);

        S.ui.spBprtTrain.Limits = [1 200];
        Btr = min(K_t,max(1,round(S.ui.spBprtTrain.Value)));
        if K_e > 0
            S.ui.spBprtEval.Limits = [1 200];
            Bev = min(K_e,max(1,round(S.ui.spBprtEval.Value)));
        else
            % Evaluation selection is inapplicable when the requested run
            % has no evaluation basins; permit the disabled control to show
            % zero only in this special case.
            S.ui.spBprtEval.Limits = [0 200];
            Bev = 0;
        end
        S.ui.spBprtTrain.Value = Btr;
        S.ui.spBprtEval.Value = Bev;
        setEnable(S.ui.spBprtEval,K_e > 0);
        setEnable(S.ui.btnRandomEval,K_e > 0);
        setEnable(S.ui.btnClearEval,K_e > 0);

        if Btr > 0
            selTT(1:Btr) = true;
            selTE(1:Btr) = true;
        end

        S.ui.tblPostTrain.Data = [ ...
            num2cell(idxT), ...
            num2cell(selTT), ...
            num2cell(selTE), ...
            cellstr(gaugeT), ...
            cellstr(zT), ...
            cellstr(gnameT)];

        if K_e > 0
            idEglob = K_t+1:K_t+K_e;
            gaugeE = local_region_gauge_id( ...
                bas.id_gauge(idEglob), ...
                region_helpers('code',S.ui.ddRegion.Value));
            gnameE = local_display_basin_names( ...
                bas.gname(idEglob));
            idxE = (K_t+1:K_t+K_e).';
            %idxE = (1:K_e).';
            zE = local_zone_table_values( ...
                bas,idEglob);

            selET = false(K_e,1);
            selEE = false(K_e,1);

            if Bev > 0
                selET(1:Bev) = true;
                selEE(1:Bev) = true;
            end

            S.ui.tblPostEval.Data = [ ...
                num2cell(idxE), ...
                num2cell(selET), ...
                num2cell(selEE), ...
                cellstr(gaugeE), ...
                cellstr(zE), ...
                cellstr(gnameE)];
        else
            S.ui.tblPostEval.Data = cell(0,6);
        end

        try
            stCenter = uistyle( ...
                'horizontalalignment', ...
                'center');
            addStyle(S.ui.tblPostTrain, ...
                stCenter,'column',[2 3 5]);
            addStyle(S.ui.tblPostEval, ...
                stCenter,'column',[2 3 5]);
        catch
        end

        try
            refreshZones();
        catch
        end

        try
            S.runtime.postSelectionIsRandom = false;
        catch
        end
    end

    function finalizeInitialPlotLayouts()

        drawnow limitrate nocallbacks
    
    
        try
            perfUpdateOnce(false);
        catch ME
            logmsg(['Initial metrics layout failed: ' ...
                ME.message]);
        end
    end

    function refreshModelDropdown(desiredValue)

        if nargin < 1 ...
                || isempty(desiredValue)
            try
                desiredValue = string(S.ui.ddModel.Value);
            catch
                desiredValue = "";
            end
        else
            desiredValue = string(desiredValue);
        end
    
        [items,itemsData] = ...
            local_model_dropdown_items( ...
            char(S.ui.edRoot.Value));
    
        S.ui.ddModel.Items = items;
        S.ui.ddModel.ItemsData = itemsData;
    
        values = string(itemsData);
        hit = find(strcmpi(values,desiredValue),1);
    
        if isempty(hit)
            hit = 1;
        end
    
        S.ui.ddModel.Value = itemsData{hit};
    
        % Keep the configuration synchronized with the dropdown.
        try
            modelName = char(string(itemsData{hit}));
            S.cfg.mdl.model = local_model_id_from_key(modelName);
            S.cfg.mdl = local_model_variant( ...
                S.cfg.mdl,modelName);
        catch
        end
    
        S.cache.modelBase = [];
        S.cache.modelBaseKey = "";
    
        refreshModelDiagram();
        refreshParamTable();
    end

    function refreshEmptyMapTitles()
    %REFRESHEMPTYMAPTITLES Update map titles for currently selected region.

        try
            [~,~,mapName] = getCurrentMapLimits();
        catch
            mapName = 'Region';
        end    
        % Region tab empty-state title
        try
            if isfield(S.ui,'axConus') ...
                    && ~isempty(S.ui.axConus) ...
                    && isvalid(S.ui.axConus)
    
                geographic_dashboard_ui('title',S.ui.axConus, ...
                    sprintf('%s basins',mapName),fontsizeMapTitle);
            end
        catch
        end    
        % Zones tab empty-state title
        try
            if isfield(S.ui,'axZones') ...
                    && ~isempty(S.ui.axZones) ...
                    && isvalid(S.ui.axZones)
    
                geographic_dashboard_ui('title',S.ui.axZones, ...
                    sprintf('%s hydroclimatic zones',mapName), ...
                    fontsizeMapTitle);
            end
        catch
        end
        % Parameter-map title: update immediately on a region change,
        % before the more expensive boundary and marker redraw begins.
        try
            if isfield(S.ui,'axParamMap') ...
                    && ~isempty(S.ui.axParamMap) ...
                    && isvalid(S.ui.axParamMap)
                title(S.ui.axParamMap, ...
                    sprintf('%s parameter map',mapName), ...
                    'fontsize',fontsizeMapTitle, ...
                    'interpreter','latex', ...
                    'fontweight','bold');
            end
        catch
        end
    end

    function region = getCurrentRegion()
        region = region_helpers('code',S.cfg);
        try
            if isfield(S.runtime,'isRunning') ...
                    && S.runtime.isRunning ...
                    && isfield(S.runtime,'lastConfig') ...
                    && ~isempty(S.runtime.lastConfig) ...
                    && isfield(S.runtime.lastConfig,'region')
                region = region_helpers('code', ...
                    S.runtime.lastConfig.region);
            elseif isfield(S.ui,'ddRegion') ...
                    && ~isempty(S.ui.ddRegion)
                region = region_helpers('code', ...
                    S.ui.ddRegion.Value);
            end
        catch
            region = region_helpers('code',S.cfg);
        end
    end

    function clearConusAxes()
        geographic_dashboard_ui('clear',S.ui.axConus, ...
            @currentMapLimits,@deleteGeoTopRightBorder, ...
            @drawGeoTopRightBorder);
    end

    function clearParamMapAxes()
        parameter_map_dashboard_ui('clear',S.ui, ...
            @getCurrentMapLimits,@cleanMapAxes, ...
            @deleteGeoTopRightBorder);
    end

    function refreshParamMapPlaceholder()
        parameter_map_dashboard_ui('placeholder',S.ui, ...
            @getCurrentMapLimits,@cleanMapAxes, ...
            @deleteGeoTopRightBorder,@refreshMapFlag, ...
            fontsizeMapTitle,fontsizeDiagText, ...
            @drawRegionLandBackground,@getCurrentRegion);
    end

    function localInitializeNaturalEarthMap()
    % Resolve the bundled GUI map once. Interactive maps always use the
    % lightweight 50 m geometry and never initiate a network download.
        if isfield(S.runtime,'mapInitialized') ...
                && S.runtime.mapInitialized
            return
        end

        result = struct( ...        
            'ok',false, ...
            'file','', ...
            'scale','none', ...
            'downloaded',false, ...
            'message',''); %#ok

        result = localResolvePackagedMap();

        if isstruct(result)
            if isfield(result,'file')
                S.runtime.mapFile = ...
                    char(string(result.file));
            end

            if isfield(result,'scale')
                S.runtime.mapScale = ...
                    char(string(result.scale));
            end

            if isfield(result,'message')
                S.runtime.mapDownloadMessage = ...
                    char(string(result.message));
            end
        end

        if ~isempty(S.runtime.mapFile)
            logmsg(sprintf( ...
                'Map background: Natural Earth %s.', ...
                S.runtime.mapScale));
        else
            logmsg(['No Natural Earth country map ' ...
                'could be resolved.']);
        end
        S.runtime.mapInitialized = true;
    end

    function refreshWorldCoverageMap()

        if ~isfield(S.ui,'axWorldCoverage') ...
                || isempty(S.ui.axWorldCoverage) ...
                || ~isgraphics(S.ui.axWorldCoverage)
            return
        end
        ax = S.ui.axWorldCoverage;
        % Reuse the drawn map until the data root or installations change.
        if isfield(S.runtime,'worldCoverageDrawn') ...
                && S.runtime.worldCoverageDrawn
            f.WindowButtonMotionFcn = @onWorldCoverageHover;
            layoutWorldCoveragePanel();
            refreshWorldCoverageSelection();
            return
        end
    
        % --------------------------
        % Get Natural Earth geometry
        % --------------------------
        Smap = [];
        try
            if ~isempty(S.cache.naturalEarthShapes)
                Smap = S.cache.naturalEarthShapes;
            end
        catch
        end
        % Usually the geometry has already been loaded during GUI startup.
        % This is just a safe fallback.
        if isempty(Smap)    
            shpFile = localPreferredMapFile();    
            if isempty(shpFile)
                localWorldCoverageMessage(ax, ...
                    'World map boundaries are not available.');
                return
            end    
            try
                Smap = shaperead(shpFile,'UseGeoCoords',true);    
                S.cache.naturalEarthFile = shpFile;
                S.cache.naturalEarthShapes = Smap;    
            catch ME
                localWorldCoverageMessage(ax, ...
                    ['Could not load world map: ' ME.message]);
                return
            end
        end
    
        % -----------------------------------------------------------
        % Determine countries represented by the active SAGE registry
        % -----------------------------------------------------------
        [sageCountries,sageRegionCodes] = ...
            world_coverage_ui_helpers('countries');
        sageCountries = arrayfun(@localWorldCountryKey,sageCountries);
        % ----------
        % Draw world
        % ----------
        % The country patches have HandleVisibility='off', so cla(ax)
        % would leave old colors beneath the refreshed map.
        delete(allchild(ax));
        hold(ax,'on');    
        % Similar appearance to the mock-up
        noneColor = [0.30 0.47 0.66];
        partialColor = [0.95 0.56 0.17];
        allColor = [0.30 0.58 0.42];
        otherColor = [0.82 0.82 0.82];
        edgeColor = [1.00 1.00 1.00];    
        for ii = 1:numel(Smap)
    
            countryName = "";    
            if isfield(Smap,'ADMIN')
                countryName = string(Smap(ii).ADMIN);
            elseif isfield(Smap,'NAME')
                countryName = string(Smap(ii).NAME);
            end    
            matched = find(strcmpi( ...
                localWorldCountryKey(countryName),sageCountries));
            if ~isempty(matched)
                [~,~,installState] = ...
                    localWorldCountryInstallStatus( ...
                    countryName,sageRegionCodes(matched));
                if installState == 2
                    faceColor = allColor;
                elseif installState == 1
                    faceColor = partialColor;
                else
                    faceColor = noneColor;
                end
            else
                faceColor = otherColor;
            end    
            localDrawWorldCountry( ...
                ax,Smap(ii).Lon,Smap(ii).Lat, ...
                faceColor,edgeColor,countryName, ...
                sageRegionCodes(matched));
        end
    
        % ----------
        % Appearance
        % ----------
        xlim(ax,[-180 180]);
        % Leave a narrow strip below Antarctica for the inline key.  The
        % key stays inside the axes so MATLAB does not shrink the map to
        % make room for an external legend.
        ylim(ax,[-106 90]);
        % Preserve the equirectangular geometry. The responsive Paths
        % layout supplies the matching height so the map can remain
        % undistorted while occupying the available width.
        axis(ax,'equal');
        axis(ax,'off');    
        ax.Color = 'none';
    
        % Compact inline installation key below the world map.
        keyY = -101;
        keyColors = {allColor,partialColor,noneColor,otherColor};
        keyLabels = {'All installed','Partly installed', ...
            'Supported, none installed','Not supported'};
        keyX = [-171 -88 3 105];
        for keyIndex = 1:numel(keyColors)
            x0 = keyX(keyIndex);
            patch(ax,[x0 x0+10 x0+10 x0], ...
                [keyY keyY keyY+4.5 keyY+4.5], ...
                keyColors{keyIndex},'EdgeColor','none', ...
                'HitTest','off','PickableParts','none', ...
                'HandleVisibility','off');
            text(ax,x0+13,keyY+2.25,keyLabels{keyIndex}, ...
                'HorizontalAlignment','left', ...
                'VerticalAlignment','middle', ...
                'FontSize',max(11,fontsizeGUI - 1), ...
                'Interpreter','none','HitTest','off', ...
                'PickableParts','none');
        end
        S.ui.txtWorldHover = text(ax,0,0,'', ...
            'Units','data','HorizontalAlignment','left', ...
            'VerticalAlignment','top','FontSize',max(12,fontsizeGUI), ...
            'FontName','Consolas', ...
            'BackgroundColor',[1 1 1],'EdgeColor',[.65 .65 .65], ...
            'Margin',0.01,'Interpreter','tex','Visible','off', ...
            'HitTest','off','PickableParts','none');
        hold(ax,'off');    
        S.runtime.worldCoverageDrawn = true;
        f.WindowButtonMotionFcn = @onWorldCoverageHover;
        layoutWorldCoveragePanel();
        refreshWorldCoverageSelection();
    end

    function refreshWorldCoverageSelection()

        if ~isfield(S.ui,'axWorldCoverage') ...
                || ~isgraphics(S.ui.axWorldCoverage)
            return
        end
        world_coverage_ui_helpers( ...
            'reset',S.ui.axWorldCoverage);
    end

    function onWorldCoverageHover(~,~)

        if ~isfield(S.ui,'txtWorldHover') ...
                || ~isgraphics(S.ui.txtWorldHover)
            return
        end
        try
            if ~isequal(S.ui.tgLeft.SelectedTab,tabPaths)
                localResetWorldHoverOutline();
                S.ui.txtWorldHover.Visible = 'off';
                return
            end
        catch
        end

        obj = world_coverage_ui_helpers( ...
            'hit',f,S.ui.axWorldCoverage);
        if isempty(obj) ...
                || ~isgraphics(obj)
            localResetWorldHoverOutline();
            S.ui.txtWorldHover.Visible = 'off';
            return
        end

        info = obj.UserData;
        countryKey = localWorldCountryKey(info.Country);
        previousKey = "";
        if isfield(S.runtime,'worldHoverCountry')
            previousKey = string(S.runtime.worldHoverCountry);
        end
        if ~strcmpi(previousKey,countryKey)
            world_coverage_ui_helpers( ...
                'highlight',S.ui.axWorldCoverage,countryKey);
            S.runtime.worldHoverCountry = countryKey;
        end

        [status,~,~] = localWorldCountryInstallStatus( ...
            info.Country,info.RegionCodes);
        countryText = strrep(info.Country,'_','\_');
        statusText = strrep(status,'_','\_');
        S.ui.txtWorldHover.String = sprintf( ...
            '\\bf%s\\rm\n%s',countryText,statusText);
        cp = S.ui.axWorldCoverage.CurrentPoint;
        x = cp(1,1);
        y = cp(1,2);
        S.ui.txtWorldHover.HorizontalAlignment = 'left';
        S.ui.txtWorldHover.VerticalAlignment = 'top';
        if x > 115
            x = x - 62;
        else
            x = x + 5;
        end
        y = min(86,y + 8);
        x = min(176,max(-176,x));
        y = max(-91,y);
        S.ui.txtWorldHover.Position = [x y 0];
        S.ui.txtWorldHover.Visible = 'on';
        drawnow limitrate nocallbacks
    end

    function localResetWorldHoverOutline()

        if ~isfield(S.ui,'axWorldCoverage') ...
                || ~isgraphics(S.ui.axWorldCoverage)
            return
        end
        world_coverage_ui_helpers( ...
            'reset',S.ui.axWorldCoverage);
        S.runtime.worldHoverCountry = "";
    end

    function layoutWorldCoveragePanel()

        if isfield(S.runtime,'worldLayoutBusy') ...
                && S.runtime.worldLayoutBusy
            return
        end
        if ~isfield(S.ui,'gPaths') ...
                || ~isgraphics(S.ui.gPaths)
            return
        end
        S.runtime.worldLayoutBusy = true;
        busyCleanup = onCleanup(@()localFinishWorldLayout());
        world_coverage_ui_helpers('layout', ...
            S.ui.gPaths,S.ui.pnlWorldCoverage, ...
            S.ui.axWorldCoverage,f);
    end

    function localFinishWorldLayout()
        S.runtime.worldLayoutBusy = false;
    end

    function localDrawWorldCountry(ax,lon,lat,faceColor,edgeColor, ...
            countryName,regionCodes)

        lon = double(lon(:));
        lat = double(lat(:));
        % Natural Earth multipart polygons are separated by NaNs.
        separator = isnan(lon) | isnan(lat);
        cut = [0; find(separator); numel(lon)+1];

        for ip = 1:numel(cut)-1
            idx = (cut(ip)+1):(cut(ip+1)-1);
            if numel(idx) < 3
                continue
            end
            hCountry = patch(ax, ...
                lon(idx),lat(idx), ...
                faceColor, ...
                'EdgeColor',edgeColor, ...
                'LineWidth',0.35, ...
                'HandleVisibility','off');
            if ~isempty(regionCodes)
                hCountry.Tag = 'SAGEWorldSupported';
                hCountry.UserData = struct( ...
                    'Country',char(countryName), ...
                    'RegionCodes',{regionCodes(:)'}, ...
                    'BaseFaceColor',faceColor);
                hCountry.HitTest = 'on';
                hCountry.PickableParts = 'visible';
            else
                hCountry.HitTest = 'off';
                hCountry.PickableParts = 'none';
            end
        end
    end

    function [status,installed,state] = ...
            localWorldCountryInstallStatus(country,regionCodes)

        if ~isfield(S.cache,'worldInstallStatus') ...
                || ~isstruct(S.cache.worldInstallStatus)
            S.cache.worldInstallStatus = struct();
        end
        base = getConfigFromUI();
        [status,installed,state,S.cache.worldInstallStatus] = ...
            world_coverage_ui_helpers('status', ...
            country,regionCodes,base,S.cache.worldInstallStatus);
    end
    function key = localWorldCountryKey(name)
        key = lower(strtrim(string(name)));
        % Natural Earth uses "Russia" while the SAGE registry uses the
        % official display name "Russian Federation" for HYDRO_CIS.
        if key == "russian federation"
            key = "russia";
        end
    end

    function localWorldCoverageMessage(ax,msg)

        cla(ax);
        text(ax,0.5,0.5,msg, ...
            'Units','normalized', ...
            'horizontalalignment','center', ...
            'verticalalignment','middle', ...
            'fontsize',fontsizeGUI, ...
            'color',[0.35 0.35 0.35], ...
            'interpreter','none');
        axis(ax,'off');
    end

    function result = localResolvePackagedMap()

        result = struct( ...
            'ok',false, ...
            'file','', ...
            'scale','none', ...
            'downloaded',false, ...
            'message','');

        file50 = localFindMapFile( ...
            '50','ne_50m_admin_0_countries.shp');

        if isempty(file50)
            file50 = localFindMapFile( ...
                '','ne_50m_admin_0_countries.shp');
        end

        if ~isempty(file50)
            result.ok = true;
            result.file = file50;
            result.scale = '50m';
            return
        end

        % Development fallback only. The distributed application bundles
        % 50 m; an existing 10 m file is accepted only if that bundle is
        % unexpectedly unavailable.
        file10 = localFindMapFile( ...
            '10','ne_10m_admin_0_countries.shp');
        if ~isempty(file10)
            result.ok = true;
            result.file = file10;
            result.scale = '10m';
        end
    end

    function shpFile = localPreferredMapFile()

        shpFile = '';

        % The 10 m country file is visually attractive but unnecessarily
        % detailed for an interactive GUI axes. Prefer 50 m here; this
        % greatly reduces geoplot vertex creation and Chromium rendering.
        try
            if isfield(S.runtime,'preferFastMap50m') ...
                    && S.runtime.preferFastMap50m
                file50 = localFindMapFile( ...
                    '50','ne_50m_admin_0_countries.shp');
                if isempty(file50)
                    file50 = localFindMapFile( ...
                        '','ne_50m_admin_0_countries.shp');
                end
                if ~isempty(file50)
                    shpFile = file50;
                    return
                end
            end
        catch
        end

        try
            candidate = char(string( ...
                S.runtime.mapFile));

            if isfile(candidate)
                shpFile = candidate;
                return
            end
        catch
        end

        result = localResolvePackagedMap();

        if result.ok
            shpFile = result.file;
            S.runtime.mapFile = result.file;
            S.runtime.mapScale = result.scale;
        end
    end

    function shpFile = localFindMapFile( ...
            scaleFolder,fname)

        shpFile = '';
        cands = {};

        if isdeployed
            if isempty(scaleFolder)
                cands{end+1} = fullfile( ...
                    ctfroot,'maps',fname);
                cands{end+1} = fullfile( ...
                    ctfroot,'SAGEhydrology','maps',fname);
            else
                cands{end+1} = fullfile( ...
                    ctfroot,'maps', ...
                    scaleFolder,fname);
                cands{end+1} = fullfile( ...
                    ctfroot,'SAGEhydrology','maps', ...
                    scaleFolder,fname);
            end
        end

        if isempty(scaleFolder)
            cands{end+1} = fullfile( ...
                S.cfg.SAGEhydro,'maps',fname);
        else
            cands{end+1} = fullfile( ...
                S.cfg.SAGEhydro,'maps', ...
                scaleFolder,fname);
        end

        sourceRoot = fullfile( ...
            fileparts(mfilename('fullpath')), ...
            '..','maps');

        if isempty(scaleFolder)
            cands{end+1} = fullfile( ...
                sourceRoot,fname);
        else
            cands{end+1} = fullfile( ...
                sourceRoot,scaleFolder,fname);
        end

        for i = 1:numel(cands)
            if isfile(cands{i})
                shpFile = cands{i};
                return
            end
        end
    end

    function local_add_country_boundary_gui( ...
            ax,region,latLim,lonLim,fillColor)

        if nargin < 5
            fillColor = [];
        end

        shpFile = localPreferredMapFile();

        if isempty(shpFile)
            warning('SAGE_ui:MapFileMissing', ...
                ['No Natural Earth 10m or 50m ' ...
                 'country shapefile was found.']);
            return
        end

        % Load the Natural Earth file only once. The 10 m file contains
        % many vertices, so repeated shaperead calls dominated Map-tab
        % switching time.
        try
            cacheMiss = isempty(S.cache.naturalEarthShapes) ...
                || ~strcmp(S.cache.naturalEarthFile,shpFile);
            if cacheMiss
                S.cache.naturalEarthShapes = shaperead(shpFile, ...
                    'UseGeoCoords',true);
                S.cache.naturalEarthFile = shpFile;
                S.cache.countryBoundary = struct();
            end
            Smap = S.cache.naturalEarthShapes;
        catch ME
            warning('SAGE_ui:ShapeReadFailed', ...
                ['Could not read boundary ' ...
                'shapefile: %s'],ME.message);
            return
        end

        countryName = region_helpers( ...
            'country_name',region);
        cacheKey = matlab.lang.makeValidName(upper(char(region)));

        % Cache the selected country coordinates as well, so subsequent
        % redraws avoid scanning every Natural Earth record.
        if isfield(S.cache.countryBoundary,cacheKey)
            boundary = S.cache.countryBoundary.(cacheKey);
        else
            keep = false(numel(Smap),1);
            for ii = 1:numel(Smap)
                nm = "";
                if isfield(Smap,'ADMIN')
                    nm = string(Smap(ii).ADMIN);
                elseif isfield(Smap,'NAME')
                    nm = string(Smap(ii).NAME);
                end
                keep(ii) = strcmpi(nm,countryName);
            end
            if ~any(keep)
                keep = true(numel(Smap),1);
            end
            idxKeep = find(keep(:));
            boundary = repmat(struct('Lat',[],'Lon',[]),numel(idxKeep),1);
            for jj = 1:numel(idxKeep)
                boundary(jj).Lat = Smap(idxKeep(jj)).Lat;
                boundary(jj).Lon = Smap(idxKeep(jj)).Lon;
            end
            S.cache.countryBoundary.(cacheKey) = boundary;
        end

        hold(ax,'on')
        for ii = 1:numel(boundary)
            try
                if isempty(fillColor)
                    hB = geoplot(ax, ...
                        boundary(ii).Lat, ...
                        boundary(ii).Lon, ...
                        '-', ...
                        'color',[0 0 0], ...
                        'linewidth',1.2, ...
                        'tag','SAGECountryBoundary', ...
                        'handlevisibility','off');
                else
                    countryShape = geopolyshape( ...
                        boundary(ii).Lat,boundary(ii).Lon);
                    hB = geoplot(ax,countryShape, ...
                        'FaceColor',fillColor, ...
                        'FaceAlpha',1, ...
                        'EdgeColor',[0 0 0], ...
                        'LineWidth',1.2, ...
                        'tag','SAGECountryLand', ...
                        'handlevisibility','off');
                end
                try
                    uistack(hB,'bottom');
                catch
                end
            catch
            end
        end
        try
            geolimits(ax,latLim,lonLim);
        catch
        end
    end

    function drawRegionLandBackground(ax,region,latLim,lonLim)
    %DRAWREGIONLANDBACKGROUND GUI-colored water with local land polygons.
        try
            geobasemap(ax,'none');
        catch
        end
        try
            % Let the dashboard layout show through.  Using f.Color here
            % can differ by a few RGB levels from the tab/layout background.
            ax.Color = 'none';
        catch
        end

        % Preserve a quiet gray-land appearance while making the water
        % exactly the same color as the surrounding SAGE window.
        landColor = [0.88 0.88 0.88];
        try
            guiColor = double(f.Color);
            try
                if isprop(ax.Parent,'BackgroundColor')
                    guiColor = double(ax.Parent.BackgroundColor);
                end
            catch
            end
            if numel(guiColor) >= 3
                landColor = max(0,min(1,guiColor(1:3) - 0.06));
            end
        catch
        end
        local_add_country_boundary_gui( ...
            ax,region,latLim,lonLim,landColor);
    end

    function hideParamMapAxes()
        parameter_map_dashboard_ui('hideaxes',S.ui, ...
            @deleteGeoTopRightBorder);
    end

    function conusPlotPlain(aux,bas)
        try
            region = getCurrentRegion();
        catch
            region = region_helpers('code',S.cfg);
        end
        cfg = struct( ...
            'clearFcn',@clearConusAxes, ...
            'limitsFcn',@getCurrentMapLimits, ...
            'backgroundFcn',@drawRegionLandBackground, ...
            'selectionFcn',@(~,~)deal( ...
                false(bas.K_t,1),false(bas.K_e,1)), ...
            'clickFcn',[], ...
            'errorFcn',@logRegionDataTipError, ...
            'capitalFcn',@(gx)site_plotRegionCapital(gx,getCurrentRegion()), ...
            'legendLocationFcn',@localMapLegendLocation, ...
            'drawBorderFcn',@drawGeoTopRightBorder, ...
            'enableDataTipsFcn',@()site_enableConusDataTips(S.ui.axConus), ...
            'region',region,'titleFont',fontsizeMapTitle, ...
            'legendFont',fontsizeMapLegend);
        geographic_dashboard_ui('renderregion',S.ui,aux,bas,cfg);
        site_removeBasinMarkerOutlines(S.ui.axConus);
        lg = S.ui.axConus.Legend;
        if ~isempty(lg) && isgraphics(lg)
            setappdata(S.ui.axConus,'SITEBaseLegendHandles',lg.PlotChildren);
            setappdata(S.ui.axConus,'SITEBaseLegendLabels',lg.String);
        end
        refreshSiteActiveBasins();
        title(S.ui.axConus,sprintf('%s basins: $K = %d$', ...
            localRegionPanelName(region),bas.K_t), ...
            'Interpreter','latex','FontSize',fontsizeMapTitle, ...
            'FontWeight','bold');
        S.ui.lblConusInfo.Text = ['Training basins ' ...
            '= blue circles.'];
    end

    function logRegionDataTipError(message)
        logmsg(['Region data-tip setup failed: ' char(string(message))]);
    end

    function paramMapPlotCountry(latlon,bas,nTheta,j,basinMode)
        try
            region = getCurrentRegion();
        catch
            region = region_helpers('code',S.cfg);
        end
        callbacks = struct( ...
            'clearFcn',@clearParamMapAxes, ...
            'limitsFcn',@getCurrentMapLimits, ...
            'boundaryFcn',@drawRegionLandBackground, ...
            'cleanFcn',@cleanMapAxes, ...
            'hideFcn',@hideParamMapAxes, ...
            'selectionFcn',@()getConusSelectionMasks_new( ...
                S.ui.tblPostTrain,S.ui.tblPostEval, ...
                bas.K_t,bas.K_e), ...
            'legendLocationFcn',@localMapLegendLocation, ...
            'labelFcn',@(name)trace_ylabel_general([],name,1), ...
            'parameterTable',{S.ui.tblPars.Data}, ...
            'region',region,'titleFont',fontsizeMapTitle, ...
            'legendFont',fontsizeMapLegend, ...
            'hideMissing',true);
        parameter_map_dashboard_ui('render',S.ui,latlon,bas,nTheta,j, ...
            basinMode,callbacks);
        site_removeBasinMarkerOutlines(S.ui.axParamMap);
    end

    function onBasinTableLocate(src,evt,group,gaugeColumn,ignoreChecks)
    %ONBASINTABLELOCATE Locate a table basin without selecting it.
        try
            if isempty(evt.Indices) ...
                    || ~S.runtime.prepared
                return
            end
            row = evt.Indices(end,1);
            col = evt.Indices(end,2);
            % Train/eval checkboxes retain their postprocessing behavior.
            if ignoreChecks && any(col == [2 3])
                return
            end
            D = src.Data;
            if row < 1 || row > size(D,1) ...
                    || gaugeColumn > size(D,2)
                return
            end
            gauge = strip(string(D{row,gaugeColumn}));
            if gauge == "" || ismissing(gauge)
                return
            end

            S.runtime.locatedGauge = gauge;
            S.runtime.locatedGaugeGroup = char(group);

            alreadyVisible = false;
            try
                alreadyVisible = isequal( ...
                    S.ui.tgRight.SelectedTab,S.ui.tabRegionMap);
            catch
            end
            if alreadyVisible
                refreshRegion();
            else
                S.ui.tgRight.SelectedTab = S.ui.tabRegionMap;
                drawnow;
            end
            localPulseRegionBasin(gauge,group);
        catch ME
            logmsg(['Could not locate basin on Region map: ' ...
                ME.message]);
        end
    end

    function onPlotTrainBasinLocate(src,evt)
        onBasinTableLocate(src,evt,'train',2,false);
    end

    function onPostTrainBasinLocate(src,evt)
        onBasinTableLocate(src,evt,'train',4,true);
    end

    function localPulseRegionBasin(gauge,group)
    %LOCALPULSEREGIONBASIN Animate one noninteractive overlay marker.
        if ~S.runtime.prepared ...
                || isempty(S.runtime.preparedBasins) ...
                || isempty(S.runtime.preparedLatLon)
            return
        end

        bas = S.runtime.preparedBasins;
        latlon = S.runtime.preparedLatLon;
        region = region_helpers('code',S.ui.ddRegion.Value);
        ids = local_region_gauge_id(bas.id_gauge(:),region);
        target = local_region_gauge_id(gauge,region);
        idx = find(strcmpi(ids,target),1);
        if isempty(idx)
            logmsg(sprintf( ...
                'Could not match basin %s on the Region map.', ...
                char(string(gauge))));
            return
        end
        if idx > size(latlon,1) ...
                || size(latlon,2) < 2
            logmsg(sprintf( ...
                'No mapped coordinates are available for basin %s.', ...
                char(string(gauge))));
            return
        end
        lat = double(latlon(idx,1));
        lon = double(latlon(idx,2));
        if ~isfinite(lat) || ~isfinite(lon)
            logmsg(sprintf( ...
                'Basin %s has invalid latitude or longitude.', ...
                char(string(gauge))));
            return
        end

        gx = S.ui.axConus;
        marker = 'o';
        baseSize = 58;
        if strcmpi(group,'eval')
            marker = 's';
            baseSize = 66;
        end

        % Remove a stale locator left by an interrupted earlier pulse.
        try
            delete(findall(gx,'Tag','SAGEBasinLocator'));
        catch
        end

        wasHeld = ishold(gx);
        hold(gx,'on');
        h = geoscatter(gx,lat,lon,baseSize*1.8, ...
            marker,'filled', ...
            'MarkerFaceColor',[0 0 0], ...
            'MarkerEdgeColor',[1 1 1], ...
            'LineWidth',1.4, ...
            'Tag','SAGEBasinLocator', ...
            'HandleVisibility','off');
        try
            h.HitTest = 'off';
            h.PickableParts = 'none';
        catch
        end
        if ~wasHeld
            hold(gx,'off');
        end

        pulse = baseSize .* [1.8 3.0 1.8 3.0 1.8];
        for ii = 1:numel(pulse)
            if ~isgraphics(h)
                return
            end
            h.SizeData = pulse(ii);
            drawnow;
            pause(0.08);
        end
        if isgraphics(h)
            delete(h);
        end
        drawnow limitrate;
    end

    function configureRegionBasinClick(h,group,tableRows)
    %CONFIGUREREGIONBASINCLICK Add selection without disabling map tools.
        try
            h.UserData = struct('group',group, ...
                'tableRows',tableRows(:));
            % A Hit listener preserves the geoaxes data-tip, pan, and zoom
            % interactions, unlike assigning the chart ButtonDownFcn.
            addlistener(h,'Hit',@onRegionBasinHit);
        catch ME
            logmsg(['Region click-selection setup failed: ' ME.message]);
        end
    end

    function onRegionBasinHit(src,evt)
        try
            if ~isprop(evt,'Button') || evt.Button ~= 1
                return
            end
        catch
        end
        try
            meta = src.UserData;
            lat = double(src.LatitudeData(:));
            lon = double(src.LongitudeData(:));
            cp = double(S.ui.axConus.CurrentPoint);
            clickLat = cp(1,1);
            clickLon = cp(1,2);
            % Longitude distances contract with latitude. Since the Hit
            % event already identifies the scatter group, nearest-neighbor
            % selection within that group is robust even for dense maps.
            d2 = (lat-clickLat).^2 + ...
                ((lon-clickLon)*cosd(clickLat)).^2;
            [~,pointIndex] = min(d2);
            row = meta.tableRows(pointIndex);

            if strcmpi(meta.group,'train')
                tbl = S.ui.tblPostTrain;
                enabled = [logical(S.ui.cbScenTT.Value), ...
                    logical(S.ui.cbScenTE.Value)];
            else
                tbl = S.ui.tblPostEval;
                enabled = [logical(S.ui.cbScenET.Value), ...
                    logical(S.ui.cbScenEE.Value)];
            end
            if strcmpi(tbl.Enable,'off')
                return
            end
            cols = find(enabled)+1;
            if isempty(cols)
                return
            end
            D = tbl.Data;
            current = false(1,numel(cols));
            for k = 1:numel(cols)
                current(k) = logical(D{row,cols(k)});
            end
            newValue = ~all(current);
            for k = 1:numel(cols)
                D{row,cols(k)} = newValue;
            end
            tbl.Data = D;
            updateBprtFromPostTables();
            onPostprocessRefresh();
        catch ME
            logmsg(['Region basin click failed: ' ME.message]);
        end
    end

    % Parser-relief: late pure/UI helper bodies moved below SITE_ui.

    % can move below?

    function local_init_geoaxes(ax,allowTips)
        
        if nargin < 2
            allowTips = false;
        end
        % Use a transparent/local map rather than the opaque grayland tile;
        % the latter fixes ocean pixels to white and ignores ax.Color.
        geobasemap(ax,'none');
        try
            % Inherit the enclosing dashboard color exactly.
            ax.Color = 'none';
        catch
        end
        try
            [latLim,lonLim,~] = getCurrentMapLimits();
            geolimits(ax,latLim,lonLim);            
        catch
            geolimits(ax,[24 50],[-125 -66]);
        end        
        try
            ax.LatitudeAxis.TickDirection = 'out';
            ax.LongitudeAxis.TickDirection = 'out';
        catch
        end
       
        if allowTips
            try
                ax.Interactions = [ ...
                    dataTipInteraction ...
                    panInteraction ...
                    zoomInteraction];
            catch
                try
                    enableDefaultInteractivity(ax);
                catch
                end
            end
        end
        styleMapGeoAxes(ax);    
    end

    function cleanMapAxes(gx)
    
        try
            gx.Color = 'none';
        catch
        end    
        try
            gx.Grid = 'off';
        catch
        end    
        try
            gx.Box = 'off';
        catch
        end 
        try
            styleMapGeoAxes(gx);
        catch
        end
    end
    
    function styleMapGeoAxes(ax)
        fonts = struct('tick',fontsizeMapTick, ...
            'label',fontsizeMapLabel,'title',fontsizeMapTitle);
        map_geoaxes_style_ui(ax,S.ui,fonts, ...
            @deleteGeoTopRightBorder);
    end

    function [latLim,lonLim,mapName] = getCurrentMapLimits()

        try
            region = getCurrentRegion();
        catch
            region = S.cfg.region;
        end
        coords = [];
        try
            coords = S.runtime.preparedLatLon;
        catch
        end
        [latLim,lonLim,mapName,messages] = ...
            region_helpers('maplimits_safe',region,coords);
        for messageIndex = 1:numel(messages)
            logmsg(messages{messageIndex});
        end
    end
end

% ==================================
%  Local standalone helper functions
% ==================================

function site_styleDiagnosticAxes(ax,bgColor,~,~,~)
    if isempty(ax) || ~isgraphics(ax), return, end
    try
        theme = sage_visual_theme();
        sage_apply_axes_theme(ax,theme,'gui');
        ax.Color = bgColor;
    catch
    end
end

function site_scaleBasinMarkers(ax)
% Scale marker area once; leave capital stars unchanged.
    markers = [findall(ax,'Type','Scatter');findall(ax,'Type','Line')];
    for ii = 1:numel(markers)
        h = markers(ii);
        if ~any(strcmp(h.Marker,{'o','s'})) || isappdata(h,'SITEOriginalMarkerSize')
            continue
        end
        if isprop(h,'SizeData')
            setappdata(h,'SITEOriginalMarkerSize',h.SizeData);
            h.SizeData = 0.7*h.SizeData;
        elseif isprop(h,'MarkerSize')
            setappdata(h,'SITEOriginalMarkerSize',h.MarkerSize);
            h.MarkerSize = sqrt(0.7)*h.MarkerSize;
        end
    end
end

function site_removeBasinMarkerOutlines(ax)
%SITE_REMOVEBASINMARKEROUTLINES Do not show SAGE selection outlines in SITE.
    site_scaleBasinMarkers(ax);
    dots = findall(ax,'Type','Scatter');
    proxies = findall(ax,'Type','Line');
    markers = [dots(:); proxies(:)];
    for ii = 1:numel(markers)
        try
            if any(strcmp(markers(ii).Marker,{'o','s'}))
                markers(ii).MarkerEdgeColor = 'none';
            end
        catch
        end
    end
end

function site_styleOutputMonitoringBackgrounds(tgRight,bgColor)
    % Plotting helpers reset axes colors; restore native GUI surfaces last.
    objects = findall(tgRight);
    foreground = site_theme_foreground(bgColor);
    for ii = 1:numel(objects)
        h = objects(ii);
        try
            if isa(h,'matlab.graphics.axis.AbstractAxes')
                if isprop(h.Parent,'BackgroundColor')
                    h.Parent.BackgroundColor = bgColor;
                end
                h.Color = bgColor;
                for name = {'XColor','YColor','ZColor','GridColor'}
                    if isprop(h,name{1})
                        old = h.(name{1});
                        if isnumeric(old) && max(old)-min(old) < 0.05
                            h.(name{1}) = foreground;
                        end
                    end
                end
                for name = {'LatitudeAxis','LongitudeAxis'}
                    if isprop(h,name{1})
                        h.(name{1}).Color = foreground;
                    end
                end
                if isprop(h,'Scalebar')
                    scale = h.Scalebar;
                    scale.FontColor = foreground;
                    scale.EdgeColor = foreground;
                    scale.BackgroundAlpha = 1;
                    if isprop(scale,'BackgroundColor')
                        scale.BackgroundColor = bgColor;
                    end
                end
            elseif isa(h,'matlab.graphics.illustration.Legend')
                h.Color = bgColor;
                h.TextColor = foreground;
            elseif isa(h,'matlab.graphics.illustration.ColorBar')
                h.Color = foreground;
            elseif isa(h,'matlab.graphics.primitive.Text')
                old = h.Color;
                if isnumeric(old) && max(old)-min(old) < 0.05
                    h.Color = foreground;
                end
                if isnumeric(h.BackgroundColor)
                    h.BackgroundColor = bgColor;
                end
            end
        catch
        end
    end
end
function site_stylePerfAxis(ax,bgColor,fontTick,fontTitle,fontLabel,~)
    if isempty(ax) || ~isgraphics(ax), return, end
    site_styleDiagnosticAxes(ax,bgColor,fontTick,fontTitle,fontLabel);
    try
        ax.TickLabelInterpreter = 'latex';
        ax.Title.Interpreter = 'latex';
        ax.XLabel.Interpreter = 'latex';
        ax.YLabel.Interpreter = 'latex';
    catch
    end
end

function site_syncIdAttrField(tblAttr,edAttr)
    D = tblAttr.Data;
    if isempty(D)
        edAttr.Value = '';
        return
    end
    sel = strcmp(string(D(:,1)),"✓");
    edAttr.Value = vec2str_local(find(sel(:)).');
end

function site_applyResolutionDefaults(ui,X,applyRegionFcn,updateSplitFcn)
    ui.edDt.Value = double(X.dt);
    applyRegionFcn();
    ui.spSpin.Value = double(X.period.spinup_days);
    P = X.period.manual;
    ui.edDts.Value = char(string(P.train_start));
    ui.edDte.Value = char(string(P.train_end));
    ui.edDes.Value = char(string(P.eval_start));
    ui.edDee.Value = char(string(P.eval_end));
    commonStart = char(string(X.period.common_start));
    commonEnd = char(string(X.period.common_end));
    ui.edDBlockStart.Value = commonStart;
    ui.edDBlockEnd.Value = commonEnd;
    ui.edRBlockStart.Value = commonStart;
    ui.edRBlockEnd.Value = commonEnd;
    ui.edRndStart.Value = commonStart;
    ui.edRndEnd.Value = commonEnd;
    ui.edDKFoldStart.Value = commonStart;
    ui.edDKFoldEnd.Value = commonEnd;
    ui.edRKFoldStart.Value = commonStart;
    ui.edRKFoldEnd.Value = commonEnd;
    ui.edRainBlockStart.Value = commonStart;
    ui.edRainBlockEnd.Value = commonEnd;
    ui.spDBlockSize.Value = 365;
    ui.edDBlockFrac.Value = 0.8;
    ui.spRBlockSize.Value = 365;
    ui.edRBlockFrac.Value = 0.8;
    ui.edRBlockSeed.Value = 1;
    ui.edRndFrac.Value = 0.8;
    ui.edRndSeed.Value = 1;
    ui.spDKFolds.Value = 5;
    ui.spDKFold.Value = 1;
    ui.spRKFolds.Value = 5;
    ui.spRKFold.Value = 1;
    ui.edRKFoldSeed.Value = 1;
    updateSplitFcn();
end

function s = site_modelPngPath(modelName,rootDir)
    docDir = localDocsDir(rootDir);
    map = containers.Map({'hymod','hmodel','sacsma','Xinanjiang','gr4j','hbv'}, ...
        {'hymod.png','hmodel.png','sacsma.png','Xinanjiang.png','gr4j.png','hbv.png'});
    m = char(modelName);
    if isKey(map,m), s = fullfile(docDir,map(m));
    else, s = fullfile(docDir,[m '.png']); end
end

function s = site_modelSvgPath(modelName,rootDir)
    docDir = localDocsDir(rootDir);
    map = containers.Map({'hymod','hmodel','sacsma','Xinanjiang', ...
        'gr4j','hbv','gchm','gchm_ode'}, ...
        {'hymod_snow.svg','hmodel_snow.svg','sacsma_snow.svg', ...
        'Xinanjiang_snow.svg','gr4j_snow.svg','hbv_snow.svg', ...
        'SAGE_new_model.svg','SAGE_new_model.svg'});
    m = char(modelName);
    if isKey(map,m), s = fullfile(docDir,map(m));
    else, s = fullfile(docDir,[m '.svg']); end
end

function [hCapital,capitalName] = site_plotRegionCapital(gx,region)
    hCapital = gobjects(0);
    capitalName = "";
    if isempty(gx) || ~isgraphics(gx), return, end
    try
        delete(findall(gx,'tag','SAGECapitalMarker'));
        delete(findall(gx,'tag','SAGECapitalLabel'));
    catch
    end
    try
        [lat,lon,name] = region_helpers('capital',region);
    catch
        return
    end
    if ~isfinite(lat) || ~isfinite(lon), return, end
    capitalName = string(name);
    holdState = ishold(gx);
    hold(gx,'on');
    hCapital = geoscatter(gx,lat,lon,170,'p','filled', ...
        'MarkerFaceColor',[1 0 0.2],'MarkerEdgeColor',[1 0 0.2], ...
        'linewidth',1,'handlevisibility','on');
    hCapital.Tag = 'SAGECapitalMarker';
    try
        hCapital.PickableParts = 'none';
        hCapital.HitTest = 'off';
    catch
    end
    try uistack(hCapital,'top'); catch, end
    if ~holdState, hold(gx,'off'); end
end

function site_enableConusDataTips(gx)
    if isempty(gx) || ~isgraphics(gx), return, end
    try
        gx.Interactions = [dataTipInteraction panInteraction zoomInteraction];
    catch
        try enableDefaultInteractivity(gx); catch, end
    end
end

function site_reorderRightTabs(tgRight,tabs)
    try
        desired = gobjects(0);
        for kk = 1:numel(tabs)
            if ~isempty(tabs{kk}) && isvalid(tabs{kk}) ...
                    && isequal(tabs{kk}.Parent,tgRight)
                desired(end+1) = tabs{kk}; %#ok<AGROW>
            end
        end
        if numel(desired) == numel(tgRight.Children)
            tgRight.Children = desired(:);
        end
    catch
    end
end


% -------------------------------------------------------------------------
% Parser-relief helpers moved out of the nested SAGE_ui workspace.
% -------------------------------------------------------------------------

function refreshMeteoPETInfo_standalone(ui,cfg,fontsizeNotes)

    % ------
    % Region
    % ------
    region = region_helpers('code', ...
        ui.ddRegion.Value);
    % ----------
    % Meteo text
    % ----------
    meteoVal = char(ui.ddMeteo.Value);
    % --------
    % PET text
    % --------
    petVal = char(ui.ddPET.Value);

    isHourly = strcmpi(char(ui.ddRes.Value),'Hourly');
    is15min = strcmpi(char(ui.ddRes.Value),'15 minutes');
    U = localFluxUnits(ui.ddRes.Value);
    try
        ui.edMeteoResolution.Value = U.Freq;
    catch
    end

    meteoText = {''};
    petText = {''};

    switch region

        case 'CAMELS_AU'
            meteoText = { ...
                '\textbf{CAMELS-AUS v2 daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from Australia. AGCD and SILO gridded ' ...
                'products from the CSV files.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                ['1: SILO = Scientific Information ' ...
                'for Land Owners. Basin-average ' ...
                'precipitation from 0.05$^\circ$ grids.'], ...
                ['2: AGCD = Bureau of Meteorology ' ...
                'Australian Gridded Climate Data. ' ...
                'Basin-average precipitation from ' ...
                '0.05$^\circ$ grids.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: SILO = mean of minimum and maximum daily ' ...
                'basin-average temperature.'], ...
                ['2: AGCD = mean of minimum and maximum daily ' ...
                'basin-average temperature.'], ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['1: Synthetic evaporation = interpolated ' ...
                'synthetic extended Class A pan evaporation. ' ...
                'Default PET/evaporative-demand choice.'], ...
                ['2: Pan evaporation = interpolated Class A ' ...
                'pan evaporation.'], ...
                ['3: Morton lake evaporation = Morton ' ...
                'shallow-lake evaporation.'], ...
                ['4: Tall crop ET = ASCE tall-crop ' ...
                'reference evapotranspiration.'], ...
                ['5: Short crop ET = FAO56 short-crop ' ...
                'reference evapotranspiration.'], ...
                ['6: Morton wet ET = Morton wet-environment ' ...
                'areal PET over land.'], ...
                ['7: Morton point ET = Morton point ' ...
                'potential evapotranspiration.'], ...
                ['8: Morton actual ET = Morton areal ' ...
                'actual evapotranspiration. For ' ...
                'completeness but not PET.'], ...
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.']};

        case 'CAMELS_AT'
            
            isHourly = strcmpi(char(ui.ddRes.Value),'Hourly');
            if isHourly
                tempNotes = { ...
                    '1: Mean temperature.'};
            else
                tempNotes = { ...
                    '1: Mean temperature.', ...
                    ['2: $T_{\rm mean} = ' ...
                     '0.5(T_{\rm min} + T_{\rm max})$.']};
            end

            meteoText = [ ...
                {'\textbf{CAMELS-AT hydrometeorological forcing}'}, ...
                {[' ' U.Freq ' hydrometeorological time ' ...
                'series for 859 river basins distributed ' ...
                'across Austria.']}, ...
                {''}, ...
                {['The hydrometeorological data include ' U.freq ...
                 ' precipitation, potential evapotranspiration, air ' ...
                 'temperature, and streamflow observations. Temperature is ' ...
                 'read from the selected temperature option.']}, ...
                {''}, ...
                {U.P}, ...
                {['1: ' U.Freq ' basin-average precipitation.']}, ...
                {''}, ...
                {'\textbf{Temperature ($^\circ$C)}'}, ...
                tempNotes(:)', ...
                {''}, ...
                {U.ET}, ...
                {'0: Zero PET.'}, ...
                {'1: Penman--Monteith.'}, ...
                {'2: Priestley--Taylor.'}, ...
                {'3: Makkink.'}, ...
                {'4: LamaH ΣET.'}, ...
                {''}, ...
                {U.Q}, ...
                {['Streamflow observations are converted ' ...
                'from discharge to runoff depth using basin area.']}];
            isHourly = strcmpi(char(ui.ddRes.Value),'Hourly');
            petVal = char(ui.ddPET.Value);
            petText = localPETNotes(petVal,isHourly,'computed');

        case 'CAMELS_BR'
            meteoText = { ...
                '\textbf{CAMELS-BR daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from Brazil. Different products from ' ...
                'CSV files'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '0: Mean of all available precipitation products.', ...
                ['1: BR-DWGD = Brazil Daily Weather Gridded ' ...
                'Dataset.'], ...
                ['2: CHIRPS = Climate Hazards Group InfraRed ' ...
                'Precipitation with Stations (CHIRPS).'], ...
                ['3: CPC = Unified Gauge-Based Analysis ' ...
                'from the NOAA Climate Prediction Center.'], ...
                ['4: ERA5-Land = ECMWF ERA5-Land reanalysis ' ...
                'precipitation.'], ...
                ['5: MSWEP = Multi-Source Weighted-Ensemble ' ...
                'Precipitation.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: ERA5-Land mean air temperature.', ...
                ['2: CPC mean of minimum and maximum air ' ...
                'temperature.'], ...
                ['3: ERA5-Land mean of minimum and maximum air ' ...
                'temperature.'], ...
                ['4: BR-DWGD mean of minimum and maximum air ' ...
                'temperature.'], ...
                '', ...
                ['\textbf{Potential evapotranspiration ' ...
                '(mm d$^{-1}$)}'], ...
                '0: Mean of all available PET products.', ...
                ['1: GLEAM = Global Land Evaporation ' ...
                'Amsterdam Model.'], ...
                ['2: ERA5-Land = ERA5-Land potential ' ...
                'evapotranspiration.'], ...
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.'], ...
                '', ...
                '\textbf{Option 0}', ...
                ['For each day, SAGE averages available ' ...
                'products with finite values. NaN values are ' ...
                'ignored for that day.']};

        case 'CAMELS_CA'
            if strcmpi(char(ui.ddRes.Value),'Hourly')
                meteoText = { ...
                    '\textbf{CAMELS-SPAT Canada | RDRS}', ...
                    'Hourly lumped meteorological forcing', ...
                    '', ...
                    U.P, ...
                    '1: RDRS basin-average precipitation.', ...
                    '', ...
                    '\textbf{Temperature ($^\circ$C)}', ...
                    '1: RDRS basin-average air temperature.', ...
                    '', ...
                    U.ET, ...
                    ['1: RDRS Penman--Monteith potential ' ...
                    'evapotranspiration.'], ...
                    '', ...
                    U.Q, ...
                    ['Observed hourly discharge converted from ' ...
                    'm$^3$ s$^{-1}$ to basin-average runoff depth.']};
            else
                meteoText = { ...
                    '\textbf{CAMELS-SPAT Canada | Daymet}', ...
                    'Daily lumped meteorological forcing', ...
                    '', ...
                    U.P, ...
                    '1: Daymet basin-average precipitation.', ...
                    '', ...
                    '\textbf{Temperature ($^\circ$C)}', ...
                    '1: Daymet mean temperature $(T_{\min}+T_{\max})/2$.', ...
                    '', ...
                    U.ET, ...
                    '1: Priestley--Taylor supplied by CAMELS-SPAT.', ...
                    '', ...
                    U.Q, ...
                    ['Observed daily discharge converted ' ...
                    'from m$^3$ s$^{-1}$ to basin-average runoff depth.']};
            end
            petText = {};
            
        case 'CAMELS_CH'
            meteoText = { ...
                '\textbf{CAMELS-CH hydrometeorological forcing}', ...
                ['Daily hydrometeorological time series for 221 ' ...
                'Swiss catchments spanning a wide range of ' ...
                'elevations, climatic conditions, and hydrologic ' ...
                'regimes. Meteorological forcing is available ' ...
                'from both observation-based and ' ...
                'simulation-based products.'], ...
                '', ...
                ['Observation-based files provide precipitation, ' ...
                'mean, minimum, and maximum air temperature, and ' ...
                'streamflow observations. Simulation-based files ' ...
                'provide precipitation and potential ' ...
                'evapotranspiration estimates together with other ' ...
                'meteorological variables.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: Observation-based.', ...
                '2: Simulation-based.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Observation-based mean air.', ...
                '2: Observation-based (Tmin+Tmax)/2.', ...
                '', ...
                ['\textbf{Potential evapotranspiration ' ...
                '(mm d$^{-1}$)}'], ...
                '1: Simulation-based.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Daily discharge observations from gauging ' ...
                'stations.']};

        case 'CAMELS_CL'
            meteoText = { ...
                '\textbf{CAMELS-CL meteorological forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from Chile. Different products are ' ...
                'read from CSV files.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                ['1: CR2MET = Center for Climate and Resilience ' ...
                'Research daily basin-average precipitation.'], ...
                ['2: CHIRPS = Climate Hazards Group InfraRed ' ...
                'Precipitation with Station data.'], ...
                ['3: MSWEP = Multi-Source Weighted-Ensemble ' ...
                'Precipitation estimates.'], ...
                ['4: TMPA = TRMM Multi-satellite Precipitation ' ...
                'Analysis estimates.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: CR2MET basin-average mean air temperature.', ...
                ['2: CR2MET daily mean air temperature computed from ' ...
                '$T_{\rm min}$ and $T_{\rm max}$ as ' ...
                '$T_{\rm mean} = (T_{\rm max} + T_{\rm min})/2$.'], ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['1: Hargreaves = reference PET estimated from daily ' ...
                'temperature and extraterrestrial radiation.'], ...
                ['2: MODIS = satellite-derived PET from MODIS ' ...
                '(https://nsidc.org/data/modis).'], ...
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.'], ...
                '', ...
                '\textbf{Hargreaves equation}', ...
                ['\hspace{0.5cm} ${\rm ET}_{0} = 0.0023\,R_{\rm a}\,(T_{\rm mean} + 17.8)' ...
                '\sqrt{T_{\rm max} - T_{\rm min}}$'], ...
                '', ...
                '\textbf{Variables and units}', ...
                ['${\rm ET}_{0}$ (mm d$^{-1}$) is reference ' ...
                'evapotranspiration, $R_{\rm a}$ (W\,m$^{-2}$) is ' ...
                'extraterrestrial radiation, and $T_{\rm mean}$, ' ...
                '$T_{\rm min}$, and $T_{\rm max}$ ($^\circ$C) are ' ...
                'mean, minimum, and maximum daily air temperatures, ' ...
                'respectively.'], ...
                '', ...
                ['Hargreaves is a simple temperature-based method. ' ...
                'Limitations are expected in humid coastal climates, ' ...
                'windy or arid regions, snow-dominated basins, and ' ...
                'places where humidity strongly controls evapotranspiration.'], ...
                '', ...
                '\textbf{References}', ...
                ['Hargreaves, G.H. and Samani, Z.A. (1985), ' ...
                'Reference crop evapotranspiration from ' ...
                'temperature, \textit{Applied Engineering in ' ...
                'Agriculture}, vol. 1, pp. 96--99, ' ...
                'doi:10.13031/2013.26773']};

        case 'CAMELS_COL'
            meteoText = { ...
                '\textbf{CAMELS-COL hydrometeorological forcing}', ...
                ['Daily hydrometeorological time series for ' ...
                '346 river basins distributed across Colombia. ' ...
                'Within SAGE, a subset of only 91 basins is used ' ...
                'with continuous meteorological forcing records.'], ...
                '', ...
                ['The hydrometeorological data include daily ' ...
                'precipitation, potential evapotranspiration, air ' ...
                'temperature, and streamflow observations. Daily ' ...
                'mean temperature is computed from minimum and ' ...
                'maximum temperature records contained in the ' ...
                'basin hydrometeorological files.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: Daily basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: Mean daily air temperature from $T_{\rm min}$ ' ...
                'and $T_{\rm max}$.'], ...
                '', ...
                ['\textbf{Potential evapotranspiration ' ...
                '(mm d$^{-1}$)}'], ...
                '1: Daily PET from the ETP column.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Daily discharge observations from the Caudal ' ...
                'column, converted from m$^3$\,s$^{-1}$ to runoff ' ...
                'depth using basin area.']};
                
        case 'CAMELS_CZ'
            if isHourly
                meteoText = { ...
                    '\textbf{CAMELS-CZ hourly forcing}', ...
                    ['Hourly hydrometeorological time series for 249 ' ...
                    'Czech catchments, 2016--2025.'], ...
                    '', ...
                    '\textbf{Precipitation (mm h$^{-1}$)}', ...
                    '1: CHMI hourly basin-average precipitation.', ...
                    '2: ERA5-Land hourly precipitation.', ...
                    '', ...
                    '\textbf{Temperature ($^\circ$C)}', ...
                    '1: CHMI hourly mean temperature.', ...
                    '2: ERA5-Land hourly temperature.', ...
                    '', ...
                    ['\textbf{Potential evapotranspiration ' ...
                    '(mm h$^{-1}$)}'], ...
                    '1: Native hourly ERA5-Land potential evaporation.', ...
                    ['2: Daily CHMI FAO Penman--Monteith, distributed ' ...
                    'uniformly over 24 hours.'], ...
                    ['3: Daily ERA5-Land FAO Penman--Monteith, ' ...
                    'distributed uniformly over 24 hours.'], ...
                    ['4: Daily native ERA5-Land potential evaporation, ' ...
                    'distributed uniformly over 24 hours.'], ...
                    '', ...
                    '\textbf{Observed discharge (mm h$^{-1}$)}', ...
                    'Hourly discharge observations.'};
            else
                meteoText = { ...
                '\textbf{CAMELS-CZ daily forcing}', ...
                ['Daily hydrometeorological time series for 249 ' ...
                'Czech catchments.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                ['1: CHMI = Czech Hydrometeorological Institute ' ...
                'daily basin-average precipitation.'], ...
                ['2: ERA5-Land = Land-surface version of ECMWF ' ...
                'Reanalysis, fifth generation.'], ...
                '3: Combined CHMI/ERA5-Land precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: CHMI = Czech Hydrometeorological Institute ' ...
                'daily mean temperature.'], ...
                ['2: ERA5-Land = Land-surface mean temperature ' ...
                'of ECMWF Reanalysis, fifth generation.'], ...
                '3: Combined CHMI/ERA5-Land mean temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['1: CHMI = Czech Hydrometeorological Institute ' ...
                'daily FAO Penman--Monteith.'], ...
                ['2: ERA5-Land = Land-surface FAO Penman-Monteith ' ...
                'of ECMWF Reanalysis, fifth generation.'], ...
                '3: ERA5-Land native potential evaporation.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Daily discharge observations in mm d$^{-1}$ ' ...
                'from gauging stations.']};
            end

        case {'CAMELS_DE','CAMELS_DEH'}

            isHourly = strcmpi(char(ui.ddRes.Value),'Hourly');
        
            if isHourly
                tempNotes = { ...
                    '1: Mean hourly air temperature.'};
        
                petIntro = ['Hourly PET is computed from the hourly ' ...
                    'CAMELS-DE hydrometeorological variables. The ' ...
                    'reader uses shortwave radiation, surface pressure, ' ...
                    'humidity or water-vapor mixing ratio, air temperature, ' ...
                    'wind speed or wind components, cloud cover, and ' ...
                    'dew-point temperature when available. Downwelling ' ...
                    'longwave radiation is estimated locally from air ' ...
                    'temperature, vapor pressure, and cloud cover.'];
        
            else
                tempNotes = { ...
                    '1: Mean daily air temperature.'};
        
                petIntro = ['Daily PET is computed from the daily ' ...
                    'CAMELS-DE hydrometeorological variables using ' ...
                    'the shared \texttt{et0\_fao56\_daily}\,\,routine. ' ...
                    'The reader uses daily minimum and maximum air ' ...
                    'temperature, radiation, vapor pressure or humidity, ' ...
                    'wind speed when available, day of year, and basin ' ...
                    'latitude/elevation from the topographic attributes.'];
            end
        
            meteoText = [ ...
                {'\textbf{CAMELS-DE hydrometeorological forcing}'}, ...
                {[' ' U.Freq ' hydrometeorological time series ' ...
                'for German river basins. Precipitation, air ' ...
                'temperature, streamflow observations, and additional ' ...
                'meteorological variables are read directly from the ' ...
                'basin CSV time-series files.']}, ...
                {''}, ...
                {['The selected data resolution controls whether SAGE ' ...
                'uses the daily or hourly CAMELS-DE time-series folder. ' ...
                'Meteorological forcing is kept over the full model ' ...
                'period, including spin-up, whereas streamflow is scored ' ...
                'only over the selected training/evaluation indices.']}, ...
                {''}, ...
                {U.P}, ...
                {['1: ' U.Freq ' basin-average precipitation.']}, ...
                {''}, ...
                {'\textbf{Temperature ($^\circ$C)}'}, ...
                tempNotes(:)', ...
                {''}, ...
                {U.ET}, ...
                {'1: Penman--Monteith.'}, ...
                {'2: Priestley--Taylor.'}, ...
                {'3: Makkink.'}, ...
                {''}, ...
                {petIntro}, ...
                {''}, ...
                {U.Q}, ...
                {['Specific discharge observations are read from ' ...
                '\texttt{discharge\_spec\_obs}. Bad or missing streamflow ' ...
                'values are masked in the scored period.']}];
        
            petVal = char(ui.ddPET.Value);
            petText = localPETNotes(petVal,isHourly,'computed');

        case 'CAMELS_DK'
            meteoText = { ...
                '\textbf{CAMELS-DK daily hydrometeorological forcing}', ...
                ['Catchment-aggregated daily meteorological and ' ...
                'streamflow time series for 304 gauged catchments ' ...
                'across Denmark.'], ...
                '', ...
                ['The daily forcing files contain precipitation, ' ...
                'mean air temperature, potential evapotranspiration, ' ...
                'and observed streamflow. Meteorological forcing is ' ...
                'retained over the complete model period, including ' ...
                'spin-up, while discharge is scored only over the ' ...
                'selected training and evaluation indices.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: Gridded Danish Meteorological Institute data.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Mean catchment air temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['1: Makkink potential evapotranspiration ' ...
                'supplied with CAMELS-DK.'], ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed streamflow in m$^3$\,s$^{-1}$ and ' ...
                'converted to catchment-average ' ...
                'runoff depth using'], ...
                ['\hspace{0.5cm} $Q_{\rm mm\,d^{-1}} = ' ...
                '86,400 \times \frac{10^{3}}{A}Q_{\rm m^3\,s^{-1}}$'], ...
                ['where $A$ is catchment area in m$^2$. Negative or ' ...
                'missing meteorological and discharge values are ' ...
                'masked before scoring.'], ...
                '', ...
                '\textbf{Resolution}', ...
                ['CAMELS-DK is currently supported at daily ' ...
                'resolution only (${\rm dt} = 1$).']};

            petVal = char(ui.ddPET.Value);
            petText = localPETNotes(petVal,false,'supplied');
            
        case 'CAMELS_ES'

            esData = parseLeadingInt_local(meteoVal);
            if esData == 2
                selectedES = 'ERA5-Land';
            else
                selectedES = 'EMO-1';
            end
            
            meteoText = { ...
                '\textbf{CAMELS-ES daily forcing}', ...
                ['Catchment-averaged daily hydrometeorological ' ...
                'time series for 269 river basins across Spain.'], ...
                '', ...
                ['Selected meteorological data set: \textbf{' ...
                selectedES '}. Precipitation, mean air temperature, and ' ...
                'potential evapotranspiration are taken from the same ' ...
                'forcing product.'], ...
                '', ...
                U.P, ...
                ['Selected product: ' selectedES '.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['Selected product: ' selectedES '.'], ...
                '', ...
                U.ET, ...
                ['Selected product: ' selectedES '.'], ...
                '', ...
                '\textbf{Meteorological data sets}', ...
                ['1: EMO-1 = European Meteorological Observations at ' ...
                '1 arc-minute spatial resolution.'], ...
                '   Precipitation: \texttt{pr\_emo1}\;(mm d$^{-1}$).', ...
                ['   Mean air temperature: \texttt{ta\_emo1}\;' ...
                '($^\circ$C).'], ...
                ['   Reference evapotranspiration: \texttt{e0\_emo1}\;' ...
                '(mm d$^{-1}$).'], ...
                '', ...
                ['2: ERA5-Land = catchment-averaged daily ERA5-Land ' ...
                'meteorological forcing.'], ...
                ['   Precipitation: \texttt{total\_precipitation\_sum}\;' ...
                '(mm d$^{-1}$).'], ...
                ['   Mean air temperature: ' ...
                '\texttt{temperature\_2m\_mean}\;($^\circ$C).'], ...
                ['   Potential evapotranspiration: ' ...
                '\texttt{potential\_evaporation\_sum}\;' ...
                '(mm d$^{-1}$).'], ...
                '', ...
                U.Q, ...
                ['Observed daily streamflow is read from the common ' ...
                '\texttt{streamflow} column in units of mm d$^{-1}$. ' ...
                'The streamflow observations are independent of the ' ...
                'selected meteorological data set.'], ...
                '', ...
                '\textbf{Notes}', ...
                ['The EFASv5 simulated discharge variable ' ...
                '\texttt{dis\_efas5} is not used for model calibration.'], ...
                ['EMO-1 and ERA5-Land are stored in separate cache ' ...
                'directories to prevent forcing products from being mixed.']};

            if strcmp(selectedES,'EMO-1')
                petText = { ...
                    '\textbf{Supplied EMO-1 reference evapotranspiration}', ...
                    ['SAGE reads daily reference evapotranspiration ' ...
                    'directly from \texttt{e0\_emo1} in the CAMELS-ES ' ...
                    'time-series files. Values are supplied as ' ...
                    'catchment averages in mm d$^{-1}$; SAGE does not ' ...
                    'recompute PET for this option.']};
            else
                petText = { ...
                    '\textbf{Supplied ERA5-Land potential evaporation}', ...
                    ['SAGE reads daily potential evaporation directly ' ...
                    'from \texttt{potential\_evaporation\_sum} in the ' ...
                    'CAMELS-ES time-series files. Values are supplied ' ...
                    'as catchment averages in mm d$^{-1}$; SAGE does ' ...
                    'not recompute PET for this option.']};
            end

        case 'BULL_ES'
            pChoice = parseLeadingInt_local( ...
                char(ui.ddPrecip.Value));
            tChoice = parseLeadingInt_local( ...
                char(ui.ddTemp.Value));
            petChoice = parseLeadingInt_local(char(ui.ddPET.Value));
            products = {'AEMET','ERA5-Land','EMO-1'};
            pName = products{max(1,min(3,pChoice))};
            tName = products{max(1,min(3,tChoice))};
            petName = products{max(1,min(3,petChoice))};
            meteoText = { ...
                '\textbf{BULL daily forcing}', ...
                ['BULL provides daily meteorological forcing and ' ...
                'observed streamflow for 484 basins across Spain.'], ...
                '', ...
                '\textbf{Selected products}', ...
                ['Precipitation: \textbf{' pName '}; mean air ' ...
                'temperature: \textbf{' tName '}; potential ' ...
                'evapotranspiration: \textbf{' petName '}.'], ...
                '', ...
                '\textbf{Available meteorological products}', ...
                '1: AEMET station-based catchment forcing.', ...
                '2: ERA5-Land reanalysis catchment forcing.', ...
                '3: EMO-1 European gridded forcing.', ...
                '', ...
                U.P, ...
                ['Selected product: ' pName '.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['Selected product: ' tName '.'], ...
                '', ...
                U.ET, ...
                ['Selected product: ' petName '.'], ...
                '', ...
                U.Q, ...
                ['Observed streamflow is supplied directly as runoff ' ...
                'depth and is not divided by basin area a second time.'], ...
                '', ...
                '\textbf{Reference}', ...
                ['BULL database, Zenodo DOI: ' ...
                '\texttt{10.5281/zenodo.10605646}. The database ' ...
                'also provides information on hydrological alteration.']};

            petText = { ...
                ['\textbf{Supplied ' petName ...
                ' potential evapotranspiration}'], ...
                ['SAGE reads \texttt{potential\_evapotranspiration} ' ...
                'from the selected BULL forcing file. The values are ' ...
                'daily catchment averages in mm d$^{-1}$ and are not ' ...
                'recomputed by SAGE. Negative supplied values are ' ...
                'clipped to zero by the regional reader.'], ...
                '', ...
                '\textbf{Available PET products}', ...
                ['1: Spanish State Meteorological Agency (AEMET) ' ...
                'station-based catchment product.'], ...
                '2: ECMWF Reanalysis v5 Land (ERA5-Land).', ...
                ['3: European Meteorological Observations at ' ...
                '1 arc-minute spatial resolution (EMO-1).']};

        case 'CAMELS_FI'
            meteoText = { ...
                '\textbf{CAMELS-FI daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from Finland.'], ...   
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: daily catchment precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: mean air temperature.', ...
                '2: minimum air temperature.', ...
                '3: maximum air temperature.', ...
                '4: grid minimum air temperature.', ...
                '', ...
                ['\textbf{Potential evapotranspiration ' ...
                '(mm d$^{-1}$)}'], ...
                '1: native.', ...
                '2: FMI = Finnish Meteorological Institute.', ...
                ['3: Singer et al. (2021) based on ' ...
                'ERA5-Land forcing.'], ...
                '0: Zero PET.', ... 
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.'], ...
                '', ...
                '\textbf{References}', ...
                ['Singer, M.B., Asfaw, D.T., Rosolem, R., ' ...
                'Cuthbert, M.O., Miralles, D.G., MacLeod, D., ' ...
                'Quichimbo, E.A., and Michaelides, K. (2021). ' ...
                'Hourly potential evapotranspiration at ' ...
                '0.1$^\circ$ resolution for the ' ...
                'global land surface from 1981-present. ' ...
                '\textit{Scientific Data}, 8, 224.']};

        case 'CAMELS_FR'

            petText = localPETNotes(petVal, ...
                isHourly || is15min,'provided');
            meteoText = { ...
                '\textbf{CAMELS-FR daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from France.'], ...
                '', ...
                U.P, ...
                '1: Daily catchment precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Mean air temperature.', ...
                ['2: Mean of minimum and maximum air ' ...
                'temperature.'], ...
                '3: Minimum air temperature.', ...
                '4: Maximum air temperature.', ...
                '', ...
                U.ET, ...
                '1: Penman--Monteith.', ...
                '2: Penman.', ...
                '3: Oudin et al.', ...
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.']};

        case 'CAMELS_GB'

            if isHourly
                meteoText = { ...
                    '\textbf{CAMELS-GB v2 hourly forcing}', ...
                    ['Hourly precipitation and discharge are read from ' ...
                    'the CAMELS-GB v2 hourly files. Temperature and PET ' ...
                    'are read from the matching original daily file.'], ...
                    '', ...
                    '\textbf{Precipitation (mm\,h$^{-1}$)}', ...
                    '1: CEH-GEAR hourly precipitation.', ...
                    ['2: Grid-to-Grid hourly precipitation ' ...
                    '(precipitation\_gradgb).'], ...
                    '', ...
                    '\textbf{Temperature ($^\circ$C)}', ...
                    ['1: The single daily temperature column is matched ' ...
                    'by calendar date and repeated for every hour of ' ...
                    'that date.'], ...
                    '', ...
                    '\textbf{Potential evapotranspiration (mm\,h$^{-1}$)}', ...
                    ['1: Daily PET matched by calendar date and ' ...
                    'divided by 24.'], ...
                    ['2: Daily PET with interception matched by ' ...
                    'calendar date and divided by 24.'], ...
                    '', ...
                    U.Q, ...
                    'Observed hourly discharge.'};
            else
                meteoText = { ...
                    '\textbf{CAMELS-GB daily forcing}', ...
                    ['Original CAMELS-GB daily catchment time series. ' ...
                    'This collection is not labelled version 2.'], ...
                    '', ...
                    '\textbf{Precipitation (mm\,d$^{-1}$)}', ...
                    '1: The single precipitation column.', ...
                    '', ...
                    '\textbf{Temperature ($^\circ$C)}', ...
                    '1: The single temperature column.', ...
                    '', ...
                    '\textbf{Potential evapotranspiration (mm\,d$^{-1}$)}', ...
                    '1: PET (pet).', ...
                    '2: PET with interception (peti).', ...
                    '', ...
                    U.Q, ...
                    'Observed daily discharge.'};
            end

        case 'CAMELS_IS'
            if isHourly
                resTxt = 'hourly';
                nBasTxt = '76';
            else
                resTxt = 'daily';
                nBasTxt = '92';
            end

            meteoText = { ...
                ['\textbf{LamaH-Ice ' resTxt ' forcing}'], ...
                ['Catchment-averaged ' resTxt ' meteorological ' ...
                'time series for ' nBasTxt ' Icelandic basins. ' ...
                'All timestamps are in GMT; an hourly value indexed ' ...
                'at 00:00 represents the mean or accumulation from ' ...
                '00:00 to 01:00.'], ...
                '', ...
                ['The forcing includes precipitation, 2-m air and ' ...
                'dew-point temperature, 10-m wind components, net ' ...
                'solar and thermal radiation, surface pressure, ' ...
                'the supplied open-water PET field, and total ' ...
                'evaporation. These variables support both supplied ' ...
                'and internally computed PET choices.'], ...
                '', ...
                U.P, ...
                ['1: ' U.Freq ' catchment-average precipitation ' ...
                'from the LamaH-Ice meteorological file.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: ' U.Freq ' mean 2-m air temperature. Daily ' ...
                'minimum and maximum temperatures are also retained ' ...
                'by the reader when available.'], ...
                '', ...
                U.ET, ...
                '0: Zero PET.', ...
                '1: Penman--Monteith.', ...
                '2: Priestley--Taylor.', ...
                '3: Makkink.', ...
                '4: LamaH-Ice open-water PET.', ...
                ['5: LamaH-Ice total evaporation; > 0 ' ...
                'evapotranspiration and < 0 condensation.'], ...
                '', ...
                U.Q, ...
                ['Observed discharge is converted from m$^3$ s$^{-1}$ ' ...
                'to runoff depth using catchment area.']};

            if startsWith(strtrim(petVal),'4')
                petText = localPETIcelandProvidedNotes( ...
                    isHourly,'pet');
            elseif startsWith(strtrim(petVal),'5')
                petText = localPETIcelandProvidedNotes( ...
                    isHourly,'total_et');
            else
                petText = localPETNotes( ...
                    petVal,isHourly,'computed');
            end

        case 'CAMELS_IL'
            meteoText = { ...
                '\textbf{CAMELS-IL daily forcing}', ...
                ['Daily Caravan-extension hydrometeorological time ' ...
                'series for 95 Israeli catchments. The files contain ' ...
                'meteorological forcing and observed streamflow.'], ...
                '', ...
                ['Available forcing includes precipitation, daily ' ...
                'mean/minimum/maximum 2-m air temperature, mean 2-m ' ...
                'dew-point temperature, 10-m wind components, net ' ...
                'solar and thermal radiation, surface pressure, and ' ...
                'two supplied potential-evaporation products.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                ['1: ERA5-Land total precipitation from ' ...
                '\texttt{total\_precipitation\_sum}.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: ERA5-Land daily mean 2-m air temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                '0: Zero PET.', ...
                '1: Penman--Monteith.', ...
                '2: Priestley--Taylor.', ...
                '3: Makkink.', ...
                '4: Supplied FAO Penman--Monteith PET.', ...
                '5: Supplied ERA5-Land potential evaporation.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed streamflow is converted from m$^3$ s$^{-1}$ ' ...
                'to runoff depth using catchment area.']};

            if startsWith(strtrim(petVal),'4')
                petText = localPETIsraelProvidedNotes('fao');
            elseif startsWith(strtrim(petVal),'5')
                petText = localPETIsraelProvidedNotes('era5');
            else
                petText = localPETNotes( ...
                    petVal,false,'computed');
            end

        case 'CAMELS_ET'
            meteoText = { ...
                '\textbf{CAMELS-Eth daily forcing}', ...
                ['Daily basin-average hydrometeorological data ' ...
                'for 83 Ethiopian catchments.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: CHIRPS basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: CHIRTS mean air temperature ' ...
                '$(T_{\min}+T_{\max})/2$.'], ...
                '', ...
                '\textbf{Potential evaporation (mm d$^{-1}$)}', ...
                '1: GLEAM potential evaporation.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed runoff is read directly as ' ...
                'catchment-average runoff depth.']};
            petText = {};
        case 'CAMELS_IND'
            meteoText = { ...
                '\textbf{CAMELS-IND daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from India.'], ...   
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: daily basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: mean air temperature.', ...
                ['2: mean of minimum and maximum air ' ...
                'temperature.'], ...
                '3: maximum air temperature.', ...
                '4: minimum air temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                '1: native.', ...
                ['2: GLEAM = Global Land Evaporation ' ...
                'Amsterdam Model.'], ...
                '', ...
                U.Q, ...
                ['Observed streamflow is converted to ' ...
                'catchment-average runoff depth.']};

        case 'CAMELS_JP'
            meteoText = { ...
                '\textbf{MERV-Jp version 2.0 daily forcing}', ...
                ['Daily hydrometeorological records for 87 Japanese ' ...
                'river basins. SAGE uses version 2.0 of the ' ...
                'Multi-model Ensemble for Robust Verification of ' ...
                'hydrological modeling in Japan.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                ['1: Daily basin-average precipitation from the ' ...
                '\texttt{Precip}\;column.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: Daily basin-average air temperature from the ' ...
                '\texttt{Temp}\;column.'], ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['1: Supplied daily PET from the ' ...
                '\texttt{PET}\;column; SAGE applies no additional ' ...
                'PET derivation.'], ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed runoff is read directly from the ' ...
                '\texttt{Obs flow}\;column. No basin-area conversion ' ...
                'is required.'], ...
                '', ...
                '\textbf{Data handling}', ...
                ['Each \texttt{varssim}\;file contains forcing, ' ...
                'observed runoff, and simulations from 44 conceptual ' ...
                'models. SAGE reads only precipitation, temperature, ' ...
                'PET, and observed runoff; simulated-runoff columns ' ...
                'are ignored.'], ...
                '', ...
                '\textbf{Reference}', ...
                ['Sawada, Y. and Okugawa, S. MERV-Jp version 2.0, ' ...
                'Zenodo, doi:10.5281/zenodo.8176305.']};
            petText = {};
        case 'MACH_US'
            meteoText = { ...
                '\textbf{MACH [daily]}', ...
                ['Daily basin-averaged hydrometeorological data ' ...
                'for 1,014 contiguous-US watersheds, 1980--2023.'], ...
                '', ...
                U.P, ...
                '1: Daymet version 4 basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Daymet version 4 mean air temperature.', ...
                '', ...
                U.ET, ...
                '1: GLEAM 4.2a potential evapotranspiration.', ...
                '', ...
                U.Q, ...
                ['USGS daily streamflow supplied by MACH as runoff ' ...
                'depth in mm/day using MACH basin areas.']};
            petText = {};

        case 'CAMELS_MX'
            meteoText = { ...
                '\textbf{Caravan--HYSETS Mexico [daily]}', ...
                ['Daily meteorological forcing and observed runoff ' ...
                'for 46 Mexican HYSETS catchments distributed ' ...
                'through Caravan.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: ERA5--Land basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: ERA5--Land daily mean 2-m air temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                '1: FAO Penman--Monteith potential evaporation.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed CONAGUA/BANDAS streamflow is supplied by ' ...
                'Caravan as catchment-average runoff depth.']};
            petText = {};

        case 'CAMELS_LUX'

            petText = localPETNotes( ...
                petVal,ui.ddRes.Value,'provided');
        
            meteoText = { ...
                ['\textbf{CAMELS-LUX ' U.freq ' forcing}'], ...
                ['Catchment-averaged ' U.freq ...
                ' hydrometeorological time series from Luxembourg. ' ...
                'Precipitation, temperature, PET, and discharge are read ' ...
                'from the CAMELS-LUX hydromet CSV files.'], ...
                '', ...
                U.P, ...
                '1: radar precipitation.', ...
                '2: station precipitation.', ...
                '3: ERA5 total precipitation.', ...
                '4: minimum radar precipitation.', ...
                '5: maximum radar precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: ERA5 2 m air temperature.', ...
                '2: station air temperature.', ...
                '', ...
                U.ET, ...
                '1: Penman-Monteith PET.', ...
                '2: Oudin PET.', ...
                '0: Zero PET.', ...
                '', ...
                U.Q, ...
                'Observed discharge is read as runoff depth.'};

        case 'CAMELS_NZ'
            if ui.edDt.Value == 24
                nzResolution = 'hourly';
                nzFluxUnit = 'mm h$^{-1}$';
            else
                nzResolution = 'daily';
                nzFluxUnit = 'mm d$^{-1}$';
            end
            meteoText = { ...
                '\textbf{CAMELS-NZ meteorological forcing}', ...
                sprintf(['Catchment-averaged %s meteorological ' ...
                'time series for New Zealand catchments. ' ...
                'Variables are stored in separate precipitation, ' ...
                'temperature, PET, and streamflow folders.'], ...
                nzResolution), ...
                '', ...
                sprintf(['The reader selects the %s files from ' ...
                'the active data resolution.'],nzResolution), ...
                '', ...
                sprintf('\\textbf{Precipitation (%s)}',nzFluxUnit), ...
                sprintf('1: Observation-based %s precipitation.', ...
                nzResolution), ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                sprintf('1: Observation-based %s air temperature.', ...
                nzResolution), ...
                '', ...
                sprintf(['\\textbf{Potential evapotranspiration ' ...
                '(%s)}'],nzFluxUnit), ...
                sprintf('1: %s PET.',nzResolution), ...
                '', ...
                sprintf('\\textbf{Observed discharge (%s)}',nzFluxUnit), ...
                sprintf('%s discharge observations from gauging stations.', ...
                [upper(nzResolution(1)) nzResolution(2:end)])};

        case 'CAMELS_KR'
            meteoText = { ...
                '\textbf{CAMELS-KR daily forcing}', ...
                ['Daily meteorological forcing for 282 South Korean ' ...
                'catchments, 1981--2025.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: KMA daily precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: KMA daily mean air temperature.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                '1: FAO Penman--Monteith potential evapotranspiration.', ...
                '2: GLEAM potential evapotranspiration.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed catchment-specific discharge is used as ' ...
                'published; missing observations remain gaps.'], ...
                ['Record length varies by gauge, and the standard ' ...
                'SAGE coverage screening is applied.'], ...
                '', ...
                '\textbf{Notes}', ...
                ['LSTM- and HBV-reconstructed discharge and GLEAM ' ...
                'actual evapotranspiration are not used as inputs.'], ...
                ['Lee, Jung, and Ahn (2026), CAMELS-KR, ' ...
                'CC BY 4.0.'], ...
                'https://doi.org/10.5281/zenodo.21930882', ...
                'https://doi.org/10.5194/essd-2026-544'};

        case 'CAMELSH_KR'
            meteoText = { ...
                '\textbf{CAMELSH-KR hourly forcing}', ...
                ['Hourly data for 178 South Korean catchments. Each ' ...
                'basin CSV contains ERA5-Land forcing, available ' ...
                'station observations, streamflow, and water level.'], ...
                '', ...
                '\textbf{Precipitation (mm h$^{-1}$)}', ...
                '1: ERA5-Land total.', ...
                '2: Observed.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: ERA5-Land 2 m air.', ...
                '2: Observed.', ...
                '', ...
                '\textbf{Potential evapotranspiration (mm h$^{-1}$)}', ...
                '1: ERA5-Land.', ...
                '', ...
                '\textbf{Observed discharge (mm h$^{-1}$)}', ...
                ['The \texttt{streamflow}\;column is stored in the ' ...
                'same basin CSV and converted from m$^3$ s$^{-1}$ ' ...
                'to catchment-average mm h$^{-1}$.']};

        case 'HYDRO_CIS'
            meteoText = { ...
                '\textbf{HydroCIS v1.3 daily forcing}', ...
                ['Daily data for 1,886 Russian catchments from ' ...
                '2008--2020. Each gauge NetCDF record contains the ' ...
                'published forcing products and observed discharge.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: ERA5-Land.', ...
                '2: ERA5.', ...
                '3: MSWEP.', ...
                '4: GPCP.', ...
                '5: IMERG.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Mean of ERA5-Land daily minimum and maximum.', ...
                '2: Mean of ERA5 daily minimum and maximum.', ...
                '', ...
                '\textbf{Potential evaporation (mm d$^{-1}$)}', ...
                '1: Oudin potential evaporation derived from temperature and latitude.', ...
                '2: GLEAM potential evaporation.', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Published discharge normalized by catchment area; ' ...
                'the selected Russian records have no missing daily ' ...
                'discharge during 2008--2020.'], ...
                '', ...
                '\textbf{Notes}', ...
                ['GLEAM actual evaporation and its component fluxes ' ...
                'are not offered as potential-evaporation inputs.'], ...
                ['Abramov and Kurochkina (2023), Hydro-meteorological ' ...
                'database for watersheds across the CIS, version 1.3, ' ...
                'CC BY 4.0.'], ...
                'https://doi.org/10.5281/zenodo.8432070'};

        case {'CAMELS_AR','CAMELS_BE','CAMELS_EE','CAMELS_IE', ...
                'CAMELS_JM','CAMELS_NO','CAMELS_PR'}
            [grdcName,grdcCount]=localGRDCRegionInfo(region);
            meteoText={sprintf('\\textbf{GRDC-Caravan %s [daily]}',grdcName), ...
                sprintf(['Daily ERA5-Land forcing and observed GRDC ' ...
                'streamflow for %d catchments.'],grdcCount), ...
                '','\textbf{Precipitation (mm d$^{-1}$)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                'FAO Penman-Monteith PET supplied by GRDC-Caravan.', ...
                '','\textbf{Observed discharge (mm d$^{-1}$)}', ...
                'Area-normalized streamflow supplied in mm day$^{-1}$.',''};

        case 'CAMELS_ZA'
            meteoText = {'\textbf{GRDC-Caravan South Africa [daily]}', ...
                ['Daily ERA5-Land forcing and observed ' ...
                'GRDC streamflow for 434 catchments.'], ...
                '','\textbf{Precipitation (mm d$^{-1}$)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                ['FAO Penman-Monteith PET supplied ' ...
                'by GRDC-Caravan.'], ...
                '','\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Area-normalized streamflow ' ...
                'supplied in mm day$^{-1}$.'],''};

        case 'CAMELS_NA'
            meteoText={'\textbf{GRDC-Caravan Namibia [daily]}', ...
                ['Daily ERA5-Land forcing and observed GRDC ' ...
                'streamflow for 51 catchments.'], ...
                '','\textbf{Precipitation (mm d$^{-1}$)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                'ERA5-Land basin average.','', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                'FAO Penman-Monteith PET supplied by GRDC-Caravan.', ...
                '','\textbf{Observed discharge (mm d$^{-1}$)}', ...
                'Area-normalized streamflow supplied in mm day$^{-1}$.',''};

        case 'CAMELS_PE'
            meteoText = { ...
                '\textbf{CAMELS-PE v1.0.1 daily forcing}', ...
                ['Daily hydrometeorological time series for 136 ' ...
                'catchments in Peru. Each PE_*.csv file contains ' ...
                'precipitation, PET, temperature, observed streamflow, ' ...
                'and additional forcing fields.'], ...
                '', ...
                '\textbf{Precipitation (mm d$^{-1}$)}', ...
                '1: Catchment precipitation (\texttt{prec}).', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Mean temperature (\texttt{tmean}).', ...
                ['2: $0.5(T_{\min}+T_{\max})$ from the supplied ' ...
                'minimum and maximum temperatures.'], ...
                '', ...
                '\textbf{Potential evapotranspiration (mm d$^{-1}$)}', ...
                '1: Supplied PET (\texttt{pet}).', ...
                '', ...
                '\textbf{Observed discharge (mm d$^{-1}$)}', ...
                ['Observed flow (\texttt{flow_obs}) is already in ' ...
                'mm d$^{-1}$; no basin-area conversion is applied.']};
            petText = { ...
                '\textbf{Supplied CAMELS-PE PET}', ...
                ['The daily \texttt{pet} column is used directly. ' ...
                'Missing forcing values are marked as invalid.']};

        case 'EStreams_PT'

            petText = localPETNotes(petVal,isHourly,'provided');
            meteoText = { ...
                '\textbf{EStreams--SNIRH Portugal v1.4 daily forcing}', ...
                ['Catchment-averaged meteorological forcing for 280 ' ...
                'Portuguese basins. The source files span 1950--2024; ' ...
                'availability depends on the selected variable.'], ...
                '', ...
                U.P, ...
                ['1: E-OBS European gridded daily precipitation at ' ...
                '0.1$^\circ$ resolution (1950--30 June 2024).'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: E-OBS European gridded daily mean air ' ...
                'temperature at 0.1$^\circ$ resolution ' ...
                '(1950--30 June 2024).'], ...
                '', ...
                U.ET, ...
                ['1: Supplied Hargreaves potential evapotranspiration ' ...
                '(1950--30 June 2024; occasional missing values).'], ...
                ['2: Supplied Makkink potential evapotranspiration ' ...
                '(1950--2023; availability varies by basin).'], ...
                ['3: Supplied Penman--Monteith potential ' ...
                'evapotranspiration (1980--2023; availability varies ' ...
                'by basin).'], ...
                '', ...
                U.Q, ...
                ['Portuguese Environment Agency National Water ' ...
                'Resources Information System observations are ' ...
                'converted from m$^3$ s$^{-1}$ to catchment-average ' ...
                'runoff depth.'], ...
                '', ...
                '\textbf{Notes}', ...
                ['All three potential-evapotranspiration choices are ' ...
                'read from EStreams v1.4; SAGE does not recompute them.']};
        case 'CAMELS_PL'

            petText = localPETNotes(petVal,isHourly,'computed');
        
            meteoText = { ...
                '\textbf{CAMELS-PL daily forcing}', ...
                ['Catchment-averaged daily hydrometeorological ' ...
                'time series for 354 streamflow gauges across ' ...
                'Poland. Precipitation, temperature, observed ' ...
                'streamflow, radiation, humidity, wind speed ' ...
                'and SWE are listed in CSV files.'], ...
                '', ...
                U.P, ...
                '1: E-OBS catchment-average daily precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['1: E-OBS daily mean air temperature, ' ...
                '$T_{\rm mean}$.'], ...
                ['2: Mean of daily minimum and maximum temperature: ' ...
                '$T_{\rm mean} = (T_{\rm min}+T_{\rm max})/2$.'], ...
                ['3: E-OBS daily minimum air temperature, ' ...
                '$T_{\rm min}$.'], ...
                ['4: E-OBS daily maximum air temperature, ' ...
                '$T_{\rm max}$.'], ...
                '', ...
                U.ET, ...
                ['1: Hargreaves PET using latitude, $T_{\rm min}$, ' ...
                '$T_{\rm max}$, and $R_{\rm a}$.'], ...
                '', ...
                U.Q, ...
                'Observed discharge converted to runoff depth.', ...
                '', ...
                '\textbf{Notes}', ...
                ['Wind speed is available only from 1980 onward in E-OBS, ' ...
                'and relative humidity and radiation contain small fractions ' ...
                'of missing values in some catchments. These variables are ' ...
                'retained for diagnostics but are not required by the default ' ...
                'Hargreaves PET option.'], ...
                '', ...
                '\textbf{References}', ...
                ['Brzezi\''nska, W., Dolich, A., Perz, A.E., Maharjan, A., ' ...
                'Loritz, R., and Wrzesi\''nski, D. (2026). CAMELS-PL: ' ...
                'hydro-meteorological time series and landscape attributes ' ...
                'for 354 catchments in Poland, version 1.0.0, Zenodo, ' ...
                'doi:10.5281/zenodo.20133183.'], ...
                ['Cornes, R.C., van der Schrier, G., van den Besselaar, ' ...
                'E.J.M., and Jones, P.D. (2018). An ensemble version of ' ...
                'the E-OBS temperature and precipitation data sets. ' ...
                '\textit{Journal of Geophysical Research: Atmospheres}, ' ...
                '123, 9391--9409.']};

        case 'CAMELS_SE'

            petText = localPETNotes(petVal,isHourly,'computed');
            meteoText = { ...
                '\textbf{CAMELS-SE daily forcing}', ...
                ['Catchment-averaged daily meteorological time ' ...
                'series from Sweden. Precipitation and temperature ' ...
                'are read directly from the time-series files.'], ...
                '', ...
                U.P, ...
                '1: Observed precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: Observed air temperature.', ...
                '', ...
                U.ET, ...
                '1: Oudin PET from temperature and latitude.', ...
                '', ...
                U.Q, ...
                'Observed discharge converted to runoff depth.', ...
                '', ...
                ''};
 
        case 'CAMELS_US'
            if startsWith(meteoVal,'1')
                meteoText = { ...
                    '\textbf{Daymet}', ...
                    [U.Freq ' gridded meteorological product'], ...
                    '', ...
                    '\textbf{Description}', ...
                    ['Provides basin-averaged ' ...
                    'meteorological forcing ' ...
                    'data for hydrologic modeling ' ...
                    'at daily resolution.'], ...
                    '', ...
                    '\textbf{Typical variables}', ...
                    ['Precipitation; minimum and ' ...
                    'maximum air temperature; ' ...
                    'shortwave radiation; vapor ' ...
                    'pressure; day length.'], ...
                    '', ...
                    '\textbf{Typical use}', ...
                    [U.Freq ' rainfall--runoff ' ...
                    'simulation and potential ' ...
                    'evapotranspiration estimation.']};

            elseif startsWith(meteoVal,'2')
                meteoText = { ...
                    '\textbf{Maurer}', ...
                    [U.Freq ' gridded meteorological forcing ' ...
                    'dataset widely used in large-sample hydrology.'], ...
                    '', ...
                    '\textbf{Description}', ...
                    ['Provides basin-averaged ' ...
                    'meteorological inputs ' ...
                    'for conceptual rainfall--runoff ' ...
                    'models at ' U.Freq ' ' ...
                    'resolution.'], ...
                    '', ...
                    '\textbf{Typical variables}', ...
                    'Precipitation; air temperature.', ...
                    '', ...
                    '\textbf{Typical use}', ...
                    [U.Freq ' simulation and comparison ' ...
                    'with earlier CAMELS ' ...
                    'benchmark studies.']};

            elseif startsWith(meteoVal,'3')
                meteoText = { ...
                    '\textbf{NLDAS}', ...
                    ['North American Land Data ' ...
                    'Assimilation System ' ...
                    'forcing product.'], ...
                    '', ...
                    '\textbf{Description}', ...
                    ['Provides gridded meteorological inputs at ' ...
                    'relatively high temporal ' ...
                    'resolution for hydrologic ' ...
                    'simulation.'], ...
                    '', ...
                    '\textbf{Typical variables}', ...
                    ['Precipitation; air ' ...
                    'temperature; radiation; ' ...
                    'humidity; wind speed; ' ...
                    'surface pressure.'], ...
                    '', ...
                    '\textbf{Typical use}', ...
                    [U.Freq ' simulation and ' ...
                    'physically based ' ...
                    'potential evapotranspiration ' ...
                    'estimation.']};
            end
            meteoText = [meteoText, { ...
                '', ...
                U.P, ...
                ['Precipitation from the selected ' U.freq ...
                ' meteorological product.'], ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                ['Air temperature from the selected ' U.freq ...
                ' meteorological product.'], ...
                '', ...
                U.ET, ...
                'Selected PET method; see the PET notes panel.', ...
                '', ...
                U.Q, ...
                ['Observed USGS discharge converted to ' ...
                'catchment-average runoff depth.']}];
            petText = localPETNotes(petVal,isHourly,'computed');
        case 'CAMELSH_US'
            meteoText = { ...
                '\textbf{CAMELSH-US}', ...
                [U.Freq ' NLDAS-2 basin-averaged forcing'], ...
                '', ...
                U.P, ...
                '1: NLDAS-2 basin-average precipitation.', ...
                '', ...
                '\textbf{Temperature ($^\circ$C)}', ...
                '1: NLDAS-2 basin-average air temperature.', ...
                '', ...
                U.ET, ...
                '1: NLDAS-2 potential evapotranspiration.', ...
                '', ...
                U.Q, ...
                ['Observed USGS discharge converted from ' ...
                'm$^3$ s$^{-1}$ to catchment-average runoff depth.']};
            petText = { ...
                '\textbf{Supplied NLDAS-2 potential evaporation}', ...
                ['Potential evaporation is read directly from the ' ...
                '\texttt{PotEvap} variable in each hourly CAMELSH-US ' ...
                'NetCDF file and used as PET in SAGE. Values are ' ...
                'expressed in mm h$^{-1}$; negative values are set ' ...
                'to zero by the regional reader.']};
    end

    if strcmp(region,'CHAMELLION')
        [meteoText,petText]=chamellion_notes_ui();
    end

    meteoText = localPrepareMeteoNotes( ...
        meteoText,meteoVal,region,ui.ddMeteo);
    petText = localCompactNoteSpacing(petText);

    separatePETRegions = { ...
        'CAMELS_US','CAMELSH_US','CAMELS_DE','CAMELS_DEH', ...
        'CAMELS_DK','CAMELS_AT','CAMELS_ES','BULL_ES', ...
        'CAMELS_IS','CAMELS_IL','CAMELS_FR','CAMELS_GB', ...
        'CAMELS_LUX','CAMELS_PE','CAMELS_PL','CAMELS_SE', ...
        'EStreams_PT','CHAMELLION'};
    [datasetReference,datasetURLs] = ...
        localDatasetReferenceNotes(region,isHourly);
    referenceWithPET = any(strcmp(region,separatePETRegions));
    if referenceWithPET
        petText = localAppendDatasetReference( ...
            petText,datasetReference);
    else
        meteoText = localAppendDatasetReference( ...
            meteoText,datasetReference);
    end
    localSetDatasetReferenceLinks( ...
        ui,datasetURLs,referenceWithPET,fontsizeNotes);

    if referenceWithPET
        ui.lblMeteoPETDivider.Visible = 'on';
        ui.txtPETInfo.Visible = 'on';
        ui.txtMeteoInfo.Text = meteoText;
        ui.txtPETInfo.Text = petText;
    else
        ui.lblMeteoPETDivider.Visible = 'off';
        ui.txtPETInfo.Visible = 'off';
        ui.txtMeteoInfo.Text = meteoText;
        ui.txtPETInfo.Text = {''};
        % Important: pass an empty PET note block to the resize helper.
        % A cell array {''} is not empty in MATLAB and would falsely
        % trigger the PET divider/second notes panel.
        petText = {};
    end

    try
        localResizeMeteoPETNotes_standalone(ui,cfg,fontsizeNotes,meteoText,petText);
    catch
    end

end

function txt = localPrepareMeteoNotes( ...
        txt,productValue,region,productControl)
%LOCALPREPAREMETEONOTES Add the shared Appendix-D dataset overview.

    txt = localCompactNoteSpacing(txt);
    if isempty(txt)
        return
    end

    productRaw = regexprep(char(string(productValue)), ...
        '^\s*[+-]?\d+(?:\.\d+)?\s*[:\-]?\s*','');
    productRaw = regexprep(productRaw,'\s*\[[^\]]+\]\s*$','');
    productRaw = regexprep(productRaw, ...
        '(?i)\s+(15[ -]?min(?:ute)?s?|hourly|daily)\s*$','');
    productRaw = strtrim(productRaw);
    product = localExpandMeteoProductName(productRaw);

    % Every regional block begins with introductory prose followed by the
    % precipitation section. Replace only that introduction and retain the
    % detailed variable, discharge, and processing notes below it.
    firstVariable = [];
    for ii = 1:numel(txt)
        line = strtrim(char(string(txt{ii})));
        if startsWith(line,'\textbf{Precipitation')
            firstVariable = ii;
            break
        end
    end
    if ~isempty(firstVariable)
        txt = txt(firstVariable:end);
    end

    [~,overview] = dataset_overview(region);
    header = {'\textbf{Dataset overview}'};
    if isempty(overview)
        header{end + 1} = ...
            'Regional hydrometeorological benchmark dataset.';
    else
        overviewParagraph = strjoin(cellstr(string(overview)),' ');
        header{end + 1} = overviewParagraph;
    end

    if localShowMeteoProduct(productControl,productRaw)
        header = [header { ...
            '', ...
            '\textbf{Meteorological product}', ...
            product}];
    end
    header{end + 1} = '';
    txt = localCompactNoteSpacing([header txt]);
end

function show = localShowMeteoProduct(productControl,product)
%LOCALSHOWMETEOPRODUCT Show source details only when they add information.

    show = false;
    try
        values = productControl.ItemsData;
        if isempty(values)
            values = productControl.Items;
        end
        show = numel(values) > 1;
    catch
    end
    if show || isempty(product)
        return
    end

    sourcePattern = [ ...
        '(?i)(RDRS|NLDAS|Daymet|Maurer|ERA5|EMO-1|AEMET|' ...
        'SILO|AGCD|CR2MET|CHIRPS|MSWEP|CPC)'];
    show = ~isempty(regexp(product,sourcePattern,'once'));
end
function product = localExpandMeteoProductName(product)
%LOCALEXPANDMETEOPRODUCTNAME Expand product acronyms once in the heading.

    replacements = { ...
        'RDRS','Regional Deterministic Reanalysis System (RDRS)'; ...
        'NLDAS-2',['North American Land Data Assimilation System, ' ...
            'Phase 2 (NLDAS-2)']; ...
        'NLDAS','North American Land Data Assimilation System (NLDAS)'; ...
        'ERA5-Land','ECMWF Reanalysis v5 Land (ERA5-Land)'; ...
        'GRDC','Global Runoff Data Centre (GRDC)'; ...
        'SNIRH','National Water Resources Information System (SNIRH)'; ...
        'GLEAM','Global Land Evaporation Amsterdam Model (GLEAM)'; ...
        'AGCD','Australian Gridded Climate Data (AGCD)'; ...
        'AEMET','Spanish State Meteorological Agency (AEMET)'; ...
        'EMO-1',['European Meteorological Observations at ' ...
            '1 arc-minute spatial resolution (EMO-1)']; ...
        'CHIRPS',['Climate Hazards Group InfraRed Precipitation ' ...
            'with Stations (CHIRPS)']; ...
        'MSWEP','Multi-Source Weighted-Ensemble Precipitation (MSWEP)'; ...
        'CPC','Climate Prediction Center (CPC)'; ...
        'CHMI','Czech Hydrometeorological Institute (CHMI)'; ...
        'MODIS','Moderate Resolution Imaging Spectroradiometer (MODIS)'};

    for ii = 1:size(replacements,1)
        acronym = replacements{ii,1};
        expanded = replacements{ii,2};
        pattern = ['(?<![A-Za-z0-9])' regexptranslate('escape',acronym) ...
            '(?![A-Za-z0-9])'];
        if ~isempty(regexp(product,pattern,'once'))
            product = regexprep(product,pattern,expanded,'once');
            break
        end
    end
end

function txt = localCompactNoteSpacing(txt)
%LOCALCOMPACTNOTESPACING Keep one internal blank line and no trailing ones.

    if isempty(txt)
        txt = {};
        return
    end

    txt = cellstr(string(txt));
    isBlank = cellfun(@(s) isempty(strtrim(s)),txt);
    keep = true(size(txt));
    for ii = 2:numel(txt)
        if isBlank(ii) && isBlank(ii - 1)
            keep(ii) = false;
        end
    end
    txt = txt(keep);

    while ~isempty(txt) && isempty(strtrim(txt{1}))
        txt(1) = [];
    end
    while ~isempty(txt) && isempty(strtrim(txt{end}))
        txt(end) = [];
    end
end
function txt = localAppendDatasetReference(txt,referenceText)
%LOCALAPPENDDATASETREFERENCE Append one nonduplicated dataset citation.

    txt = localCompactNoteSpacing(txt);
    referenceText = localCompactNoteSpacing(referenceText);
    if isempty(referenceText)
        return
    end

    combined = strjoin(cellstr(string(txt)),' ');
    referenceCombined = strjoin( ...
        cellstr(string(referenceText)),' ');
    doi = regexp(referenceCombined, ...
        '10\.[0-9]{4,9}/[^\s,;]+','match','once');
    if ~isempty(doi) && contains(combined,doi)
        return
    end

    if ~isempty(txt)
        txt{end + 1} = '';
    end
    txt = localCompactNoteSpacing([txt referenceText]);
end

function [txt,urls] = localDatasetReferenceNotes(region,isHourly)
%LOCALDATASETREFERENCENOTES Dataset citations used in the SAGE GUI paper.

    citation = {};
    switch region
        case {'CAMELS_AR','CAMELS_BE','CAMELS_EE','CAMELS_IE', ...
                'CAMELS_JM','CAMELS_NA','CAMELS_NO','CAMELS_PR', ...
                'CAMELS_ZA'}
            citation = { ...
                ['Färber et al. (2025), GRDC-Caravan: Extending ' ...
                'Caravan with data from the Global Runoff Data Centre, ' ...
                '\textit{Earth System Science Data}, 17, 4613--4625, ' ...
                'doi:10.5194/essd-17-4613-2025.']};
        case 'CAMELS_AU'
            citation = { ...
                ['Fowler et al. (2025), CAMELS-AUS v2, ' ...
                '\textit{Earth System Science Data}, 17, 4079--4095, ' ...
                'doi:10.5194/essd-17-4079-2025.']};
        case 'CAMELS_AT'
            citation = { ...
                ['Klingler et al. (2021), LamaH-CE, ' ...
                '\textit{Earth System Science Data}, 13, 4529--4565, ' ...
                'doi:10.5194/essd-13-4529-2021.']};
        case 'CAMELS_BR'
            citation = { ...
                ['Chagas et al. (2020), CAMELS-BR, ' ...
                '\textit{Earth System Science Data}, 12, 2075--2096, ' ...
                'doi:10.5194/essd-12-2075-2020.']};
        case 'CAMELS_CA'
            citation = { ...
                ['Knoben et al. (2025), CAMELS-SPAT, ' ...
                '\textit{Hydrology and Earth System Sciences}, 29, ' ...
                '5791--5833, doi:10.5194/hess-29-5791-2025.']};
        case 'CAMELS_CL'
            citation = { ...
                ['Alvarez-Garreton et al. (2018), CAMELS-CL, ' ...
                '\textit{Hydrology and Earth System Sciences}, 22, ' ...
                '5817--5846, doi:10.5194/hess-22-5817-2018.']};
        case 'CAMELS_COL'
            citation = { ...
                ['Jimenez et al. (2025), CAMELS-COL, ' ...
                '\textit{Earth System Science Data Discussions}, ' ...
                'doi:10.5194/essd-2025-200.']};
        case 'CAMELS_CH'
            citation = { ...
                ['Höge et al. (2023), CAMELS-CH, ' ...
                '\textit{Earth System Science Data}, 15, 5755--5784, ' ...
                'doi:10.5194/essd-15-5755-2023.']};
        case 'CAMELS_CZ'
            citation = { ...
                ['Krejčí and Nearing (2025), CAMELS-CZ v3, Zenodo, ' ...
                'doi:10.5281/zenodo.17593968.']};
        case 'CAMELS_DE'
            citation = { ...
                ['Loritz et al. (2024), CAMELS-DE, ' ...
                '\textit{Earth System Science Data}, 16, 5625--5642, ' ...
                'doi:10.5194/essd-16-5625-2024.']};
        case 'CAMELS_DEH'
            citation = { ...
                ['Dolich et al. (2026), CAMELS-DE-1h, GFZ Data ' ...
                'Services, doi:10.5880/fidgeo.2026.045.']};
        case 'CAMELS_DK'
            citation = { ...
                ['Liu et al. (2025), CAMELS-DK, ' ...
                '\textit{Earth System Science Data}, 17, 1551--1572, ' ...
                'doi:10.5194/essd-17-1551-2025.']};
        case 'CAMELS_ET'
            citation = { ...
                ['CAMELS-Eth provider dataset. Access requires ' ...
                'one-time registration with the dataset provider.']};
        case 'CAMELS_FI'
            citation = { ...
                ['Seppä et al. (2026), CAMELS-FI, ' ...
                '\textit{Earth System Science Data}, 18, 4745--4769, ' ...
                'doi:10.5194/essd-18-4745-2026.']};
        case 'CAMELS_FR'
            citation = { ...
                ['Delaigue et al. (2025), CAMELS-FR, ' ...
                '\textit{Earth System Science Data}, 17, 1461--1479, ' ...
                'doi:10.5194/essd-17-1461-2025.']};
        case 'CAMELS_GB'
            citation = { ...
                ['Coxon et al. (2020), CAMELS-GB, ' ...
                '\textit{Earth System Science Data}, 12, 2459--2483, ' ...
                'doi:10.5194/essd-12-2459-2020.'], ...
                ['Coxon et al. (2026), CAMELS-GB v2, ' ...
                '\textit{Earth System Science Data}, 18, 4345--4371, ' ...
                'doi:10.5194/essd-18-4345-2026.']};
        case 'CAMELS_IS'
            citation = { ...
                ['Helgason and Nijssen (2024), LamaH-Ice, ' ...
                '\textit{Earth System Science Data}, 16, 2741--2771, ' ...
                'doi:10.5194/essd-16-2741-2024.']};
        case 'CAMELS_IND'
            citation = { ...
                ['Mangukiya et al. (2025), CAMELS-IND, ' ...
                '\textit{Earth System Science Data}, 17, 461--491, ' ...
                'doi:10.5194/essd-17-461-2025.']};
        case 'CAMELS_IL'
            citation = { ...
                ['Morin (2024), Caravan Extension Israel, Zenodo, ' ...
                'doi:10.5281/zenodo.12760798.']};
        case 'CAMELS_JP'
            citation = { ...
                ['Sawada and Okugawa (2023), MERV-Jp version 2.0, ' ...
                'Zenodo, doi:10.5281/zenodo.8176305.']};
        case 'CAMELS_KR'
            citation = { ...
                ['Lee et al. (2026), CAMELS-KR, ' ...
                '\textit{Earth System Science Data Discussions}, ' ...
                'doi:10.5194/essd-2026-544.']};
        case 'CAMELSH_KR'
            citation = { ...
                ['Tran and Kim (2025), CAMELSH-KR v1, Zenodo, ' ...
                'doi:10.5281/zenodo.15073264.']};
        case 'CAMELS_LUX'
            citation = { ...
                ['Nijzink et al. (2025), CAMELS-LUX, ' ...
                '\textit{Earth System Science Data Discussions}, ' ...
                'doi:10.5194/essd-2024-482.']};
        case 'CAMELS_MX'
            citation = { ...
                ['Kratzert et al. (2023), Caravan, ' ...
                '\textit{Scientific Data}, 10, 61, ' ...
                'doi:10.1038/s41597-023-01975-w.']};
        case 'CAMELS_NZ'
            citation = { ...
                ['Bushra et al. (2025), CAMELS-NZ, ' ...
                '\textit{Earth System Science Data}, 17, 5745--5760, ' ...
                'doi:10.5194/essd-17-5745-2025.']};
        case 'CAMELS_PE'
            citation = { ...
                ['Llauca et al. (2026), CAMELS-PE, ' ...
                '\textit{Earth System Science Data Discussions}, ' ...
                'doi:10.5194/essd-2026-386.']};
        case 'CAMELS_PL'
            citation = { ...
                ['Brzezińska et al. (2026), CAMELS-PL v1.0.0, ' ...
                'Zenodo, doi:10.5281/zenodo.20133183.']};
        case 'EStreams_PT'
            citation = { ...
                ['do Nascimento et al. (2025), EStreams v1.4, ' ...
                'Zenodo, doi:10.5281/zenodo.17598150.']};
        case 'HYDRO_CIS'
            citation = { ...
                ['Abramov et al. (2026), HydroCIS, ' ...
                '\textit{Russian Meteorology and Hydrology}, 51, ' ...
                '232--242, doi:10.3103/S1068373926030052.']};
        case 'CAMELS_ES'
            citation = { ...
                ['Casado Rodríguez (2025), CAMELS-ES, Zenodo, ' ...
                'doi:10.5281/zenodo.15040948.']};
        case 'BULL_ES'
            citation = { ...
                ['Senent-Aparicio et al. (2024), BULL Database, ' ...
                '\textit{Scientific Data}, 11, 737, ' ...
                'doi:10.1038/s41597-024-03594-5.']};
        case 'CAMELS_SE'
            citation = { ...
                ['Teutschbein (2024), CAMELS-SE, ' ...
                '\textit{Geoscience Data Journal}, 11, 655--668, ' ...
                'doi:10.1002/gdj3.239.']};
        case 'CAMELS_US'
            if isHourly
                citation = { ...
                    ['Gauch et al. (2020), hourly CAMELS-US forcing, ' ...
                    'Zenodo, doi:10.5281/zenodo.4072701.'], ...
                    ['Addor et al. (2017), CAMELS catchment attributes, ' ...
                    'UCAR/NCAR, doi:10.5065/D6G73C3Q.']};
            else
                citation = { ...
                    ['Newman et al. (2015), CAMELS-US daily ' ...
                    'hydrometeorological data, ' ...
                    '\textit{Hydrology and Earth System Sciences}, ' ...
                    '19, 209--223, doi:10.5194/hess-19-209-2015.'], ...
                    ['Addor et al. (2017), CAMELS catchment attributes, ' ...
                    'UCAR/NCAR, doi:10.5065/D6G73C3Q.']};
            end
        case 'CAMELSH_US'
            citation = { ...
                ['Tran et al. (2025), CAMELSH, ' ...
                '\textit{Scientific Data}, 12, 1307, ' ...
                'doi:10.1038/s41597-025-05612-6.']};
        case 'MACH_US'
            citation = { ...
                ['Sink (2026), MACH v4.0, Zenodo, ' ...
                'doi:10.5281/zenodo.18686475.']};
    end

    if isempty(citation)
        txt = {};
        urls = {};
    else
        txt = [{'\textbf{Dataset}'} citation];
        urls = localDatasetCitationURLs(citation);
    end
end

function urls = localDatasetCitationURLs(citation)
%LOCALDATASETCITATIONURLS Convert citation DOIs to browser URLs.

    urls = {};
    for ii = 1:numel(citation)
        value = char(string(citation{ii}));
        doi = regexp(value, ...
            '10\.[0-9]{4,9}/[^\s,;]+','match','once');
        if isempty(doi)
            continue
        end
        doi = regexprep(doi,'[\.\)\]]+$','');
        urls{end + 1} = ['https://doi.org/' doi]; %#ok<AGROW>
    end
end

function localSetDatasetReferenceLinks( ...
        ui,urls,usePET,fontSize)
%LOCALSETDATASETREFERENCELINKS Show DOI links under the matching citation.

    grids = {ui.gMeteoDatasetLinks,ui.gPETDatasetLinks};
    for ii = 1:numel(grids)
        try
            delete(grids{ii}.Children);
            grids{ii}.RowHeight = {0};
        catch
        end
    end
    if isempty(urls)
        return
    end

    target = ui.gMeteoDatasetLinks;
    if usePET
        target = ui.gPETDatasetLinks;
    end
    count = numel(urls);
    rowHeight = max(18,round(1.55*fontSize));
    target.RowHeight = repmat({rowHeight},1,count);
    target.RowSpacing = 0;
    target.Padding = [0 0 0 0];
    for ii = 1:count
        url = char(string(urls{ii}));
        doi = erase(url,'https://doi.org/');
        link = uihyperlink(target, ...
            'Text',['Open dataset: ' doi], ...
            'URL',url, ...
            'FontSize',fontSize);
        link.Layout.Row = ii;
        link.Layout.Column = 1;
    end
end

function height = localDatasetLinksHeight(grid,fontSize)
%LOCALDATASETLINKSHEIGHT Height occupied by the DOI hyperlink rows.

    height = 0;
    try
        count = numel(grid.Children);
        if count > 0
            rowHeight = max(18,round(1.55*fontSize));
            height = count*rowHeight;
        end
    catch
    end
end
function localResizeMeteoPETNotes_standalone( ...
    ui,~,fontsizeNotes,meteoText,petText)
%LOCALRESIZEMETEOPETNOTES_STANDALONE Fit notes to their rendered content.

    meteoText = localCompactNoteSpacing(meteoText);
    petText = localCompactNoteSpacing(petText);
    hasPET = ~isempty(petText);

    try
        fsM = ui.txtMeteoInfo.FontSize;
    catch
        fsM = fontsizeNotes;
    end
    try
        fsP = ui.txtPETInfo.FontSize;
    catch
        fsP = fontsizeNotes;
    end

    try
        drawnow limitrate nocallbacks
    catch
    end

    try
        labelPosition = ui.txtMeteoInfo.Position;
        labelWidth = max(120,labelPosition(3));
    catch
        try
            panelPosition = ui.pnlMeteoPETInfo.Position;
            labelWidth = max(120,panelPosition(3) - 24);
        catch
            labelWidth = 560;
        end
    end

    options = struct( ...
        'MinHeight',40, ...
        'MaxHeight',3000, ...
        'HorizontalPadding',0, ...
        'CharacterWidthFactor',0.52);
    fallbackMeteo = notes_box_ui( ...
        'height',meteoText,labelWidth,fsM,options);
    fallbackPET = 0;
    if hasPET
        fallbackPET = notes_box_ui( ...
            'height',petText,labelWidth,fsP,options);
    end

    hMeteoLinks = localDatasetLinksHeight( ...
        ui.gMeteoDatasetLinks,fsM);
    hPETLinks = localDatasetLinksHeight( ...
        ui.gPETDatasetLinks,fsP);

    % One visual blank line separates meteorological and PET notes.
    % The notes grid has zero RowSpacing, so this is the only gap.
    spacerHeight = double(hasPET)* ...
        max(14,round(1.25*max(fsM,fsP)));
    dividerHeight = double(hasPET);
    try
        if hasPET
            ui.gMeteoPETNotes.RowHeight = { ...
                'fit',hMeteoLinks,spacerHeight,dividerHeight, ...
                'fit',hPETLinks};
        else
            ui.gMeteoPETNotes.RowHeight = { ...
                'fit',hMeteoLinks,0,0,0,0};
        end
        drawnow limitrate nocallbacks
    catch
    end
    hMeteo = localFittedNoteLabelHeight( ...
        ui.txtMeteoInfo,meteoText,fsM,fallbackMeteo,40,3000);
    hPET = 0;
    if hasPET
        hPET = localFittedNoteLabelHeight( ...
            ui.txtPETInfo,petText,fsP,fallbackPET,40,3000);
    end


    % Reserve clearance within the text row so the links cannot cover it.
    if hMeteoLinks>0,hMeteo=hMeteo+round(0.5*max(18,1.55*fsM));end
    if hPETLinks>0,hPET=hPET+round(0.5*max(18,1.55*fsP));end
    try
        if hasPET
            ui.gMeteoPETNotes.RowHeight = { ...
                hMeteo,hMeteoLinks,spacerHeight,dividerHeight, ...
                hPET,hPETLinks};
            ui.lblMeteoPETDivider.Visible = 'on';
            ui.lblMeteoPETDivider.Text = '';
            ui.lblMeteoPETDivider.BackgroundColor = ...
                [0.65 0.65 0.65];
            ui.txtPETInfo.Visible = 'on';
        else
            ui.gMeteoPETNotes.RowHeight = { ...
                hMeteo,hMeteoLinks,0,0,0,0};
            ui.lblMeteoPETDivider.Visible = 'off';
            ui.txtPETInfo.Visible = 'off';
        end
    catch
    end

    try
        contentHeight = hMeteo + hMeteoLinks + spacerHeight + ...
            dividerHeight + hPET + hPETLinks;
        innerPadding = ui.gMeteoPETNotes.Padding;
        contentHeight = contentHeight + ...
            innerPadding(2) + innerPadding(4);

        mainPosition = ui.gMeteoPETMain.Position;
        mainPadding = ui.gMeteoPETMain.Padding;
        mainSpacing = ui.gMeteoPETMain.RowSpacing;
        availableHeight = mainPosition(4) - 184 - ...
            2*mainSpacing - mainPadding(2) - mainPadding(4);

        panelChrome = 26;
        requiredHeight = contentHeight + panelChrome;
        visibleHeight = min(requiredHeight,max(100,availableHeight));
        ui.gMeteoPETMain.RowHeight = { ...
            184,round(visibleHeight),'1x'};

        drawnow limitrate nocallbacks
        actualPanelHeight = ui.pnlMeteoPETInfo.Position(4);
        actualContentHeight = max(1,actualPanelHeight - panelChrome);
        needsScroll = contentHeight > actualContentHeight + 1;
        if needsScroll
            ui.gMeteoPETNotes.Scrollable = 'on';
        else
            ui.gMeteoPETNotes.Scrollable = 'off';
        end
    catch
    end

    try
        ui.pnlMeteoPETInfo.Scrollable = 'off';
        ui.pnlMeteoPETInfo.AutoResizeChildren = 'on';
    catch
    end
end
function updateReferenceBlock_standalone(ui,fontsizeNotes)

    method = lower(char(ui.ddSplitMethod.Value));

    region = region_helpers('code',ui.ddRegion.Value);
    resolution = char(ui.ddRes.Value);
    isCamelsUS = strcmpi(region,'CAMELS_US');
    isDaily = strcmpi(resolution,'Daily');
    isHourly = strcmpi(resolution,'Hourly');
    sp = '<div style="height:4px;"></div>';

    switch method

        case 'manual'
            titleTxt = 'Method notes | references';

            noteTxt = [ ...
                '<b>Manual dates</b>: the user explicitly defines ' ...
                'the training and evaluation periods. This is the ' ...
                'traditional temporal split used in hydrology, ' ...
                'where one fixed block is used for training and a ' ...
                'separate fixed block is used for evaluation.' ...
                sp ...
                '<b>Pros</b>: easy to interpret, hydrologically ' ...
                'realistic, preserves chronology, and provides ' ...
                'the cleanest test of ' ...
                'temporal generalization.' ...
                sp ...
                '<b>Cons</b>: results can depend on the specific ' ...
                'years chosen; one wet or dry evaluation block ' ...
                'may not be fully representative.' ...
                sp ...
                '<b>Recommendation</b>: best default choice when ' ...
                'the goal is to test how well the model transfers ' ...
                'from one time period ' ...
                'to another. Usually the preferred method for ' ...
                'final model evaluation and reporting.' ];
            if isCamelsUS && isHourly
                refHtml = [ ...
                    "<ol style='margin:8px 0 0 0;" + ...
                    "padding-left:20px;'>" ...
                    "<li style='margin-bottom:0px;'>" ...
                    "J.A. Vrugt, J.M. Frame and Y. Gao (2026): " ...
                    "Continental-Scale Hydrologic Model Training " ...
                    "at Hourly Resolution with Sensitivity-Aware " ...
                    "Gradient Estimation. " ...
                    "<i>Water Resources Research</i>, preprint. " ...
                    "Reference link to be added" ...
                    " | " ...
                    "<a href='#' onclick=""return " + ...
                    "applyDefaults();"">" ...
                    "defaults</a></li>" ...
                    "</ol>" ];
            elseif isCamelsUS && isDaily
                refHtml = [ ...
                    "<ol style='margin:8px 0 0 0;" + ...
                    "padding-left:20px;'>" ...
                    "<li style='margin-bottom:10px;'>" ...
                    "W. Tsai, D. Feng, M. Pan, H. Beck, " + ...
                    "K. Lawson, " ...
                    "Y. Yang, J. Liu and C. Shen (2021): From " ...
                    "calibration to parameter learning: " + ...
                    "Harnessing " ...
                    "the scaling effects of big data in " ...
                    "geoscientific modeling. " ...
                    "<i>Nature Communications</i>. " ...
                    "<a href='#' onclick=""return openRef(" ...
                    "'https://www.nature.com/articles/" + ...
                    "s41467-021-26107-z');"">" ...
                    "open reference</a>" ...
                    " | " ...
                    "<a href='#' onclick=""return " + ...
                    "applyDefaults();"">" ...
                    "defaults</a></li>" ...
                    "<li style='margin-bottom:0px;'>" ...
                    "J.A. Vrugt and J.M. Frame (2026): " ...
                    "SAGE: Sensitivity-Aware Learning for Rapid " ...
                    "Training of Process-Based Hydrologic Models " ...
                    "across Large Basin Samples. " ...
                    "<i>Hydrology and Earth System Sciences " ...
                    "Discussions</i>, preprint. " ...
                    "<a href='#' onclick=""return openRef(" ...
                    "'https://egusphere.copernicus.org/" + ...
                    "preprints/2026/egusphere-2026-693/');"">" ...
                    "open reference</a></li></ol>"];
            else
                refHtml = "";
            end

        case 'deterministic_block'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Deterministic block</b>: the selected time ' ...
                'range is divided into contiguous blocks of ' ...
                'prescribed length. The first fraction of blocks ' ...
                'is assigned to training and the remaining blocks ' ...
                'to evaluation, without randomization.' ...
                sp ...
                '<b>Pros</b>: preserves local time dependence ' ...
                'within each ' ...
                'block, is reproducible, and is easy to interpret.' ...
                sp ...
                '<b>Cons</b>: training and evaluation may differ ' ...
                'strongly depending on where the block boundary ' ...
                'falls; the split can ' ...
                'be sensitive to long wet or dry episodes.' ...
                sp ...
                '<b>Recommendation</b>: useful when a structured ' ...
                'block-based split is desired but the user does ' ...
                'not want to specify manual training and ' ...
                'evaluation dates. More realistic than ' ...
                'fully random splitting for time-series data.' ];

            refHtml = "";

        case 'random_block'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Random block</b>: the selected time range ' ...
                'is divided into contiguous blocks of prescribed ' ...
                'length, and those blocks are randomly assigned ' ...
                'to training or evaluation ' ...
                'using the specified random seed.' ...
                sp ...
                '<b>Pros</b>: preserves short-range temporal ' ...
                'dependence within blocks while reducing ' ...
                'sensitivity to one particular ' ...
                'deterministic block arrangement.' ...
                sp ...
                '<b>Cons</b>: still mixes information from ' ...
                'different parts of the record, so it is less ' ...
                'strict than a true forward ' ...
                'temporal test; results depend on the random seed.' ...
                sp ...
                '<b>Recommendation</b>: a good compromise ' ...
                'between block-based splitting and randomized ' ...
                'sampling. Often preferable to ' ...
                'fully random sampling when temporal ' ...
                'dependence matters.' ];

            refHtml = "";

        case 'random'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Random</b>: all scored time steps within ' ...
                'the selected time window are randomly assigned ' ...
                'to training or evaluation ' ...
                'according to the requested train fraction ' ...
                'and random seed.' ...
                sp ...
                '<b>Pros</b>: simple, balanced, and efficient; ' ...
                'usually gives training and evaluation sets ' ...
                'with similar overall ' ...
                'distributions.' ...
                sp ...
                '<b>Cons</b>: breaks chronology completely and ' ...
                'can be overly ' ...
                'optimistic for hydrologic time series because ' ...
                'nearby days are strongly correlated.' ...
                sp ...
                '<b>Recommendation</b>: useful for algorithm ' ...
                'debugging, internal comparisons, and stress ' ...
                'testing, but usually not the best choice for ' ...
                'final evaluation of temporal generalization.' ];

            refHtml = "";

        case 'deterministic_kfold'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Deterministic k-fold</b>: the selected time ' ...
                'range is partitioned sequentially into <i>k</i> ' ...
                'folds. One fold is held out for evaluation and ' ...
                'the remaining folds are used ' ...
                'for training.' ...
                sp ...
                '<b>Pros</b>: reproducible, structured, and ' ...
                'useful for cross-validation over multiple parts ' ...
                'of the record.' ...
                sp ...
                '<b>Cons</b>: depending on fold size, neighboring ' ...
                'folds may still be similar, and a single ' ...
                'held-out fold may not be a ' ...
                'strong test of extrapolation.' ...
                sp ...
                '<b>Recommendation</b>: useful for sensitivity ' ...
                'studies and cross-validation across the record, ' ...
                'but less direct than manual dates when the ' ...
                'objective is a clean train-then-test ' ...
                'temporal split.' ];

            refHtml = "";

        case 'random_kfold'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Random k-fold</b>: the selected time range ' ...
                'is first randomized using the specified seed ' ...
                'and then partitioned ' ...
                'into <i>k</i> folds. One fold is held out ' ...
                'for evaluation and the remaining folds are ' ...
                'used for training.' ...
                sp ...
                '<b>Pros</b>: makes efficient use of the full ' ...
                'record and often gives balanced folds with ' ...
                'similar distributions of ' ...
                'conditions.' ...
                sp ...
                '<b>Cons</b>: destroys chronology and can ' ...
                'yield overly optimistic performance for ' ...
                'hydrologic time series because ' ...
                'training and evaluation points may be close ' ...
                'in time.' ...
                sp ...
                '<b>Recommendation</b>: useful for internal ' ...
                'benchmarking, method comparison, and robustness ' ...
                'checks, but generally not recommended as the ' ...
                'main final evaluation method when ' ...
                'temporal transfer is important.' ];

            refHtml = "";

        case 'rainfall_block'
            titleTxt = 'Method notes';

            noteTxt = [ ...
                '<b>Rainfall block</b>: training and evaluation ' ...
                'indices are defined from rainfall-event blocks, ' ...
                'typically separately for each basin. The actual ' ...
                'time indices are read from <tt>dat{k}.id_train</tt> ' ...
                'and <tt>dat{k}.id_eval</tt> after the forcing and ' ...
                'discharge data have been loaded.' ...
                sp ...
                '<b>Pros</b>: focuses evaluation on hydrologically ' ...
                'meaningful wet-event structure rather than arbitrary ' ...
                'calendar periods. This is useful when the objective is ' ...
                'to test event-scale transfer and rainfall-runoff response.' ...
                sp ...
                '<b>Cons</b>: the split is basin-specific and therefore ' ...
                'less transparent than one global date range. It also ' ...
                'requires the rainfall-event indices to be available in ' ...
                'the basin data structures.' ...
                sp ...
                '<b>Recommendation</b>: use this option when the split ' ...
                'has already been prepared from rainfall events and stored ' ...
                'as local training/evaluation indices. For JKGE methods ' ...
                'with moving windows, verify that the resulting masks are ' ...
                'consistent with the intended benchmark averaging.' ];

            refHtml = "";

        otherwise
            titleTxt = 'Method notes';
            noteTxt = ['No method description ' ...
                'available.'];
            refHtml = "";
    end

    % Match Meteo/PET and Loss-function notes font size
    try
        ui.pPeriodRef.Title = titleTxt;
        ui.pPeriodRef.FontWeight = 'bold';
        ui.pPeriodRef.Visible = 'on';
    catch
    end

    % Estimate visible height of Period method 
    % notes from text, width, and font size
    try
        drawnow limitrate
    catch
    end
    
    try
        ppos = ui.pPeriodRef.Position;
        panelW = max(330,ppos(3) - 15);
    catch
        panelW = 600;
    end
    fsHTML = round(1.15*fontsizeNotes);
    % Include references in height estimate for manual/default cases
    heightTxt = string(noteTxt) + " " + string(refHtml);
    nLines = local_estimate_wrapped_lines(heightTxt,panelW,fsHTML);
    nLines = nLines/1.42;
    hContent = localNoteHeightFromLineCount( ...
        nLines,fsHTML,120,1800);
    % Add panel title and padding
    noteH = hContent + 15;
    % Keep notes panel compact but allow scrolling for long references
    noteH = min(max(noteH,130),260);
    try
        ui.gPeriodMain.RowHeight = ...
            {102,'fit',120,noteH,'1x'};
    catch
    end

    % --------------------------------------------
    % Add "Apply defaults" button for daily/manual
    % --------------------------------------------
    html = [ ...
        "<html><head><meta charset='utf-8'>" ...
        "<style>" ...
        "html,body{height:100%;margin:0;padding:0;overflow:hidden;}" ...
        string(site_html_theme_css(ancestor(ui.refHTML,'figure').Color)) ...
        "</style><script>" ...
        "function setup(htmlComponent){" ...
        "window.openRef=function(url){" ...
        "htmlComponent.sendEventToMATLAB('open',{url:url});" ...
        "return false;};" ...
        "window.applyDefaults=function(){" ...
        "htmlComponent.sendEventToMATLAB('defaults',{});" ...
        "return false;};" ...
        "}" ...
        "</script></head><body>" ...
        "<div style='" ...
        "font-family:Helvetica,Arial,sans-serif;" ...
        "font-size:" + string(fsHTML) + "px;" ...
        "line-height:1.25;" ...
        "height:100%;" ...
        "box-sizing:border-box;" ...
        "padding:5px 10px 5px 10px;" ...
        "overflow-y:auto;" ...
        "overflow-x:hidden;" ...
        "'>" ...
        "<div style='margin-bottom:2px;'>" noteTxt "</div>" ...
        refHtml ...
        "</div></body></html>" ];
    % IMPORTANT: fresh temporary file each time to avoid uihtml caching
    refFile = fullfile(tempdir, ...
        ['SAGE_period_method_notes_' ...
        char(java.util.UUID.randomUUID) '.html']);
    
    try
        fid = fopen(refFile,'w');
        if fid == -1
            error(['Could not open reference ' ...
                'HTML file for writing.']);
        end
        fwrite(fid,char(html),'char');
        fclose(fid);
    
        ui.refHTML.HTMLSource = refFile;
    
    catch ME
        try
            if exist('fid','var') ...
                    && fid > 0
                fclose(fid);
            end
        catch
        end
        warning('SAGE:ReferenceHTML', ...
            ['Could not update ' ...
            'reference HTML: %s'],ME.message);
    end
end

function setDropdownPreserve(dd,items,defaultValue,enableState)
    %SETDROPDOWNPRESERVE Update dropdown items without resetting a
    %valid user selection. This avoids regional meteo/PET controls
    %jumping back to their first/default option after callbacks.
    oldValue = "";
    try
        oldValue = string(dd.Value);
    catch
    end

    dd.Items = items;

    if nargin < 3 ...
            || isempty(defaultValue)
        defaultValue = items{1};
    end
    if nargin < 4 ...
            || isempty(enableState)
        enableState = 'on';
    end

    if any(strcmp(cellstr(oldValue),items))
        dd.Value = char(oldValue);
    else
        dd.Value = defaultValue;
    end

    dd.Enable = enableState;
end

function applyConfiguredDropdown(dd,C,role,productValue)
%APPLYCONFIGUREDDROPDOWN Apply items/default/enabled generically.

    required = {'items','default','enabled'};
    for ii = 1:numel(required)
        if ~isfield(C,required{ii})
            error('SAGE_ui:InvalidMeteoControl', ...
                'Meteo control is missing field "%s".',required{ii});
        end
    end

    values = cellstr(string(C.items));
    if isempty(values)
        error('SAGE_ui:EmptyMeteoControl', ...
            'A meteo control contains no dropdown items.');
    end

    defaultValue = char(string(C.default));
    if ~any(strcmp(defaultValue,values))
        defaultValue = values{1};
    end
    oldValue = "";
    try
        oldValue = string(dd.Value);
    catch
    end
    labels = local_meteo_dropdown_labels( ...
        values,role,productValue);
    dd.ItemsData = {};
    dd.Items = labels;
    dd.ItemsData = values;
    if any(strcmp(cellstr(oldValue),values))
        dd.Value = char(oldValue);
    else
        dd.Value = defaultValue;
    end
    dd.Enable = tern(logical(C.enabled),'on','off');
end

function localRefreshMeteoChoicePresentation(ui)
%LOCALREFRESHMETEOCHOICEPRESENTATION Show arrows only for real choices.

    pairs = { ...
        'ddMeteo','edMeteoChoice'; ...
        'ddPrecip','edPrecipChoice'; ...
        'ddTemp','edTempChoice'; ...
        'ddPET','edPETChoice'};

    for ii = 1:size(pairs,1)
        if ~isfield(ui,pairs{ii,1}) ...
                || ~isfield(ui,pairs{ii,2})
            continue
        end
        dropdown = ui.(pairs{ii,1});
        readOnly = ui.(pairs{ii,2});
        try
            values = dropdown.ItemsData;
            if isempty(values)
                values = dropdown.Items;
            end
            numberOfChoices = numel(values);
            canChoose = numberOfChoices > 1 ...
                && strcmpi(char(dropdown.Enable),'on');
            if canChoose
                readOnly.Visible = 'off';
                dropdown.Visible = 'on';
            else
                readOnly.Value = local_dropdown_display_text(dropdown);
                dropdown.Visible = 'off';
                readOnly.Visible = 'on';
            end
        catch
            try
                readOnly.Visible = 'off';
                dropdown.Visible = 'on';
            catch
            end
        end
    end
end
function labels = local_meteo_dropdown_labels(values,role,productValue)
%LOCAL_METEO_DROPDOWN_LABELS Create concise presentation-only labels.

    labels = cellstr(string(values));
    product = regexprep(char(string(productValue)), ...
        '^\s*[+-]?\d+(?:\.\d+)?\s*[:\-]?\s*','');
    product = regexprep(product,'\s*\[[^\]]+\]\s*$','');
    product = regexprep(product, ...
        '(?i)\s+(15[ -]?min(?:ute)?s?|hourly|daily)\s*$','');
    product = strtrim(product);

    for kk = 1:numel(labels)
        value = regexprep(labels{kk}, ...
            '^\s*[+-]?\d+(?:\.\d+)?\s*[:\-]?\s*','');
        value = strtrim(value);
        valueLower = lower(value);

        switch lower(role)
            case 'product'
                value = regexprep(value, ...
                    '\s*\[[^\]]+\]\s*$','');
                value = regexprep(value, ...
                    '(?i)\s+(15[ -]?min(?:ute)?s?|hourly|daily)\s*$','');
                value = localExpandMeteoProductName(strtrim(value));

            case 'precipitation'
                value = regexprep(value, ...
                    '(?i)^basin[- ](?:average[d]?\s+)?','');
                value = regexprep(value, ...
                    '(?i)\s+(precipitation|rainfall)$','');
                if any(strcmpi(strtrim(value), ...
                        {'precipitation','rainfall', ...
                         'controlled by meteo product'}))
                    value = product;
                end

            case 'temperature'
                if contains(valueLower,'tmin') ...
                        && contains(valueLower,'tmax')
                    source = product;
                    token = regexp(value, ...
                        '\(([A-Za-z][A-Za-z0-9\- ]+)\)\s*$', ...
                        'tokens','once');
                    if ~isempty(token)
                        source = strtrim(token{1});
                    else
                        candidate = regexprep(value, ...
                            '(?i)\s*\(?tmin\s*\+\s*tmax\)?\s*/\s*2\s*$','');
                        candidate = regexprep(candidate, ...
                            '(?i)^mean\s+','');
                        if ~isempty(strtrim(candidate))
                            source = strtrim(candidate);
                        end
                    end
                    value = sprintf('%s (mean of Tmin and Tmax)',source);
                elseif contains(valueLower,'tmin') ...
                        || contains(valueLower,'minimum')
                    value = regexprep(value, ...
                        ['(?i)\s*(daily\s+)?(minimum|tmin)' ...
                         '(\s+air)?(\s+temperature)?\s*$'],'');
                    if isempty(strtrim(value))
                        value = product;
                    end
                    value = sprintf('%s (minimum)',strtrim(value));
                elseif contains(valueLower,'tmax') ...
                        || contains(valueLower,'maximum')
                    value = regexprep(value, ...
                        ['(?i)\s*(daily\s+)?(maximum|tmax)' ...
                         '(\s+air)?(\s+temperature)?\s*$'],'');
                    if isempty(strtrim(value))
                        value = product;
                    end
                    value = sprintf('%s (maximum)',strtrim(value));
                else
                    value = regexprep(value, ...
                        '(?i)\s+(mean\s+)?air temperature$','');
                    value = regexprep(value, ...
                        '(?i)\s+temperature$','');
                    if any(strcmpi(strtrim(value), ...
                            {'mean','air','temperature', ...
                             'controlled by meteo product'})) ...
                            || isempty(strtrim(value))
                        value = product;
                    elseif strcmpi(strtrim(value),'daily')
                        value = product;
                    end
                    if ~contains(value,'(')
                        value = sprintf('%s (mean)',strtrim(value));
                    end
                end

            case 'pet'
                if any(strcmpi(value,{'PET', ...
                        'Potential evapotranspiration', ...
                        'Potential evaporation'}))
                    value = product;
                elseif strcmpi(value,'Zero PET')
                    value = 'Zero';
                elseif strcmpi(value,'native')
                    value = 'Supplied';
                else
                    value = regexprep(value, ...
                        '(?i)\s+potential evapotranspiration$','');
                    value = regexprep(value, ...
                        '(?i)\s+potential evaporation$','');
                end
        end

        if isempty(strtrim(value))
            value = product;
        end
        labels{kk} = strtrim(value);
    end
end

function lines = formatPreview(cfg)
    helpers = struct( ...
        'text',@local_text_scalar, ...
        'mode',@fmtMode_local, ...
        'sampleMode',@sampleModeText_local, ...
        'vector',@vec2str_local, ...
        'period',@appendPeriodPreview_local, ...
        'smallVector',@fmtSmallVector_local, ...
        'number',@fmtNum_local, ...
        'safeField',@getfield_safe, ...
        'normalizeLoss',@normalizeLossStruct_local, ...
        'lossName',@lossName, ...
        'jkgeName',@jkgeMethodName, ...
        'value',@previewValue_local, ...
        'cellStrings',@fmtCellStrList_local, ...
        'modelName',@local_model_name_from_id);
    lines = preview_formatter(cfg,helpers);
end

function lines = formatSITEPreview(cfg)
    lines = formatPreview(cfg);
    txt = string(lines(:));
    % Retain the shared hydrologic preview, but omit SAGE-only sections.
    keep = true(size(txt));
    section = "";
    for ii = 1:numel(txt)
        entry = strtrim(txt(ii));
        if startsWith(entry,"[")
            section = entry;
        end
        if any(section == ["[Network]","[Algorithm]", ...
                "[Miscellaneous: postprocessor]"])
            keep(ii) = false;
        elseif any(startsWith(entry,["K_t ","K_e ","id_eval "]))
            keep(ii) = false;
        end
    end
    txt = txt(keep);
    if isfield(cfg,'site') && isstruct(cfg.site)
        a = cfg.site.alg;
        extra = strings(0,1);
        extra(end+1) = "[SITE calibration]";
        extra(end+1) = sprintf('%-13s : %d %s', ...
            'optimizer',a.method,optName(a.method));
        extra(end+1) = sprintf('%-13s : %d', ...
            'trials',a.n);
        extra(end+1) = sprintf('%-13s : %d', ...
            'max iter',a.i_max);
        extra(end+1) = sprintf('%-13s : %s', ...
            'calculation',cfg.site.calc);
        if cfg.site.numWorkers > 0
            extra(end+1) = sprintf('%-13s : %d', ...
                'workers',cfg.site.numWorkers);
        else
            extra(end+1) = sprintf('%-13s : %s', ...
                'workers','local profile default');
        end
        if cfg.site.maxPending > 0
            extra(end+1) = sprintf('%-13s : %d', ...
                'max futures',cfg.site.maxPending);
        else
            extra(end+1) = sprintf('%-13s : %s', ...
                'max futures','pool worker count');
        end
        extra(end+1) = sprintf('%-13s : every %d basin(s)', ...
            'checkpoint',cfg.site.saveEvery);
        if isfield(a,'opts') && isstruct(a.opts)
            names = string(fieldnames(a.opts));
            if a.method == 7
                preferred = ["adam_maxIter";"adam_alpha"; ...
                    "adam_beta1";"adam_beta2";"adam_eps"; ...
                    "finish_maxIter";"tolPG_finish"; ...
                    "tolRelF_finish";"stallPG";"stallStep"; ...
                    "stallWindow";"minAdamIterBeforeSwitch"; ...
                    "tolPG";"tolRelF";"b_eps";"verbose"; ...
                    "finisher"];
                names = [preferred(ismember(preferred,names)); ...
                    names(~ismember(names,preferred))];
            end
            if ~isempty(names)
                extra(end+1) = " ";
                extra(end+1) = "[Optimizer opts]";
                for ii=1:numel(names)
                    name = char(names(ii));
                    value = a.opts.(name);
                    if isnumeric(value) || islogical(value)
                        if isscalar(value)
                            vtxt = num2str(value,16);
                        else
                            vtxt = mat2str(value,16);
                        end
                    else
                        vtxt = char(string(value));
                    end
                    label = sitePreviewOptionLabel(name,a.method, ...
                        a.opts);
                    extra(end+1) = sprintf('%s : %s',label,vtxt); %#ok
                end
            end
        end
        txt = [txt(:); extra(:)];
    end
    lines = cellstr(siteAlignPreviewColons(txt));
end

function label = sitePreviewOptionLabel(name,method,opts)
    % Keep configuration field names unchanged, but present conventional
    % mathematical subscripts in the human-readable Preview.
    switch name
        case 'c1', label = 'c_1';
        case 'alpha0', label = 'alpha_0';
        case 'beta1', label = 'beta_1';
        case 'beta2', label = 'beta_2';
        case 'lambda0', label = 'lambda_0';
        case 'lambdaMin', label = 'lambda_min';
        case 'lambdaMax', label = 'lambda_max';
        otherwise, label = name;
    end
    if method ~= 7, return, end
    finisher = 'lbfgsb';
    if isfield(opts,'finisher')
        finisher = lower(char(string(opts.finisher)));
    end
    switch name
        case 'adam_maxIter', label = 'adam:maxIt';
        case 'adam_alpha', label = 'adam:alpha';
        case 'adam_beta1', label = 'adam:beta_1';
        case 'adam_beta2', label = 'adam:beta_2';
        case 'adam_eps', label = 'adam:eps';
        case 'finish_maxIter', label = [finisher ':maxIt'];
        case 'tolPG_finish', label = [finisher ':tolPG'];
        case 'tolRelF_finish', label = [finisher ':tolRelF'];
        case 'minAdamIterBeforeSwitch', label = 'minAdamIter';
    end
end

function txt = siteAlignPreviewColons(txt)
    % Keep one separator column across shared SAGE and SITE sections.
    keys = strings(size(txt));
    values = strings(size(txt));
    isField = false(size(txt));
    for ii = 1:numel(txt)
        token = regexp(char(txt(ii)), ...
            '^(.*?)\s+:\s+(.*)$','tokens','once');
        if isempty(token), continue, end
        keys(ii) = strtrim(string(token{1}));
        values(ii) = string(token{2});
        isField(ii) = true;
    end
    if ~any(isField), return, end
    keyWidth = max(13,max(strlength(keys(isField))));
    for ii = find(isField).'
        txt(ii) = string(sprintf('%-*s : %s', ...
            keyWidth,char(keys(ii)),char(values(ii))));
    end
end

function applyGlobalButtonLock(~)
    % Do not globally disable all push buttons during SAGE iterations.
    % Configuration controls are locked explicitly in updateLockState(),
    % while monitoring buttons such as Refresh, Copy, Apply, and
    % Show first error should remain available during a run.
end

function tf = localRefreshDue(iter,every)
    % Refresh at iteration 1 so a newly available diagnostic appears
    % immediately, then at the requested cadence.
    if nargin < 2 || isempty(every) || every <= 1
        tf = true;
        return
    end
    tf = iter == 1 || mod(iter,every) == 0;
end

function setVisibleSafe(h,tf)
    try
        h.Visible = tern(tf,'on','off');
    catch
    end
end

function local_make_noninteractive(h)
    try
        h.HitTest = 'off';
        h.PickableParts = 'none';
    catch
    end
end

function onParamCellSelected(src,~)
    % MATLAB uitable keeps the selected cell highlighted until another
    % cell is clicked. Clear the selection so the parameter table does
    % not retain a colored cell after inspection or editing.
    clearTableSelection(src);
end

function clearTableSelection(src)
    try
        drawnow limitrate
        if isvalid(src) ...
                && isprop(src,'Selection')
            src.Selection = [];
        end
    catch
    end
end

function setEnable(h,tf)
    try
        h.Enable = tern(tf,'on','off');
    catch
    end
end

function scaleGUIFonts(parent,fac)

    kids = findall(parent);

    for kk = 1:numel(kids)
        h = kids(kk);

        try
            if isprop(h,'fontsize') ...
                    && isnumeric(h.FontSize)
                h.FontSize = max(9,round(fac*h.FontSize));
            end
        catch
        end
    end

    % Tables often need row-height adjustment too
    tbls = findall(parent, ...
        'Type','uitable');
    for kk = 1:numel(tbls)
        try
            tbls(kk).RowHeight = max(20,round(fac*20));
        catch
        end
    end
end

function setAllDropdownFonts(parent,fs)

    dds = findall(parent);

    for kk = 1:numel(dds)
        try
            if isa(dds(kk),'matlab.ui.control.DropDown')
                dds(kk).FontSize = fs;
            end
        catch
        end
    end
end

function C = local_default_config()
    C = sage_default_config_local('');
end

function root = local_deployed_companion_root()
%LOCAL_DEPLOYED_COMPANION_ROOT Find folders beside the running executable.

    root = '';
    try
        if ispc
            proc = System.Diagnostics.Process.GetCurrentProcess();
            root = fileparts(char(proc.MainModule.FileName));
        elseif ismac
            [status,command] = system(sprintf( ...
                'ps -p %d -o comm=',matlabProcessID));
            if status == 0
                root = fileparts(strtrim(command));
                % Finder apps store the executable inside the .app bundle.
                appDir = regexp(root, ...
                    '^(.*?\.app)[/\\]Contents[/\\]MacOS$', ...
                    'tokens','once');
                if ~isempty(appDir)
                    root = fileparts(appDir{1});
                end
            end
        end
    catch
        root = '';
    end
    if isempty(root) || ~isfolder(root)
        root = pwd;
    end
end

function pathValue = local_canonical_path(pathValue)
%LOCAL_CANONICAL_PATH Normalize a folder without requiring Java.

    pathValue = char(string(pathValue));
    try
        pathValue = char(java.io.File(pathValue).getCanonicalPath());
    catch
        [ok,info] = fileattrib(pathValue);
        if ok
            pathValue = info.Name;
        end
    end
end

function siteRoot = local_find_site_root(fallbackRoot)
%LOCAL_FIND_SITE_ROOT Locate SITE independently of Data and SAGE.

    candidates = strings(0,1);
    try
        candidates(end+1) = string( ...
            getpref('SITEhydrology','SITEhydro',''));
    catch
    end
    candidates(end+1) = fullfile(string(fallbackRoot),'SITEhydrology');
    candidates(end+1) = string(fileparts(fileparts(mfilename('fullpath'))));
    siteRoot = char(candidates(end));
    for k = 1:numel(candidates)
        candidate = char(candidates(k));
        if isfile(fullfile(candidate,'src','run_SITE.m'))
            siteRoot = local_canonical_path(candidate);
            return
        end
    end
end

function sageRoot = local_find_sage_root(fallbackRoot,siteRoot)
%LOCAL_FIND_SAGE_ROOT Locate a selected, adjacent, or active SAGE tree.

    candidates = strings(0,1);
    try
        candidates(end+1) = string( ...
            getpref('SITEhydrology','SAGEhydro',''));
    catch
    end
    candidates(end+1) = fullfile(string(fallbackRoot),'SAGEhydrology');
    candidates(end+1) = fullfile(string(fileparts(siteRoot)),'SAGEhydrology');
    active = which('region_helpers');
    if ~isempty(active)
        folder = fileparts(active);
        for k = 1:6
            candidates(end+1) = string(folder);
            folder = fileparts(folder);
        end
    end
    sageRoot = char(candidates(2));
    for k = 1:numel(candidates)
        candidate = char(candidates(k));
        if isfolder(fullfile(candidate,'regions')) ...
                && isfolder(fullfile(candidate,'maps'))
            sageRoot = local_canonical_path(candidate);
            return
        end
    end
end
function C = sage_default_config_local(root)

    if nargin < 1 ...
            || isempty(root)
        if isdeployed
            % External companion folders take precedence over the
            % MATLAB Runtime extraction cache. This also exposes a
            % user_model folder beside the executable.
            companionRoot = local_deployed_companion_root();
            if isfolder(fullfile(companionRoot,'SITEhydrology')) ...
                    && isfolder(fullfile(companionRoot,'SAGEhydrology'))
                root = companionRoot;
            else
                root = ctfroot;
                % The complete packaged trees may sit below SITE_ui while
                % a partial SAGEhydrology tree exists at the cache root.
                if ~isfolder(fullfile(root,'SITEhydrology'))
                    nested = fullfile(root,'SITE_ui');
                    if isfolder(fullfile(nested,'SITEhydrology')) ...
                            && isfolder(fullfile(nested,'SAGEhydrology'))
                        root = nested;
                    end
                end
                if ~isfolder(fullfile(root,'SAGEhydrology'))
                    nested = fullfile(root,'SAGE_ui');
                    if isfolder(fullfile(nested,'SAGEhydrology'))
                        root = nested;
                    end
                end
            end
        else
            thisFile = mfilename('fullpath');
            thisDir = fileparts(thisFile);
            % SAGE_ui.m now resides in SAGEhydrology/gui. The selected
            % software root is therefore two levels above this file.
            root = fullfile(thisDir,'..','..');
            try
                root = char(java.io. ...
                    File(root).getCanonicalPath());
            catch
            end
        end
    end
    
    C.root = root;
    if isdeployed
        C.SITEhydro = local_find_site_root(root);
    else
        C.SITEhydro = local_canonical_path( ...
            fullfile(fileparts(mfilename('fullpath')),'..'));
        C.root = fileparts(C.SITEhydro);
    end
    C.SAGEhydro = local_find_sage_root(C.root,C.SITEhydro);
    C.SAGEdir = C.SAGEhydro;
    
    C.region = 'CAMELS_US';
    C.regionName = 'United States';

    if isdeployed
        C.dirDroot = fullfile(pwd,'Data');
    else
        C.dirDroot = fullfile(root,'Data');
    end
    try
        preferredData = char(getpref( ...
            'SITEhydrology','DataRoot',''));
        if isfolder(preferredData)
            C.dirDroot = preferredData;
        end
    catch
    end
    C.dirD = fullfile(C.dirDroot, ...
        C.region);

    C.dirM = fullfile(C.dirD, ...
        'daily','v1p2','forcing');

    C.dirQ = fullfile(C.dirD, ...
        'daily','v1p2','streamflow');

    if isdeployed
        companionResults = fullfile(C.SITEhydro,'results');
        if strcmpi(root,local_deployed_companion_root()) ...
                && isfolder(companionResults)
            C.dirres = companionResults;
        else
            C.dirres = fullfile(prefdir,'SITE','results');
        end
    else
        C.dirres = fullfile(C.SITEhydro,'results');
    end
    try
        preferredResults = char(getpref( ...
            'SITEhydrology','ResultsRoot',''));
        if isfolder(preferredResults)
            C.dirres = preferredResults;
        end
    catch
    end

    C.file_univ = 'US_531_basins.txt';
    C.file_split = 'split_US_531_531_0_1.txt';
    
    C.mdl = struct('model',6, ...
        'mcode',4,'calc','parfeval', ...
        'names',["hymod","hmodel", ...
        "sacsma","Xinanjiang", ...
        "gr4j","hbv","cfe_nwm","gchm","user_model"]);
    
    C.bas = struct('K',531, ...
        'K_t',531,'K_e',0, ...
        'sample','random', ...
        'seed',1, ...
        'rng_type','twister', ...
        'min_per_zone',[], ...
        'max_zones',[], ...
        'id_attr',local_default_attr_ids(), ...
        'pr_attr',0);
    
    C.r = numel(C.bas.id_attr);
    
    C.prd = struct( ...
        'dt',1, ...
        'method','manual', ...
        'dts',[1 10 1999], ...
        'dte',[30 9 2008], ...
        'des',[1 10 1989], ...
        'dee',[30 9 1999], ...
        'ds',[1 10 1989], ...
        'de',[30 9 2008], ...
        'block_size',365, ...
        'train_frac',0.8, ...
        'seed',1, ...
        'n_folds',5, ...
        'fold',1, ...
        'spinup',365);
    
    C.misc = struct('meteo', ...
        struct('data',1,'precip',1,'temp',1,'pet',1), ...
        'net',struct('r',NaN,'d',NaN,'h',32, ...
        'tf',{{'tanh'}},'seed',0,'l',NaN), ...
        'loss',struct('fnc',2,'observed',{{'Q'}}, ...
        'fdc',struct('formulation',1)), ...
        'alg',struct('method',2,'i_max',250,'lr',1e-2, ...
        'beta_1',0.9,'beta_2',0.999,'vareps',1e-8, ...
        'wdecay',1e-4,'clipn',1,'lr_min',1e-4, ...
        'lr_scheme','constant','lr_hold',0.20), ...
        'io',struct('prt',1,'file',1), ...
        'attr',1,'attr_view','rel');
    C.site = struct('calc','parfeval','numWorkers',0,'maxPending',0, ...
        'saveEvery',1,'alg',struct('method',5,'n',10,'i_max',1000, ...
        'opts',struct()));
end

function id = local_default_attr_ids()
    id = [1 2 4 5];   % safe fallback: p_mean, pet_mean, frac_snow, aridity
end


function name = localResolutionName(dt)
    if abs(double(dt) - 96) < 1e-8
        name = '15 minutes';
    elseif abs(double(dt) - 24) < 1e-8
        name = 'Hourly';
    else
        name = 'Daily';
    end
end


function out = tern(tf,a,b)
    if tf
        out = a;
    else
        out = b;
    end
end

function s = fmtDMY(dmy)
    s = sprintf('%02d/%02d/%04d', ...
        dmy(1),dmy(2),dmy(3));
end
    
function tf = localTabExists(h)
    tf = false; %#ok
    try
        tf = ~isempty(h) ...
            && isgraphics(h);
    catch
        try
            tf = ~isempty(h) ...
                && isprop(h,'Parent');
        catch
            tf = false;
        end
    end
end

function q = attrReduce(A,statMode)
    if isempty(A)
        q = NaN(0,1);
        return
    end
    switch lower(strtrim(statMode))
        case 'median(abs(.))'
            q = median(abs(A),2,'omitnan');
        case 'mean(abs(.))'
            q = mean(abs(A),2,'omitnan');
        case 'max(abs(.))'
            q = max(abs(A),[],2);
        otherwise
            q = median(abs(A),2,'omitnan');
    end
end

function v = parseLeadingInt_local(str)
    tok = regexp(char(str),'^\s*(\d+)', ...
        'tokens','once');
    if isempty(tok)
        v = NaN;
    else
        v = str2double(tok{1});
    end
end

function code = siteMeteoChoiceCode(dropdown)
%SITEMETEOCHOICECODE Preserve numeric codes or use an unnumbered choice's index.
    code = parseLeadingInt_local(dropdown.Value);
    if isfinite(code)
        return
    end
    choices = string(dropdown.Items);
    value = string(dropdown.Value);
    if ~isempty(dropdown.ItemsData)
        data = string(dropdown.ItemsData);
        index = find(data == value,1);
    else
        index = find(choices == value,1);
    end
    if isempty(index)
        error('SITE:InvalidMeteoChoice', ...
            'The selected meteorological or PET choice is unavailable.');
    end
    code = double(index);
end

function dmy = parseDMY_local(s)
    s = strtrim(char(s));
    parts = regexp(s, ...
        ['^(\d{1,2})\s*/\s*(\d{1,2})' ...
        '\s*/\s*(\d{4})$'], ...
        'tokens','once');
    if isempty(parts)
        error(['Date must be dd/mm/yyyy ' ...
            '(got "%s").'],s);
    end
    dmy = [str2double(parts{1}), ...
        str2double(parts{2}), ...
        str2double(parts{3})];
end

function dmy = parseDMYOrEmpty_local(s)
    s = strtrim(char(s));
    if isempty(s)
        dmy = [];
    else
        dmy = parseDMY_local(s);
    end
end

function dmy = forceDMYRow_local(dmy)
    if isempty(dmy)
        return
    end
    dmy = reshape(double(dmy),1,[]);
end

function x = parseIntVector_local(s)
    s = strrep(char(s),',',' ');
    s = strtrim(s);
    if isempty(s)
        x = [];
        return
    end
    if ~isempty(regexp(s, ...
            '[^0-9:\s\[\]]','once'))
        error(['id_attr contains invalid ' ...
            'characters. Use numbers, ' ...
            'spaces, and ":" ranges.']);
    end
    expr = ['[' s ']'];
    x = eval(expr);
    x = unique(x(:).','stable');
end

function s = vec2str_local(v)
    v = unique(v(:).','stable');
    if isempty(v)
        s = "";
        return
    end
    runs = {};
    i = 1;
    while i <= numel(v)
        j = i;
        while j < numel(v) ...
                && v(j+1) == v(j)+1
            j = j+1;
        end
        if j == i
            runs{end+1} = ...
                sprintf('%d',v(i));         %#ok
        else
            runs{end+1} = ...
                sprintf('%d:%d',v(i),v(j)); %#ok
        end
        i = j+1;
    end
    s = strjoin(string(runs),' ');
end

function [ok,msg,minv,maxv] = ...
    validateParamBoundsLocal(unit,minv,maxv,allowNegative)
    if nargin < 4 ...
            || isempty(allowNegative)
        allowNegative = false;
    end
    ok = false; msg = '';
    if isempty(minv) ...
            || isempty(maxv) ...
            || ~isscalar(minv) ...
            || ~isscalar(maxv) ...
            || ~isnumeric(minv) ...
            || ~isnumeric(maxv) ...
            || ~isfinite(minv) ...
            || ~isfinite(maxv)
        msg = ['Min and Max must be finite ' ...
            'numeric scalars.'];
        return
    end
    minv = double(minv);
    maxv = double(maxv);
    if minv >= maxv
        msg = ['Min must be strictly ' ...
            'smaller than Max.'];
        return
    end

    if ~allowNegative && minv < 0
        msg = ['Negative bounds are not allowed for this ' ...
            'parameter. The default model range is nonnegative.'];
        return
    end

    if ~allowNegative && maxv <= 0
        msg = ['The maximum bound must be positive for this ' ...
            'parameter.'];
        return
    end

    unitNoSpace = lower(strrep(unit, ...
        ' ',''));
    if (contains(unitNoSpace,'1/d') ...
            || contains(unitNoSpace,'1/h')) ...
            && maxv <= 0
        msg = ['This rate parameter must ' ...
            'have a positive maximum.'];
        return
    end
    if minv < -1e20 ...
            || maxv > 1e20
        msg = ['Bounds are suspiciously ' ...
            'extreme.'];
        return
    end
    ok = true;
end


function D = local_gen_metric_data(out,metric)
%LOCAL_GEN_METRIC_DATA Build paired train/evaluation metric vectors.

    D = struct('trainX',[],'trainY',[],'evalX',[],'evalY',[], ...
        'trainGap',[],'evalGap',[],'latTrain',[],'lonTrain',[], ...
        'latEval',[],'lonEval',[]);

    if isempty(out) || ~isstruct(out) ...
            || ~isfield(out,'bas') || ~isfield(out,'latlon')
        return
    end

    bas = out.bas;
    latlon = double(out.latlon);
    Kt = min(double(bas.K_t),size(latlon,1));
    Ke = min(double(bas.K_e),max(0,size(latlon,1)-Kt));

    D.trainX = local_gen_scenario_group(out,metric,'tt',Kt,Ke);
    D.trainY = local_gen_scenario_group(out,metric,'te',Kt,Ke);
    D.evalX = local_gen_scenario_group(out,metric,'et',Kt,Ke);
    D.evalY = local_gen_scenario_group(out,metric,'ee',Kt,Ke);

    if any(strcmpi(metric,{'KGE_alpha','KGE_beta'}))
        D.trainX = local_gen_log2_ratio(D.trainX);
        D.trainY = local_gen_log2_ratio(D.trainY);
        D.evalX = local_gen_log2_ratio(D.evalX);
        D.evalY = local_gen_log2_ratio(D.evalY);
    end

    % Accumulated loss values depend directly on record length. Display
    % their mean contribution per valid observation so training and
    % evaluation periods remain comparable.
    if local_gen_is_accumulated_loss(metric)
        nTrain = local_gen_count_group(out,'train',Kt,Ke);
        mEval = local_gen_count_group(out,'eval',Kt,Ke);

        D.trainX = D.trainX ./ nTrain(1:Kt);
        D.trainY = D.trainY ./ mEval(1:Kt);
        D.evalX = D.evalX ./ nTrain(Kt+1:Kt+Ke);
        D.evalY = D.evalY ./ mEval(Kt+1:Kt+Ke);
    end

    if any(strcmpi(metric,{'KGE_alpha','KGE_beta'}))
        D.trainGap = abs(D.trainX) - abs(D.trainY);
        D.evalGap = abs(D.evalX) - abs(D.evalY);
    elseif local_gen_higher_is_better(metric)
        D.trainGap = D.trainY - D.trainX;
        D.evalGap = D.evalY - D.evalX;
    else
        D.trainGap = D.trainX - D.trainY;
        D.evalGap = D.evalX - D.evalY;
    end

    D.latTrain = latlon(1:Kt,1);
    D.lonTrain = latlon(1:Kt,2);
    D.latEval = latlon(Kt+1:Kt+Ke,1);
    D.lonEval = latlon(Kt+1:Kt+Ke,2);
end

function v = local_gen_log2_ratio(v)
%LOCAL_GEN_LOG2_RATIO Symmetric display of KGE ratios around one.

    bad = ~isfinite(v) | v <= 0;
    v = log2(v);
    v(bad) = NaN;
end

function v = local_gen_scenario_group(out,metric,scen,Kt,Ke)
%LOCAL_GEN_SCENARIO_GROUP Extract one basin group for one scenario.

    isTrain = any(strcmpi(scen,{'tt','te'}));
    if isTrain
        n = Kt;
    else
        n = Ke;
    end
    v = nan(n,1);

    % Current basin-wise metrics moved under prf.curr. The live GUI output
    % also exposes the same structure as out.curr for dashboard access.
    current = struct();
    if isfield(out,'curr') && isstruct(out.curr)
        current = out.curr;
    elseif isfield(out,'prf') && isstruct(out.prf) ...
            && isfield(out.prf,'curr') && isstruct(out.prf.curr)
        current = out.prf.curr;
    end

    [family,component] = local_gen_component_metric(metric);
    if ~isempty(family) ...
            && isfield(current,family) ...
            && isstruct(current.(family)) ...
            && isfield(current.(family),'components') ...
            && isfield(current.(family).components,scen) ...
            && isfield(current.(family).components.(scen),component)
        q = double(current.(family).components.(scen).(component));
        q = q(:);
        nq = min(n,numel(q));
        v(1:nq) = q(1:nq);
        return
    end

    if isfield(current,metric)
        src = current.(metric);
        q = [];
        try
            if isstruct(src) && isfield(src,scen)
                q = double(src.(scen));
                q = q(:);
            elseif isnumeric(src)
                A = double(src);
                col = find(strcmpi(scen,{'tt','te','et','ee'}),1);
                if size(A,2) >= col
                    q = A(:,col);
                elseif size(A,1) >= col
                    q = A(col,:).';
                end
            end

            if numel(q) == Kt + Ke
                if isTrain
                    q = q(1:Kt);
                else
                    q = q(Kt+1:Kt+Ke);
                end
            end

            if ~isempty(q)
                nq = min(n,numel(q));
                v(1:nq) = q(1:nq);
            end
            if any(isfinite(v))
                return
            end
        catch
        end
    end

    % CAMELS stores basin-wise diagnostics under met.variable.Q. The
    % flattened met.performance/met.loss fields below are only a
    % compatibility fallback for older outputs.
    if isfield(out,'met') && isstruct(out.met) ...
            && isfield(out.met,'variable') ...
            && isstruct(out.met.variable) ...
            && isfield(out.met.variable,'Q')
        if any(strcmpi(scen,{'tt','et'}))
            period = 't';
        else
            period = 'e';
        end
        if any(strcmpi(metric,{'RSS','SAR','GLS','Huber'}))
            family = 'diagnostic';
        else
            family = 'performance';
        end
        qBlock = out.met.variable.Q;
        if isfield(qBlock,family) ...
                && isfield(qBlock.(family),period) ...
                && isfield(qBlock.(family).(period),metric)
            q = double(qBlock.(family).(period).(metric));
            q = q(:);
            if numel(q) >= Kt + Ke
                if isTrain
                    q = q(1:Kt);
                else
                    q = q(Kt+1:Kt+Ke);
                end
            end
            nq = min(n,numel(q));
            v(1:nq) = q(1:nq);
            if any(isfinite(v))
                return
            end
        end
    end

    if isfield(out,'met') && isstruct(out.met)
        if any(strcmpi(scen,{'tt','et'}))
            suffix = 't';
        else
            suffix = 'e';
        end
        q = [];
        try
            if any(strcmpi(metric, ...
                    {'NSE','KGE','D_fdc','D_p','D_logp','JKGE'}))
                group = 'performance';
            else
                group = 'loss';
            end
            if isfield(out.met,group) ...
                    && isfield(out.met.(group),suffix) ...
                    && isfield(out.met.(group).(suffix),metric)
                q = double(out.met.(group).(suffix).(metric));
                q = q(:);
            end

            if numel(q) >= Kt + Ke
                if isTrain
                    q = q(1:Kt);
                else
                    q = q(Kt+1:Kt+Ke);
                end
            end

            if ~isempty(q)
                nq = min(n,numel(q));
                v(1:nq) = q(1:nq);
            end
        catch
        end
    end
end

function [family,component] = local_gen_component_metric(metric)
%LOCAL_GEN_COMPONENT_METRIC Resolve selector to stored component family.

    family = '';
    component = '';
    switch char(metric)
        case 'KGE_r'
            family = 'KGE';
            component = 'r';
        case 'KGE_alpha'
            family = 'KGE';
            component = 'alpha';
        case 'KGE_beta'
            family = 'KGE';
            component = 'beta';
        case 'JKGE_M'
            family = 'JKGE';
            component = 'M';
        case 'JKGE_V'
            family = 'JKGE';
            component = 'V';
        case 'JKGE_C'
            family = 'JKGE';
            component = 'C';
    end
end

function [outTrain,outEval] = local_gen_outlier_masks(D)
    outTrain = local_gen_pair_outliers(D.trainX,D.trainY);
    outEval = local_gen_pair_outliers(D.evalX,D.evalY);
end

function out = local_gen_pair_outliers(x,y)
    x = double(x(:));
    y = double(y(:));
    out = false(size(x));
    good = isfinite(x) & isfinite(y);
    if sum(good) < 8
        return
    end
    out(good) = local_gen_vector_outliers(x(good)) ...
        | local_gen_vector_outliers(y(good));
end

function out = local_gen_vector_outliers(v)
    v = double(v(:));
    out = false(size(v));
    good = isfinite(v);
    z = v(good);
    if numel(z) < 8
        return
    end

    q1 = prctile(z,25);
    q3 = prctile(z,75);
    iq = q3-q1;

    if ~(isfinite(iq) && iq > 0)
        med = median(z);
        mad0 = median(abs(z-med));
        if ~(isfinite(mad0) && mad0 > 0)
            return
        end
        lo = med - 6*1.4826*mad0;
        hi = med + 6*1.4826*mad0;
    else
        lo = q1 - 3*iq;
        hi = q3 + 3*iq;
    end
    out(good) = z < lo | z > hi;
end

function tf = local_gen_higher_is_better(metric)
    tf = any(strcmpi(metric, ...
        {'NSE','KGE','S_fdc','S_p','S_logp','JKGE','KGE_r'}));
end

function tf = local_gen_is_accumulated_loss(metric)
    tf = any(strcmpi(metric,{'RSS','SAR','GLS','Huber'}));
end

function [pow10,scaleVal] = local_gen_scale(v,metric)
%LOCAL_GEN_SCALE Common multiplier for RSS, SAR, and Huber displays.

    pow10 = 0;
    scaleVal = 1;

    if any(strcmpi(metric, ...
            {'NSE','KGE','S_fdc','S_p','S_logp','JKGE','KGE_r', ...
            'KGE_alpha','KGE_beta','JKGE_M','JKGE_V','JKGE_C'}))
        return
    end

    v = abs(double(v(:)));
    v = v(isfinite(v) & v > 0);
    if isempty(v)
        return
    end

    % RSS, SAR, and Huber all use the same power-of-ten multiplier
    % strategy in the scatterplot, histogram, and map colorbar.
    ref = max(v);
    exponent = floor(log10(ref));

    % Show every non-unit power explicitly. This keeps the multiplier
    % visible for values in the 10^1 and 10^-1 ranges as well as for more
    % extreme RSS, SAR, Huber, and generalization-gap values.
    if exponent ~= 0
        pow10 = exponent;
        scaleVal = 10^pow10;
    end
end

function s = local_gen_metric_tex(metric,period,pow10)
%LOCAL_GEN_METRIC_TEX Metric axis label including active multiplier.

    base = local_gen_metric_symbol(metric);
    if local_gen_is_accumulated_loss(metric)
        if strcmpi(period,'eval')
            count = 'm_{\rm valid,eval}';
        else
            count = 'n_{\rm valid,train}';
        end
        s = ['$\underline{' base '}_{\rm ' period '}' ...
            '=' base '_{\rm ' period '}/' count];
    else
        periodMetric = local_gen_metric_period_symbol(metric,period);
        s = ['$' periodMetric];
    end

    if pow10 ~= 0
        s = [s '\;(\times 10^{' sprintf('%d',pow10) '})'];
    end
    s = [s '$'];
end

function s = local_gen_gap_tex(metric,pow10)
%LOCAL_GEN_GAP_TEX Gap definition and active multiplier.

    mname = local_gen_metric_symbol(metric);
    trainMetric = local_gen_metric_period_symbol(metric,'train');
    evalMetric = local_gen_metric_period_symbol(metric,'eval');

    if any(strcmpi(metric,{'KGE_alpha','KGE_beta'}))
        expr = ['\Delta E=|' trainMetric '|-|' evalMetric '|'];
    elseif local_gen_is_accumulated_loss(metric)
        mname = ['\underline{' mname '}'];
        expr = ['\Delta ' mname '=' mname '_{\rm train}-' ...
            mname '_{\rm eval}'];
    elseif local_gen_higher_is_better(metric)
        expr = ['\Delta ' mname '=' evalMetric '-' trainMetric];
    else
        expr = ['\Delta ' mname '=' trainMetric '-' evalMetric];
    end

    if pow10 ~= 0
        expr = [expr '\quad(\times 10^{' ...
            sprintf('%d',pow10) '})'];
    end
    s = ['$' expr '$'];
end

function [lim,ticks] = local_gen_scatter_limits(values,metric)
%LOCAL_GEN_SCATTER_LIMITS Shared square limits and clean tick labels.

    values = double(values(:));
    values = values(isfinite(values));

    if any(strcmpi(metric,{'KGE_alpha','KGE_beta'}))
        [lim,ticks] = local_gen_gap_limits(values);
        return
    end

    if any(strcmpi(metric, ...
            {'NSE','KGE','S_fdc','S_p','S_logp','JKGE','KGE_r'}))
        hi = 1;
        if isempty(values)
            lo = -1;
        else
            loData = min(values);
            if loData >= 0
                lo = 0;
            elseif loData >= -0.5
                lo = -0.5;
            elseif loData >= -1
                lo = -1;
            elseif loData >= -2
                lo = -2;
            else
                lo = floor(loData);
            end
        end

        span = hi-lo;
        if span <= 1
            step = 0.25;
        elseif span <= 2
            step = 0.5;
        else
            step = 1;
        end
        ticks = lo:step:hi;
        lim = [lo hi];
        return
    end

    % RSS, SAR, and Huber are nonnegative by definition. Add a small
    % negative plotting margin so points at zero are not pressed against
    % the axes. Tick marks and labels still begin at zero.
    if isempty(values)
        hiData = 1;
    else
        hiData = max(values);
    end

    [hi,step] = local_gen_nice_upper(hiData,5);
    margin = 0.05*hi;
    lim = [-margin hi];
    ticks = 0:step:hi;
end

function [lim,ticks] = local_gen_gap_limits(values)
%LOCAL_GEN_GAP_LIMITS Symmetric clean limits for generalization gaps.

    values = double(values(:));
    values = values(isfinite(values));

    if isempty(values)
        lim = [-1 1];
        ticks = -1:0.5:1;
        return
    end

    bound = max(abs(values));
    [boundNice,step] = local_gen_nice_upper(bound,4);
    lim = [-boundNice boundNice];
    ticks = -boundNice:step:boundNice;
end

function [upper,step] = local_gen_nice_upper(value,targetIntervals)
%LOCAL_GEN_NICE_UPPER Return a publication-style upper limit and step.

    if nargin < 2 || isempty(targetIntervals)
        targetIntervals = 5;
    end
    if ~isfinite(value) || value <= 0
        upper = 1;
        step = 0.2;
        return
    end

    rawStep = value/targetIntervals;
    exponent = floor(log10(rawStep));
    fraction = rawStep/(10^exponent);

    if fraction <= 1
        niceFraction = 1;
    elseif fraction <= 2
        niceFraction = 2;
    elseif fraction <= 2.5
        niceFraction = 2.5;
    elseif fraction <= 5
        niceFraction = 5;
    else
        niceFraction = 10;
    end

    step = niceFraction*(10^exponent);
    upper = ceil(value/step)*step;

    % Prefer integer ticks after the multiplier has been applied.
    if upper >= 4 && step < 1
        step = 1;
        upper = ceil(value/step)*step;
    end
end

function cm = local_gen_diverging_map(n)
%LOCAL_GEN_DIVERGING_MAP Publication-style blue-white-red colormap.

    if nargin < 1 || isempty(n)
        n = 256;
    end
    n1 = floor(n/2);
    n2 = n-n1;

    blue = [0.230 0.299 0.754];
    white = [0.97 0.97 0.97];
    red = [0.706 0.016 0.150];

    left = [ ...
        linspace(blue(1),white(1),n1)' ...
        linspace(blue(2),white(2),n1)' ...
        linspace(blue(3),white(3),n1)'];

    right = [ ...
        linspace(white(1),red(1),n2)' ...
        linspace(white(2),red(2),n2)' ...
        linspace(white(3),red(3),n2)'];

    cm = [left;right];
end


function [nTrain,nEval] = local_gen_valid_counts(dat,mdl,bas)
%LOCAL_GEN_VALID_COUNTS Valid observations per basin and period.

    K = double(bas.K_t) + double(bas.K_e);
    nTrain = nan(K,1);
    nEval = nan(K,1);

    globalTrain = [];
    globalEval = [];
    try
        globalTrain = mdl.id_train(:); 
    catch
    end
    try
        globalEval = mdl.id_eval(:); 
    catch
    end

    for k = 1:min(K,numel(dat))
        idt = globalTrain;
        ide = globalEval;

        try
            if isfield(dat{k},'id_train') && ~isempty(dat{k}.id_train)
                idt = dat{k}.id_train(:);
            end
        catch
        end
        try
            if isfield(dat{k},'id_eval') && ~isempty(dat{k}.id_eval)
                ide = dat{k}.id_eval(:);
            end
        catch
        end

        obs = local_gen_observed_series(dat{k});

        nTrain(k) = local_gen_count_valid_indices(obs,idt);
        nEval(k) = local_gen_count_valid_indices(obs,ide);
    end

    nTrain(~isfinite(nTrain) | nTrain < 1) = NaN;
    nEval(~isfinite(nEval) | nEval < 1) = NaN;
end

function obs = local_gen_observed_series(d)
%LOCAL_GEN_OBSERVED_SERIES Locate the observed discharge vector.

    obs = [];
    candidates = {'y','Y','Q','q','obs','Qobs','qobs','flow'};
    for i = 1:numel(candidates)
        f = candidates{i};
        try
            if isfield(d,f) && isnumeric(d.(f)) && ~isempty(d.(f))
                v = d.(f);
                if isvector(v)
                    obs = double(v(:));
                    return
                end
            end
        catch
        end
    end
end

function n = local_gen_count_valid_indices(obs,idx)
    if isempty(idx)
        n = NaN;
        return
    end

    idx = double(idx(:));
    % if islogical(idx)
    %     idx = find(idx);
    % end
    idx = idx(isfinite(idx));
    idx = round(idx);

    if isempty(obs)
        n = numel(idx);
        return
    end

    idx = idx(idx >= 1 & idx <= numel(obs));
    n = sum(isfinite(obs(idx)));
end

function counts = local_gen_count_group(out,whichPeriod,Kt,Ke)
%LOCAL_GEN_COUNT_GROUP Return all-basin valid-observation counts.

    K = Kt + Ke;
    counts = nan(K,1);

    if strcmpi(whichPeriod,'train')
        field = 'nValidTrain';
    else
        field = 'nValidEval';
    end

    if isfield(out,field)
        q = double(out.(field));
        q = q(:);
        counts(1:min(K,numel(q))) = q(1:min(K,numel(q)));
    end

    counts(~isfinite(counts) | counts < 1) = NaN;
end

function s = local_gen_colorbar_label(metric,mapMode,pow10)
%LOCAL_GEN_COLORBAR_LABEL Colorbar text including active multiplier.

    metricName = local_gen_metric_symbol(metric);
    if local_gen_is_accumulated_loss(metric)
        metricName = ['\underline{' metricName '}'];
    end

    if strcmpi(mapMode,'gap')
        if any(strcmpi(metric,{'KGE_alpha','KGE_beta'}))
            base = ['\Delta E_{' metricName '}'];
        else
            base = ['\Delta ' metricName];
        end
    elseif strcmpi(mapMode,'train')
        base = local_gen_metric_period_symbol(metric,'train');
    elseif strcmpi(mapMode,'eval')
        base = local_gen_metric_period_symbol(metric,'eval');
    else
        base = metricName;
    end

    if pow10 ~= 0
        s = ['$' base '\;(\times 10^{' sprintf('%d',pow10) '})$'];
    else
        s = ['$' base '$'];
    end
end


function local_gen_text_key( ...
        ax,showTrain,showEval,blue,orange,fontSize,location,referenceHeight)
%LOCAL_GEN_TEXT_KEY Draw colored labels without MATLAB legend().
%
% Both panels use the same normalized vertical spacing. The top scatter
% key is placed in the southeast; the histogram key remains northeast.

    if nargin < 7 || isempty(location)
        location = 'northeast';
    end

    dy = 0.070;
    if nargin >= 8 && ~isempty(referenceHeight) ...
            && isfinite(referenceHeight) && referenceHeight > 0
        try
            axisHeight = max(1,double(ax.Position(4)));
            % Preserve exactly the scatter key's pixel separation even
            % though the histogram axes have a different height.
            dy = 0.070*double(referenceHeight)/axisHeight;
        catch
            dy = 0.070;
        end
    end
    dy = min(max(dy,0.070),0.25);

    switch lower(location)
        case 'southeast'
            x0 = 0.71;
            y0 = 0.17;
            secondY = y0-dy;
        otherwise
            x0 = 0.71;
            y0 = 0.95;
            secondY = y0-dy;
    end

    if showTrain
        text(ax,x0,y0,'●  Training basins', ...
            'Units','normalized', ...
            'color',blue, ...
            'fontsize',fontSize, ...
            'fontweight','normal', ...
            'interpreter','none', ...
            'horizontalalignment','left', ...
            'verticalalignment','top', ...
            'BackgroundColor','none');
    end

    if showEval
        text(ax,x0,secondY,'■  Evaluation basins', ...
            'Units','normalized', ...
            'color',orange, ...
            'fontsize',fontSize, ...
            'fontweight','normal', ...
            'interpreter','none', ...
            'horizontalalignment','left', ...
            'verticalalignment','top', ...
            'BackgroundColor','none');
    end
end

function local_draw_gen_color_scale( ...
        ax,mapAx,mapMode,tickFont,labelText,titleFont)
%LOCAL_DRAW_GEN_COLOR_SCALE Stable horizontal scale with label above.

    if nargin < 5, labelText=''; end
    if nargin < 6 || isempty(titleFont), titleFont=tickFont+2; end

    try
        lim = clim(mapAx);
    catch
        return
    end

    if any(~isfinite(lim)) || lim(2) <= lim(1)
        return
    end

    upperBound = inf;
    if isappdata(mapAx,'GeneralizationUpperBound')
        upperBound = getappdata(mapAx,'GeneralizationUpperBound');
    end

    if strcmpi(mapMode,'gap')
        bound = max(abs(lim));
        [boundNice,step] = local_gen_nice_upper(bound,4);
        lim = [-boundNice boundNice];
        clim(mapAx,lim);
        ticks = -boundNice:step:boundNice;
    else
        lo = lim(1);
        hi = lim(2);

        if lo >= 0
            loNice = 0;
            [hiNice,step] = local_gen_nice_upper(hi,5);
            hiNice = min(hiNice,upperBound);
            if hiNice <= loNice
                hiNice = min(max(hi,eps),upperBound);
            end
            lim = [loNice hiNice];
            ticks = loNice:step:hiNice;
            if isfinite(upperBound) ...
                    && (isempty(ticks) || ticks(end) < hiNice)
                ticks = [ticks hiNice];
            end
        else
            span = hi-lo;
            rawStep = span/5;
            [~,step] = local_gen_nice_upper(rawStep*5,5);
            loNice = floor(lo/step)*step;
            hiNice = min(ceil(hi/step)*step,upperBound);
            if hiNice <= loNice
                loNice = hiNice-step;
            end
            lim = [loNice hiNice];
            ticks = loNice:step:hiNice;
            if isfinite(upperBound) ...
                    && (isempty(ticks) || ticks(end) < hiNice)
                ticks = [ticks hiNice];
            end
        end
        clim(mapAx,lim);
    end

    cla(ax);
    % CLA removes plotted children but can leave native UIAxes title and
    % label objects populated. Clear them explicitly so only the custom,
    % multiplier-aware scale title below is shown.
    title(ax,'');
    xlabel(ax,'');
    ylabel(ax,'');
    % Use a clearly visible bar while retaining room below for outward
    % ticks and labels. Use many image rows so IMAGESC treats the supplied
    % y values as the bar limits rather than as two pixel centres.
    % Keep title, bar, ticks, and tick labels inside this single axes. This
    % avoids web-layout z-order races between a UI label and the axes.
    % Reserve distinct vertical bands for title, scale, and tick labels.
    % The previous compact positions allowed the title to touch the bar and
    % outward tick labels to extend into the basin-key row below the host.
    % Use twice the former color-strip height (0.60 instead of 0.30).
    % The lower bound still leaves a dedicated in-axes band for ticks and
    % tick labels, preventing them from entering the basin-key row below.
    barBottom = 0.38;
    barTop = 0.80; % 70% of the former 0.60-high strip.
    c = repmat(linspace(0,1,256),64,1);
    imagesc(ax,lim,[barBottom barTop],c);
    colormap(ax,colormap(mapAx));
    clim(ax,[0 1]);
    ax.YDir = 'normal';
    ax.YLim = [0 1];
    ax.YTick = [];
    ax.XLim = lim;
    ax.XTick = [];
    ax.FontSize = tickFont;
    ax.XColor = 'none';
    ax.YColor = 'none';
    ax.Color = 'none';
    ax.Box = 'off';
    try
        ax.Toolbar.Visible = 'off';
        ax.Interactions = [];
    catch
    end
    hold(ax,'on');
    rectangle(ax,'Position',[lim(1) barBottom diff(lim) barTop-barBottom], ...
        'edgecolor',[0 0 0],'linewidth',1,'FaceColor','none', ...
        'Clipping','off','tag','GeneralizationColorbarPerimeter');
    if ~isempty(labelText)
        text(ax,mean(lim),0.88,labelText, ...
            'horizontalalignment','center', ...
            'verticalalignment','middle', ...
            'interpreter','latex', ...
            'fontsize',titleFont, ...
            'color',[0 0 0], ...
            'Clipping','on', ...
            'tag','GeneralizationColorbarTitle');
    end
    tickLength = 0.060;
    for it = 1:numel(ticks)
        line(ax,[ticks(it) ticks(it)], ...
            [barBottom barBottom-tickLength], ...
            'color',[0 0 0],'linewidth',0.75,'Clipping','off');
        text(ax,ticks(it),barBottom-tickLength-0.035,compose('%g',ticks(it)), ...
            'horizontalalignment','center','verticalalignment','top', ...
            'interpreter','none','fontsize',tickFont,'Clipping','off');
    end
    hold(ax,'off');
end


function name = local_gen_metric_display_name(metric)
%LOCAL_GEN_METRIC_DISPLAY_NAME Preserve publication-style metric casing.

    switch char(metric)
        case 'Huber'
            name = 'Huber';
        case 'S_fdc'
            name = 'Physical-discharge FDC skill score';
        case 'S_p'
            name = 'Probability-space FDC skill score';
        case 'S_logp'
            name = 'Log-quantile FDC skill score';
        case 'D_fdc'
            name = 'Physical-discharge FDC divergence';
        case 'D_p'
            name = 'Probability-space FDC divergence';
        case 'D_logp'
            name = 'Log-quantile FDC divergence';
        case 'KGE_r'
            name = 'KGE correlation';
        case 'KGE_alpha'
            name = 'KGE variability ratio';
        case 'KGE_beta'
            name = 'KGE mean ratio';
        case 'JKGE_M'
            name = 'JKGE benchmark penalty';
        case 'JKGE_V'
            name = 'JKGE variability penalty';
        case 'JKGE_C'
            name = 'JKGE correlation penalty';
        otherwise
            name = upper(char(metric));
    end
end

function s = local_gen_metric_period_symbol(metric,period)
%LOCAL_GEN_METRIC_PERIOD_SYMBOL Place KGE-ratio subscripts inside log2().

    switch char(metric)
        case 'S_fdc'
            s = ['S_{\rm fdc,' period '}'];
        case 'S_p'
            s = ['S_{p,\rm ' period '}'];
        case 'S_logp'
            s = ['S_{\log p,\rm ' period '}'];
        case 'D_fdc'
            s = ['d_{\rm fdc,' period '}'];
        case 'D_p'
            s = ['d_{p,\rm ' period '}'];
        case 'D_logp'
            s = ['d_{\log p,\rm ' period '}'];
        case 'KGE_alpha'
            s = ['\log_2(\alpha_{\rm ' period '})'];
        case 'KGE_beta'
            s = ['\log_2(\beta_{\rm ' period '})'];
        otherwise
            s = [local_gen_metric_symbol(metric) '_{\rm ' period '}'];
    end
end

function s = local_gen_metric_symbol(metric)
%LOCAL_GEN_METRIC_SYMBOL Publication-style mathematical metric symbol.

    switch char(metric)
        case 'S_fdc'
            s = 'S_{\rm fdc}';
        case 'S_p'
            s = 'S_p';
        case 'S_logp'
            s = 'S_{\log p}';
        case 'D_fdc'
            s = 'd_{\rm fdc}';
        case 'D_p'
            s = 'd_p';
        case 'D_logp'
            s = 'd_{\log p}';
        case 'KGE_r'
            s = 'r';
        case 'KGE_alpha'
            s = '\log_2(\alpha)';
        case 'KGE_beta'
            s = '\log_2(\beta)';
        case 'JKGE_M'
            s = 'M';
        case 'JKGE_V'
            s = 'V';
        case 'JKGE_C'
            s = 'C';
        otherwise
            s = ['{\rm ' local_gen_metric_display_name(metric) '}'];
    end
end


function s = local_gen_gap_axis_label(pow10)
%LOCAL_GEN_GAP_AXIS_LABEL Histogram x-axis label with multiplier.

    if pow10 ~= 0
        s = ['$\mathrm{Generalization\ gap}\;' ...
            '(\times 10^{' sprintf('%d',pow10) '})$'];
    else
        s = '$\mathrm{Generalization\ gap}$';
    end
end

function txt = localPrettyCoreCount(n)
    if isempty(n)
        txt = '-';
    else
        txt = sprintf('%d',n);
    end
end

function s = localMatlabMemoryString()
    s = '-';
    try
        if ispc
            m = memory;
            s = sprintf(['%.1f GB used, ' ...
                ' %.1f GB avail'], ...
                m.MemUsedMATLAB/1e9, ...
                m.MemAvailableAllArrays/1e9);
        else
            ws = whos;
            bytes = sum([ws.bytes]);
            s = sprintf('workspace: %.2f GB', ...
                bytes/1e9);
        end
    catch
    end
end

function s = localDiskFreeString(pathHere)

    s = '-';
    try
        if ispc
            % safer: use PowerShell instead of WMIC
            cmd = ['powershell -command "Get-PSDrive ' pathHere(1:1) ...
                   ' | Select-Object -ExpandProperty Free"'];
            [~,out] = system(cmd);
            freeB = str2double(strtrim(out));
            if ~isnan(freeB)
                s = sprintf('%.1f GB', freeB/1e9);
            end
        else
            % macOS / Linux (robust df parsing)
            cmd = ['df -k "' pathHere '"'];
            [~,out] = system(cmd);
            lines = splitlines(strtrim(out));
            if numel(lines) >= 2
                vals = regexp(lines{2}, '\s+', 'split');
                if numel(vals) >= 4
                    freeKB = str2double(vals{4});
                    if ~isnan(freeKB)
                        s = sprintf('%.1f GB', freeKB/1e6);
                    end
                end
            end
        end
    catch
        s = '-';
    end
end

function s = localDataStorageString(dataDir)
    s = '-';
    try
        dataDir = char(string(dataDir));
        if ~isfolder(dataDir)
            return
        end
        bytes = localFolderBytes(dataDir);
        s = localBytesString(bytes);
    catch
        s = '-';
    end
end

function bytes = localFolderBytes(folderName)
    bytes = 0;
    try
        D = dir(folderName);
        for ii = 1:numel(D)
            nm = D(ii).name;
            if strcmp(nm,'.') ...
                    || strcmp(nm,'..')
                continue
            end
            pth = fullfile(D(ii).folder,nm);
            if D(ii).isdir
                bytes = bytes + localFolderBytes(pth);
            else
                bytes = bytes + double(D(ii).bytes);
            end
        end
    catch
    end
end

function s = localBytesString(bytes)
    if ~isfinite(bytes) ...
            || bytes < 0
        s = '-';
    elseif bytes >= 1e12
        s = sprintf('%.2f TB',bytes/1e12);
    elseif bytes >= 1e9
        s = sprintf('%.1f GB',bytes/1e9);
    elseif bytes >= 1e6
        s = sprintf('%.1f MB',bytes/1e6);
    else
        s = sprintf('%.0f KB',bytes/1e3);
    end
end

function s = localCpuUsageEstimate()
    s = '-';
    try
        if ispc
            % Prefer PowerShell; WMIC is deprecated/unreliable
            cmd = ['powershell -NoProfile -Command ' ...
                '"(Get-Counter ''\Processor(_Total)' ...
                '\% Processor Time'')' ...
                '.CounterSamples.CookedValue"'];
            [ok,out] = system(cmd);
            if ok == 0
                cpu = str2double(strtrim(out));
                if isfinite(cpu)
                    s = sprintf('%.0f %%',cpu);
                    return
                end
            end
            % Fallback
            [ok,out] = system(['wmic cpu get ' ...
                'LoadPercentage /value']);
            if ok == 0
                tok = regexp(out, ...
                    'LoadPercentage=(\d+)', ...
                    'tokens','once');
                if ~isempty(tok)
                    s = sprintf('%s %%',tok{1});
                    return
                end
            end
        elseif ismac
            [ok,out] = system("ps -A -o %cpu " + ...
                "| awk '{s+=$1} END {print s}'");
            if ok == 0
                cpu = str2double(strtrim(out));
                if isfinite(cpu)
                    s = sprintf('%.0f %%',cpu);
                    return
                end
            end
        else
            [ok,out] = system("top -bn1 " + ...
                "| grep 'Cpu(s)'");
            if ok == 0
                tok = regexp(out,'(\d+\.?\d*)\s*id', ...
                    'tokens','once');
                if ~isempty(tok)
                    cpu = 100 - str2double(tok{1});
                    s = sprintf('%.0f %%',cpu);
                    return
                end
            end
        end
    catch
        s = '-';
    end
end

function name = lossName(i)
    switch i
        case 1
            name = ['Sum of Absolute ' ...
                'Residuals'];
        case 2
            name = ['Generalized Least ' ...
                'Squares'];
        case 3
            name = ['Nash Sutcliffe ' ...
                'efficiency'];
        case 4
            name = ['Kling Gupta ' ...
                'efficiency'];
        case 5
            name = ['Huber robust ' ...
                'estimator'];
        case 6
            name = ['Flow Duration Curve ' ...
                'divergence'];
        case 7
            name = ['Jawad-Kling-Gupta ' ...
                'efficiency'];
        otherwise
            name = '?';
    end
end

function name = jkgeMethodName(i)
    switch i
        case 1
            name = 'Moving-average mean';
        case 2
            name = 'Section-wise mean';
        case 3
            name = 'Long-term mean';
        case 4
            name = 'Monthly climatology';
        otherwise
            name = '?';
    end
end

function lossCfg = normalizeLossStruct_local(lossIn)
    if isstruct(lossIn)
        lossCfg = lossIn;
    else
        lossCfg = struct('fnc',double(lossIn), ...
            'method',1,'n_win',30);
    end
    if ~isfield(lossCfg,'fnc') ...
            || isempty(lossCfg.fnc)
        lossCfg.fnc = 2;
    end
    if ~isfield(lossCfg,'method') ...
            || isempty(lossCfg.method)
        lossCfg.method = 1;
    end
    if ~isfield(lossCfg,'n_win') ...
            || isempty(lossCfg.n_win)
        lossCfg.n_win = 30;
    end
    if ~isfield(lossCfg,'M') ...
            || isempty(lossCfg.M)
        lossCfg.M = 2;
    end
    lossCfg.observed = {'Q'};
    if ~isfield(lossCfg,'fdc') ...
            || ~isstruct(lossCfg.fdc)
        lossCfg.fdc = struct();
    end
    if ~isfield(lossCfg.fdc,'formulation') ...
            || isempty(lossCfg.fdc.formulation)
        lossCfg.fdc.formulation = 1;
    end
    lossCfg.fdc.formulation = double(lossCfg.fdc.formulation);
    if ~(isscalar(lossCfg.fdc.formulation) ...
            && isfinite(lossCfg.fdc.formulation) ...
            && any(lossCfg.fdc.formulation == 1:3))
        lossCfg.fdc.formulation = 1;
    end
    lossCfg.M = double(lossCfg.M);
    if ~(isscalar(lossCfg.M) ...
            && isfinite(lossCfg.M) ...
            && any(lossCfg.M == [1 2]))
        lossCfg.M = 2;
    end
    lossCfg.method = double(lossCfg.method);
    lossCfg.n_win = max(1,round(double(lossCfg.n_win)));
    if mod(lossCfg.n_win,2) == 0
        lossCfg.n_win = lossCfg.n_win + 1;
    end
end

function name = optName(i)
    switch i
        case 1, name = 'Projected gradient descent (PGD)';
        case 2, name = 'Gauss-Newton';
        case 3, name = 'Levenberg-Marquardt';
        case 4, name = 'Adam';
        case 5, name = 'L-BFGS-B';
        case 6, name = 'Preconditioned conjugate gradient (PCG)';
        case 7, name = 'Hybrid';
        otherwise, name = '?';
    end
end

function key = overrideKey(mdl,dt)
    if local_is_gchm_ode(mdl)
        key = sprintf('gchm_ode_dt%02d',dt);
    else
        key = sprintf('m%02d_dt%02d', ...
            mdl.model,dt);
    end
end

function [items,itemsData] = local_model_dropdown_items(root)

    items = {'hymod','hmodel','sacsma', ...
        'Xinanjiang','gr4j','hbv', ...
        'cfe_nwm'};
    
    itemsData = {'hymod','hmodel','sacsma', ...
        'Xinanjiang','gr4j','hbv', ...
        'cfe_nwm'};

    if local_gchm_available(root)
        items{end+1} = 'gchm';
        itemsData{end+1} = 'gchm';
    end
    if local_gchm_ode_available(root)
        items{end+1} = 'gchm_ode';
        itemsData{end+1} = 'gchm_ode';
    end
    
    if isfolder(local_user_model_dir(root))
        items{end+1} = 'user_model';
        itemsData{end+1} = 'user_model';
    end

end

function tf = local_gchm_available(root)
    if isdeployed
        tf = false;
        return
    end
    hdir = local_gchm_dir(root);
    tf = isfolder(hdir) && isfile(fullfile(hdir,'gchm.m')) ...
        && isfile(fullfile(hdir,'read_gchm_info.m')) ...
        && (isfile(fullfile(hdir,['crr_gchm.' mexext])) ...
        || (isfile(fullfile(hdir,'crr_gchm_mex.cpp')) ...
        && isfile(fullfile(hdir,'gchm.cpp'))));
end

function hdir = local_gchm_dir(root)
    hdir = fullfile(root,'SAGEhydrology','private','gchm');
end

function tf = local_gchm_ode_available(root)
    if isdeployed
        tf = false;
        return
    end
    odir = local_gchm_ode_dir(root);
    tf = isfile(fullfile(odir,'gchm_ode.m')) ...
        && isfile(fullfile(odir,'read_gchm_ode_info.m')) ...
        && isfile(fullfile(odir,['crr_gchm_ode.' mexext]));
end

function odir = local_gchm_ode_dir(root)
    odir = fullfile(root,'SAGEhydrology', ...
        'private','gchm_ode');
end

function tf = local_user_model_available(root)

    udir = fullfile(root,'user_model');

    hasInfo = isfile(fullfile(udir, ...
        'user_model_info.mat')) ...
        || isfile(fullfile(udir, ...
        'make_user_model_info.m'));

    hasMex = isfile(fullfile(udir, ...
        ['crr_user_model.' mexext]));

    hasCompile = isfile(fullfile(udir, ...
        'user_model_compile.m'));

    hasCppTemplate = isfile(fullfile(udir, ...
        'crr_user_model_mex.cpp')) ...
        && isfile(fullfile(udir, ...
        'user_model_prepare.cpp')) ...
        && isfile(fullfile(udir, ...
        'user_model.cpp'));

    tf = isfolder(udir) ...
        && hasInfo ...
        && (hasMex ...
        || (hasCompile ...
        && hasCppTemplate));

end

function udir = local_user_model_dir(root)
    udir = fullfile(root,'user_model');
end

function s = fmtMode_local(mode)
    if isempty(mode) ...
            || ~isfinite(mode)
        s = '[]';
        return
    end
    switch double(mode)
        case 1
            s = ['1  training basins ' ...
                '| training period'];
        case 2
            s = ['2  training basins ' ...
                '| evaluation period/mask'];
        case 3
            s = ['3  training + evaluation basins ' ...
                '| training period'];
        case 4
            s = ['4  training + evaluation basins ' ...
                '| evaluation period/mask'];
        otherwise
            s = sprintf('%g',double(mode));
    end
end

function s = fmtCellStrList_local(x)

    if isempty(x)
        s = '{}';
        return
    end
    
    if isstring(x)
        x = cellstr(x);
    end
    
    if ischar(x)
        x = {x};
    end
    
    if ~iscell(x)
        try
            x = cellstr(string(x));
        catch
            s = '{}';
            return
        end
    end
    
    x = x(:).';
    
    if isempty(x)
        s = '{}';
    elseif numel(x) <= 8
        s = ['{' strjoin(x,', ') '}'];
    else
        s = ['{' strjoin(x(1:4),', ') ...
            ' ... ' ...
            strjoin(x(end-3:end),', ') ...
            sprintf('} (%d)',numel(x))];
    end

end

function s = previewValue_local(x)
%PREVIEWVALUE_LOCAL Compact, robust formatter for Preview structure fields.

    if isempty(x)
        s = '[]';
    elseif isnumeric(x) || islogical(x)
        if isscalar(x)
            s = fmtNum_local(double(x));
        else
            s = fmtSmallVector_local(double(x));
        end
    elseif iscell(x)
        s = fmtCellStrList_local(x);
    elseif ischar(x) || isstring(x) || iscategorical(x)
        s = local_text_scalar(x);
    else
        try
            s = local_text_scalar(string(x));
        catch
            s = '<unavailable>';
        end
    end
end


function lines = appendPeriodPreview_local( ...
    lines,prd)

    method = 'manual';
    if isfield(prd,'method') ...
            && ~isempty(prd.method)
        method = lower(char(prd.method));
    end
    lines{end+1} = ['dt           : ' ...
        sprintf('%d',prd.dt)];
    lines{end+1} = ['method       : ' ...
        method];
    switch method
    
        case 'manual'
            lines{end+1} = ['train        : ' ...
                fmtDMY(prd.dts) ' → ' ...
                fmtDMY(prd.dte)];
            if isfield(prd,'eval_partial') ...
                    && prd.eval_partial
                lines{end+1} = ['eval         : ' ...
                    '[incomplete: provide ' ...
                    'both dates or leave both empty]'];
            elseif isfield(prd,'eval_was_empty') ...
                    && prd.eval_was_empty
                lines{end+1} = ['eval       : ' ...
                    '[not provided separately; ' ...
                    'using training dates]'];
            else
                lines{end+1} = ['eval         : ' ...
                    fmtDMY(prd.des) ' → ' ...
                    fmtDMY(prd.dee)];
            end
    
        case 'deterministic_block'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['block_size   : ' ...
                sprintf('%d',prd.block_size)];
            lines{end+1} = ['train_frac   : ' ...
                fmtNum_local(prd.train_frac)];
    
        case 'random_block'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['block_size   : ' ...
                sprintf('%d',prd.block_size)];
            lines{end+1} = ['train_frac   : ' ...
                fmtNum_local(prd.train_frac)];
            lines{end+1} = ['seed         : ' ...
                fmtNum_local(prd.seed)];
    
        case 'random'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['train_frac   : ' ...
                fmtNum_local(prd.train_frac)];
            lines{end+1} = ['seed         : ' ...
                fmtNum_local(prd.seed)];
    
        case 'deterministic_kfold'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['n_folds      : ' ...
                sprintf('%d',prd.n_folds)];
            lines{end+1} = ['fold         : ' ...
                sprintf('%d',prd.fold)];
    
        case 'random_kfold'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['n_folds      : ' ...
                sprintf('%d',prd.n_folds)];
            lines{end+1} = ['fold         : ' ...
                sprintf('%d',prd.fold)];
            lines{end+1} = ['seed         : ' ...
                fmtNum_local(prd.seed)];
    
        case 'rainfall_block'
            lines{end+1} = ['overall      : ' ...
                fmtDMY(prd.ds) ' → ' ...
                fmtDMY(prd.de)];
            lines{end+1} = ['train        : ' ...
                'local rainfall-event blocks'];
            lines{end+1} = ['eval         : ' ...
                'complementary non-training blocks'];
            lines{end+1} = ['source       : ' ...
                'dat{k}.id_train / dat{k}.id_eval'];
    
        otherwise
            % fallback: print only the essentials
            if isfield(prd,'ds') ...
                    && isfield(prd,'de')
                lines{end+1} = ['overall      : ' ...
                    fmtDMY(prd.ds) ' → ' ...
                    fmtDMY(prd.de)];
            end
    end
    lines{end+1} = ['spinup       : ' ...
        sprintf('%d',prd.spinup)];
    end
    
    function x = getfield_safe(S,f)
    if isfield(S,f)
        x = S.(f);
    else, x = [];
    end
end

function s = fmtNum_local(x)
    if isempty(x) ...
            || ~isfinite(x)
        s = '[]';
    else
        s = sprintf('%.6g',x);
    end
end

function s = fmtSmallVector_local(x)
    if isempty(x)
        s = '[]';
        return
    end
    x = x(:).';
    if isnumeric(x)
        if isscalar(x)
            s = sprintf('[%g]',x);
        elseif numel(x)==2
            s = sprintf('[%g %g]',x(1),x(2));
        else
            s = sprintf('[%g ... %g] (%d)', ...
                x(1),x(end),numel(x));
        end
    else
        xs = string(x);
        if isscalar(xs)
            s = ['[' char(xs(1)) ']'];
        elseif numel(xs)==2
            s = ['[' char(xs(1)) ' ' ...
                char(xs(2)) ']'];
        else
            s = ['[' char(xs(1)) ' ... ' ...
                char(xs(end)) sprintf('] (%d)', ...
                numel(xs))];
        end
    end
end

function ensureInstallerOnPath(rootDir)

    if isdeployed
        return
    end

    try
        uiDir = fileparts(mfilename('fullpath'));

        if ~isempty(uiDir) ...
                && isfolder(uiDir)
            addpath(uiDir);
        end

        if nargin >= 1 ...
                && ~isempty(rootDir) ...
                && isfolder(rootDir)
            addpath(rootDir);
        end

        if nargin >= 1 ...
                && ~isempty(rootDir)
            sageDir = fullfile(rootDir, ...
                'SAGEhydrology');
            if isfolder(sageDir)
                addpath(sageDir);
            end
            regionsDir = fullfile(sageDir,'regions');
            if isfolder(regionsDir)
                addpath(genpath(regionsDir));
            end
            srcDir = fullfile(sageDir,'src');
            if isfolder(srcDir)
                addpath(srcDir);
            end
            utilsDir = fullfile(sageDir,'utils','various');
            if isfolder(utilsDir)
                addpath(genpath(utilsDir));
            end
        end
    catch
    end
end

function [selTrain,selEval] = ...
    getConusSelectionMasks_new(tblTrain,tblEval,K_t,K_e)
% Map visible table rows back to the contiguous active basin population.
% Excluded rows remain visible with an empty index and must not change mask
% length or shift selections after data-quality screening.
    if nargin < 3 || isempty(K_t), K_t = 0; end
    if nargin < 4 || isempty(K_e), K_e = 0; end
    selTrain = false(K_t,1);
    selEval = false(K_e,1);

    try
        Dtr = tblTrain.Data;
        for row = 1:size(Dtr,1)
            idx = localSelectionTableIndex(Dtr{row,1});
            if idx >= 1 && idx <= K_t
                selTrain(idx) = logical(Dtr{row,2}) ...
                    || logical(Dtr{row,3});
            end
        end
    catch
        selTrain = false(K_t,1);
    end

    try
        Dev = tblEval.Data;
        for row = 1:size(Dev,1)
            idx = localSelectionTableIndex(Dev{row,1})-K_t;
            if idx >= 1 && idx <= K_e
                selEval(idx) = logical(Dev{row,2}) ...
                    || logical(Dev{row,3});
            end
        end
    catch
        selEval = false(K_e,1);
    end
end

function idx = localSelectionTableIndex(value)
    idx = NaN;
    try
        if ~isempty(value)
            if isnumeric(value)
                idx = double(value(1));
            else
                idx = str2double(string(value));
                idx = idx(1);
            end
        end
    catch
    end
end

function rows = local_export_period_rows(prd)
%LOCAL_EXPORT_PERIOD_ROWS Header metadata only; never generates a split.
    method = lower(char(string(prd.method)));
    keys = {'manual','deterministic_block','random_block','random', ...
        'deterministic_kfold','random_kfold','rainfall_block'};
    names = {'Manual dates','Deterministic block','Random block','Random', ...
        'Deterministic k-fold','Random k-fold','Rainfall block'};
    methodName = strrep(method,'_',' ');
    j = find(strcmp(method,keys),1);
    if ~isempty(j), methodName = names{j}; end
    fmt = 'dd MMM yyyy';
    if prd.dt > 1, fmt = 'dd MMM yyyy HH:mm'; end
    if strcmp(method,'manual')
        first = local_export_header_date(prd.dts,prd.dt,false);
        last = local_export_header_date(prd.dte,prd.dt,true);
        training = [char(string(first,fmt)) ' - ' char(string(last,fmt))];
        evaluation = 'Not configured';
        hasEval = isfield(prd,'des') && ~isempty(prd.des) ...
            && isfield(prd,'dee') && ~isempty(prd.dee);
        if isfield(prd,'eval_was_empty') && prd.eval_was_empty
            hasEval = false;
        end
        if hasEval
            evalFirst = local_export_header_date(prd.des,prd.dt,false);
            evalLast = local_export_header_date(prd.dee,prd.dt,true);
            evaluation = [char(string(evalFirst,fmt)) ' - ' ...
                char(string(evalLast,fmt))];
            first = min(first,evalFirst);
            last = max(last,evalLast);
        end
    else
        first = local_export_header_date(prd.ds,prd.dt,false);
        last = local_export_header_date(prd.de,prd.dt,true);
    end
    rows = {'Period',[char(string(first,fmt)) ' - ' char(string(last,fmt))]; ...
        'Temporal split',methodName};
    if strcmp(method,'manual')
        rows = [rows; {'Training',training; 'Evaluation',evaluation}];
    end
end

function t = local_export_header_date(v,dt,isEnd)
% Date vectors in exported prd are [day month year (hour minute second)].
    v = double(v(:).');
    n = numel(v);
    v(end+1:6) = 0;
    t = datetime(v(3),v(2),v(1),v(4),v(5),v(6));
    if isEnd && n == 3 && dt > 1
        t = t + days(1-1/dt);
    end
end

function text = local_export_data_type_text(loss)
%LOCAL_EXPORT_DATA_TYPE_TEXT Return readable exported observation names.

    names = "Q";
    if isfield(loss,'observed') && ~isempty(loss.observed)
        names = unique(upper(strtrim( ...
            string(loss.observed(:)))),'stable');
        names = names(strlength(names) > 0);
    end
    labels = strings(size(names));
    for k = 1:numel(names)
        switch names(k)
            case "Q"
                labels(k) = "Discharge";
            case "SWE"
                labels(k) = "snow water equivalent";
            case "SM"
                labels(k) = "soil moisture";
            otherwise
                labels(k) = names(k);
        end
    end
    if isscalar(labels)
        text = char(labels);
    else
        text = char(strjoin(labels(1:end-1),', ') ...
            + " and " + labels(end));
    end
end

function sel = local_adjust_selection_mask(sel,B,available)

    sel = logical(sel(:));
    nRows = numel(sel);
    if nargin < 3 || isempty(available)
        available = true(nRows,1);
    else
        available = logical(available(:));
    end
    available = available(1:min(numel(available),nRows));
    available(end+1:nRows,1) = false;
    sel = sel & available;
    B = min(B,nnz(available));
    
    idxSel = find(sel);
    nSel = numel(idxSel);
    
    if nSel == B
        return
    end
    
    if nSel < B
        % keep old ones, add more from the first unselected rows
        idxUnsel = find(available & ~sel);
        nAdd = min(B - nSel,numel(idxUnsel));
        if nAdd > 0
            addIdx = idxUnsel(1:nAdd);
            sel(addIdx) = true;
        end
    else
        % keep the first B selected rows, drop the rest
        keepIdx = idxSel(1:B);
        sel(:) = false;
        sel(keepIdx) = true;
    end
end

function sel = local_adjust_selection_mask_random(sel,B,available)

    sel = logical(sel(:));
    nRows = numel(sel);
    if nargin < 3 || isempty(available)
        available = true(nRows,1);
    else
        available = logical(available(:));
    end
    available = available(1:min(numel(available),nRows));
    available(end+1:nRows,1) = false;
    sel = sel & available;
    B = min(B,nnz(available));
    
    idxSel = find(sel);
    nSel = numel(idxSel);
    
    % If B is unchanged, keep the current random selection as-is.
    if nSel == B
        return
    end
    
    if nSel < B
        idxUnsel = find(available & ~sel);
        nAdd = min(B - nSel,numel(idxUnsel));
        if nAdd > 0
            addIdx = idxUnsel(randperm(numel(idxUnsel),nAdd));
            sel(addIdx) = true;
        end
    else
        nDrop = nSel - B;
        if nDrop > 0
            dropIdx = idxSel(randperm(nSel,nDrop));
            sel(dropIdx) = false;
        end
    end
end

function available = local_available_table_rows(D)
%LOCAL_AVAILABLE_TABLE_ROWS Rows retained by data-quality screening.
% Screened-out rows remain visible for transparency but have a blank first
% column and must not be reselected automatically.

    available = false(size(D,1),1);
    if isempty(D)
        return
    end
    for ii = 1:size(D,1)
        try
            value = D{ii,1};
            available(ii) = ~isempty(value) ...
                && ~(isnumeric(value) && any(~isfinite(value(:))));
        catch
            available(ii) = false;
        end
    end
end

function sel = local_full_random_selection(nRows,B)

    B = min(max(0,round(B)),nRows);
    sel = false(nRows,1);
    
    if nRows <= 0 ...
            || B <= 0
        return
    end
    
    idx = randperm(nRows,B);
    sel(idx) = true;
end

function sel = local_column_selection(D,col)

    nRows = size(D,1);
    sel = false(nRows,1);
    
    if isempty(D) ...
            || size(D,2) < col
        return
    end
    
    try
        sel = logical(cell2mat(D(:,col)));
    catch
        sel = false(nRows,1);
    end
end

function Qfdc = local_attach_fdc_local_indices(Qfdc,dat,mdl)

    if isempty(Qfdc) ...
            || ~isstruct(Qfdc) ...
            || ~isfield(Qfdc,'id')
        return
    end
    
    isLocal = false;
    try
        isLocal = isfield(mdl,'local') ...
            && mdl.local == 1;
    catch
    end
    try
        isLocal = isLocal ...
            || strcmpi(mdl.sp_method, ...
            'rainfall_block');
    catch
    end
    
    if ~isLocal
        return
    end
    
    nq = numel(Qfdc.id);
    
    Qfdc.idx.tt = cell(nq,1);
    Qfdc.idx.te = cell(nq,1);
    Qfdc.idx.et = cell(nq,1);
    Qfdc.idx.ee = cell(nq,1);
    
    for ip = 1:nq
        k = double(Qfdc.id(ip));
    
        if k < 1 ...
                || k > numel(dat)
            continue
        end
    
        idt = [];
        ide = [];
    
        if isfield(dat{k},'id_train') ...
                && ~isempty(dat{k}.id_train)
            idt = dat{k}.id_train(:);
        end
        if isfield(dat{k},'id_eval') ...
                && ~isempty(dat{k}.id_eval)
            ide = dat{k}.id_eval(:);
        end
    
        % Same local period indices apply to train/eval basin groups.
        Qfdc.idx.tt{ip} = idt;
        Qfdc.idx.et{ip} = idt;
    
        Qfdc.idx.te{ip} = ide;
        Qfdc.idx.ee{ip} = ide;
    end
end

function s = sampleModeText_local(x)
    x = lower(strtrim(char(string(x))));
    switch x
        case 'random'
            s = 'Random';
        case 'zone'
            s = 'Zone-stratified random';
        case 'file'
            s = 'User file';
        otherwise
            s = char(string(x));
    end
end

function s = local_text_scalar(x)
    if isempty(x)
        s = '';
    elseif ischar(x)
        s = x;
    elseif isstring(x)
        x = x(:);
        s = char(x(1));
    else
        s = char(string(x));
    end
end

function [fileUnivRel,fileSplitRel,fileSplitFull] = ...
    local_generate_random_basin_split(cfg)
%LOCAL_GENERATE_RANDOM_BASIN_SPLIT Create a writable reproducible split.
%
% Basin-universe files are stored in the registered dataset module. In deployed mode,
% packaged copies can be extracted beneath ctfroot. Generated split files
% are written to the writable registered dataset-module directory.

    moduleRel = char(region_helpers('modulepath',cfg.region));
    writableUniverse = local_materialize_basin_universe(cfg);
    [~,univName,univExt] = fileparts(writableUniverse);
    univBase = [univName univExt];

    writableDir = fullfile(cfg.SAGEhydro,'regions',moduleRel);

    oldRngState = rng;
    cleanupRng = onCleanup(@() rng(oldRngState));

    splitKt = round(double(cfg.bas.K_t));
    splitKe = max(0,round(double(cfg.bas.K)-splitKt));
    split_basin_ids(writableUniverse, ...
        splitKt,splitKe,round(double(cfg.bas.seed)));

    splitName = sprintf('split_%s_%d_%d_%d.txt', ...
        regexprep(univName,'_basins$',''), ...
        splitKt,splitKe,round(double(cfg.bas.seed)));

    fileUnivRel = univBase;
    fileSplitRel = splitName;
    fileSplitFull = fullfile(writableDir,splitName);
end

function writableUniverse = local_materialize_basin_universe(cfg)
%LOCAL_MATERIALIZE_BASIN_UNIVERSE Make packaged basin IDs writable.

    moduleRel = char(region_helpers('modulepath',cfg.region));
    [~,name,ext] = fileparts(char(cfg.file_univ));
    fname = [name ext];
    writableDir = fullfile(cfg.SAGEhydro,'regions',moduleRel);
    if ~isfolder(writableDir)
        mkdir(writableDir);
    end
    writableUniverse = fullfile(writableDir,fname);
    if isfile(writableUniverse)
        return
    end

    sourceUniverse = local_basin_absolute_file(cfg,cfg.file_univ);
    if strcmpi(sourceUniverse,writableUniverse)
        return
    end
    [copied,message] = copyfile(sourceUniverse,writableUniverse,'f');
    if ~copied
        error('SAGE_ui:CouldNotMaterializeBasinUniverse', ...
            'Could not copy basin universe file to %s: %s', ...
            writableUniverse,message);
    end
end

function K = site_basin_list_count(fileName)
%SITE_BASIN_LIST_COUNT Count gauge IDs in the active basin-universe file.
    K = 0;
    if ~isfile(fileName), return, end
    lines = strip(readlines(fileName));
    lines(lines == "" | startsWith(lines,"#")) = [];
    K = numel(lines);
end

function f = local_basin_absolute_file(cfg,f)
%LOCAL_BASIN_ABSOLUTE_FILE Resolve a basin file through the dataset registry.
%
% Preferred source-tree location:
%   <root>/SAGEhydrology/regions/<country>/<dataset>/<file>
%
% Packaged application fallbacks are also supported.

    f = strtrim(char(string(f)));
    if isempty(f)
        return
    end

    % Already absolute and valid.
    if isfile(f)
        return
    end

    [~,name,ext] = fileparts(f);
    fname = [name ext];
    short = char(region_helpers('short',cfg.region));
    moduleRel = char(region_helpers('modulepath',cfg.region));

    candidates = { ...
        fullfile(cfg.SAGEhydro,'regions',moduleRel,fname), ...
        fullfile(cfg.SAGEhydro,'regions',fname)};

    if isfield(cfg,'dirD') && ~isempty(cfg.dirD)
        dataRoot=char(string(cfg.dirD)); [p,n]=fileparts(dataRoot);
        if any(strcmpi(n,{'daily','hourly','15min'})), dataRoot=p; end
        candidates{end+1}=fullfile(dataRoot,fname);
    end

    if isfield(cfg,'root') && ~isempty(cfg.root)
        candidates{end+1} = fullfile( ...
            cfg.root,'SAGEhydrology','regions',moduleRel,fname);
        candidates{end+1} = fullfile( ...
            cfg.root,'SAGEhydrology','regions',fname);
    end

    if isdeployed
        appDir = fileparts(mfilename('fullpath'));
        candidates{end+1} = fullfile( ...
            ctfroot,'regions',moduleRel,fname);
        candidates{end+1} = fullfile( ...
            ctfroot,'SAGEhydrology','regions',moduleRel,fname);
        candidates{end+1} = fullfile( ...
            ctfroot,'regions',fname);
        candidates{end+1} = fullfile(ctfroot,short,fname);
        candidates{end+1} = fullfile(ctfroot,fname);
        candidates{end+1} = fullfile( ...
            appDir,'regions',moduleRel,fname);
        candidates{end+1} = fullfile( ...
            appDir,'..','regions',moduleRel,fname);
        candidates{end+1} = fullfile( ...
            appDir,'..','..','regions',moduleRel,fname);
    end

    for i = 1:numel(candidates)
        if isfile(candidates{i})
            f = candidates{i};
            return
        end
    end

    msg = sprintf('Could not find basin file: %s\nTried:',fname);
    for i = 1:numel(candidates)
        msg = sprintf('%s\n  %s',msg,candidates{i});
    end
    error('SAGE_ui:missingBasinFile','%s',msg);
end

function id = local_region_gauge_id(x,region)
%LOCAL_REGION_GAUGE_ID Region-aware gauge-code formatting for GUI tables.

    region = region_helpers('code',region);
    if strcmp(region,'CAMELS_CA')
        % Display compact Canadian station IDs in GUI tables.
        % Accept either CAN_ID, CAN-ID, or already compact IDs.
        id = upper(strtrim(string(x)));
        id = regexprep(id,'^CAN[-_]?','');
        id = id(:);
    elseif localIsGRDCRegion(region)
        id = strip(string(x(:)));
    elseif any(strcmp(region,{'CAMELS_AT', ...
            'CAMELS_CH','CAMELSH_KR','CAMELS_KR','CAMELS_NZ','CAMELS_IS', ...
            'HYDRO_CIS'}))
        id = string(x);
        id = strtrim(id);
        id = regexprep(id,'\.0+$','');
        id = regexprep(id,'\D','');
        id = regexprep(id,'^0+','');
        id(id == "") = "0";
        id = id(:);
    else
        id = normalize_usgs(x);
    end
end

function n = local_count_files(d,patterns)

    n = 0;
    
    if ~isfolder(d)
        return
    end
    
    for i = 1:numel(patterns)
        q = dir(fullfile(d,patterns{i}));
        n = n + sum(~[q.isdir]);
    end

end

function localSetDropdownByLeadingInt(dd,id)

    id = double(id);
    values = dd.Items;
    try
        if ~isempty(dd.ItemsData)
            values = dd.ItemsData;
        end
    catch
    end

    items = string(values);
    prefix = string(sprintf('%d ',id));
    
    hit = find(startsWith(items,prefix),1);
    
    if ~isempty(hit)
        if iscell(values)
            dd.Value = values{hit};
        else
            dd.Value = values(hit);
        end
    end

end

function d = localDocsDir(rootFolder)
    % Locate docs both in MATLAB and in the deployed CTF archive.
    % rootFolder is the normal project root selected in the GUI.
    if nargin < 1 || isempty(rootFolder)
        rootFolder = '';
    end
    rootFolder = char(string(rootFolder));
    
    % Preferred deployed/runtime lookup: docs packaged next to SAGE/src.
    pCompile = which('compile_model');
    if ~isempty(pCompile)
        sageRoot = fileparts(fileparts(pCompile));
        d = fullfile(sageRoot,'docs');
        if isfolder(d)
            return
        end
    end
    
    % Common deployed package locations.
    if isdeployed
        cand = { ...
            fullfile(ctfroot,'SAGEhydrology','docs'), ...
            fullfile(ctfroot,'docs')};
        for ii = 1:numel(cand)
            if isfolder(cand{ii})
                d = cand{ii};
                return
            end
        end
        d = cand{1};
        return
    end
    
    % MATLAB source-tree fallback.
    if ~isempty(rootFolder)
        d = fullfile(rootFolder, ...
            'SAGEhydrology','docs');
        if isfolder(d)
            return
        end
    end

    % Direct fallback relative to SAGEhydrology/gui.
    try
        d = fullfile(fileparts(mfilename('fullpath')), ...
            '..','docs');
        if isfolder(d)
            return
        end
    catch
    end

    d = fullfile(pwd,'SAGEhydrology','docs');
end

function html = local_html_page(body,background)
    if nargin < 2, background = [1 1 1]; end
    css = site_html_theme_css(background);

    html = [ ...
        '<html><head><meta charset="utf-8">' ...
        '<style>' ...
        'body { font-family: Arial, Helvetica, sans-serif; ' ...
        'font-size:15px; margin:6px; }' ...
        css ...
        'p { margin-top:0; margin-bottom:4px; }' ...
        'ol { margin-top:2px; margin-bottom:4px; padding-left:18px; }' ...
        'li { margin-bottom:3px; }' ...
        'a { text-decoration:none; }' ...
        '</style>' ...
        '<script>' ...
        'function setup(htmlComponent) {' ...
        'window.openRef = function(url) {' ...
        'htmlComponent.sendEventToMATLAB("open",{url:url});' ...
        'return false;' ...
        '};' ...
        '}' ...
        '</script>' ...
        '</head><body>' ...
        body ...
        '</body></html>'];
end

function foreground = site_theme_foreground(background)
    % Match native light/dark surfaces without relying on browser defaults.
    if dot(double(background),[0.2126 0.7152 0.0722]) < 0.5
        foreground = [1 1 1];
    else
        foreground = [0.067 0.067 0.067];
    end
end

function css = site_html_theme_css(background)
    foreground = site_theme_foreground(background);
    bg = sprintf('#%02X%02X%02X',round(255*background));
    fg = sprintf('#%02X%02X%02X',round(255*foreground));
    if foreground(1) == 1
        link = '#8AB4F8'; scheme = 'dark';
    else
        link = '#0645AD'; scheme = 'light';
    end
    css = ['html,body{background-color:' bg ';color:' fg ...
        ';color-scheme:' scheme ';}a{color:' link ';}'];
end
function nLines = local_estimate_wrapped_lines(txt, ...
    panelWidthPx,fontSize)

    if nargin < 3 || isempty(fontSize)
        fontSize = 13;
    end

    if isempty(txt)
        txt = {''};
    end

    % More realistic average text width for uilabel notes.
    % 0.44 was too small and overestimated wrapping too much.
    avgCharWidthPx = 0.64 * fontSize;

    usableWidthPx = max(panelWidthPx - 35,80);
    charsPerLine = max(floor(usableWidthPx / avgCharWidthPx),24);

    nLines = 0;

    for i = 1:numel(txt)

        s = string(txt{i});

        if strlength(s) == 0
            nLines = nLines + 0.55;
            continue
        end

        % Strip common LaTeX markup for visual-length estimation.
        s2 = s;
        s2 = regexprep(s2,'\\textbf\{([^}]*)\}','$1');
        s2 = regexprep(s2,'\rm','');
        s2 = regexprep(s2,'\\[a-zA-Z]+','');
        s2 = erase(s2,{'$','{','}','_','^'});

        L = double(strlength(s2));

        % Add a small safety factor, but not enough to create huge gaps.
        nLines = nLines + 1.08 * ceil(L / charsPerLine);

    end

    nLines = max(1,nLines);

end

function b64 = local_png_to_base64(pngFile)
%LOCAL_PNG_TO_BASE64 Convert PNG file to base64 string for uihtml.

    fid = fopen(pngFile,'r');
    
    if fid < 0
        b64 = '';
        return
    end
    
    bytes = fread(fid,Inf,'uint8=>uint8');
    fclose(fid);
    
    b64 = char(matlab.net.base64encode(bytes));
end

function [mdl,d] = local_read_user_model_info(mdl, ...
    prd,rootDir)

    if ~isfield(mdl,'root') ...
            || isempty(mdl.root)
        mdl.root = rootDir;
    end

    mdl.user_model_folder=local_user_model_dir(rootDir);
    [mdl,d] = read_user_model_info( ...
        mdl,prd,false);
    
end

function ztxt = local_short_zone_name(zname)

    ztxt = string(zname);

    for ii = 1:numel(ztxt)

        s = char(string(ztxt(ii)));
        s = lower(strrep(s,'_',' '));
        s = regexprep(s,'\s+',' ');
        s = strtrim(s);

        % Germany / general humidity-rain classes
        s = strrep(s,'very humid rain','VH-rain');
        s = strrep(s,'subhumid rain','SH-rain');
        s = strrep(s,'sub humid rain','SH-rain');
        s = strrep(s,'humid rain','H-rain');
        s = strrep(s,'dry rain','D-rain');

        % US snow/rain classes
        s = strrep(s,'humid snow','Humid snow');
        s = strrep(s,'subhumid snow','Subhumid snow');
        s = strrep(s,'sub humid snow','Subhumid snow');
        s = strrep(s,'dry snow','Dry snow');

        % Brazil runoff / land-cover classes
        s = strrep(s,'low runoff / forest','Low runoff');
        s = strrep(s,'moderate runoff / forest','Mod runoff');
        s = strrep(s,'high runoff / forest','High runoff');

        % General runoff classes
        s = strrep(s,'low runoff','Low Q');
        s = strrep(s,'moderate runoff','Mod Q');
        s = strrep(s,'high runoff','High Q');
        s = strrep(s,'unknown runoff','Unk Q');

        % General fallback classes
        s = strrep(s,'semi humid','Semi-humid');
        s = strrep(s,'semi arid','Semi-arid');
        s = strrep(s,'snow dominated','snow');
        s = strrep(s,'rain dominated','rain');
        s = strrep(s,'snowfall dominated','snow');
        s = strrep(s,'rainfall dominated','rain');

        if strcmp(s,lower(s))
            w = split(string(s));
            w(w=="") = [];
            for jj = 1:numel(w)
                ww = char(w(jj));
                if ~isempty(ww)
                    w(jj) = upper(ww(1)) + string(ww(2:end));
                end
            end
            s = char(strjoin(w,' '));
        end

        if strlength(string(s)) > 24
            s = char(extractBefore(string(s),25));
        end

        ztxt(ii) = string(s);
    end
end

function local_set_geo_label_font(ax,fs)
    try
        ax.LatitudeAxis.Label.FontSize = fs;
        ax.LongitudeAxis.Label.FontSize = fs;
    catch
    end
end

function lbl = addLabel(g,row,txt,fs)
    theme = sage_visual_theme();
    lbl = uilabel(g,'Text',txt, ...
        'horizontalalignment','left', ...
        'fontsize',fs, ...
        'FontName',theme.fonts.family.gui);
    lbl.Layout.Row = row;
    lbl.Layout.Column = 1;
end

function setValueFieldFonts(fig,fs)
    % Central place to control the font size of editable values.
    % This includes numeric fields, date/text fields, and spinners.

    try
        objs = findobj(fig, ...
            '-property','fontsize');
    catch
        return
    end

    for ii = 1:numel(objs)
        try
            cls = class(objs(ii));

            isValueField = contains(cls, ...
                'matlab.ui.control.NumericEditField') ...
                || contains(cls,'matlab.ui.control.EditField') ...
                || contains(cls,'matlab.ui.control.Spinner');

            if isValueField
                objs(ii).FontSize = fs;
            end
        catch
        end
    end
end

function s = prettyModelName(m)
    m = char(string(m));
    switch lower(m)
        case 'xinanjiang'
            s = 'Xinanjiang';
        case 'gchm'
            s = 'gchm';
        otherwise
            s = m;
    end
end

function name = local_model_name_from_mdl(mdl)
    if local_is_gchm_ode(mdl)
        name = 'gchm_ode';
    elseif mdl.model==99 && isfield(mdl,'name')
        name=char(string(mdl.name));
    else
        name = local_model_name_from_id(mdl.model);
    end
end

function name = local_model_name_from_id(id)

    switch double(id)
        case 1
            name = 'hymod';
        case 2
            name = 'hmodel';
        case 3
            name = 'sacsma';
        case 4
            name = 'Xinanjiang';
        case 5
            name = 'gr4j';
        case 6
            name = 'hbv';
        case 7
            name = 'cfe_nwm';
        case 11
            name = 'gchm';
        case 99
            name = 'user_model';
        otherwise
            name = sprintf('model %g',id);
    end
end

function s = local_param_name_latex(p,pspace)
    p = strtrim(char(p));
    pl = lower(p);
    switch pl
        case 'alpha'
            base = '\alpha';
        case 'beta'
            base = '\beta';
        case 'gamma'
            base = '\gamma';
        case 'delta'
            base = '\delta';
        case 'epsilon'
            base = '\epsilon';
        case 'lambda'
            base = '\lambda';
        case 'omega'
            base = '\omega';
        case 'theta'
            base = '\theta';
        case 'phi'
            base = '\phi';
        case 'psi'
            base = '\psi';
        case 'mu'
            base = '\mu';
        case 'sigma'
            base = '\sigma';
        otherwise
            base = '';
    end
    if ~isempty(base)
        if pspace == 1
            s = ['\underline{' base '}'];
        else
            s = base;
        end
        return
    end

    pclean = lower(strtrim(p));
    pclean = strrep(pclean,'$','');
    pclean = strrep(pclean,'\rm','');
    pclean = strrep(pclean,'\mathrm','');
    pclean = strrep(pclean,'{','');
    pclean = strrep(pclean,'}','');
    pclean = strrep(pclean,' ','');
    pclean = strrep(pclean,'\_','_');
    
    if strcmp(pclean,'sf_cf')
        if pspace == 1
            s = '\underline{sf}_{\rm cf}';
        else
            s = 'sf_{\rm cf}';
        end
        return
    end

    if strcmp(pclean,'ell_lp') ...
            || strcmp(pclean,'\ell_lp') ...
            || strcmp(pclean,'l_lp')
        if pspace == 1
            s = '\underline{\ell}_{\rm lp}';
        else
            s = '\ell_{\rm lp}';
        end
        return
    end

    tok = regexp(p,'^([A-Za-z]+)_(.+)$', ...
        'tokens','once');
    if ~isempty(tok)
        head = tok{1}; tail = tok{2};
        headLatex = ...
            local_main_symbol_latex(head);
        tailLatex = ...
            local_subscript_latex(tail);
        if pspace == 1
            s = ['\underline{' headLatex '}_' ...
                '{' tailLatex '}'];
        else
            s = [headLatex '_' ...
                '{' tailLatex '}'];
        end
        return
    end

    tok = regexp(p,'^([A-Za-z]+)(\d+)$', ...
        'tokens','once');
    if ~isempty(tok)
        head = tok{1}; tail = tok{2};
        headLatex = ...
            local_main_symbol_latex(head);
        if pspace == 1
            s = ['\underline{' headLatex '}_' ...
                '{' tail '}'];
        else, s = [headLatex '_' ...
                '{' tail '}'];
        end
        return
    end

    switch pl
        case 'stot'
            head = 's';
            sub = '\rm tot';
        case 'smax'
            head = 's';
            sub = '\rm max';
        case 'smin'
            head = 's';
            sub = '\rm min';
        case 'cmax'
            head = 'c';
            sub = '\rm max';
        case 'cmin'
            head = 'c';
            sub = '\rm min';
        case 'ks'
            head = 'k';
            sub = '\rm s';
        case 'ki'
            head = 'k';
            sub = '\rm i';
        case 'kb'
            head = 'k';
            sub = '\rm b';
        case 'kq'
            head = 'k';
            sub = '\rm q';
        case 'uzl'
            head = 'u';
            sub = '\rm zl';
        case 'bexp'
            head = 'b';
            sub = '\rm exp';
        case 'qb'
            head = 'q';
            sub = '\rm b';
        case 'qs'
            head = 'q';
            sub = '\rm s';
        case 'qt'
            head = 'q';
            sub = '\rm t';
        case 'ep'
            head = 'e';
            sub = '\rm p';
        case 'pet'
            head = 'ET';
            sub = '\rm p';
        case 'fp'
            head = 'f';
            sub = '\rm p';
        otherwise
            headLatex = local_main_symbol_latex(p);
            if pspace == 1
                s = ['\underline{' headLatex '}'];
            else
                s = headLatex;
            end
            return
    end
    headLatex = local_main_symbol_latex(head);
    if pspace == 1
        s = ['\underline{' headLatex '}_' ...
            '{' sub '}'];
    else
        s = [headLatex '_' ...
            '{' sub '}'];
    end
end

function s = local_main_symbol_latex(head)
    hl = lower(strtrim(head));
    switch hl
        case 'ell'
            s = '\ell';
        otherwise
            s = head;
    end
end

function s = local_subscript_latex(tail)
    tail = strtrim(char(tail));
    if isempty(tail)
        s = ''; return
    end
    if ~isempty(regexp(tail, ...
            '^\d+$','once'))
        s = tail;
        return
    end
    s = ['\rm ' tail];
end

function s = local_pretty_num(x)
    ax = abs(x);
    if ax >= 1000
        s = sprintf('%.0f',x);
    elseif ax >= 100
        s = sprintf('%.0f',x);
    elseif ax >= 10
        s = sprintf('%.1f',x);
        s = regexprep(s,'\.0$','');
    elseif ax >= 1
        s = sprintf('%.2f',x);
        s = regexprep(s,'0+$','');
        s = regexprep(s,'\.$','');
    elseif ax >= 1e-2
        s = sprintf('%.3f',x);
        s = regexprep(s,'0+$','');
        s = regexprep(s,'\.$','');
    else
        s = sprintf('%.1e',x);
    end
end

function lab = local_zone_legend_label(jj,zname)
    ztxt = char(local_short_zone_name(zname));
    ztxt = strrep(ztxt,' ','\ ');

    % sprintf needs a doubled backslash to produce \mathrm.
    lab = sprintf('$%d = \\mathrm{%s}$',jj,ztxt);
end

function [tf,msg] = local_check_mex_available(cfg)

    tf = false;
    msg = 'No precompiled MEX file found.'; %#ok

    try
        modelName = local_model_name_from_id(cfg.mdl.model);
        if local_is_gchm_ode(cfg.mdl)
            modelName = 'gchm_ode';
        end
        ext = mexext;
        pattern = ['*.' ext];
    
        cands = {};

        if isfield(cfg,'SAGEhydro') ...
                && ~isempty(cfg.SAGEhydro)
            cands{end+1} = fullfile(cfg.SAGEhydro, ...
                'models',modelName);
            cands{end+1} = fullfile(cfg.SAGEhydro, ...
                'models');
            if local_is_gchm_ode(cfg.mdl)
                cands{end+1} = fullfile( ...
                    cfg.SAGEhydro,'private','gchm_ode');
            end
        end

        if isdeployed
            cands{end+1} = ctfroot;
        end
    
        for ii = 1:numel(cands)
            if isfolder(cands{ii})
                d = dir(fullfile(cands{ii}, ...
                    '**',pattern));
    
                if ~isempty(d)
                    names = string({d.name});
                    id = contains(lower(names), ...
                        lower(modelName));
    
                    if any(id)
                        jj = find(id,1,'first');
                    else
                        jj = 1;
                    end
    
                    tf = true;
                    msg = sprintf(['Found %d %s ' ...
                        'file(s), e.g. %s'], ...
                        numel(d),ext, ...
                        fullfile(d(jj).folder, ...
                        d(jj).name));
                    return
                end
            end
        end
    
        % Nondeployed path fallback only
        if ~isdeployed
            mexName = [modelName '.' ext];
            p = which(mexName);
            if ~isempty(p)
                tf = true;
                 msg = ['Found model MEX on path: ' p];
                return
            end
        end
        msg = ['No .' ext ' MEX file found ' ...
            'for model ' modelName '.'];

    catch ME
        tf = false;
        msg = ['MEX check failed: ' ME.message];
    end
end

function n = countTableMatches(tbl,q)
    n = 0;
    if isempty(q)
        return,
    end
    D = tbl.Data;
    if isempty(D)
        return
    end
    for ii = 1:size(D,1)
        rowtxt = lower(sprintf('%s %s', ...
            string(D{ii,2}),string(D{ii,3})));
        if contains(rowtxt,q)
            n = n + 1;
        end
    end
end

function tf = localIsValidObject(h)
    tf = ~isempty(h) ...
        && isobject(h) ...
        && isvalid(h);
end

function names = local_display_basin_names(names)
    % Basin names are assumed to be standardized upstream by
    % standardize_camels_name_file/read_attr.  Do not apply GUI-local
    % substitutions here; the tables should show the names exactly as
    % stored in bas.gname.
    names = string(names(:));
end

function z = local_zone_table_values(bas,idx)
    idx = idx(:);
    z = strings(numel(idx),1);
    if isfield(bas,'zone') ...
            && isstruct(bas.zone) ...
            && isfield(bas.zone,'num') ...
            && numel(bas.zone.num) >= max(idx)
        zn = bas.zone.num(idx);
        for ii = 1:numel(zn)
            if isfinite(zn(ii))
                z(ii) = string(zn(ii));
            end
        end
    end
end

function txt = local_zone_legend_text(bas)
    txt = '';
    if isfield(bas,'zone') ...
            && isstruct(bas.zone) ...
            && isfield(bas.zone,'names') ...
            && ~isempty(bas.zone.names)
        nm = string(bas.zone.names(:));
        pairs = strings(numel(nm),1);
        for ii = 1:numel(nm)
            pairs(ii) = sprintf('%d = %s',ii, ...
                local_short_zone_name(nm(ii)));
        end
        txt = sprintf('Zones: %s', ...
            strjoin(cellstr(pairs.'),', '));
    end
end

function drawGeoTopRightBorder(gx)
%DRAWGEOTOPRIGHTBORDER Draw the requested foreground frame on a geoaxes.
% Region and Zones use an open frame, for which foreground left and bottom
% lines keep the axes visible above filled land polygons. Other geographic
% views retain the optional top and right frame used previously.

    try
        deleteGeoTopRightBorder(gx);
        try
            latLim = gx.LatitudeLimits;
            lonLim = gx.LongitudeLimits;
        catch
            [latLim,lonLim] = geolimits(gx);
        end
        if numel(latLim) ~= 2 ...
                || numel(lonLim) ~= 2 ...
                || any(~isfinite([latLim(:); lonLim(:)]))
            return
        end
        % Slightly inset the artificial border so geoaxes clipping
        % does not hide the top/right lines.
        dLat = diff(latLim);
        dLon = diff(lonLim);
        useOpenFrame = isappdata(gx,'SAGEHideTopRightBorder') ...
            && logical(getappdata(gx,'SAGEHideTopRightBorder'));
        if useOpenFrame
            % Geographic axes draw their native rulers below plotted map
            % polygons. Redraw only the open left/bottom frame as map
            % objects after the polygons, so neither axis is obscured.
            latBottom = latLim(1) + 0.002*dLat;
            lonLeft = lonLim(1) + 0.002*dLon;
            hold(gx,'on');
            h.left = geoplot(gx, ...
                [latLim(1) latLim(2)], ...
                [lonLeft lonLeft], ...
                'k-', ...
                'linewidth',0.5, ...
                'handlevisibility','off');
            h.bottom = geoplot(gx, ...
                [latBottom latBottom], ...
                [lonLim(1) lonLim(2)], ...
                'k-', ...
                'linewidth',0.5, ...
                'handlevisibility','off');
            try
                h.left.PickableParts = 'none';
                h.left.HitTest = 'off';
                h.bottom.PickableParts = 'none';
                h.bottom.HitTest = 'off';
            catch
            end
            setappdata(gx,'GeoTopRightBorderHandles',h);
            return
        end
        latTop = latLim(2) - 0.002*dLat;
        lonRight = lonLim(2) - 0.002*dLon;
        hold(gx,'on');
        h.top = geoplot(gx, ...
            [latTop latTop], ...
            [lonLim(1) lonLim(2)], ...
            'k-', ...
            'linewidth',1.0, ...
            'handlevisibility','off');
        h.right = geoplot(gx, ...
            [latLim(1) latLim(2)], ...
            [lonRight lonRight], ...
            'k-', ...
            'linewidth',1.0, ...
            'handlevisibility','off');
        try
            h.top.PickableParts = 'none';
            h.top.HitTest = 'off';
            h.right.PickableParts = 'none';
            h.right.HitTest = 'off';
        catch
        end
        setappdata(gx,'GeoTopRightBorderHandles',h);
    catch
    end
end

function deleteGeoTopRightBorder(gx)
    try
        if isappdata(gx,'GeoTopRightBorderHandles')
            h = getappdata(gx,'GeoTopRightBorderHandles');
            if isstruct(h)
                fns = fieldnames(h);
                for ii = 1:numel(fns)
                    try
                        if isgraphics(h.(fns{ii}))
                            delete(h.(fns{ii}));
                        end
                    catch
                    end
                end
            end
            rmappdata(gx,'GeoTopRightBorderHandles');
        end
    catch
    end
end

function znames = local_zone_names_for_numbers(bas,zn)
    zfinite = zn(isfinite(zn));
    if isempty(zfinite)
        znames = strings(0,1);
        return
    end
    nmax = max(zfinite);
    znames = strings(nmax,1);
    if isfield(bas.zone,'names') ...
            && ~isempty(bas.zone.names)
        nm = string(bas.zone.names(:));
        ncopy = min(numel(nm),nmax);
        znames(1:ncopy) = nm(1:ncopy);
    end    
    needRecover = any(strlength(strtrim(znames)) == 0) ...
        || all(~contains(znames,"_") ...
        & ~contains(lower(znames),"rain") ...
        & ~contains(lower(znames),"snow"));
    if needRecover ...
            && isfield(bas.zone,'id') ...
            && numel(bas.zone.id) >= numel(zn)
        zid = string(bas.zone.id(:));
        zid = zid(1:numel(zn));
        for jj = 1:nmax
            loc = find(zn == jj ...
                & strlength(strtrim(zid)) > 0, ...
                1,'first');
            if ~isempty(loc)
                znames(jj) = zid(loc);
            end
        end
    end    
    for jj = 1:nmax
        if strlength(strtrim(znames(jj))) == 0
            znames(jj) = sprintf('zone %d',jj);
        end
    end
end

function ztxt = local_clean_zone_name(zname)
    ztxt = lower(strrep(char(string(zname)),'_',' '));
    ztxt = regexprep(ztxt,'\s+',' ');
    ztxt = strtrim(ztxt);
end

function local_add_zone_datatips(h,bas,idx,znames,jj,usage,lat,lon,region)
    try
        h.PickableParts = 'all';
        h.HitTest = 'on';
    catch
    end
    try
        gauge = local_region_gauge_id(bas.id_gauge(idx),region);
        gnm = string(bas.gname(idx));
        r = dataTipTextRow('gauge:',gauge);
        r(2) = dataTipTextRow('Name:',gnm);
        r(3) = dataTipTextRow('Usage:',usage);
        r(4) = dataTipTextRow('Zone:', ...
            repmat(string(znames(jj)),numel(idx),1));
        r(5) = dataTipTextRow('Zone #:', ...
            repmat(jj,numel(idx),1));
        r(6) = dataTipTextRow('Latitude:',lat(idx));
        r(7) = dataTipTextRow('Longitude:',lon(idx));
        h.DataTipTemplate.DataTipRows = r;
    catch
    end
end

function C = local_zone_colors(n)
    base = [ ...
        0.0000 0.4470 0.7410; ...
        0.8500 0.3250 0.0980; ...
        0.4660 0.6740 0.1880; ...
        0.4940 0.1840 0.5560; ...
        0.9290 0.6940 0.1250; ...
        0.3010 0.7450 0.9330; ...
        0.6350 0.0780 0.1840; ...
        0.2500 0.2500 0.2500];
    if n <= size(base,1)
        C = base(1:n,:);
    else
        C = lines(n);
    end
end

function out = filterLines(lines,query,mode)
    out = lines;
    if isempty(out)
        return
    end
    q = lower(strtrim(char(query)));
    if strcmpi(mode,'Warnings / errors')
        keep = contains(lower(out),'error') ...
            | contains(lower(out),'warning');
        out = out(keep);
    end
    if ~isempty(q)
        keep = contains(lower(out),q);
        out = out(keep);
    end
end

function h = localPeriodPanelHeight(nRows,rowHValuePeriod)
    rowGap = 8;
    % Use actual number of rows.
    % Rainfall block has only 2 rows, so do not force minimum 4.
    nRows = max(1,nRows);
    h = nRows*rowHValuePeriod + ...
        (nRows-1)*rowGap + ...
        2;   % modest top/bottom breathing room
end

function vals = perfScenarioListForMode(mode)
    vals = {'all','tt'};
    switch double(mode)
        case 2
            vals = {'all','tt','te'};
        case 3
            vals = {'all','tt','et'};
        case 4
            vals = {'all','tt','te','et','ee'};
    end
end

function txt = perfScenarioLabel(tag)
    switch lower(string(tag))
        case "all"
            txt = 'All available scenarios';
        case "tt"
            txt = ['Training basins ' ...
                '| training period'];
        case "te"
            txt = ['Training basins ' ...
                '| evaluation period'];
        case "et"
            txt = ['Evaluation basins ' ...
                '| training period'];
        case "ee"
            txt = ['Evaluation basins ' ...
                '| evaluation period'];
        otherwise
            txt = char(tag);
    end
end

function C = perfScenarioColors()
    C = struct('tt',[0 0.4470 0.7410], ...
        'te',[0.9290 0.6940 0.1250], ...
        'et',[0.4660 0.6740 0.1880], ...
        'ee',[0.4940 0.1840 0.5560]);
end

function [vals,scens] = ...
    perfExtractSeries(prf,metric,scenSel)
    vals = {}; scens = {};
    if isfield(prf,'iter') ...
            && isstruct(prf.iter)
        prf = prf.iter;
    end
    if isfield(prf,metric) ...
            && isstruct(prf.(metric))
        src = prf.(metric);
        if strcmpi(scenSel,'all')
            order = {'tt','te','et','ee'};
        else
            order = {char(scenSel)};
        end
        for jj = 1:numel(order)
            sc = order{jj};
            if isfield(src,sc)
                v = src.(sc);
                if ~isempty(v)
                    vals{end+1} = double(v(:)');    %#ok<AGROW>
                    scens{end+1} = sc;              %#ok<AGROW>
                end
            end
        end
    elseif isfield(prf,metric)
        v = prf.(metric);
        if ~isempty(v) ...
                && isnumeric(v)
            vals = {double(v(:)')};
            scens = {'tt'};
        end
    end
end

function perfDeleteFrame(ax)
    try
        if isappdata(ax,'PerfFrameHandles')
            hh = getappdata(ax,'PerfFrameHandles');
            if isstruct(hh)
                fns = fieldnames(hh);
                for kk = 1:numel(fns)
                    try
                        if isgraphics(hh.(fns{kk}))
                            delete(hh.(fns{kk}));
                        end
                    catch
                    end
                end
            end
            rmappdata(ax,'PerfFrameHandles');
        end
    catch
    end
end

function perfDrawTopRightFrame(ax)
    try
        perfDeleteFrame(ax);
        xl = xlim(ax);
        yl = ylim(ax);
        if any(~isfinite([xl yl]))
            return
        end
        hold(ax,'on');
        h.top = line(ax,[xl(1) xl(2)], ...
            [yl(2) yl(2)], ...
            'color',ax.XColor, ...
            'linewidth',ax.LineWidth, ...
            'Clipping','off', ...
            'handlevisibility','off');
        h.right = line(ax,[xl(2) xl(2)], ...
            [yl(1) yl(2)], ...
            'color',ax.YColor, ...
            'linewidth',ax.LineWidth, ...
            'Clipping','off', ...
            'handlevisibility','off');
        setappdata(ax,'PerfFrameHandles',h);
    catch
    end
end

function perfApplyIntegerXTicks(ax,xmax)
    try
        xmax = max(2,round(double(xmax)));
        if xmax <= 10
            xt = 1:xmax;
        else
            % Iteration 1 is a special first label. Subsequent labels must
            % remain on clean multiples of a readable 1-2-5 interval; do
            % not offset the whole sequence from 1 (1,50,99,148,...).
            rawStep = xmax/7;
            p10 = 10^floor(log10(rawStep));
            mantissa = rawStep/p10;
            if mantissa <= 1
                nice = 1;
            elseif mantissa <= 2
                nice = 2;
            elseif mantissa <= 5
                nice = 5;
            else
                nice = 10;
            end
            step = max(1,nice*p10);
            xt = unique([1 step:step:xmax]);
        end
        xticks(ax,xt);
        ax.XTickLabel = compose('%d',xt);
        ax.XTickLabelMode = 'manual';
        ax.XTickLabelRotation = 0;
        ax.XAxis.Exponent = 0;
    catch
    end
end

function tf = perfMetricSupportsLog(metric)
    tf = ismember(char(metric), ...
        {'SAR','GLS','RSS','Huber', ...
        'Sib_NSE','Sib_KGE','Sib_S_fdc','Sib_S_p','Sib_S_logp'});
end

function txt = perfScenarioLegendLatex(sc)
    switch char(sc)
        case 'tt'
            txt = ['\;training\,basin\,' ...
                '|\,training\,period'];
        case 'te'
            txt = ['\;training\,basin\,' ...
                '|\,evaluation\,period'];
        case 'et'
            txt = ['\;evaluation\,basin\,' ...
                '|\,training\,period'];
        case 'ee'
            txt = ['\;evaluation\,basin\,' ...
                '|\,evaluation\,period'];
        otherwise
            txt = ['\mathrm{' strrep(char(sc), ...
                '_','\_') '}'];
    end
end

function [pow10,scaleVal] = perfNiceScale(y,metric)
    if nargin < 2
        metric = '';
    end
    y = y(isfinite(y));
    if isempty(y)
        pow10 = 0;
        scaleVal = 1;
        return
    end
    % Dimensionless skill, ratio, and correlation summaries are normally
    % easiest to read on their native scale. The JKGE benchmark penalty M
    % is intentionally omitted from this list: it can be many orders of
    % magnitude larger than one and therefore uses the standard axis
    % multiplier below for both its mean and median histories.
    if ismember(char(metric), ...
            {'NSE','KGE','S_fdc','S_p','S_logp','JKGE', ...
            'KGE_r','KGE_alpha', ...
            'KGE_beta','JKGE_V','JKGE_C', ...
            'mNSE','mKGE','mS_fdc','mS_p','mS_logp','mJKGE','mKGE_r', ...
            'mKGE_alpha','mKGE_beta','mJKGE_V','mJKGE_C'})
        pow10 = 0;
        scaleVal = 1;
        return
    end
    m = max(abs(y));
    if ~isfinite(m) ...
            || m <= 0
        pow10 = 0;
        scaleVal = 1;
        return
    end
    if ismember(char(metric), ...
            {'Sib_NSE','Sib_KGE','Sib_S_fdc','Sib_S_p','Sib_S_logp'}) ...
            && m < 1e4
        pow10 = 0;
        scaleVal = 1;
        return
    end
    pow10 = floor(log10(m));
    scaleVal = 10^pow10;
    if abs(scaleVal) < eps
        pow10 = 0;
        scaleVal = 1;
    end
end

function txt = perfMetricLatex(metric,applyScale,pow10)
    if nargin < 2
        applyScale = false; 
    end
    if nargin < 3
        pow10 = 0; 
    end
    switch char(metric)
        case 'L'
            base = '$\mathcal{L}_{\rm SAGE}$';
        case 'SAR'
            base = '$\mathcal{L}_{\rm SAR}$';
        case 'GLS'
            base = '$\mathcal{L}_{\rm GLS}$';
        case 'RSS'
            base = '$\mathcal{L}_{\rm RSS}$';
        case 'Huber'
            base = '$\mathcal{L}_{\rm Huber}$';
        case 'JKGE'
            base = '$\mathrm{mean\ JKGE}$';
        case 'NSE'
            base = '$\mathrm{mean\ NSE}$';
        case 'KGE'
            base = '$\mathrm{mean\ KGE}$';
        case 'mNSE'
            base = '$\widehat{T}_{\rm nse}$';
        case 'mKGE'
            base = '$\widehat{T}_{\rm kge}$';
        case 'mJKGE'
            base = '$\widehat{T}_{\rm jkge}$';
        case 'KGE_r'
            base = '$\mathrm{mean}(r)$';
        case 'mKGE_r'
            base = '$\mathrm{median}(r)$';
        case 'KGE_alpha'
            base = '$\mathrm{mean}(\alpha)$';
        case 'mKGE_alpha'
            base = '$\mathrm{median}(\alpha)$';
        case 'KGE_beta'
            base = '$\mathrm{mean}(\beta)$';
        case 'mKGE_beta'
            base = '$\mathrm{median}(\beta)$';
        case 'JKGE_M'
            base = '$\mathrm{mean}(M)$';
        case 'mJKGE_M'
            base = '$\mathrm{median}(M)$';
        case 'JKGE_V'
            base = '$\mathrm{mean}(V)$';
        case 'mJKGE_V'
            base = '$\mathrm{median}(V)$';
        case 'JKGE_C'
            base = '$\mathrm{mean}(C)$';
        case 'mJKGE_C'
            base = '$\mathrm{median}(C)$';
        case 'S_fdc'
            base = '$\mathrm{mean}(S_\mathrm{fdc})$';
        case 'S_p'
            base = '$\mathrm{mean}(S_p)$';
        case 'S_logp'
            base = '$\mathrm{mean}(S_{\log p})$';
        case 'mS_fdc'
            base = '$\widehat{T}_{S_{\rm fdc}}$';
        case 'mS_p'
            base = '$\widehat{T}_{S_p}$';
        case 'mS_logp'
            base = '$\widehat{T}_{S_{\log p}}$';
        case 'Sib_NSE'
            base = '$\widehat{\mathcal{S}}_{\mathrm{ib,nse}}$';
        case 'Sib_KGE'
            base = '$\widehat{\mathcal{S}}_{\mathrm{ib,kge}}$';
        case 'Sib_S_fdc'
            base = '$\widehat{\mathcal{S}}_{\mathrm{ib},S_{\rm fdc}}$';
        case 'Sib_S_p'
            base = '$\widehat{\mathcal{S}}_{\mathrm{ib},S_p}$';
        case 'Sib_S_logp'
            base = '$\widehat{\mathcal{S}}_{\mathrm{ib},S_{\log p}}$';
        otherwise
            base = ['$' strrep(char(metric),'_','\_') '$'];
    end
    if applyScale ...
            && pow10 ~= 0
        txt = sprintf('%s $\\times 10^{%d}$', ...
            base,pow10);
    else
        txt = base;
    end
end

function txt = perfMetricDisplayName(metric)
    switch char(metric)
        case 'L'
            txt = 'Loss function: selected';
        case 'SAR'
            txt = 'Sum of Absolute Residuals';
        case 'GLS'
            txt = 'Generalized Least Squares';
        case 'RSS'
            txt = 'Residual Sum of Squares';
        case 'Huber'
            txt = 'Huber loss score';
        case 'NSE'
            txt = 'Nash-Sutcliffe efficiency';
        case 'KGE'
            txt = 'Kling-Gupta efficiency';
        case 'JKGE'
            txt = 'Jawad Kling Gupta efficiency';
        case 'mNSE'
            txt = 'Median NSE';
        case 'mKGE'
            txt = 'Median KGE';
        case 'mJKGE'
            txt = 'Median JKGE';
        case 'KGE_r'
            txt = 'Mean KGE correlation';
        case 'mKGE_r'
            txt = 'Median KGE correlation';
        case 'KGE_alpha'
            txt = 'Mean KGE variability ratio';
        case 'mKGE_alpha'
            txt = 'Median KGE variability ratio';
        case 'KGE_beta'
            txt = 'Mean KGE mean ratio';
        case 'mKGE_beta'
            txt = 'Median KGE mean ratio';
        case 'JKGE_M'
            txt = 'Mean JKGE benchmark penalty';
        case 'mJKGE_M'
            txt = 'Median JKGE benchmark penalty';
        case 'JKGE_V'
            txt = 'Mean JKGE variability penalty';
        case 'mJKGE_V'
            txt = 'Median JKGE variability penalty';
        case 'JKGE_C'
            txt = 'Mean JKGE correlation penalty';
        case 'mJKGE_C'
            txt = 'Median JKGE correlation penalty';
        case 'S_fdc'
            txt = 'Mean physical-discharge FDC skill score';
        case 'S_p'
            txt = 'Mean probability-space FDC skill score';
        case 'S_logp'
            txt = 'Mean log-quantile FDC skill score';
        case 'mS_fdc'
            txt = 'Median physical-discharge FDC skill score';
        case 'mS_p'
            txt = 'Median probability-space FDC skill score';
        case 'mS_logp'
            txt = 'Median log-quantile FDC skill score';
        case 'Sib_NSE'
            txt = 'Integrated basin loss: NSE';
        case 'Sib_KGE'
            txt = 'Integrated basin loss: KGE';
        case 'Sib_S_fdc'
            txt = 'Integrated basin loss: physical-discharge FDC skill';
        case 'Sib_S_p'
            txt = 'Integrated basin loss: probability-space FDC skill';
        case 'Sib_S_logp'
            txt = 'Integrated basin loss: log-quantile FDC skill';
        otherwise
            txt = char(metric);
    end
end

function txt = perfMetricTitleLatex(metric)
    switch char(metric)
        case 'L'
            txt = '\mathcal{L}_{\rm SAGE}';
        case 'SAR'
            txt = '\mathcal{L}_{\rm SAR}';
        case 'GLS'
            txt = '\mathcal{L}_{\rm GLS}';
        case 'RSS'
            txt = '\mathcal{L}_{\rm RSS}';
        case 'Huber'
            txt = '\mathcal{L}_{\rm Huber}';
        case 'JKGE'
            txt = '\mathrm{mean\ JKGE}';
        case 'NSE'
            txt = '\mathrm{mean\ NSE}';
        case 'KGE'
            txt = '\mathrm{mean\ KGE}';
        case 'mNSE'
            txt = '\widehat{T}_{\rm nse}';
        case 'mKGE'
            txt = '\widehat{T}_{\rm kge}';
        case 'mJKGE'
            txt = '\widehat{T}_{\rm jkge}';
        case 'KGE_r'
            txt = '\mathrm{mean}(r)';
        case 'mKGE_r'
            txt = '\mathrm{median}(r)';
        case 'KGE_alpha'
            txt = '\mathrm{mean}(\alpha)';
        case 'mKGE_alpha'
            txt = '\mathrm{median}(\alpha)';
        case 'KGE_beta'
            txt = '\mathrm{mean}(\beta)';
        case 'mKGE_beta'
            txt = '\mathrm{median}(\beta)';
        case 'JKGE_M'
            txt = '\mathrm{mean}(M)';
        case 'mJKGE_M'
            txt = '\mathrm{median}(M)';
        case 'JKGE_V'
            txt = '\mathrm{mean}(V)';
        case 'mJKGE_V'
            txt = '\mathrm{median}(V)';
        case 'JKGE_C'
            txt = '\mathrm{mean}(C)';
        case 'mJKGE_C'
            txt = '\mathrm{median}(C)';
        case 'S_fdc'
            txt = '\mathrm{mean}(S_\mathrm{fdc})';
        case 'S_p'
            txt = '\mathrm{mean}(S_p)';
        case 'S_logp'
            txt = '\mathrm{mean}(S_{\log p})';
        case 'mS_fdc'
            txt = '\widehat{T}_{S_{\rm fdc}}';
        case 'mS_p'
            txt = '\widehat{T}_{S_p}';
        case 'mS_logp'
            txt = '\widehat{T}_{S_{\log p}}';
        case 'Sib_NSE'
            txt = '\widehat{\mathcal{S}}_{\mathrm{ib,nse}}';
        case 'Sib_KGE'
            txt = '\widehat{\mathcal{S}}_{\mathrm{ib,kge}}';
        case 'Sib_S_fdc'
            txt = '\widehat{\mathcal{S}}_{\mathrm{ib},S_\mathrm{fdc}}';
        case 'Sib_S_p'
            txt = '\widehat{\mathcal{S}}_{\mathrm{ib},S_p}';
        case 'Sib_S_logp'
            txt = '\widehat{\mathcal{S}}_{\mathrm{ib},S_{\log p}}';
        otherwise
            txt = strrep(char(metric),'_','\_');
    end
end

function txt = perfModelLatexTitle(cfg)
    txt = 'MODEL';
    try
        if ~isempty(cfg) ...
                && isfield(cfg,'mdl') ...
                && isfield(cfg.mdl,'names') ...
                && isfield(cfg.mdl,'model')
            raw = local_model_name_from_mdl(cfg.mdl);
            if strcmpi(raw,'xinanjiang')
                raw = 'Xinanjiang';
            end
            txt = strrep(raw,'_','\_');
        end
    catch
    end
end

function txt = localLossHelpLatex(lossID,fdcFormulation)
%LOCALLOSSHELPLATEX LaTeX help text for loss-function panel in GUI

    if nargin < 2 ...
            || isempty(fdcFormulation)
        fdcFormulation = 1;
    end

    switch lossID    
        case 1
            txt = { ...
                '\textbf{Sum of absolute residuals}', ...
                ['Model performance can also be quantified ' ...
                'using the sum of absolute residuals (SAR), ' ...
                'which measures the cumulative absolute ' ...
                'mismatch between measured and simulated ' ...
                'discharge. The CAMELS-wide loss is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}' ...
                '\mathcal{L}_{\rm SAR}^{k}$,'], ...
                ['where, for basin $k$ with observed and ' ...
                'simulated discharge $\mathbf{y}^{k} = ' ...
                '\bigl(y^{k}_{1},\ldots,y^{k}_{n}\bigr)' ...
                '^{\top}$ and $\mathbf{q}^{k} = ' ...
                '\bigl(q^{k}_{1},\ldots,q^{k}_{n}\bigr)' ...
                '^{\top}$, the SAR objective is defined as'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAR}^{k} = ' ...
                '\sum_{t=1}^{n}\left|y^{k}_{t} - ' ...
                'q^{k}_{t}\right|$,'], ...
                ['with residuals $e^{k}_{t} = y^{k}_{t} - ' ...
                'q^{k}_{t}$ at time step $t$.'], ...
                ['The SAR objective corresponds to the ' ...
                '$\ell_{1}$ norm of the residual vector ' ...
                'and assigns linear weight to ' ...
                ['deviations between measured and ' ...
                'simulated discharge. '], ...
                'As a result, SAR is more robust to ' ...
                'outliers than quadratic objectives ' ...
                'such as GLS, as large residuals do ' ...
                'not receive disproportionate influence.'], ...
                '', ...
                ['The absolute-value operator is not ' ...
                'differentiable at zero residual, which ' ...
                'can slow convergence in gradient-based ' ...
                'optimization and requires subgradient ' ...
                'or smoothing strategies.'], ...
                '', ...
                '\textbf{References}', ...
                ['Schoups, G. and Vrugt, ' ...
                'J.A. (2010), A formal likelihood function ' ...
                'for parameter and predictive inference of ' ...
                'hydrologic models with correlated, ' ...
                'heteroscedastic, and non-Gaussian errors, ' ...
                '\textit{Water Resources Research}, 46, ' ...
                'W10531, doi: 10.1029/2009WR008933.'], ...
                ['Vrugt, J.A., de Oliveira, ' ...
                'D.Y., Schoups, G., and Diks, C.G.H. (2022), ' ...
                'On the use of distribution-adaptive ' ...
                'likelihood functions: Generalized and ' ...
                'universal likelihood functions, scoring ' ...
                'rules and multi-criteria ranking, ' ...
                '\textit{Journal of Hydrology}, 615, ' ...
                '128542, doi: 10.1016/j.jhydrol.2022.128542.']};    
        case 2
            txt = { ...
                '\textbf{Generalized least squares}', ...
                ['We consider a generalized least-squares ' ...
                '(GLS) or $\ell_{2}$ objective, which ' ...
                'accounts for the covariance structure ' ...
                'of discharge measurement errors. ' ...
                'The CAMELS-wide loss is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}' ...
                '\mathcal{L}_{\rm GLS}^{k}$,'], ...
                ['where, for basin $k$ with observed and ' ...
                'simulated discharge $\mathbf{y}^{k}$ and ' ...
                '$\mathbf{q}^{k}$, the GLS loss is '], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm GLS}^{k} = ' ...
                '½\,\mathbf{e}^{k\top}\,\Sigma_' ...
                '{\epsilon}^{-1}\,\mathbf{e}^{k}$,'], ...
                ['with residual vector $\mathbf{e}^{k} = ' ...
                '\mathbf{y}^{k} - \mathbf{q}^{k}$, and ' ...
                '$n \times n$ covariance matrix ' ...
                '$\Sigma_{\epsilon} \in \mathbb{R}' ...
                '^{n \times n}$ of the discharge measurement ' ...
                'errors.'], ...
                '', ...
                ['Equivalently, GLS can be ' ...
                'written in terms of whitened residuals ' ...
                '$\mathbf{e}^{k\ast} = \mathbf{W}_{n}' ...
                '\mathbf{e}^{k}$'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm GLS}^{k} = ' ...
                '½\,\mathbf{e}^{k\ast\top}\mathbf{e}' ...
                '^{k\ast}$.'], ...
                ['where $\mathbf{W}_{n} = \Sigma_{\epsilon}' ...
                '^{-1/2}$. The GLS formulation therefore ' ...
                'measures the squared norm of the residuals ' ...
                'after decorrelation and variance ' ...
                'normalization.'], ...
                '', ...
                ['For $\Sigma_{\epsilon} = \mathbf{I}_{n}$, ' ...
                ['GLS reduces to ordinary least squares ' ...
                '(OLS). '], ...
                ['For diagonal $\Sigma_{\epsilon}$, GLS ' ...
                'reduces to weighted least squares (WLS) ' ...
                'with heteroscedastic errors. '], ...
                ['For full (non-diagonal) $\Sigma_' ...
                '{\epsilon}$, GLS accounts for correlated ' ...
                'residuals and measurement errors. '], ...
                'The quadratic form is smooth and fully ' ...
                'differentiable, which makes GLS particularly ' ...
                'suitable for gradient-based optimization.'], ...
                '', ...
                ['The current GUI implementation does not ' ...
                'yet support GLS or WLS with user-specified ' ...
                'error covariance structures. A future ' ...
                'version may allow specification of ' ...
                '$\Sigma_{\epsilon}$, but this is nontrivial ' ...
                'for long hourly records because the ' ...
                'covariance matrix becomes very large and ' ...
                'may need to be represented in sparse, ' ...
                'banded, or parametric form.'], ...
                '', ...
                '\textbf{References}', ...
                ['Aitken, A.C. (1936), On ' ...
                'least squares and linear combination of ' ...
                'observations, \textit{Proceedings of the ' ...
                'Royal Society of Edinburgh}, 55, 42--48, ' ...
                'doi:10.1017/S0370164600014346.'], ...
                ['Vrugt, J.A. and de Oliveira, ' ...
                'D.Y. (2022), Confidence intervals of the ' ...
                'Kling--Gupta efficiency, \textit{Journal ' ...
                'of Hydrology}, 612, 127968, ' ...
                'doi:10.1016/j.jhydrol.2022.127968.']};
        case 3
            txt = { ...
                '\textbf{Nash--Sutcliffe efficiency}', ...
                ['Model skill can also be evaluated using ' ...
                'the Nash--Sutcliffe efficiency (NSE), which ' ...
                'measures predictive performance relative to ' ...
                'the variance of the observed discharge ' ...
                'record. The CAMELS-wide loss is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}' ...
                '\left(1 - \mathrm{NSE}^{k}\right)$,'], ...
                ['where, for basin $k$ with observed and ' ...
                'simulated discharge $\mathbf{y}^{k} = ' ...
                '\bigl(y^{k}_{1},\ldots,y^{k}_{n}\bigr)' ...
                '^{\top}$ and $\mathbf{q}^{k} = ' ...
                '\bigl(q^{k}_{1},\ldots,q^{k}_{n}\bigr)' ...
                '^{\top}$,'], ...
                ['\hspace{1cm}$\mathrm{NSE}^{k} = 1 - ' ...
                '\frac{\sum_{t=1}^{n}\left(y^{k}_{t} - ' ...
                'q^{k}_{t}\right)^2}{\sum_{t=1}^{n}' ...
                '\left(y^{k}_{t} - m^{k}_{y}\right)^2}$,'], ...
                'with', ...
                '\hspace{1cm}$m^{k}_{y} = n^{-1}\sum_{t=1}^{n} y^{k}_{t}$,' ...
                ['the sample mean of the measured ' ...
                'discharge record. '], ...
                '', ...
                ['The denominator represents the variance ' ...
                ['of the measured discharge series, whereas ' ...
                'the numerator represents the residual ' ...
                'variance of the model. '], ...
                ['NSE therefore evaluates the extent to ' ...
                'which the model reproduces the temporal ' ...
                'variability of the observed discharge. '], ...
                'An NSE value of one corresponds to a ' ...
                'perfect simulation, whereas values below ' ...
                'zero indicate that the observed mean ' ...
                'provides a better predictor than the model.'], ...
                '', ...
                '\textbf{References}', ...
                ['Nash, J.E. and Sutcliffe, ' ...
                'J.V. (1970), River flow forecasting ' ...
                'through conceptual models part I—A ' ...
                'discussion of principles, ' ...
                '\textit{Journal of Hydrology}, 10(3), ' ...
                '282--290, doi:10.1016/0022-1694(70)90255-6.']};
        case 4
            txt = { ...
                '\textbf{Kling--Gupta efficiency}', ...
                ['The Kling--Gupta efficiency (KGE) ' ...
                'evaluates hydrologic model performance by ' ...
                'combining bias, variability, and correlation ' ...
                'into a single metric. ' ...
                'The CAMELS-wide loss is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}' ...
                '\left(1 - \mathrm{KGE}^{k}\right)$,'], ...
                ['where, for basin $k$ with observed and ' ...
                'simulated discharge $\mathbf{y}^{k} = ' ...
                '\bigl(y^{k}_{1},\ldots,y^{k}_{n}\bigr)' ...
                '^{\top}$ and $\mathbf{q}^{k} = ' ...
                '\bigl(q^{k}_{1},\ldots,q^{k}_{n}\bigr)' ...
                '^{\top}$,'], ...
                ['\hspace{1cm}$\mathrm{KGE}^{k} = ' ...
                '1 - \sqrt{M^{k} + V^{k} + C^{k}}$,'], ...
                'with', ...
                ['\hspace{1cm}$M^{k} = \left(1 - m^{k}_{q} ' ...
                '\,/\, m^{k}_{y}\right)^{2}$,'], ...
                ['which measures agreement between mean ' ...
                'discharge values $m^{k}_{y} = n^{-1}' ...
                '\sum_{t=1}^{n} y^{k}_{t}$ and $m^{k}_{q} = ' ...
                'n^{-1}\sum_{t=1}^{n} q^{k}_{t}$,'], ...
                ['\hspace{1cm}$V^{k} = \left(1 - s^{k}_{q} ' ...
                '\,/\, s^{k}_{y}\right)^{2}$,'], ...
                ['which quantifies differences in variability ' ...
                'of measured and simulated anomaly series ' ...
                '$\mathbf{a}^{k}_{y} = \mathbf{y}^{k} - ' ...
                'm^{k}_{y}$ and $\mathbf{a}^{k}_{q} = ' ...
                '\mathbf{q}^{k} - m^{k}_{q}$, with'], ...
                ['\hspace{1cm}$s^{k}_{q} = \sqrt{n^{-1}' ...
                '\sum_{t=1}^{n} \left(a^{k}_{q,t}\right)^2}, ' ...
                '\qquad s^{k}_{y} = \sqrt{n^{-1}' ...
                '\sum_{t=1}^{n} \left(a^{k}_{y,t}' ...
                '\right)^2}$,'], ...
                'and', ...
                '\hspace{1cm}$C^{k} = (1 - r^{k})^2$,', ...
                ['which quantifies the linear association ' ...
                'between measured and simulated anomaly ' ...
                'series using Pearson''s linear ' ...
                'correlation coefficient,'], ...
                ['\hspace{1cm}$r^{k} = \frac{1}{n}\sum' ...
                '\limits_{t=1}^{n} \biggl(\frac{ ' ...
                'a^{k}_{q,t} }{s^{k}_{q}} \frac{ ' ...
                'a^{k}_{y,t}}{s^{k}_{y}}\biggr)$.'], ...
                '', ...
                ['KGE provides a balanced assessment ' ...
                'of bias, variability, and temporal dynamics ' ...
                'using a time-invariant long-term mean ' ...
                'benchmark.'], ...
                '', ...
                '\textbf{References}', ...
                ['Gupta, H.V., Kling, H., ' ...
                'Yilmaz, K.K., and Martinez, G.F. (2009), ' ...
                'Decomposition of the mean squared error ' ...
                'and NSE performance criteria: Implications ' ...
                'for improving hydrological modelling, ' ...
                '\textit{Journal of Hydrology}, 377(1--2), ' ...
                '80--91, doi: 10.1016/j.jhydrol.2009.08.003.']};
        case 5
            txt = { ...
                '\textbf{Huber robust estimator}', ...
                ['To balance sensitivity to small residuals ' ...
                'with robustness to extreme deviations, we ' ...
                'employ the Huber loss, a classical ' ...
                'M-estimator that replaces the purely ' ...
                'quadratic penalty of generalized least ' ...
                'squares with a piecewise quadratic--linear ' ...
                'formulation. The CAMELS-wide loss is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}' ...
                '\sum_{t=1}^{n}\mathcal{L}_{c}\!' ...
                '(\underline{e}^{k}_{t})$,'], ...
                'where the Huber loss function is defined as', ...
                ['\hspace{1cm}$\mathcal{L}_{c}' ...
                '(\underline{e}) = \begin{cases}' ...
                '½\underline{e}^{2} & ' ...
                '|\underline{e}| \le c \\ ' ...
                'c\,|\underline{e}| - ½c^{2} & ' ...
                '|\underline{e}| > c,' ...
                '\end{cases}$'], ...
                'with standardized residuals ', ...
                ['\hspace{1cm}$\underline{e}^{k}_{t} = ' ...
                '\frac{y^{k}_{t} - q^{k}_{t} }{S^{k}_{y}}$,'], ...
                ['where $S^{k}_{y}$ is a scale parameter of ' ...
                'the measured discharge series and ' ...
                'coefficient $c = 1.345$.'], ...
                '', ...
                ['The Huber loss behaves quadratically ' ...
                'for small residuals and linearly for ' ...
                'large residuals, ' ...
                'thereby limiting the influence of ' ...
                'outliers while retaining efficiency ' ...
                'for near-Gaussian errors. ' ...
                'It therefore provides a smooth transition ' ...
                'between generalized least squares for ' ...
                '$c \rightarrow \infty$ ' ...
                'and an absolute-residual (SAR) objective ' ...
                'for $c \rightarrow 0$, illustrating ' ...
                'its interpolation ' ...
                'between mean- and median-based estimation.'], ...
                '', ...
                ['A robust choice for the scale $S_{y}$ ' ...
                'is the median absolute deviation (MAD)'], ...
                ['\hspace{1cm}$\mathrm{MAD}(\mathbf{y}_{n}) ' ...
                '= \mathrm{median}_{t=1,\ldots,n}\bigl(|' ...
                'y_{t} - \widehat{T}_{\!\!\!y}\,|\bigr)$,'], ...
                ['where $\widehat{T}_{\!\!\!y}$ denotes ' ...
                'the sample median of the measured record. ', ...
                'Unlike the standard deviation, the MAD ' ...
                'is insensitive to extreme values and ' ...
                'provides a stable measure ' ...
                'of spread for skewed or heavy-tailed ' ...
                'discharge data. To obtain a scale ' ...
                'estimator that is consistent under ' ...
                'Gaussian errors, the MAD is multiplied ' ...
                'by the normal-consistency constant ' ...
                '$\kappa \approx 1.4826$, ' ...
                'so that $S_{y} = \kappa\,\mathrm{MAD}' ...
                '(\mathbf{y}_{n})$ equals the standard ' ...
                'deviation when the data ' ...
                'are normally distributed. The derivative ' ...
                'of the Huber loss is bounded, so that ' ...
                'large residuals do ' ...
                'not dominate the estimation, making ' ...
                'the estimator well suited for hydrologic ' ...
                'data with outliers ' ...
                'or non-Gaussian residuals (Vrugt et al., ' ...
                '2025, 2026).'] ...
                '', ...
                '\textbf{References}', ...
                ['Vrugt, J.A., Diks, C.G.H., ' ...
                'de Punder, R., and Gr\"{u}nwald, P. (2025), ' ...
                'A Sandwich with Water: Bayesian \& ' ...
                'Frequentist inference under model ' ...
                'misspecification, \textit{ARC Geophysical ' ...
                'Research}, 1, Article 16, ' ...
                'doi:10.5149/ARC-GR.1824.'], ...
                ['Vrugt, J.A., Frame, ' ...
                'J.M., and Bollman, E. (2026), Reclaiming ' ...
                'first principles: An analytic differentiable ' ...
                'framework for conceptual hydrologic models, ' ...
                '\textit{arXiv preprint}, arXiv:2602.06429, ' ...
                'doi:10.48550/arXiv.2602.06429.'], ...
                };    
        case 6
            if fdcFormulation ~= 1
                txt = local_fdc_loss_help_latex(fdcFormulation);
                return
            end
            txt = { ...
                '\textbf{6a: Physical-discharge FDC divergence}', ...
                ['Model performance can also be evaluated ' ...
                'using a flow-duration-curve (FDC) loss, ' ...
                'which compares the full ' ...
                'distribution of simulated and measured ' ...
                'discharge through their exceedance ' ...
                'probabilities. The flow-duration ' ...
                'curve corresponds to the survival function'] ...
                ['\hspace{1cm}$R_Y(y) = \mathbb{P}(Y > y) ' ...
                '= 1 - F_Y(y)$,'], ...
                ['where $F_Y(y)$ is the cumulative ' ...
                'distribution function of streamflow. ' ...
                'The CAMELS flow duration curve ' ...
                'divergence loss is then given by'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}} ' ...
                'd^{k}_{\rm fdc}(Q,F)$,'], ...
                ['where $Q$ and $F$ denote the distributions ' ...
                'of simulated and measured discharge, ' ...
                'respectively, for basin $k$. ' ...
                'The FDC divergence is defined as'] ...
                ['\hspace{1cm}$d^{k}_{\rm fdc}(Q,F) = ' ...
                '\int_{0}^{\infty}\bigl(R_{F}(z) - ' ...
                'R_{Q}(z)\bigr)^{2}\,\mathrm{d}z$,'], ...
                ['which measures the squared difference ' ...
                'between the exceedance probabilities of ' ...
                'measured and simulated discharge. ' ...
                'This divergence is nonnegative and ' ...
                'equals zero only when the simulated ' ...
                'and observed flow-duration curves coincide.'], ...
                '', ...
                ['For finite time series $\mathbf{y}^{k} = ' ...
                '(y^{k}_{1},\ldots,y^{k}_{n})^{\top}$ and ' ...
                '$\mathbf{q}^{k} = (q^{k}_{1},\ldots,' ...
                'q^{k}_{n})^{\top}$, the FDC loss can be ' ...
                'approximated using the Monte Carlo ' ...
                'estimator'], ...
                ['\hspace{1cm}$d^{k}_{\rm fdc}(Q,F) = ' ...
                '\frac{1}{n^{2}}\sum\limits_{i=1}^{n}\sum' ...
                '\limits_{j=1}^{n}|q^{k}_{i} - y^{k}_{j}| - ' ...
                '\frac{1}{2}\frac{1}{n^{2}}\sum' ...
                '\limits_{i=1}^{n}\sum\limits_{j=1}^{n}' ...
                '\bigl(\left|q^{k}_{i} - q^{k}_{j}\right| + ' ...
                '\left|y^{k}_{i} - y^{k}_{j}\right|\bigr)$,'], ...
                ['which corresponds to an energy-distance ' ...
                'formulation combining between-distribution ' ...
                'and within-distribution variability.'], ...
                '', ...
                ['The FDC loss captures the full ' ...
                'distributional behavior of streamflow, ' ...
                'including low, medium, and high flows, ' ...
                'and is expressed in physical discharge ' ...
                'units. Unlike NSE or KGE, this objective ' ...
                'does not depend on temporal ' ...
                'ordering and instead evaluates agreement ' ...
                'in flow magnitude distributions. The ' ...
                'FDC loss is a strictly proper ' ...
                'scoring rule, ensuring that the true ' ...
                'distribution is uniquely optimal when ' ...
                'the model is correctly specified ' ...
                '(Vrugt, 2024).'] ...
                '', ...
                ['SAGE also computes a revised, dimensionless ' ...
                'form of loss function 6 for every basin and ' ...
                'period, even when the FDC loss is not selected ' ...
                'for training. First, a basin- and period-specific ' ...
                'zero-skill reference, $d^{k}_{0}$, is obtained by ' ...
                'assigning to every element of the simulated ' ...
                'discharge time series, $\mathbf{q}^{k}_{n} = ' ...
                '(q^{k}_{1},\ldots,q^{k}_{n})^{\top}$, the median ' ...
                'observed discharge, $T^{k}_{\!\!y} = {\rm median}' ...
                '(y^{k}_{1},\ldots,y^{k}_{n})$, to yield'], ...
                ['\hspace{1cm}$d^{k}_{0} = ' ...
                '\frac{1}{n^{2}}\sum\limits_{i=1}^{n}\sum' ...
                '\limits_{j=1}^{n}|T^{k}_{\!\!y} - y^{k}_{j}| - ' ...
                '\frac{1}{2}\frac{1}{n^{2}}\sum' ...
                '\limits_{i=1}^{n}\sum\limits_{j=1}^{n}' ...
                '\left|y^{k}_{i} - y^{k}_{j}\right|$,'], ...
                ['The reference $d^{k}_{0}$ is estimated ' ...
                'separately for each basin and separately for its ' ...
                'training and evaluation periods. The normalized ' ...
                'FDC skill score is then'], ...
                ['\hspace{1cm}$S^{k}_{\rm fdc} = 1 - ' ...
                '\frac{d^{k}_{\rm fdc}(Q,F)}{d^{k}_{0}}$,'], ...
                ['so that $S^{k}_{\rm fdc} = 1$ for coincident FDCs, ' ...
                '$S^{k}_{\rm fdc}=0$ for the constant-median ' ...
                'reference, and $S^{k}_{\rm fdc}<0$ for poorer ' ...
                'simulations. This orientation and scale facilitate ' ...
                'comparison with NSE, KGE, and JKGE (Vrugt and ' ...
                'Frame, 2026).'], ...
                '', ...
                ['SAGE computes $S_{\rm fdc}$, $S_p$, and $S_{\log p}$ ' ...
                'together using one sort of the simulated record; this ' ...
                'selection changes the training objective, not which ' ...
                'three diagnostic scores are calculated.'], ...
                '', ...
                '\textbf{References}', ...
                ['Vrugt, J.A. (2024), ' ...
                'Distribution-Based Model Evaluation and ' ...
                'Diagnostics: Elicitability, Propriety, ' ...
                'and Scoring Rules for Hydrograph ' ...
                'Functionals, \textit{Water Resources ' ...
                'Research}, 60, e2023WR036710, ' ...
                'doi:10.1029/2023WR036710.'], ...
                ['Vrugt, J.A. and Frame, J.M. ' ...
                '(2026), SAGE: Sensitivity-Aware Learning for Rapid ' ...
                'Training of Process-Based Hydrologic Models across ' ...
                'Large Basin Samples, manuscript submitted to ' ...
                '\textit{Hydrology and Earth System Sciences}.'], ...
                };    
        case 7    
            txt = { ...
                '\textbf{Jawad--Kling--Gupta efficiency}', ...
                ['The Jawad--Kling--Gupta efficiency (JKGE) ' ...
                'extends the classical Kling--Gupta ' ...
                'efficiency by replacing ' ...
                'the time-invariant long-term mean with a ' ...
                'time-varying benchmark. Let ' ...
                '$\mathbf{y}^{k}_{n} = (y^{k}_{1},\ldots,' ...
                'y^{k}_{n})^{\top}$ denote measured ' ...
                'discharge and $\mathbf{q}^{k}_{n} = ' ...
                '(q^{k}_{1},\ldots,q^{k}_{n})^{\top}$ ' ...
                'the corresponding simulations for basin $k$. ' ...
                'A linear operator $\mathcal{B}$ defines a ' ...
                'time-varying benchmark'], ...
                ['\hspace{1cm}$\mathbf{b}^{k}_{y} = ' ...
                '\mathcal{B}(\mathbf{y}^{k}_{n}), \qquad ' ...
                '\mathbf{b}^{k}_{q} = \mathcal{B}' ...
                '(\mathbf{q}^{k}_{n})$,'], ...
                ['with associated anomaly series ' ...
                '$\mathbf{a}^{k}_{y} = \mathbf{y}^{k}_{n} - ' ...
                '\mathbf{b}^{k}_{y}$ and ' ...
                '$\mathbf{a}^{k}_{q} = \mathbf{q}^{k}_{n} - ' ...
                '\mathbf{b}^{k}_{q}$. This decomposition ' ...
                'separates ' ...
                'variability into a benchmark and an anomaly ' ...
                'component, implying that model evaluation ' ...
                'must consider both spaces.'], ...
                '', ...
                ['Within anomaly space, differences ' ...
                'between $\mathbf{a}^{k}_{y}$ and ' ...
                '$\mathbf{a}^{k}_{q}$ arise ' ...
                'from both magnitude and alignment, ' ...
                'leading to three complementary ' ...
                'performance measures'], ...
                ['\hspace{1cm}$C^{k}_{qy} = \frac{' ...
                '\mathbf{a}^{k}_{q}{}^{\top}\mathbf{a}^{k}_' ...
                '{y}}{\|\mathbf{a}^{k}_{q}\|\,\|\mathbf{a}^{k}' ...
                '_{y}\|}, \hspace{2cm} V^{k}_{qy} = ' ...
                '\frac{\|\mathbf{a}^{k}_{q}\|}{\|' ...
                '\mathbf{a}^{k}_{y}\|}, \hspace{2cm} ' ...
                'M^{k}_{qy} = \frac{\|\mathbf{b}^{k}_{q} - ' ...
                '\mathbf{b}^{k}_{y}\|}{\|\mathbf{b}^{k}_{y} - ' ...
                '\bar{y}^{k}\mathbf{1}_{n}\|}$,'], ...
                ['where $C^{k}_{qy}$ measures anomaly ' ...
                'correlation, $V^{k}_{qy}$ their relative ' ...
                'magnitude, ' ...
                'and $M^{k}_{qy}$ the mismatch of the ' ...
                'time-varying benchmark and ' ...
                '$\|\mathbf{a}\| = \left(a^{1}_{1} + ' ...
                '\ldots + a^{2}_{n}\right)^{1/2}$. ' ...
                'Basin-wise efficiency is then defined as'], ...
                ['\hspace{1cm}$\mathrm{JKGE}^{k} = 1 - ' ...
                '\sqrt{ (C^{k}_{qy} - 1)^2 + (V^{k}_{qy} ' ...
                '- 1)^2 + (M^{k}_{qy}\,)^2 }$,'], ...
                'and the CAMELS-wide loss is' ...
                '\hspace{1cm}$\mathcal{L}_{\rm SAGE} = K^{-1}_{\rm t}\sum_{k=1}^{K_{\rm t}}(1 - \mathrm{JKGE}^{k})$. ' ...
                '', ...
                ['Benchmark operators 1 and 2 require an odd-valued ' ...
                'window length $n_{\rm JKGE}$, whereas ' ...
                'methods 3 and 4 do not require/use a window. ' ...
                'A skill-score adjusted variant of the JKGE'], ...
                '\hspace{1cm}$\mathrm{JKGE}^{k}_{\rm ss} = 1 - \sqrt{ ( M^{k}_{qy} + V^{k}_{qy} + C^{k}_{qy} \,)\,/\,2}$, ' ...
                ['attains a zero-value when $M^{k}_{qy} = 0$, ' ...
                '$V^{k}_{qy} = 1$ and $C^{k}_{qy} = 1$.'], ...
                '', ...
                '\textbf{References}', ...
                ['Jawad, M., Gupta, H.V., ' ...
                'Wang, Y.H., Farmani, M. A., Behrangi, A., ' ...
                'and Niu, G.Y. (2026), Improving model ' ...
                'performance by adapting the KGE metric ' ...
                'to account for system non-stationarity, ' ...
                '\textit{arXiv preprint}, arXiv:2604.03906, ' ...
                'doi:10.48550/arXiv.2604.03906.'], ...
                };    
        otherwise
            txt = { ...
                '\textbf{Unknown loss function}', ...
                'No help text is available for the ' ...
                'selected loss function.' ...
                };
    end
end

function txt = local_fdc_loss_help_latex(formulation)
%LOCAL_FDC_LOSS_HELP_LATEX Notes for probability-space FDC losses 6b/6c.

    switch double(formulation)
        case 2
            txt = { ...
                '\textbf{6b: Probability-space FDC divergence}', ...
                ['The flow-duration curve (FDC) may be represented by ' ...
                'its quantile function rather than by its survival ' ...
                'function on the physical discharge axis. Let ' ...
                '$q^{k}_{Y}(p) = F_{Y}^{-1}(1-p)$ and ' ...
                '$q^{k}_{Q}(p) = F_{Q}^{-1}(1-p)$ denote the observed and ' ...
                'simulated discharge quantiles at exceedance probability ' ...
                '$p\in[0,1]$ for basin $k$. The probability-space FDC ' ...
                'divergence is'], ...
                ['\hspace{1cm}$d^{k}_{p} = \int_{0}^{1}' ...
                '\left[q^{k}_{Q}(p)-q^{k}_{Y}(p)\right]^2' ...
                '\,\mathrm{d}p,$'], ...
                ['and the regional training objective is obtained by ' ...
                'averaging this divergence over the training basins,'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE} = ' ...
                'K_{\rm t}^{-1}\sum_{k=1}^{K_{\rm t}}d^{k}_{p}$.' ], ...
                '', ...
                ['For finite records $\mathbf{y}^{k}=(y^{k}_{1},\ldots,' ...
                'y^{k}_{n})^{\top}$ and $\mathbf{q}^{k}=(q^{k}_{1},' ...
                '\ldots,q^{k}_{n})^{\top}$, let $y^{k}_{(i)}$ and ' ...
                '$q^{k}_{(i)}$ denote their order statistics. SAGE uses ' ...
                'the empirical estimator'], ...
                ['\hspace{1cm}$d^{k}_{p} = \frac{1}{n}\sum' ...
                '\limits_{i=1}^{n}\left(q^{k}_{(i)}-' ...
                'y^{k}_{(i)}\right)^2$.' ], ...
                ['This is the squared $2$-Wasserstein distance between ' ...
                'the empirical discharge distributions. It is ' ...
                'nonnegative and equals zero only when the observed and ' ...
                'simulated FDCs coincide. As with $d_{\rm fdc}$, temporal ' ...
                'ordering is deliberately ignored: the criterion measures ' ...
                'agreement in the distribution of flow magnitudes.'], ...
                '', ...
                ['Integration over $p$ assigns the same integration weight ' ...
                'to equal-probability portions of the FDC. This differs ' ...
                'from $d_{\rm fdc}$, whose integration over physical ' ...
                'discharge can give greater weight to flow regimes spanning ' ...
                'large discharge intervals. Nevertheless, $d_p$ measures ' ...
                'squared differences in physical discharge units, so a ' ...
                'large absolute high-flow error may still contribute more ' ...
                'than a comparable relative error at low flow.'], ...
                '', ...
                ['The gradient is analytic. Away from tied order ' ...
                'statistics,'], ...
                ['\hspace{1cm}$\frac{\partial d^{k}_{p}}{' ...
                '\partial q^{k}_{(i)}}=\frac{2}{n}\left(' ...
                'q^{k}_{(i)}-y^{k}_{(i)}\right)$,' ], ...
                ['which SAGE maps from ranked discharge back to the ' ...
                'original time indices before applying the hydrologic-model ' ...
                'and neural-network chain rule. Stable sorting supplies a ' ...
                'valid subgradient at exact ties.'], ...
                '', ...
                ['For reporting, the dimensional divergence is converted ' ...
                'to a positively oriented skill score. Let ' ...
                '$T^{k}_{\!\!y}=\mathrm{median}(y^{k}_{1},\ldots,y^{k}_{n})$ ' ...
                'and use the constant simulation $q^{k}_{i}=T^{k}_{\!\!y}$ ' ...
                'to define'], ...
                ['\hspace{1cm}$d^{k}_{0,p}=\frac{1}{n}\sum' ...
                '\limits_{i=1}^{n}\left(T^{k}_{\!\!y} -' ...
                'y^{k}_{(i)}\right)^2$.' ], ...
                ['The basin- and period-specific probability-space FDC ' ...
                'skill score is'], ...
                ['\hspace{1cm}$S^{k}_{p}=1-\frac{d^{k}_{p}}{' ...
                'd^{k}_{0,p}}$.' ], ...
                ['$S^{k}_{p}=1$ denotes coincident FDCs, ' ...
                '$S^{k}_{p}=0$ matches the constant-median reference, and ' ...
                '$S^{k}_{p}<0$ denotes poorer performance. This ' ...
                'normalization makes the orientation directly comparable ' ...
                'with NSE, KGE, JKGE, and the other FDC skill scores.'], ...
                '', ...
                ['SAGE computes $S_{\rm fdc}$, $S_p$, and $S_{\log p}$ ' ...
                'together using one sort of the simulated record. The ' ...
                'additional calculations are linear in record length; ' ...
                'selecting 6b changes the optimized divergence but not ' ...
                'which three diagnostic scores are calculated.'], ...
                '', ...
                '\textbf{References}', ...
                ['Vrugt, J.A. (2024), ' ...
                'Distribution-Based Model Evaluation and Diagnostics: ' ...
                'Elicitability, Propriety, and Scoring Rules for ' ...
                'Hydrograph Functionals, \textit{Water Resources ' ...
                'Research}, 60, e2023WR036710, ' ...
                'doi:10.1029/2023WR036710.'], ...
                ['Vrugt, J.A. and Frame, J.M. (2026), ' ...
                'SAGE: Sensitivity-Aware Learning for Rapid Training of ' ...
                'Process-Based Hydrologic Models across Large Basin Samples, ' ...
                'manuscript submitted to \textit{Hydrology and Earth ' ...
                'System Sciences}.']};
        case 3
            txt = { ...
                '\textbf{6c: Log-quantile FDC divergence}', ...
                ['The log-quantile formulation compares observed and ' ...
                'simulated flow-duration curves in exceedance-probability ' ...
                'space after compressing the discharge scale. Let ' ...
                '$q^{k}_{Y}(p) = F_{Y}^{-1}(1-p)$ and ' ...
                '$q^{k}_{Q}(p) = F_{Q}^{-1}(1-p)$ denote the observed and ' ...
                'simulated discharge quantiles for basin $k$. The ' ...
                'log-quantile FDC divergence is'], ...
                ['\hspace{1cm}$d^{k}_{\log p}=\int_{0}^{1}\!\left[' ...
                '\log\!\left(q^{k}_{Q}(p)+q^{k}_{0}\right)-' ...
                '\log\!\left(q^{k}_{Y}(p)+q^{k}_{0}\right)' ...
                '\right]^2\,\mathrm{d}p,$'], ...
                ['where $q^{k}_{0}=0.01\,\mathrm{median}' ...
                '(\mathbf{y}^{k}_{+})$ and $\mathbf{y}^{k}_{+}$ contains ' ...
                'the positive observed discharges. This basin-specific ' ...
                'offset keeps zero flows finite while remaining small ' ...
                'relative to characteristic discharge. The regional ' ...
                'training objective is'], ...
                ['\hspace{1cm}$\mathcal{L}_{\rm SAGE}=' ...
                'K_{\rm t}^{-1}\sum_{k=1}^{K_{\rm t}}' ...
                'd^{k}_{\log p}$.' ], ...
                '', ...
                ['For finite records, let $y^{k}_{(i)}$ and ' ...
                '$q^{k}_{(i)}$ denote the observed and simulated order ' ...
                'statistics. SAGE evaluates'], ...
                ['\hspace{1cm}$d^{k}_{\log p}=\frac{1}{n}\sum' ...
                '\limits_{i=1}^{n}\left[\log\!\left(' ...
                'q^{k}_{(i)}+q^{k}_{0}\right)-\log\!\left(' ...
                'y^{k}_{(i)}+q^{k}_{0}\right)\right]^2$.' ], ...
                ['The divergence is nonnegative and equals zero only when ' ...
                'the two empirical FDCs coincide. It is insensitive to ' ...
                'temporal ordering and evaluates the distribution of ' ...
                'discharge magnitudes over the complete flow regime.'], ...
                '', ...
                ['As in 6b, integration over exceedance probability assigns ' ...
                'equal weight to equal-probability portions of the FDC. ' ...
                'The logarithmic transformation additionally compresses ' ...
                'large discharge values and measures discrepancies more ' ...
                'nearly in relative terms. Consequently, systematic ' ...
                'low-flow errors that contribute little to $d_{\rm fdc}$ ' ...
                'or $d_p$ remain visible. Formulation 6c is therefore the ' ...
                'most suitable of the three when an accurate description ' ...
                'of all flow levels, including low flows, is desired.'], ...
                '', ...
                ['The analytic derivative with respect to a ranked ' ...
                'simulated discharge is'], ...
                ['\hspace{1cm}$\frac{\partial d^{k}_{\log p}}{' ...
                '\partial q^{k}_{(i)}}=\frac{2}{n}\,' ...
                '\frac{\log(q^{k}_{(i)}+q^{k}_{0})-' ...
                '\log(y^{k}_{(i)}+q^{k}_{0})}{' ...
                'q^{k}_{(i)}+q^{k}_{0}}$.' ], ...
                ['SAGE maps this derivative from ranked discharge to the ' ...
                'original time indices before applying the model and ' ...
                'network chain rule. The hydrologic models generate ' ...
                'nonnegative discharge, ensuring that the logarithm is ' ...
                'well defined; stable sorting supplies a valid subgradient ' ...
                'at exact ties.'], ...
                '', ...
                ['For reporting, the same constant-median benchmark used ' ...
                'for the other FDC formulations defines'], ...
                ['\hspace{1cm}$d^{k}_{0,\log p}=\frac{1}{n}\sum' ...
                '\limits_{i=1}^{n}\left[\log(T^{k}_{\!\!y}+q^{k}_{0})-' ...
                '\log(y^{k}_{(i)}+q^{k}_{0})\right]^2$,' ], ...
                ['where $T^{k}_{\!\!y}$ is the median observed discharge. ' ...
                'The positively oriented log-quantile FDC skill score is'], ...
                ['\hspace{1cm}$S^{k}_{\log p}=1-' ...
                '\frac{d^{k}_{\log p}}{d^{k}_{0,\log p}}$.' ], ...
                ['$S^{k}_{\log p}=1$ denotes coincident FDCs, zero matches ' ...
                'the constant-median reference, and negative values denote ' ...
                'poorer performance. The reference is computed separately ' ...
                'for every basin and for its training and evaluation ' ...
                'periods.'], ...
                '', ...
                ['SAGE computes $S_{\rm fdc}$, $S_p$, and $S_{\log p}$ ' ...
                'together using one sort of the simulated record. The ' ...
                'additional calculations are linear in record length; ' ...
                'selecting 6c changes the optimized divergence but not ' ...
                'which three diagnostic scores are calculated.'], ...
                '', ...
                '\textbf{References}', ...
                ['Vrugt, J.A. (2024), ' ...
                'Distribution-Based Model Evaluation and Diagnostics: ' ...
                'Elicitability, Propriety, and Scoring Rules for ' ...
                'Hydrograph Functionals, \textit{Water Resources ' ...
                'Research}, 60, e2023WR036710, ' ...
                'doi:10.1029/2023WR036710.'], ...
                ['Vrugt, J.A. and Frame, J.M. (2026), ' ...
                'SAGE: Sensitivity-Aware Learning for Rapid Training of ' ...
                'Process-Based Hydrologic Models across Large Basin Samples, ' ...
                'manuscript submitted to \textit{Hydrology and Earth ' ...
                'System Sciences}.']};
        otherwise
            txt = localLossHelpLatex(6,1);
    end
end

function name = local_fdc_formulation_name(formulation)
%LOCAL_FDC_FORMULATION_NAME Compact, publication-style loss variant name.

    switch double(formulation)
        case 1
            name = '6a d_fdc';
        case 2
            name = '6b d_p';
        case 3
            name = '6c d_logp';
        otherwise
            name = '6a d_fdc';
    end
end

function txt = localOptHelpLatex(optMethod,lrSchedule)

    if nargin < 2 ...
            || isempty(lrSchedule)
        lrSchedule = 'constant';
    end
    lrSchedule = lower(char(string(lrSchedule)));

    switch optMethod
        case 1
            txt = { ...
                '\textbf{Gradient descent}', ...
                ['Having access to analytic gradients enables ' ...
                'efficient application of derivative-based ' ...
                'optimization methods. Parameter estimation is ' ...
                'performed using gradient descent, which ' ...
                'iteratively updates the parameter vector in ' ...
                'the direction of steepest decrease of the ' ...
                'CAMELS objective function.'], ...
                ['\hspace{1cm}$\mathbf{\theta}_{(i+1)} = ' ...
                '\mathbf{\theta}_{(i)} - \eta_{(i)}\,\nabla ' ...
                '\mathcal{L}_{\rm SAGE}(\mathbf{\theta}_{(i)})$,'], ...
                ['where $\eta_{(i)} > 0$ denotes the learning ' ...
                'rate at iteration $i$. Substitution of the ' ...
                'analytic gradient expression yields the ' ...
                'parameter update'], ...
                ['\hspace{1cm}$\Delta \mathbf{\theta}_{(i)} = ' ...
                '- \eta_{(i)}\,\mathbf{J}_{q}^{\top}' ...
                '(\mathbf{\theta}_{(i)})\,\mathbf{\delta}_{n}(\mathbf{\theta}_{(i)})$,'], ...
                ['with $\mathbf{J}_{q} = \partial ' ...
                '\mathbf{q}_{n} / \partial \mathbf{\theta}^{\top}$ ' ...
                'the Jacobian of the simulated discharge and ' ...
                '$\mathbf{\delta}_{n}$ the loss-sensitivity vector. ' ...
                'The learning rate $\eta_{(i)}$ controls ' ...
                'the step size and may be determined by ' ...
                'line search, selecting the optimal point ' ...
                'along the descent direction that ' ...
                'minimizes the loss.' ...
                'This formulation provides a general recipe ' ...
                'for minimizing any differentiable loss ' ...
                'function and highlights that gradient-based ' ...
                'learning proceeds through a sequence of ' ...
                'Jacobian--vector products.'], ...
                '', ...
                ['Gradient descent is computationally ' ...
                'efficient and transparent, but its ' ...
                'convergence depends on the conditioning ' ...
                'of the objective function and may require ' ...
                'careful tuning of the learning rate.']};    
        otherwise
            txt = { ...
                '\textbf{Adam / AdamW}', ...
                ['Adaptive moment estimation (Adam) computes ' ...
                'the parameter shift vector ' ...
                '$\Delta \mathbf{\theta}_{(i+1)} = ' ...
                '\mathbf{\theta}_{(i+1)} ' ...
                '- \mathbf{\theta}_{(i)}$ from exponentially ' ...
                'weighted bias-corrected estimates, ' ...
                '$\widehat{\mathbf{m}}_{(i)} \in \mathbb{R}^{d}$ ' ...
                'and $\widehat{\mathbf{v}}_{(i)} \in ' ...
                '\mathbb{R}^{d}$, of first and second moments'], ...
                ['\hspace{1cm}$\mathbf{\theta}_{(i+1)} = ' ...
                '\mathbf{\theta}_{(i)} - \eta_{(i)} \, ' ...
                '\frac{\widehat{\mathbf{m}}_{(i)}}{' ...
                '\sqrt{\widehat{\mathbf{v}}_{(i)}} + \epsilon}$,'], ...
                'of the gradient', ...
                '\hspace{1cm}$\mathbf{g}_{(i)}(\mathbf{\theta}_{(i)}) = \nabla \mathcal{L}_{\rm SAGE}(\mathbf{\theta}_{(i)}) \in \mathbb{R}^{d}$, ' ...
                ['where $\eta_{(i)} > 0$ denotes the ' ...
                'learning rate. The moment updates satisfy the ' ...
                'following recursions'], ...
                ['\hspace{1cm}$\mathbf{m}_{(i)} = \beta_{1}' ...
                '\mathbf{m}_{(i-1)} + (1 - \beta_{1})\,' ...
                '\mathbf{g}_{(i)}(\mathbf{\theta}_{(i)})$ '], ...
                ['\hspace{1cm}$\mathbf{v}_{(i)} = \beta_{2}' ...
                '\mathbf{v}_{(i-1)} + (1-\beta_{2}) \cdot' ...
                '\bigl(\mathbf{g}_{(i)}(\mathbf{\theta}_{(i)})' ...
                '\odot\mathbf{g}_{(i)}(\mathbf{\theta}_{(i)})\bigr)$,'],...
                ['where $\odot$ signifies the Hadamard ' ...
                'product (element-wise multiplication). ', ...
                ['Bias correction ensures that $\widehat{' ...
                '\mathbf{m}}_{(i)}$ and $\widehat{\mathbf{v}}_{(i)}$ ' ...
                'are unbiased during early iterations. '], ...
                ['This adaptive scaling reduces sensitivity to ' ...
                'differences in gradient magnitude and is ' ...
                'particularly effective for high-dimensional ' ...
                'parameter spaces. '], ...
                ['AdamW augments Adam with decoupled weight ' ...
                'decay, providing improved regularization by ' ...
                'penalizing parameter magnitude independently ' ...
                'of the gradient update. '], ...
                'Gradient-norm clipping may be applied to ' ...
                'stabilize training when occasional large ' ...
                'gradients arise from the hydrologic Jacobian ' ...
                'or loss function.']};
    end    
    s1 = ['\textbf{Maximum iterations}: Upper bound on the ' ...
        'number of optimization steps.'];
    s2 = ['\textbf{Learning rate}: Controls the step size ' ...
        'of each parameter update.'];
    s2a = ['\textbf{First-moment decay rate}: Adam coefficient ' ...
        '$\beta_{1}$ for the exponential moving average of gradients.'];
    s2b = ['\textbf{Second-moment decay rate}: Adam coefficient ' ...
        '$\beta_{2}$ for the exponential moving average of squared gradients.'];
    s2c = ['\textbf{Stabilization constant}: Positive Adam constant ' ...
        '$\varepsilon$ added to the denominator for numerical stability.'];
    s3 = ['\textbf{Weight decay}: AdamW-only penalty on parameter ' ...
        'magnitude; it is not used by gradient descent.'];
    s4 = ['\textbf{Clipn}: Threshold for gradient-norm ' ...
        'clipping used by both optimizers to prevent unstable updates.'];
    s5 = ['\textbf{Learning-rate schedule}: Relationship between ' ...
        'optimizer iteration and learning rate.'];
    s5a = '\hspace{0.5cm}1. Constant: keeps the initial rate.';
    s5b = ['\hspace{0.5cm}2. Cosine: smoothly decays from the initial ' ...
        'to the minimum rate.'];
    s5c = ['\hspace{0.5cm}3. Hold + cosine: holds the initial rate, ' ...
        'then begins the cosine decay.'];
    s6 = ['\textbf{Minimum learning rate}: Final floor for a cosine ' ...
        'schedule. If it equals the initial rate, no decay occurs.'];
    s7 = ['\textbf{Hold fraction}: Fraction of optimizer updates kept ' ...
        'at the initial rate before hold + cosine begins to decay.'];
    settings = {s1,s2};
    if optMethod == 2
        settings = [settings,{s2a,s2b,s2c,s3}];
    end
    settings = [settings,{s4,s5,s5a,s5b,s5c}];
    if ~strcmp(lrSchedule,'constant')
        settings{end+1} = s6;
    end
    if strcmp(lrSchedule,'hold_cosine')
        settings{end+1} = s7;
    end
    txt = [txt,{' '},settings];
end

function mdl = local_model_variant(mdl,key)
    if strcmpi(string(key),'gchm_ode')
        mdl.variant = 'gchm_ode';
        if isfield(mdl,'names')
            mdl.names(8) = "gchm_ode";
        end
    else
        if isfield(mdl,'variant')
            mdl = rmfield(mdl,'variant');
        end
        if isfield(mdl,'names')
            mdl.names(8) = "gchm";
        end
    end
end

function tf = local_is_gchm_ode(mdl)
    tf = isfield(mdl,'variant') ...
        && strcmpi(string(mdl.variant),'gchm_ode');
end

function [mdl,d] = local_read_model_info(mdl,prd,verbose)
    if nargin < 3
        verbose = true;
    end
    if local_is_gchm_ode(mdl)
        [mdl,d] = read_gchm_ode_info(mdl,prd,verbose);
    else
        [mdl,d] = read_model(mdl,prd,verbose);
    end
end

function [mdl,misc,status] = local_prepare_backend(mdl,misc)
    if ~local_is_gchm_ode(mdl)
        [mdl,misc,status] = crr_prepare_backend(mdl,misc);
        return
    end
    if mdl.mcode == 4 ...
            && exist('crr_gchm_ode','file') ~= 3
        error('SAGE_ui:GCHMOdeMissingMex', ...
            'Compile private/gchm_ode/crr_gchm_ode first.');
    end
    misc.crr_backend = 'matlab';
    mdl.crr_backend = 'matlab';
    status = 'standalone gchm_ode';
end

function id = local_model_id_from_key(key)

    switch lower(char(string(key)))
        case 'hymod'
            id = 1;
        case 'hmodel'
            id = 2;
        case 'sacsma'
            id = 3;
        case 'xinanjiang'
            id = 4;
        case 'gr4j'
            id = 5;
        case 'hbv'
            id = 6;
        case 'cfe_nwm'
            id = 7;
        case {'gchm','gchm_ode'}
            id = 11;
        case 'user_model'
            id = 99;
        otherwise
            id = 1;
    end
end

function U = localFluxUnits(resolution)

    if islogical(resolution) ...
            || isnumeric(resolution)
        if logical(resolution)
            key = 'hourly';
        else
            key = 'daily';
        end
    else
        key = lower(strtrim(char(string(resolution))));
    end

    if contains(key,'15')
        U.rate = 'mm (15 min)$^{-1}$';
        U.freq = '15-minute';
        U.Freq = '15-minute';
    elseif contains(key,'hour')
        U.rate = 'mm h$^{-1}$';
        U.freq = 'hourly';
        U.Freq = 'Hourly';
    else
        U.rate = 'mm d$^{-1}$';
        U.freq = 'daily';
        U.Freq = 'Daily';
    end
    U.P = ['\textbf{Precipitation (' U.rate ')}'];
    U.ET = ['\textbf{Potential evapotranspiration (' U.rate ')}'];
    U.Q = ['\textbf{Observed discharge (' U.rate ')}'];
end

function petText = localPETNotes(petVal,resolution,sourceMode)

    if nargin < 3 ...
            || isempty(sourceMode)
        sourceMode = 'computed';   % 'computed' or 'provided'
    end
    method = localPETMethodKey(petVal);
    switch method
        case 'zero'
            petText = localPETZeroNotes( ...
                resolution);    
        case 'penman-monteith'
            petText = localPETPenmanMonteithNotes( ...
                resolution,sourceMode);    
        case 'penman'
            petText = localPETPenmanNotes( ...
                resolution,sourceMode);    
        case 'priestley-taylor'
            petText = localPETPriestleyTaylorNotes( ...
                resolution,sourceMode);    
        case 'makkink'
            petText = localPETMakkinkNotes( ...
                resolution,sourceMode);    
        case 'oudin'
            petText = localPETOudinNotes( ...
                resolution,sourceMode);    
        case 'hargreaves'
            petText = localPETHargreavesNotes( ...
                resolution,sourceMode);
        case {'lamah-et','lamah-pet','lamah-total-et'}
            petText = localPETLamaHNotes( ...
                resolution);    
        otherwise
            petText = {'\textbf{PET method}', ...
                ['No PET-method notes are ' ...
                'available for this option.']};
    end
end

function method = localPETMethodKey(petVal)

    s = lower(strtrim(char(petVal)));
    if startsWith(s,'0') ...
            || contains(s,'zero')
        method = 'zero';    
    elseif contains(s,'penman-monteith') ...
            || contains(s,'monteith') ...
            || contains(s,'reference grass')
        method = 'penman-monteith';
    elseif contains(s,'priestley') ...
            || contains(s,'taylor')
        method = 'priestley-taylor';    
    elseif contains(s,'makkink')
        method = 'makkink';    
    elseif contains(s,'oudin')
        method = 'oudin';    
    elseif contains(s,'total et') ...
            || contains(s,'total_et') ...
            || contains(s,'total evaporation') ...
            || contains(s,'Σet')
        method = 'lamah-total-et';
    elseif contains(s,'lamah-ice pet') ...
            || (contains(s,'lamah') ...
            && contains(s,'pet'))
        method = 'lamah-pet';
    elseif contains(s,'lamah')
        method = 'lamah-et';
    elseif contains(s,'penman')
        method = 'penman';
    elseif contains(s,'hargreaves')
        method = 'hargreaves';    
    else
        method = 'unknown';
    end
end

function [timeFactor,unitText] = localPETUnits(resolution)

    if islogical(resolution) ...
        || isnumeric(resolution)
        if isscalar(resolution) ...
                && double(resolution) == 96
            key = '15min';
        elseif logical(resolution)
            key = 'hourly';
        else
            key = 'daily';
        end
    else
        key = lower(strtrim(char(string(resolution))));
    end

    if contains(key,'15')
        timeFactor = '900';
        unitText = 'mm\,(15\,min)$^{-1}$';
    elseif contains(key,'hour')
        timeFactor = '3,600';
        unitText = 'mm\,h$^{-1}$';
    else
        timeFactor = '86,400';
        unitText = 'mm\,d$^{-1}$';
    end
end

function txt = localPETSourceSentence(sourceMode, ...
    computedTxt,providedTxt)

    if strcmpi(sourceMode,'provided')
        txt = providedTxt;
    else
        txt = computedTxt;
    end
end

function petText = localPETIcelandProvidedNotes(isHourly,kind)

    [~,unitText] = localPETUnits(isHourly);

    if strcmpi(kind,'pet')
        petText = { ...
            '\textbf{Supplied LamaH-Ice PET}', ...
            ['Potential evaporation is read directly from the ' ...
            '\texttt{pet} column of the LamaH-Ice meteorological ' ...
            'time-series file. The dataset defines this variable as ' ...
            'open-water potential evaporation.'], ...
            '', ...
            '\textbf{Units and time convention}', ...
            ['$E_{\rm p}$ is used in ' unitText '. Each value applies ' ...
            'to the indexed time step. For hourly data, the value at ' ...
            '00:00 represents the interval from 00:00 to 01:00 GMT.'], ...
            '', ...
            '\textbf{Interpretation}', ...
            ['This option uses the supplied reanalysis-derived product ' ...
            'without recomputing PET from the meteorological variables. ' ...
            'It represents open-water evaporative demand rather than ' ...
            'reference-crop evapotranspiration.']};
    else
        petText = { ...
            '\textbf{Supplied LamaH-Ice total evaporation}', ...
            ['Total evaporation is read directly from the ' ...
            '\texttt{total\_et}\;column of the LamaH-Ice ' ...
            'meteorological time-series file. It includes evaporation ' ...
            'and vegetation transpiration represented by the source ' ...
            'reanalysis.'], ...
            '', ...
            '\textbf{Sign convention}', ...
            ['Positive values indicate evapotranspiration and are used ' ...
            'as $E_{\rm p}$ (' unitText '). Negative values indicate ' ...
            'condensation and are set to zero by the Iceland reader.'], ...
            '', ...
            '\textbf{Interpretation}', ...
            ['This is an actual/total evaporation product, not a pure ' ...
            'potential-evapotranspiration estimate. It is included as ' ...
            'an alternative forcing choice for comparison and diagnostic ' ...
            'experiments.']};
    end
end

function petText = localPETIsraelProvidedNotes(kind)

    [~,unitText] = localPETUnits(false);

    if strcmpi(kind,'fao')
        petText = { ...
            '\textbf{Supplied FAO Penman--Monteith PET}', ...
            ['Potential evapotranspiration is read directly from the ' ...
            '\texttt{potential\_evaporation\_sum\_FAO\_PENMAN\_MONTEITH} ' ...
            '\; column in the CAMELS-IL time-series file.'], ...
            '', ...
            '\textbf{Units}', ...
            ['$E_{\rm p}$ is used in ' unitText '. Negative supplied ' ...
            'values are set to zero by the Israel reader.'], ...
            '', ...
            '\textbf{Interpretation}', ...
            ['This option uses the dataset-provided FAO reference-crop ' ...
            'PET without recomputing it from the underlying meteorological ' ...
            'variables. It can be compared directly with option 1.']};
    else
        petText = { ...
            '\textbf{Supplied ERA5-Land potential evaporation}', ...
            ['Potential evaporation is read directly from the ' ...
            '\texttt{potential\_evaporation\_sum\_ERA5\_LAND}\;' ...
            'column in the CAMELS-IL time-series file.'], ...
            '', ...
            '\textbf{Units}', ...
            ['$E_{\rm p}$ is used in ' unitText '. Negative supplied ' ...
            'values are set to zero by the Israel reader.'], ...
            '', ...
            '\textbf{Interpretation}', ...
            ['This is the native ERA5-Land potential-evaporation product. ' ...
            'It is retained as an alternative to the three internally ' ...
            'computed PET methods and the supplied FAO product.']};
    end
end

function petText = localPETZeroNotes(isHourly)

    [~,unitText] = localPETUnits(isHourly);
    petText = { ...
        '\textbf{Zero PET}', ...
        ['Potential evapotranspiration, $E_{\rm p}$ (' unitText ...
        '), is set equal to zero. This option is mainly useful ' ...
        'for diagnostic tests, debugging, or isolating the effect ' ...
        'of precipitation.']};
end

function petText = localPETPenmanNotes(isHourly,sourceMode)

    [timeFactor,unitText] = localPETUnits(isHourly);
    intro = localPETSourceSentence(sourceMode, ...
        ['Potential evapotranspiration is computed using the Penman ' ...
        'equation, which combines the available energy term with an ' ...
        'aerodynamic evaporation term. Unlike Penman--Monteith, it ' ...
        'does not include an explicit surface-resistance term.'], ...
        ['Potential evapotranspiration is read from the selected ' ...
        'regional forcing product. The Penman equation combines the ' ...
        'available energy term with an aerodynamic evaporation term, ' ...
        'but does not include an explicit surface-resistance term.']);
    petText = { ...
        '\textbf{Penman method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm}$E_{\rm p}=' ...
        '\frac{' timeFactor '}{\lambda}' ...
        '\frac{\Delta(R_{\rm n} - G) + \gamma \, E_{\rm a}}' ...
        '{\Delta + \gamma}$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['$E_{\rm p}$ (' unitText ') is potential evapotranspiration; ' ...
        '$R_{\rm n}$ and $G$ (W\,m$^{-2}$) are net radiation and ' ...
        'ground heat flux, respectively; ' ...
        '$\Delta$ and $\gamma$ (kPa\,$^\circ$C$^{-1}$) are the slope ' ...
        'of the saturation vapor pressure curve and the psychrometric ' ...
        'constant, respectively; ' ...
        '$E_{\rm a}$ (W\,m$^{-2}$) is the aerodynamic evaporation ' ...
        'term; and $\lambda$ (J\,kg$^{-1}$) is the latent heat of ' ...
        'vaporization.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Penman, H.L. (1948), Natural evaporation from open water, ' ...
        'bare soil and grass, Proceedings of the Royal Society A, ' ...
        '193, 120--145.']};
end

function petText = localPETPenmanMonteithNotes(isHourly,sourceMode)

    [timeFactor,unitText] = localPETUnits(isHourly); 

    intro = localPETSourceSentence(sourceMode, ...
        ['Reference evapotranspiration is computed using the ' ...
        'FAO-56 Penman--Monteith equation. This method combines ' ...
        'net radiation, aerodynamic transport, and surface ' ...
        'resistance effects.'], ...
        ['Reference evapotranspiration is read from the selected ' ...
        'regional forcing product. The FAO-56 Penman--Monteith ' ...
        'equation combines net radiation, aerodynamic transport, ' ...
        'and surface resistance effects.']);    
    petText = { ...
        '\textbf{Penman--Monteith method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm}$E_{\rm p}=' ...
        '\frac{' timeFactor '}{\lambda}' ...
        '\frac{\Delta(R_{\rm n} - G)+\rho_{\rm a} c_{\rm p}(e_{\rm s} - e_{\rm a})/r_{\rm a}}' ...
        '{\Delta+\gamma(1+r_{\rm s}/r_{\rm a})}$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['$E_{\rm p}$ (' unitText ') is potential evapotranspiration; ' ...
        '$R_{\rm n}$ and $G$ (W\,m$^{-2}$) are net radiation and ' ...
        'ground heat flux, respectively; ' ...
        '$\Delta$ and $\gamma$ (kPa\,$^\circ$C$^{-1}$) are the slope ' ...
        'of the saturation vapor pressure curve and the psychrometric ' ...
        'constant, respectively; ' ...
        '$\rho_{\rm a}$ (kg\,m$^{-3}$) is air density; ' ...
        '$c_{\rm p}$ (J\,kg$^{-1}$\,$^\circ$C$^{-1}$) is the specific ' ...
        'heat capacity of air; ' ...
        '$e_{\rm s}$ and $e_{\rm a}$ (kPa) are the saturation and ' ...
        'actual vapor pressures; ' ...
        '$r_{\rm a}$ and $r_{\rm s}$ (s\,m$^{-1}$) are the aerodynamic ' ...
        'and surface resistances; and ' ...
        '$\lambda$ (J\,kg$^{-1}$) is the latent heat of vaporization.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Allen, R.G., Pereira, L.S., Raes, D., and Smith, M. ' ...
        '(1998), \textit{Crop evapotranspiration: Guidelines ' ...
        'for computing crop water requirements}, FAO Irrigation ' ...
        'and Drainage Paper 56, doi:10.1016/S0378-3774(98)00077-9.']};
end

function petText = localPETPriestleyTaylorNotes(isHourly,sourceMode)

    [timeFactor,unitText] = localPETUnits(isHourly);   

    intro = localPETSourceSentence(sourceMode, ...
        ['Potential evapotranspiration is estimated from the ' ...
        'radiation term of the energy balance, multiplied by ' ...
        'the Priestley--Taylor coefficient.'], ...
        ['Potential evapotranspiration is read from the selected ' ...
        'regional forcing product. The Priestley--Taylor method ' ...
        'estimates evapotranspiration from the radiation term of the ' ...
        'energy balance, multiplied by the Priestley--Taylor coefficient.']);    
    petText = { ...
        '\textbf{Priestley--Taylor method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm}$E_{\rm p}=' ...
        '\frac{' timeFactor '}{\lambda}\,\alpha\,' ...
        '\frac{\Delta}{\Delta + \gamma}(R_{\rm n} - G)$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['$E_{\rm p}$ (' unitText ') is potential evapotranspiration; ' ...
        '$\alpha$ is the dimensionless Priestley--Taylor coefficient; ' ...
        '$R_{\rm n}$ and $G$ (W\,m$^{-2}$) are net radiation and ' ...
        'ground heat flux, respectively; ' ...
        '$\Delta$ and $\gamma$ (kPa\,$^\circ$C$^{-1}$) are the slope ' ...
        'of the saturation vapor pressure curve and the psychrometric ' ...
        'constant, respectively; and ' ...
        '$\lambda$ (J\,kg$^{-1}$) is the latent heat of vaporization.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Priestley, C.H.B. and Taylor, R.J. (1972), On the ' ...
        'assessment of surface heat flux and evaporation using ' ...
        'large-scale parameters, \textit{Monthly Weather Review}, ' ...
        '100(2), 81--92, doi:10.1175/1520-0493(1972)' ...
        '100<0081:OTAOSH>2.3.CO;2.']};
end

function petText = localPETMakkinkNotes(isHourly,sourceMode)

    [timeFactor,unitText] = localPETUnits(isHourly);  

    intro = localPETSourceSentence(sourceMode, ...
        ['The Makkink method is a radiation-based estimate of ' ...
        'potential evapotranspiration based on incoming shortwave ' ...
        'radiation.'], ...
        ['Potential evapotranspiration is read from the selected ' ...
        'regional forcing product. The Makkink method is a ' ...
        'radiation-based estimate based on incoming shortwave radiation.']);
    petText = { ...
        '\textbf{Makkink method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm}$E_{\rm p}=' ...
        '\frac{' timeFactor '}{\lambda}\,c\,' ...
        '\frac{\Delta}{\Delta + \gamma}\,R_{\rm s}$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['$E_{\rm p}$ (' unitText ') is potential evapotranspiration; ' ...
        '$c$ is the dimensionless empirical Makkink coefficient; ' ...
        '$R_{\rm s}$ (W\,m$^{-2}$) is incoming shortwave radiation; ' ...
        '$\Delta$ and $\gamma$ (kPa\,$^\circ$C$^{-1}$) are the slope ' ...
        'of the saturation vapor pressure curve and the psychrometric ' ...
        'constant, respectively; and ' ...
        '$\lambda$ (J\,kg$^{-1}$) is the latent heat of vaporization.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Makkink, G.F. (1957), Testing the Penman formula by means ' ...
        'of lysimeters, \textit{Journal of the Institution of Water ' ...
        'Engineers}, 11, 277--288, doi:10.1016/S0022-1694(57)80003-8.']};
end

function petText = localPETOudinNotes(isHourly,sourceMode)

    [~,unitText] = localPETUnits(isHourly);    

    intro = localPETSourceSentence(sourceMode, ...
        ['Potential evapotranspiration is computed using the Oudin ' ...
        'formulation, which estimates evapotranspiration from air ' ...
        'temperature and extraterrestrial radiation.'], ...
        ['Potential evapotranspiration is read from the selected ' ...
        'regional forcing product. The Oudin formulation estimates ' ...
        'evapotranspiration from air temperature and extraterrestrial ' ...
        'radiation.']);
    petText = { ...
        '\textbf{Oudin et al. method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm} $\mathrm{PET}_{\Delta t} = ' ...
        '\left\{ \begin{array}{ll} ' ...
        '\displaystyle \frac{R_{\rm e,\Delta t}}' ...
        '{\lambda\,\rho_{\rm w}}' ...
        '\frac{T_{\rm a}+5}{100}, ' ...
        '& T_{\rm a} > -5^\circ \\ ' ...
        '0, & T_{\rm a} \leq -5^\circ ' ...
        '\end{array} \right.$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['$E_{\rm p}$ (' unitText ') is potential evapotranspiration; ' ...
        '$R_{\rm e,\Delta t}$ (J\,m$^{-2}$ per time step) is ' ...
        'extraterrestrial radiation accumulated over the active time step ' ...
        '$\Delta t$; $T_{\rm a}$ ($^\circ$C) is mean air temperature; ' ...
        '$\lambda$ (J\,kg$^{-1}$) is the latent heat of vaporization; ' ...
        'and $\rho_{\rm w}$ (kg\,m$^{-3}$) is the density of water.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Oudin, L., Hervieu, F., Michel, C., Perrin, C., Andréassian, V., ' ...
        'Anctil, F., and Loumagne, C. (2005), Which potential ' ...
        'evapotranspiration input for a lumped rainfall-runoff model? ' ...
        'Part 2 -- Towards a simple and efficient potential ' ...
        'evapotranspiration model for rainfall-runoff modelling, ' ...
        '\textit{Journal of Hydrology}, 303, 290--306.']};
end

function petText = localPETHargreavesNotes(isHourly,sourceMode)

    [~,unitText] = localPETUnits(isHourly);
    
    intro = localPETSourceSentence(sourceMode, ...
        ['Reference evapotranspiration is computed using the ' ...
        'Hargreaves--Samani temperature-based method. This method ' ...
        'uses extraterrestrial radiation and daily minimum and ' ...
        'maximum temperature.'], ...
        ['Reference evapotranspiration is read from the selected ' ...
        'regional forcing product. The Hargreaves--Samani method ' ...
        'uses extraterrestrial radiation and daily minimum and ' ...
        'maximum temperature.']);
    
    petText = { ...
        '\textbf{Hargreaves--Samani method}', ...
        intro, ...
        '', ...
        '\textbf{Governing equation}', ...
        ['\hspace{0.5cm}${\rm ET}_{0} = ' ...
        '0.0023\,R_{\rm a}\,(T_{\rm mean}+17.8)' ...
        '\sqrt{T_{\rm max}-T_{\rm min}}$'], ...
        '', ...
        '\textbf{Variables and units}', ...
        ['${\rm ET}_{0}$ (' unitText ') is reference ' ...
        'evapotranspiration; $R_{\rm a}$ is extraterrestrial ' ...
        'radiation expressed as equivalent water depth per time step; ' ...
        '$T_{\rm mean}$, $T_{\rm min}$, and $T_{\rm max}$ ' ...
        '($^\circ$C) are mean, minimum, and maximum air temperature.'], ...
        '', ...
        '\textbf{Limitations}', ...
        ['The method is simple and temperature based, and limitations ' ...
        'are expected in humid coastal climates, windy or arid regions, ' ...
        'snow-dominated basins, and locations where humidity strongly ' ...
        'controls evapotranspiration.'], ...
        '', ...
        '\textbf{Reference}', ...
        ['Hargreaves, G.H. and Samani, Z.A. (1985), Reference crop ' ...
        'evapotranspiration from temperature, \textit{Applied ' ...
        'Engineering in Agriculture}, 1, 96--99.']};
end

function petText = localPETLamaHNotes(isHourly)

    [~,unitText] = localPETUnits(isHourly);
    petText = { ...
        '\textbf{LamaH ΣET}', ...
        ['Potential evapotranspiration, $E_{\rm p}$ (' unitText ...
        '), is read directly from the LamaH basin CSV files.']};
end

function h = localNoteHeightFromLineCount(nLines,fontSize,hMin,hMax)

    if isempty(nLines) ...
            || ~isfinite(nLines) ...
            || nLines < 1
        nLines = 1;
    end
    fontSize = max(8,fontSize);
    % Tighter estimate now that the inner grid scrolls.
    % The previous larger values made the scrollbar continue beyond
    % the actual text.
    lineH = max(14,1.25*fontSize);
    % Only modest top/bottom padding.
    padH = max(14,1.3*fontSize);
    h = padH + lineH*nLines;
    h = min(hMax,max(hMin,round(h)));
end

function h = localFittedNoteLabelHeight( ...
    label,textValue,fontSize,fallbackH,hMin,hMax)
%LOCALFITTEDNOTELABELHEIGHT Use reliable rendered wrapped-text height.
% MATLAB occasionally reports only one or two lines during startup. A
% rendered measurement is accepted only if it can accommodate the explicit
% source lines at the selected font size; otherwise the shared estimate is
% retained.

    h = fallbackH;
    measured = NaN;
    try
        % Position is the height allocated by the parent grid and can
        % therefore include all unused space. Extent is the intrinsic
        % rendered text size and is the only valid content measurement.
        extent = double(label.Extent);
        if numel(extent) >= 4 && isfinite(extent(4)) ...
                && extent(4) > 0
            measured = extent(4);
        end
    catch
    end

    lines = string(textValue);
    lines = lines(:);
    blank = strlength(strtrim(lines)) == 0;
    explicitLines = sum(~blank) + 0.65*sum(blank);
    lineHeight = max(16,1.40*double(fontSize));
    % Reject the transient one-line Extent reported during startup, but
    % otherwise prefer the intrinsic rendered height over the conservative
    % wrapping estimate. This keeps the box tight below the final line.
    reliableMinimum = max(hMin,0.35*explicitLines*lineHeight);
    if isfinite(measured) && measured >= reliableMinimum
        h = ceil(measured) + 2;
    end
    h = min(hMax,max(hMin,round(h)));
end

function h = localRenderedNoteLabelHeight(label,fallbackH,hMin,hMax)
%LOCALRENDEREDNOTELABELHEIGHT Use MATLAB's rendered wrapped-text extent.
% The fallback is retained for releases or transient layout states in which
% Extent is unavailable. Only a two-pixel descender guard is added; padding
% belongs to the surrounding scrollable grid and is not part of the row.

    h = fallbackH;
    try
        drawnow limitrate nocallbacks
        extent = double(label.Extent);
        if numel(extent) >= 4 ...
                && isfinite(extent(3)) ...
                && isfinite(extent(4)) ...
                && extent(3) > 0 ...
                && extent(4) > 0
            h = max(h,ceil(extent(4)) + 2);
        end
    catch
    end
    h = min(hMax,max(hMin,round(h)));
end

function tf=localIsGRDCRegion(region)
    tf=any(strcmp(char(string(region)),{ ...
        'CAMELS_AR','CAMELS_BE','CAMELS_EE','CAMELS_IE','CAMELS_JM', ...
        'CAMELS_NA','CAMELS_NO','CAMELS_PR','CAMELS_ZA'}));
end

function [name,count]=localGRDCRegionInfo(region)
    switch char(string(region))
        case 'CAMELS_AR'
            name = 'Argentina';
            count = 59;
        case 'CAMELS_BE'
            name = 'Belgium';
            count = 55;
        case 'CAMELS_EE'
            name = 'Estonia';
            count = 51;
        case 'CAMELS_IE'
            name = 'Ireland';
            count = 43;
        case 'CAMELS_JM'
            name = 'Jamaica';
            count = 12;
        case 'CAMELS_NA'
            name = 'Namibia';
            count = 51;
        case 'CAMELS_NO'
            name = 'Norway';
            count = 206;
        case 'CAMELS_PR'
            name = 'Puerto Rico';
            count = 24;
        case 'CAMELS_ZA'
            name = 'South Africa';
            count = 434;
        otherwise
            name = char(string(region)); 
            count = 0;
    end
end

function loc = localMapLegendLocation(region)

    region = char(string(region));
    % Important:
    % Do not use 'southwest' on geoaxes.
    % MATLAB's geographic scale bar is commonly drawn in the lower-left
    % corner, so a southwest legend can overlap it.
    if strcmp(region,'CAMELS_AU') ...
            || strcmp(region,'CAMELS_AT') ...
            || strcmp(region,'CAMELS_IS') ...
            || strcmp(region,'CAMELS_JP') ...
            || strcmp(region,'CAMELS_CH') ...
            || strcmp(region,'CAMELS_CL') ...
            || strcmp(region,'CAMELS_DE') ...
            || strcmp(region,'CAMELS_DEH') ...
            || strcmp(region,'CAMELS_DK') ...
            || strcmp(region,'CAMELS_FI') ...
            || strcmp(region,'CAMELS_FR') ...
            || strcmp(region,'CAMELS_LUX') ...
            || strcmp(region,'CAMELS_MX') ...
            || strcmp(region,'CAMELS_NZ') ...
            || strcmp(region,'CAMELS_NO') ...
            || strcmp(region,'CAMELS_CA') ...
            || strcmp(region,'CAMELS_PE') ...
            || strcmp(region,'CAMELS_PL') ...
            || strcmp(region,'CAMELS_SE') ...
            || strcmp(region,'CAMELS_US') ...
            || strcmp(region,'CAMELSH_US') ...
            || strcmp(region,'MACH_US') ...
            || strcmp(region,'CAMELS_ZA')
        loc = 'northwest';
    elseif strcmp(region,'CAMELS_IND') ...
            || strcmp(region,'CAMELS_IL') ...
            || strcmp(region,'CAMELS_NA') ...
            || strcmp(region,'CAMELS_ES') ...
            || strcmp(region,'BULL_ES')
        loc = 'southeast';
    elseif strcmp(region,'CAMELS_BR')
        loc = 'southwest';
    else
        loc = 'northeast';
    end
end

function [latTxt,lonTxt,hAlign,vAlign] = ...
    bestCapitalLabelPosition(gx,lat0,lon0)

    % Current map limits
    try
        latLim = gx.LatitudeLimits;
        lonLim = gx.LongitudeLimits;
    catch
        % Defensive fallback only; geoaxes normally provide these limits.
        latLim = [-60 85];
        lonLim = [-180 180];
    end

    dLat = diff(latLim);
    dLon = diff(lonLim);

    % Small offsets relative to visible map size
    offLat = 0.02*dLat;
    offLon = 0.01*dLon;

    % Candidate positions:
    % name, lat offset, lon offset, horizontal align, vertical align
    cand = { ...
        'top',        offLat,  0,       'center', 'bottom'; ...
        'right',      0,       offLon,  'left',   'middle'; ...
        'left',       0,      -offLon,  'right',  'middle'; ...
        'bottom',    -offLat,  0,       'center', 'top'}; %...
        % 'top-right',  offLat,  offLon,  'left',   'bottom'; ...
        % 'top-left',   offLat, -offLon,  'right',  'bottom'; ...
        % 'bottom-right',-offLat, offLon, 'left',   'top'; ...
        % 'bottom-left', -offLat,-offLon, 'right',  'top'};

    % Get basin marker locations from scatter objects already on map
    latB = [];
    lonB = [];

    try
        hs = findall(gx,'Type','Scatter');

        for k = 1:numel(hs)
            try
                latB = [latB; hs(k).LatitudeData(:)];   %#ok
                lonB = [lonB; hs(k).LongitudeData(:)];  %#ok
            catch
            end
        end
    catch
    end

    % Remove the capital point itself, if already plotted
    try
        d0 = hypot((latB-lat0)/max(dLat,eps), ...
                   (lonB-lon0)/max(dLon,eps));
        keep = d0 > 1e-4;
        latB = latB(keep);
        lonB = lonB(keep);
    catch
    end

    % If no basin points found, use above the capital
    if isempty(latB)
        best = 1;
    else
        score = -inf(size(cand,1),1);

        for i = 1:size(cand,1)

            latC = lat0 + cand{i,2};
            lonC = lon0 + cand{i,3};

            % Penalize positions outside the map
            if latC < latLim(1) ...
                    || latC > latLim(2) ...
                    || lonC < lonLim(1) ...
                    || lonC > lonLim(2)
                score(i) = -inf;
                continue
            end

            % Normalized distance to nearest basin
            d = hypot((latB-latC)/max(dLat,eps), ...
                      (lonB-lonC)/max(dLon,eps));

            score(i) = min(d);

            % Mild preference for top label if distances are similar
            if strcmp(cand{i,1},'top')
                score(i) = score(i) + 0.01;
            end
        end
        [~,best] = max(score);
    end
    latTxt = lat0 + cand{best,2};
    lonTxt = lon0 + cand{best,3};
    hAlign = cand{best,4};
    vAlign = cand{best,5};
end

function h = localExtraNoteHeight(nLines,fs)

    if nargin < 1 ...
            || isempty(nLines)
        nLines = 0;
    end

    if nargin < 2 ...
            || isempty(fs)
        fs = 14;
    end

    lineH = max(15,1.23*fs);
    h = round(nLines*lineH);
end

function label = localDatasetSelectorName(SAGEhydro,region,fallback)
%LOCALDATASETSELECTORNAME Dataset-facing label for the Region tab.
    label = char(string(fallback));
    try
        C = region_helpers('config',SAGEhydro,region);
        if isfield(C,'dataset') ...
                && ~isempty(C.dataset)
            label = char(string(C.dataset));
        end
    catch
    end
    label = strtrim(label);
end
function name = localRegionPanelName(region)
%LOCALREGIONPANELNAME Country-facing title used on the Region tab.
% Dataset-qualified names belong in selectors. Remove parenthetical
% dataset qualifiers and bracketed temporal-resolution qualifiers from
% the registered display name while preserving its familiar geography
% wording (for example, "Great Britain" rather than a map-provider name).
    code = char(region_helpers('code',region));
    name = char(region_helpers('name',code));
    name = regexprep(name,'\s*\([^)]*\).*$','');
    name = regexprep(name,'\s*\[[^]]*\].*$','');
    name = strtrim(name);
    if strcmpi(code,'HYDRO_CIS')
        name = 'Russia';
    end
end
function flagFile = localRegionFlagFile(region,SAGEhydro)
%LOCALREGIONFLAGFILE Return packaged SVG or PNG country flag.
%
% In MATLAB, flags are found beneath SAGEhydrology/flags.
% In a deployed application, AdditionalFiles are extracted beneath ctfroot.

    flagFile = '';

    try
        regionCode = char(region_helpers('code',region));
        short = char(region_helpers('short',regionCode));

        % CAMELS-US and CAMELSH-US are different datasets for the same
        % country. USH remains the dataset/region-directory tag, whereas
        % both datasets must resolve to the packaged United States flag.
        if any(strcmpi(regionCode, ...
                {'CAMELS_US','CAMELSH_US','MACH_US'}))
            short = 'US';
        elseif any(strcmpi(regionCode,{'CAMELS_KR','CAMELSH_KR'}))
            short = 'KR';
        elseif strcmpi(regionCode,'CAMELS_DEH')
            short = 'DE';
        elseif strcmpi(regionCode,'BULL_ES')
            short = 'ES';
        end
    catch
        return
    end

    if isempty(short)
        return
    end

    % Candidate flag directories, ordered by likely relevance.
    flagDirs = {};

    % Normal MATLAB/development location.
    if nargin >= 2 ...
            && ~isempty(SAGEhydro)
        flagDirs{end+1} = fullfile( ...
            char(SAGEhydro),'flags');
    end

    % Location relative to SAGEhydrology/gui in the flat source tree.
    try
        appDir = fileparts(mfilename('fullpath'));
        flagDirs{end+1} = fullfile(appDir,'..','flags');
    catch
    end

    % Locations used by MATLAB Compiler.
    if isdeployed
        flagDirs{end+1} = fullfile( ...
            ctfroot,'flags');

        flagDirs{end+1} = fullfile( ...
            ctfroot,'SAGEhydrology','flags');

        % Depending on how AdditionalFiles are staged, the executable's
        % compiled source hierarchy may also contain the folder.
        appDir = fileparts(mfilename('fullpath'));

        flagDirs{end+1} = fullfile( ...
            appDir,'flags');

        flagDirs{end+1} = fullfile( ...
            appDir,'..','flags');
    end

    % Remove duplicate candidate directories while preserving order.
    flagDirs = unique(flagDirs,'stable');

    % Prefer PNG in deployed mode. It is generally more reliable for
    % Chromium-backed UI components than SVG across MATLAB releases.
    if isdeployed
        extensions = {'.png','.svg'};
    else
        extensions = {'.svg','.png'};
    end

    for i = 1:numel(flagDirs)
        for j = 1:numel(extensions)
            candidate = fullfile( ...
                flagDirs{i}, ...
                [short extensions{j}]);

            if isfile(candidate)
                flagFile = candidate;
                return
            end
        end
    end
end

function [dirTS,nFiles] = localResolveCZTimeseries(regionRoot,stream)
%LOCALRESOLVECZTIMESERIES Resolve a canonical CAMELS-CZ data folder.
%
% Canonical layout:
%   Data/CAMELS_CZ/daily/timeseries

    if nargin < 2 ...
            || isempty(stream)
        stream = 'daily';
    end
    regionRoot = char(string(regionRoot));
    dirTS = fullfile(regionRoot,char(string(stream)),'timeseries');
    nFiles = 0;

    if isfolder(dirTS)
        D = dir(fullfile(dirTS,'camelscz_*.csv'));
        if ~isempty(D)
            nFiles = sum(~[D.isdir]);
        end
    end
end

function txt = localDataStatusText(supported,installed, ...
    installedText,missingText,unsupportedText)
    if ~supported
        txt = ['× ' unsupportedText];
    elseif installed
        txt = ['✓ ' installedText];
    else
        txt = ['× ' missingText];
    end
end

function varargout = localSessionHelper(action,varargin)
%SAGE_GUI_SESSION Session metadata, migration, and compatibility checks.
%
% This helper keeps file-system-dependent session logic outside the main
% SAGE GUI. It does not access GUI handles and is safe to unit test.

    action = lower(string(action));
    switch action
        case "enrich"
            session = varargin{1};
            if isfield(session,'cfg') ...
                    && isstruct(session.cfg)
                session.dataFingerprint = ...
                    localFingerprint(session.cfg);
            else
                session.dataFingerprint = struct();
            end
            varargout{1} = session;

        case "migrate"
            session = varargin{1};
            targetVersion = double(varargin{2});
            if ~isfield(session,'schemaVersion') ...
                    || isempty(session.schemaVersion)
                session.schemaVersion = 1;
            end
            if ~isfield(session,'odeOverride') ...
                    || ~isstruct(session.odeOverride)
                session.odeOverride = struct();
            end
            if ~isfield(session,'parOverride') ...
                    || ~isstruct(session.parOverride)
                session.parOverride = struct();
            end
            if ~isfield(session,'dataFingerprint') ...
                    && isfield(session,'cfg') ...
                    && isstruct(session.cfg)
                % Older sessions can still be loaded, but prepared basin
                % state will be treated conservatively by validation.
                session.dataFingerprint = struct();
            end
            session.schemaVersion = targetVersion;
            varargout{1} = session;

        case "validate"
            session = varargin{1};
            varargout{1} = localValidate(session);

        case "fingerprint"
            varargout{1} = localFingerprint(varargin{1});

        otherwise
            error('SAGE_ui:UnknownSessionAction', ...
                'Unknown session action: %s',action);
    end
end

function report = localValidate(session)
    report = struct();
    report.configCompatible = isfield(session,'cfg') ...
        && isstruct(session.cfg);
    report.preparedCompatible = false;
    report.preparedReason = "Prepared state " + ...
        "was not saved.";
    report.warnings = strings(0,1);

    if ~report.configCompatible
        report.warnings(end+1,1) = ...
            "The session has no valid " + ...
            "configuration structure.";
        return
    end

    savedPrepared = false;
    if isfield(session,'runtimePrepared') ...
            && ~isempty(session.runtimePrepared)
        savedPrepared = logical(session.runtimePrepared);
    end
    if ~savedPrepared
        report.preparedReason = "The saved " + ...
            "session was not basin-prepared.";
        return
    end

    if ~isfield(session,'preparedBasins') ...
            || isempty(session.preparedBasins)
        report.preparedReason = "Prepared basin " + ...
            "identifiers are missing.";
        return
    end

    current = localFingerprint(session.cfg);
    if ~isfield(session,'dataFingerprint') ...
            || ~isstruct(session.dataFingerprint) ...
            || isempty(fieldnames(session.dataFingerprint))
        report.preparedReason = ...
            "This older session has no data fingerprint; " + ...
            "its configuration is restored, " + ...
            "but basin preparation must be repeated.";
        report.warnings(end+1,1) = report.preparedReason;
        return
    end

    [same,reasons] = localCompareFingerprint( ...
        session.dataFingerprint,current);
    report.preparedCompatible = same;
    if same
        report.preparedReason = ...
            "Prepared basin state is compatible.";
    else
        report.preparedReason = strjoin(reasons,"; ");
        report.warnings(end+1,1) = ...
            "Prepared basin state was invalidated because " + ...
            report.preparedReason;
    end
end

function fp = localFingerprint(cfg)
    fp = struct();
    fp.region = localTextField(cfg,'region');
    fp.root = localCanonical(localTextField(cfg,'root'));
    fp.dirD = localCanonical(localTextField(cfg,'dirD'));
    fp.fileUniverse = localTextField(cfg,'file_univ');
    fp.dt = localNestedNumeric(cfg,{'prd','dt'},NaN);
    fp.K = localNestedNumeric(cfg,{'bas','K'},NaN);
    fp.Kt = localNestedNumeric(cfg,{'bas','K_t'},NaN);
    fp.Ke = localNestedNumeric(cfg,{'bas','K_e'},NaN);
    fp.sample = localNestedText(cfg,{'bas','sample'});

    fp.universePath = localResolveUniversePath(cfg,fp.fileUniverse);
    fp.universeExists = isfile(fp.universePath);
    fp.universeBytes = NaN;
    fp.universeDateNum = NaN;
    if fp.universeExists
        d = dir(fp.universePath);
        if ~isempty(d)
            fp.universeBytes = double(d(1).bytes);
            fp.universeDateNum = double(d(1).datenum);
        end
    end
end

function [same,reasons] = localCompareFingerprint(a,b)
    reasons = strings(0,1);
    localCheckText('region',a,b);
    localCheckNumeric('time-step resolution',a,b,'dt');
    localCheckText('basin universe file',a,b,'fileUniverse');
    localCheckNumeric('basin universe size',a,b,'K');
    localCheckNumeric('training basin count',a,b,'Kt');
    localCheckNumeric('evaluation basin count',a,b,'Ke');
    localCheckText('sampling method',a,b,'sample');

    if isfield(a,'universeExists') ...
            && logical(a.universeExists)
        if ~isfield(b,'universeExists') ...
                || ~logical(b.universeExists)
            reasons(end+1,1) = "the saved " + ...
                "basin-universe file is unavailable";
        else
            if isfield(a,'universeBytes') ...
                    && isfinite(a.universeBytes) ...
                    && isfield(b,'universeBytes') ...
                    && isfinite(b.universeBytes) ...
                    && double(a.universeBytes) ~= double(b.universeBytes)
                reasons(end+1,1) = "the basin-universe " + ...
                    "file size changed";
            end
            if isfield(a,'universeDateNum') ...
                    && isfinite(a.universeDateNum) ...
                    && isfield(b,'universeDateNum') ...
                    && isfinite(b.universeDateNum) ...
                    && abs(double(a.universeDateNum) - ...
                    double(b.universeDateNum)) > 1/86400
                reasons(end+1,1) = "the basin-universe " + ...
                    "file modification time changed";
            end
        end
    end

    same = isempty(reasons);

    function localCheckText(label,x,y,field)
        if nargin < 4
            field = label; 
        end
        if isfield(x,field) ...
                && isfield(y,field)
            if ~strcmpi(string(x.(field)),string(y.(field)))
                reasons(end+1,1) = string(label) + " changed";
            end
        end
    end

    function localCheckNumeric(label,x,y,field)
        if isfield(x,field) ...
                && isfield(y,field)
            xv = double(x.(field));
            yv = double(y.(field));
            if ~(isnan(xv) ...
                    && isnan(yv)) ...
                    && xv ~= yv
                reasons(end+1,1) = string(label) + " changed";
            end
        end
    end
end

function p = localResolveUniversePath(cfg,fileName)
    p = char(fileName);
    if isempty(p)
        return
    end
    if isfile(p)
        p = localCanonical(p);
        return
    end
    candidates = strings(0,1);
    if isfield(cfg,'SAGEhydro') ...
            && ~isempty(cfg.SAGEhydro) ...
            && isfield(cfg,'region') ...
            && ~isempty(cfg.region)
        try
            candidates(end+1,1) = fullfile( ...
                string(region_helpers('regiondir', ...
                cfg.SAGEhydro,cfg.region)), ...
                string(fileName));
        catch
        end
    end
    if isfield(cfg,'dirD') ...
            && ~isempty(cfg.dirD)
        candidates(end+1,1) = ...
            fullfile(string(cfg.dirD), ...
            string(fileName));
    end
    if isfield(cfg,'root') ...
            && ~isempty(cfg.root)
        candidates(end+1,1) = ...
            fullfile(string(cfg.root), ...
            string(fileName));
        candidates(end+1,1) = ...
            fullfile(string(cfg.root), ...
            'Data',string(fileName));
    end
    for k = 1:numel(candidates)
        if isfile(candidates(k))
            p = localCanonical(candidates(k));
            return
        end
    end
    if ~isempty(candidates)
        p = localCanonical(candidates(1));
    else
        p = localCanonical(p);
    end
end

function value = localTextField(S,name)
    value = "";
    if isfield(S,name) ...
            && ~isempty(S.(name))
        value = string(S.(name));
    end
end

function value = localNestedText(S,path)
    value = "";
    x = S;
    for k = 1:numel(path)
        if ~isstruct(x) ...
                || ~isfield(x,path{k})
            return
        end
        x = x.(path{k});
    end
    if ~isempty(x)
        value = string(x); 
    end
end

function value = localNestedNumeric(S,path,defaultValue)
    value = defaultValue;
    x = S;
    for k = 1:numel(path)
        if ~isstruct(x) ...
                || ~isfield(x,path{k})
            return
        end
        x = x.(path{k});
    end
    if isnumeric(x) ...
            && isscalar(x) ...
            && ~isempty(x)
        value = double(x);
    end
end

function p = localCanonical(p)
    p = char(string(p));
    if isempty(p)
        return
    end
    try
        p = char(java.io.File(p).getCanonicalPath());
    catch
        p = char(string(p));
    end
end

function tf = localValidMapLimits(latLim,lonLim)
    tf = isnumeric(latLim) ...
        && isnumeric(lonLim) ...
        && numel(latLim) == 2 ...
        && numel(lonLim) == 2 ...
        && all(isfinite(latLim)) ...
        && all(isfinite(lonLim)) ...
        && latLim(1) < latLim(2) ...
        && lonLim(1) < lonLim(2);
end

% =========================================================================
function D = local_meteo_display_metadata(ddMeteo,ddPrecip,ddTemp,ddPET,dt)
%LOCAL_METEO_DISPLAY_METADATA Capture GUI forcing labels for reporting.
%
% This structure is deliberately presentation-only. Numeric selections in
% misc.meteo remain the source used by the meteorological readers.

    D = struct();
    D.product = local_dropdown_display_text(ddMeteo);
    D.precip = local_dropdown_display_text(ddPrecip);
    D.temp = local_dropdown_display_text(ddTemp);
    D.pet = local_dropdown_display_text(ddPET);
    D.resolution = local_meteo_resolution_text(dt);

    D.summary = sprintf( ...
        'product=%s; precip=%s; temp=%s; PET=%s', ...
        D.product,D.precip,D.temp,D.pet);
end

% =========================================
function s = local_dropdown_display_text(h)
%LOCAL_DROPDOWN_DISPLAY_TEXT Return readable selected dropdown text.

    s = 'n/a';
    try
        if isempty(h) ...
                || ~isvalid(h)
            return
        end
        value = h.Value;
        s = char(string(value));
        try
            data = string(h.ItemsData);
            item = string(h.Items);
            hit = find(data == string(value),1);
            if ~isempty(hit) ...
                    && hit <= numel(item)
                s = char(item(hit));
            end
        catch
        end
        s = strtrim(s);
        % Remove only a leading numeric selector such as "1 " or "2: ".
        % Dataset names, source names, years, and units remain untouched.
        s = regexprep(s,'^\s*[+-]?\d+(?:\.\d+)?\s*[:\-]?\s*','');
        if isempty(s)
            s = 'n/a';
        end
    catch
        s = 'n/a';
    end
end

% ==========================================
function s = local_meteo_resolution_text(dt)
%LOCAL_METEO_RESOLUTION_TEXT Human-readable forcing resolution.

    switch double(dt)
        case 1
            s = 'daily';
        case 24
            s = 'hourly';
        case 96
            s = '15-minute';
        otherwise
            s = sprintf('%g time steps/day', ...
                double(dt));
    end
end
% =====================================================
function [ok,message] = local_required_period_dates(ui)
%LOCAL_REQUIRED_PERIOD_DATES Validate required split-period date fields.

    ok = false;
    message = ['Enter both a start date ' ...
        'and an end date for the selected ' ...
        'time-splitting method. ' ...
        'Dates must use dd/mm/yyyy.'];

    try
        method = lower(char(string(ui.ddSplitMethod.Value)));
        switch method
            case 'manual'
                startText = strtrim(char(string(ui.edDts.Value)));
                endText = strtrim(char(string(ui.edDte.Value)));
                periodName = 'training period';
            case 'deterministic_block'
                startText = strtrim(char(string(ui.edDBlockStart.Value)));
                endText = strtrim(char(string(ui.edDBlockEnd.Value)));
                periodName = 'deterministic-block period';
            case 'random_block'
                startText = strtrim(char(string(ui.edRBlockStart.Value)));
                endText = strtrim(char(string(ui.edRBlockEnd.Value)));
                periodName = 'random-block period';
            case 'random'
                startText = strtrim(char(string(ui.edRndStart.Value)));
                endText = strtrim(char(string(ui.edRndEnd.Value)));
                periodName = 'random-split period';
            case 'deterministic_kfold'
                startText = strtrim(char(string(ui.edDKFoldStart.Value)));
                endText = strtrim(char(string(ui.edDKFoldEnd.Value)));
                periodName = 'deterministic k-fold period';
            case 'random_kfold'
                startText = strtrim(char(string(ui.edRKFoldStart.Value)));
                endText = strtrim(char(string(ui.edRKFoldEnd.Value)));
                periodName = 'random k-fold period';
            case 'rainfall_block'
                startText = strtrim(char(string(ui.edRainBlockStart.Value)));
                endText = strtrim(char(string(ui.edRainBlockEnd.Value)));
                periodName = 'rainfall-block period';
            otherwise
                message = 'Select a valid time-splitting method.';
                return
        end

        if isempty(startText) ...
                || isempty(endText)
            message = sprintf(['Enter both the start date and end date ' ...
                'for the %s. Dates must use dd/mm/yyyy.'],periodName);
            return
        end

        ok = true;
        message = '';
    catch
    end
end
% ==============================================================
function [restored,fieldName] = local_restore_required_period_date( ...
    ui,src,event)
%LOCAL_RESTORE_REQUIRED_PERIOD_DATE Reject empty required date edits.

    restored = false;
    fieldName = 'Date';
    if isempty(src) ...
            || ~isprop(src,'Value') ...
            || ~isempty(strtrim(char(string(src.Value))))
        return
    end

    controls = { ...
        ui.edDts,'Training start'; ...
        ui.edDte,'Training end'; ...
        ui.edDBlockStart,'Start day'; ...
        ui.edDBlockEnd,'End day'; ...
        ui.edRBlockStart,'Start day'; ...
        ui.edRBlockEnd,'End day'; ...
        ui.edRndStart,'Start day'; ...
        ui.edRndEnd,'End day'; ...
        ui.edDKFoldStart,'Start day'; ...
        ui.edDKFoldEnd,'End day'; ...
        ui.edRKFoldStart,'Start day'; ...
        ui.edRKFoldEnd,'End day'; ...
        ui.edRainBlockStart,'Start day'; ...
        ui.edRainBlockEnd,'End day'};

    row = [];
    for ii = 1:size(controls,1)
        if isequal(src,controls{ii,1})
            row = ii;
            break
        end
    end
    if isempty(row)
        return
    end

    previousValue = '';
    try
        previousValue = char(string(event.PreviousValue));
    catch
    end
    previousValue = strtrim(previousValue);
    if isempty(previousValue)
        return
    end

    src.Value = previousValue;
    fieldName = controls{row,2};
    restored = true;
end

% ===========================================================
% SITE-only local helpers kept outside the main GUI function.
% Keeping these non-nested reduces MATLAB parser complexity.
% ===========================================================

function ids = site_default_attribute_ids(region)
    try
        A = attr_catalog(region_helpers('code',region));
        if isfield(A,'default_ids') ...
                && ~isempty(A.default_ids)
            ids = double(A.default_ids(:).');
        else
            ids = local_default_attr_ids();
        end
        if isfield(A,'selectable') ...
                && ~isempty(A.selectable)
            selectable = logical(A.selectable(:));
            ids = ids(ids>=1 & ids<=numel(selectable));
            ids = ids(selectable(ids));
        end
    catch
        ids = local_default_attr_ids();
    end
end

function site_configure_basin_layout(ui,tabBasins)
    % SITE Basins layout: one derived basin count, Min/Zone and Max Zones,
    % a bottom-strip Load basins action, a full-height training
    % table, and the Zone summary directly below it.

    % Preserve the inherited SAGE handles but force SITE's single loading mode.
    try
        ui.ddSample.Value = 'zone';
    catch
    end
    try
        ui.spKe.Value = 0;
        ui.spKe.Enable = 'off';
        ui.spKe.Visible = 'off';
    catch
    end

    % Capture the old sampling grid before moving zone controls out of it.
    sampleGrid = [];
    countsGrid = [];
    try
        sampleGrid = ui.ddSample.Parent;
    catch
    end

    % Stack Min/Zone and Max Zones under the basin-count controls.
    try
        g = ui.spKt.Parent;
        countsGrid = g;
        valueCol = ui.spKt.Layout.Column;
        if numel(valueCol) > 1
            valueCol = valueCol(end);
        end
        labelCol = max(1,valueCol-1);
        rowK = ui.ddKcns.Layout.Row;
        rowKt = ui.spKt.Layout.Row;
        try
            countDisplay = findobj(g,'Tag', ...
                'SITEAvailableBasinCount');
            if isempty(countDisplay)
                countDisplay = uieditfield(g,'numeric', ...
                    'Tag','SITEAvailableBasinCount', ...
                    'Editable','off', ...
                    'FontSize',ui.ddKcns.FontSize, ...
                    'Value',str2double(char(ui.ddKcns.Value)));
                countDisplay.Layout.Row = rowK;
                countDisplay.Layout.Column = valueCol;
            end
            ui.ddKcns.Visible = 'off';
        catch
        end
        % Keep the SAGE universe control as a read-only SITE basin count.
        try
            controls = {ui.ddKcns,'# basins'};
            children0 = g.Children;
            for kk=1:size(controls,1)
                c = controls{kk,1};
                ccol = c.Layout.Column;
                if numel(ccol)>1
                    ccol = ccol(1); 
                end
                for jj=1:numel(children0)
                    try
                        jcol = children0(jj).Layout.Column;
                        if numel(jcol)>1
                            jcol = jcol(1); 
                        end
                        if isa(children0(jj), ...
                                'matlab.ui.control.Label') ...
                                && children0(jj).Layout.Row ...
                                == c.Layout.Row ...
                                && jcol == max(1,ccol-1)
                            children0(jj).Text = controls{kk,2};
                            break
                        end
                    catch
                    end
                end
            end
        catch
        end
        rowMin = rowKt;
        rowMax = rowMin + 1;
        minLabelCol = labelCol; minValueCol = valueCol;
        maxLabelCol = labelCol; maxValueCol = valueCol;

        % SITE has no separate training/evaluation population. Preserve
        % their handles for shared callbacks, but remove both visible rows.
        try
            hiddenCounts = {ui.spKt,ui.spKe};
            children = g.Children;
            for kk=1:numel(hiddenCounts)
                control = hiddenCounts{kk};
                rHidden = control.Layout.Row;
                cHidden = control.Layout.Column;
                if numel(cHidden)>1
                    cHidden=cHidden(1); 
                end
                control.Visible = 'off';
                for ii=1:numel(children)
                    try
                        ccol = children(ii).Layout.Column;
                        if numel(ccol)>1
                            ccol=ccol(1); 
                        end
                        if isa(children(ii),'matlab.ui.control.Label') ...
                                && children(ii).Layout.Row == rHidden ...
                                && ccol == max(1,cHidden-1)
                            children(ii).Visible = 'off';
                        end
                    catch
                    end
                end
            end
            ui.spKe.Visible = 'off';
        catch
        end
        ui.ddKcns.Enable = 'off';

        ui.lblMinZone.Parent = g;
        ui.spMinPerZone.Parent = g;
        ui.lblMaxZones.Parent = g;
        ui.spMaxZones.Parent = g;
        ui.lblMinZone.Layout.Row = rowMin;
        ui.lblMinZone.Layout.Column = minLabelCol;
        ui.spMinPerZone.Layout.Row = rowMin;
        ui.spMinPerZone.Layout.Column = minValueCol;
        ui.lblMaxZones.Layout.Row = rowMax;
        ui.lblMaxZones.Layout.Column = maxLabelCol;
        ui.spMaxZones.Layout.Row = rowMax;
        ui.spMaxZones.Layout.Column = maxValueCol;

        % Keep one Load basins button in the bottom action strip.
        try
            ui.btnNewRandomSplit.Visible = 'off';
            bottomGrid = ui.btnValidate.Parent;
            ui.btnPrepare.Parent = bottomGrid;
            bottomButtons = {ui.btnValidate,ui.btnPrepare,ui.btnRun, ...
                ui.btnStop,ui.btnExportScript};
            for bb = 1:numel(bottomButtons)
                bottomButtons{bb}.Layout.Row = 1;
                bottomButtons{bb}.Layout.Column = bb;
            end
            bottomGrid.ColumnWidth = {'1x','1x','1x','1x','1x'};
        catch
        end
        ui.lblMinZone.Text = 'Min/Zone';
        ui.lblMaxZones.Text = 'Max Zones';
        ui.lblMinZone.Visible = 'on';
        ui.lblMaxZones.Visible = 'on';
        ui.spMinPerZone.Visible = 'on';
        ui.spMaxZones.Visible = 'on';

        % Match the label style already used by this SAGE-derived setup grid.
        refLabel = [];
        children = g.Children;
        for ii=1:numel(children)
            try
                if isa(children(ii),'matlab.ui.control.Label') ...
                        && children(ii).Layout.Row == rowK ...
                        && children(ii).Visible
                    refLabel = children(ii);
                    break
                end
            catch
            end
        end
        if ~isempty(refLabel)
            styleLabels = {ui.lblMinZone,ui.lblMaxZones};
            for jj=1:numel(styleLabels)
                h = styleLabels{jj};
                try h.FontName = refLabel.FontName; 
                catch
                end
                try h.FontSize = refLabel.FontSize; 
                catch
                end
                try h.FontWeight = refLabel.FontWeight; 
                catch
                end
                try h.FontColor = refLabel.FontColor; 
                catch
                end
                try 
                    h.HorizontalAlignment = ...
                        refLabel.HorizontalAlignment; 
                catch
                end
            end
        end

        rh = g.RowHeight;
        nRows = rowMax;
        if numel(rh) < nRows
            rh(end+1:nRows) = {'fit'};
        end
        for rr=1:nRows
            if rr > numel(rh) ...
                    || isempty(rh{rr})
                rh{rr} = 'fit';
            end
        end
        rh{rowMin} = 'fit';
        if rowMax ~= rowMin
            rh{rowMax} = 'fit'; 
        end
        rh{rowK} = 28;
        for rr=rowMax+1:numel(rh)
            rh{rr} = 0;
        end
        g.RowHeight = rh;

        % Three compact setup rows leave the rest of the tab for the table.
        try
            setupPanel = g.Parent;
            mainGrid = setupPanel.Parent;
            if isgraphics(mainGrid) ...
                    && isprop(mainGrid,'RowHeight')
                rSetup = setupPanel.Layout.Row;
                mainRH = mainGrid.RowHeight;
                if rSetup >= 1 ...
                        && rSetup <= numel(mainRH)
                    mainRH{rSetup} = 120;
                    mainGrid.RowHeight = mainRH;
                end
            end
        catch
        end
    catch
    end

    % Hide the old sampling/file/random controls. Min/Max zone controls were
    % reparented above, so the obsolete Sampling + zoning block can collapse.
    hiddenNames = {'ddSample','lblBasinFile', ...
        'edBasinFile','btnPickBasinFile', ...
        'lblBasinSeed','spBasinSeed', ...
        'lblBasinGenerator','txtBasinGenerator'};
    for ii=1:numel(hiddenNames)
        try 
            ui.(hiddenNames{ii}).Visible = 'off'; 
        catch
        end
    end
    try
        ui.btnNewRandomSplit.Visible = 'off';
    catch
    end
    try
        if ~isempty(sampleGrid) ...
                && isgraphics(sampleGrid) ...
                && (isempty(countsGrid) ...
                || ~isequal(sampleGrid,countsGrid))
            % If this is a distinct grid and no longer owns Min/Max controls,
            % the obsolete Sampling + zoning block can collapse completely.
            sampleGrid.Visible = 'off';
            parentGrid = sampleGrid.Parent;
            if isgraphics(parentGrid) ...
                    && isprop(parentGrid,'RowHeight')
                r = sampleGrid.Layout.Row;
                rh = parentGrid.RowHeight;
                if r >= 1 && r <= numel(rh)
                    rh{r} = 0;
                    parentGrid.RowHeight = rh;
                end
            end
        end
    catch
    end
    % If SAGE placed sampling controls in the same setup grid, collapse any
    % now-empty rows rather than leaving blank vertical gaps.
    try
        if ~isempty(sampleGrid) && ~isempty(countsGrid) ...
                && isequal(sampleGrid,countsGrid) ...
                && isprop(countsGrid,'RowHeight')
            rh = countsGrid.RowHeight;
            children = countsGrid.Children;
            for rr=1:numel(rh)
                occupied = false;
                for ii=1:numel(children)
                    try
                        col = children(ii).Layout.Column; %#ok<NASGU>
                        if children(ii).Visible ...
                                && any(children(ii).Layout.Row == rr)
                            occupied = true;
                            break
                        end
                    catch
                    end
                end
                if ~occupied
                    rh{rr} = 0;
                end
            end
            countsGrid.RowHeight = rh;
        end
    catch
    end

    % Training table occupies all space down to the Zone summary.
    try
        ui.gtblBasins.RowHeight = {20,'1x',0,0,80};
        ui.lblZoneCount.Parent.Padding = [4 10 4 4];
        ui.lblPlotTrain.Visible = 'on';
        ui.tblPlotTrain.Visible = 'on';
        ui.lblPlotEval.Visible = 'off';
        ui.tblPlotEval.Visible = 'off';
        try
            ui.lblEvalLegend.Visible = 'off';
        catch
        end
        host = ui.gtblBasins.Parent;
        if isprop(host,'RowHeight')
            row = ui.gtblBasins.Layout.Row;
            rh = host.RowHeight;
            if row >= 1 && row <= numel(rh)
                rh{row} = '1x';
                host.RowHeight = rh;
            end
        end
    catch
    end

    % Zone summary is always the final block on the SITE Basins tab.
    try
        ui.lblZoneSummary.Visible = 'on';
    catch
    end
    try
        ui.pnlZoneSummary.Visible = 'on';
        ui.pnlZoneSummary.BackgroundColor = ui.gtblBasins.Parent.BackgroundColor;
        ui.pnlZoneSummary.ForegroundColor = ...
            site_theme_foreground(ui.pnlZoneSummary.BackgroundColor);
    catch
    end

    % Remove any leftover evaluation-basin labels inherited from SAGE.
    try
        labels = findall(tabBasins,'Type','uilabel');
        for ii=1:numel(labels)
            try
                t = lower(char(string(labels(ii).Text)));
                if contains(t,'evaluation basins') ...
                        || strcmp(strtrim(t),'evaluation') ...
                        || contains(t,'sampling + zoning')
                    labels(ii).Visible = 'off';
                end
            catch
            end
        end
    catch
    end
end

function site_customize_notes_tab(tab,ui,fontsizeNotes,root)
    background = ancestor(tab,'figure').Color;
    intro = [ ...
        '<div style="text-align:center;font-size:20px;font-weight:700;">' ...
        'SITEhydrology: Basin-Specific Calibration and Benchmarking</div>' ...
        '<div style="margin-top:10px;font-size:' ...
        num2str(fontsizeNotes) 'px;line-height:1.32;">' ...
        'SITE calibrates conceptual hydrologic models independently ' ...
        'for each basin using SAGEhydrology source code. These ' ...
        'site-specific parameter fits provide a direct benchmark ' ...
        'for SAGE''s attribute-based parameter learning. ' ...
        'Use the configuration tabs to define the regional data, ' ...
        'model, loss function, and calibration settings.' ...
        '</div>'];
    figureText = [ ...
        '<div style="font-size:' num2str(fontsizeNotes) ...
        'px;line-height:1.28;">' ...
        'The diagram illustrates <b>SAGE</b>: a neural network maps ' ...
        'basin attributes to hydrologic-model parameters. ' ...
        '<b>SITE</b> uses the same model equations, data readers, and ' ...
        'analytic sensitivities, but optimizes a separate parameter ' ...
        'vector for each basin, without attribute or spatial context.' ...
        '</div>'];
    body = [ ...
        '<div style="padding-right:8px;font-size:' ...
        num2str(fontsizeNotes) 'px;line-height:1.32;">' ...
        '<p>Research on differentiable conceptual hydrologic models ' ...
        'began in November 2025 with analytic gradients for ODE-based ' ...
        'models [1]. SAGE builds on these sensitivities to train a ' ...
        'feedforward neural network across large basin samples [2]. ' ...
        'The framework was subsequently extended to hourly data [3] ' ...
        'and a graphical interface [4]. SITE was developed alongside ' ...
        'SAGE to ask a complementary question: how well can the same ' ...
        'model perform when calibrated separately at each basin?</p>' ...
        '<p>SITE is directly linked to SAGEhydrology and calls its ' ...
        'model, data-preparation, and sensitivity source code. It ' ...
        'shares SAGE''s meteorological and discharge inputs, model ' ...
        'definitions, parameter bounds, and loss functions. Users can ' ...
        'choose among seven calibration algorithms; each acts on the ' ...
        'hydrologic-model parameters directly, not on neural-network ' ...
        'weights.</p>' ...
        '<p>Results are organized by region, training/evaluation ' ...
        'period, meteorological forcing and PET choice, and model. ' ...
        'A model-specific Excel workbook has a sheet for each saved ' ...
        'metric. Each sheet records the best training score found so ' ...
        'far, its evaluation-period score, normalized and physical ' ...
        'parameter values, the loss function used for the fit, ' ...
        'optimizer, parameter-range ID, runtime, and update time. ' ...
        'Separate registries document period and parameter-range ' ...
        'definitions. The model-master workbook collects scores ' ...
        'across models for comparison.</p>' ...
        '<p>After a basin is trained for the selected loss function, ' ...
        'SITE also evaluates its other metrics. If any candidate ' ...
        'metric improves the corresponding stored score, SITE saves ' ...
        'that parameter vector for that metric; otherwise the ' ...
        'existing record remains. Repeated runs therefore build a ' ...
        'best-found, basin-specific benchmark for each model and ' ...
        'metric. Sharing compatible result files can strengthen ' ...
        'that benchmark over time, although a best-found score is ' ...
        'not proof of a global optimum.</p>' ...
        '<p>The performance gap between SITE''s basin-specific fits ' ...
        'and SAGE''s attribute-based fits tests how much predictive ' ...
        'skill is lost when parameters must be inferred from static ' ...
        'catchment attributes. A large gap would call into question ' ...
        'the information in those attributes or the learned mapping: ' ...
        'spatially smooth parameter fields alone are not evidence ' ...
        'of hydrologic realism, because the attributes themselves ' ...
        'can have strong spatial structure.</p>' ...
        '<p>The Map tab in Output &amp; Monitoring lets users inspect ' ...
        'the spatial pattern of a selected model parameter for each ' ...
        'loss function. Because SITE calibrates basins independently, ' ...
        'these patterns are obtained without imposing spatial ' ...
        'structure. Figure 5 of Tsai et al. (2021) [5] contrasts ' ...
        'parameters learned across basins with those obtained by ' ...
        'site-by-site calibration. SITE maps can likewise be compared ' ...
        'with SAGE''s attribute-conditioned parameter fields.</p>' ...
        '<p><b>References</b></p><ol>' ...
        '<li>Vrugt, J.A., Frame, J.M., and Bollman, E. (2026). ' ...
        'Reclaiming first principles: An analytic differentiable ' ...
        'framework for conceptual hydrologic models. ' ...
        '<i>Water Resources Research</i>. ' ...
        '<a href="#" onclick="return openRef(''https://arxiv.org/' ...
        'pdf/2602.06429'');">Preprint</a></li>' ...
        '<li>Vrugt, J.A. and Frame, J.M. (2026). SAGE: ' ...
        'Sensitivity-Aware Learning for Rapid Training of ' ...
        'Process-Based Hydrologic Models across Large Basin Samples. ' ...
        '<i>Hydrology and Earth System Sciences Discussions</i>. ' ...
        '<a href="#" onclick="return openRef(''https://' ...
        'egusphere.copernicus.org/preprints/2026/' ...
        'egusphere-2026-693'');">Preprint</a></li>' ...
        '<li>Vrugt, J.A., Frame, J.M., and Gao, Y. (2026). ' ...
        'Continental-scale hydrologic model training at hourly ' ...
        'resolution with sensitivity-aware gradient estimation. ' ...
        '<i>In preparation</i>.</li>' ...
        '<li>Vrugt, J.A. and Frame, J.M. (2026). SAGE GUI: Fast ' ...
        'and Flexible Differentiable Hydrologic Modeling with ' ...
        'Analytic Gradients. <i>Environmental Modelling &amp; ' ...
        'Software</i>. <a href="#" onclick="return openRef(''https://' ...
        'drive.google.com/file/d/1VDnJXse_6VvKpQOq26gk9Im1uBV4d1oQ/' ...
        'view?usp=drive_link'');">Preprint</a></li>' ...
        '<li>Tsai, W.-P. et al. (2021). From calibration to parameter ' ...
        'learning: Harnessing the scaling effects of big data in ' ...
        'geoscientific modeling. <i>Nature Communications</i>. ' ...
        '<a href="#" onclick="return openRef(''https://www.nature.com/' ...
        'articles/s41467-021-26107-z'');">Article</a></li>' ...
        '</ol>'];
    sigFile = fullfile(localDocsDir(root),'signature_jasper.png');
    sigHTML = '';
    if isfile(sigFile)
        sig64 = local_png_to_base64(sigFile);
        sigHTML = ['<img src="data:image/png;base64,' sig64 ...
            '" style="display:block;margin-top:2px;' ...
            'width:65px;height:auto;">'];
    end
    body = [body ...
        '<div style="margin-top:10px;">' ...
        '<p style="margin:0;">Jasper A. Vrugt</p>' ...
        '<p style="margin:1px 0 0 0;">' ...
        '&#9993;&nbsp;<a href="mailto:jasper@uci.edu">' ...
        'jasper@uci.edu</a></p>' ...
        sigHTML '</div></div>'];

    % The shared SAGE builder creates HTML components, not text areas.
    % Replace only SITE's visible introduction, diagram caption, and body.
    ui.htmlSageFigureText.HTMLSource = local_html_page(figureText,background);
    mainGrid = ui.htmlSageFigureText.Parent.Parent.Parent;
    children = mainGrid.Children;
    for ii = 1:numel(children)
        child = children(ii);
        if ~isprop(child,'HTMLSource')
            continue
        end
        if child.Layout.Row == 1
            child.HTMLSource = local_html_page(intro,background);
        elseif child.Layout.Row == 3
            child.HTMLSource = local_html_page(body,background);
        end
    end
    % Keep the first visible layout stable while the HTML renderer starts.
    % The extra sentence occupies the same row height used after resize.
    rows = mainGrid.RowHeight;
    rows{1} = 105;
    mainGrid.RowHeight = rows;
    siteResizeNotesIntro(ui);
end

function siteResizeNotesIntro(ui)
    % The short SITE introduction needs less height as the GUI widens.
    try
        mainGrid = ui.htmlSageFigureText.Parent.Parent.Parent;
        width = double(mainGrid.Position(3));
        if width < 100
            fig = ancestor(mainGrid,'figure');
            width = double(fig.Position(3)) - 30;
        end
        if width >= 650
            introHeight = 105;
        else
            introHeight = 130;
        end
        rows = mainGrid.RowHeight;
        rows{1} = introHeight;
        mainGrid.RowHeight = rows;
    catch
    end
end

function h = siteTrainLabel(grid,row,col,txt,fontSize)
    % Match the ordinary labels used before dropdowns/spinners on the other
    % configuration tabs: normal weight, standard UI font, left aligned.
    h = uilabel(grid,'Text',txt,'fontsize',fontSize, ...
        'FontWeight','normal','HorizontalAlignment','left');
    h.Layout.Row = row;
    h.Layout.Column = col;
end

function siteHideTab(tab)
    try
        if isempty(tab) ...
                || ~isvalid(tab)
            return
        end
        if isprop(tab,'Visible')
            tab.Visible = 'off';
        elseif ~isempty(tab.Parent)
            tab.Parent = [];
        end
    catch
        try
            tab.Parent = [];
        catch
        end
    end
end

function items = siteOptimizerItems()
    items = {'1 Projected gradient descent (PGD)', ...
        '2 Gauss-Newton', ...
        '3 Levenberg-Marquardt', ...
        '4 Adam', ...
        '5 L-BFGS-B (bounded quasi-Newton)', ...
        '6 Preconditioned conjugate gradient (PCG)', ...
        '7 Hybrid'};
end

function key = siteOptimizerKey(method)
    keys = {'pgd','gauss_newton','levenberg_marquardt','adam', ...
        'lbfgsb','pcg','hybrid'};
    method = max(1,min(7,round(double(method))));
    key = keys{method};
end

function names = siteOptimizerSearchTokens(method)
    switch round(double(method))
        case 1
            names = {'pgd','projected_gradient','projected gradient'};
        case 2
            names = {'gauss_newton','gauss-newton','gauss newton', ...
                'gaussnewton','_gn','gn_'};
        case 3
            names = {'levenberg','marquardt','_lm','lm_'};
        case 4
            names = {'adam'};
        case 5
            names = {'lbfgs','l-bfgs','bfgs'};
        case 6
            names = {'pcg','conjugate_gradient','conjugate gradient'};
        case 7
            names = {'hybrid'};
        otherwise
            names = {};
    end
end

function [opts,source] = siteOptimizerDefaults(method,~)
    source = 'optimizer_options_SITE.m';
    % optimizer_options_SITE is a direct compiled dependency. No runtime
    % MATLAB path changes are needed in either source or deployed mode.
    alg = struct('method',round(double(method)),'i_max',200);
    opts = optimizer_options_SITE(alg,0);
    opts = rmfield(opts,{'maxIter','stopFcn','iterFcn'});
end

function opts = siteTryExecuteDefaultOptsFile(fileName)
    % A standalone set_default_opts_* function is the most authoritative
    % source of GUI defaults. Call it with an empty struct when possible;
    % local/nested setters simply fall back to source parsing.
    opts = struct();
    try
        [folder,name,~] = fileparts(fileName);
        lname = lower(name);
        if ~contains(lname,'default') ...
                || ~contains(lname,'opt')
            return
        end
        oldPath = path;
        cleaner = onCleanup(@()path(oldPath));
        addpath(folder);
        out = feval(name,struct());
        if isstruct(out) ...
                && isscalar(out)
            opts = out;
            % Exclude obvious run-time state/callback fields.
            fields = fieldnames(opts);
            for kk = numel(fields):-1:1
                v = opts.(fields{kk});
                if isa(v,'function_handle') ...
                        || iscell(v) ...
                        || isstruct(v)
                    opts = rmfield(opts,fields{kk});
                end
            end
        end
    catch
        opts = struct();
    end
end

function opts = siteParseDefaultOptsFile(fileName)
    txt = fileread(fileName);
    opts = siteParseDefaultOptsText(txt,fileName);
end

function opts = siteParseDefaultOptsText(txt,fileName)
    opts = struct();
    if nargin < 2
        fileName = '';
    end

    % Join MATLAB continuation lines so defaults such as
    % opts.alpha0 = ...\n 1; are parsed as one assignment.
    txtFlat = regexprep(txt,'\.\.\.[ \t]*(\r?\n)[ \t]*',' ');
    tok = regexp(txtFlat, ...
        'opts\.([A-Za-z]\w*)\s*=\s*([^;\r\n]+)\s*;', ...
        'tokens');
    isDefaultFile = contains(lower(fileName),'default') ...
        || contains(lower(fileName),'opts');
    compact = regexprep(txtFlat,'\s+','');

    for ii=1:numel(tok)
        name = tok{ii}{1};
        expr = strtrim(tok{ii}{2});
        guard1 = sprintf('isfield(opts,''%s'')',name);
        guard2 = ['isfield(opts,"' name '")'];
        guarded = contains(compact,guard1) ...
            || contains(compact,guard2);
        if ~(guarded ...
                || isDefaultFile)
            continue
        end
        try
            val = eval(expr); % trusted local optimizer source
            % Exclude callbacks/internal state; expose user-settable controls.
            if isa(val,'function_handle') ...
                    || iscell(val) ...
                    || isstruct(val)
                continue
            end
            opts.(name) = val;
        catch
            % Preserve simple scalar/string expressions that depend on a local
            % constant; users can still see/edit the default text.
            if ~contains(expr,'@') ...
                    && ~contains(expr,'opts.')
                opts.(name) = expr;
            end
        end
    end
end

function D = siteOptsToTable(opts,method,rootDir,finisher)
    if nargin < 2, method = NaN;
    end
    if nargin < 3
        rootDir = '';
    end
    if nargin < 4
        finisher = '';
    end
    names = fieldnames(opts);
    if isempty(names)
        D = {'-', 'No settings for this optimizer', '-', '-', ''};
        return
    end
    D = cell(numel(names),5);
    for ii=1:numel(names)
        name = names{ii};
        value = opts.(name);
        [description,minValue,maxValue] = ...
            siteOptionMetadata(name,value,method,rootDir);
        D{ii,1} = siteOptionDisplaySymbol(name,method,finisher);
        D{ii,2} = description;
        D{ii,3} = minValue;
        D{ii,4} = maxValue;
        D{ii,5} = siteOptionValueText(value);
    end
end

function opts = siteWithoutIterationOption(opts)
    if isfield(opts,'maxIter')
        opts = rmfield(opts,'maxIter'); 
    end
    if isfield(opts,'stopFcn')
        opts = rmfield(opts,'stopFcn'); 
    end
    if isfield(opts,'iterFcn')
        opts = rmfield(opts,'iterFcn'); 
    end
end

function opts = siteNormalizeOptimizerOpts(saved,method,rootDir)
    [opts,~] = siteOptimizerDefaults(method,rootDir);
    names = fieldnames(opts);
    for ii=1:numel(names)
        name = names{ii};
        if isstruct(saved) ...
                && isfield(saved,name)
            opts.(name) = saved.(name);
        end
    end
    opts = siteWithoutIterationOption(opts);
end

function [methodOpts,sharedOpts] = siteSplitOpts(opts)
    methodOpts = struct();
    sharedOpts = struct();
    sharedNames = {'tolPG','tolRelF','b_eps','verbose'};
    names = fieldnames(opts);
    for ii=1:numel(names)
        name = names{ii};
        if any(strcmp(name,sharedNames))
            sharedOpts.(name) = opts.(name);
        else
            methodOpts.(name) = opts.(name);
        end
    end
end

function opts = siteMergeOptsTables( ...
    methodData,sharedData,methodNames,sharedNames)
    opts = siteTableToOpts(methodData,methodNames);
    shared = siteTableToOpts(sharedData,sharedNames);
    names = fieldnames(shared);
    for ii=1:numel(names)
        opts.(names{ii}) = shared.(names{ii});
    end
    opts = siteWithoutIterationOption(opts);
end

function symbol = siteOptionDisplaySymbol(name,method,finisher)
    symbol = char(name);
    if method == 7
        localMethod = 'L-BFGS-B';
        if strcmpi(finisher,'pgd')
            localMethod = 'PGD'; 
        end
        switch name
            case 'adam_maxIter'
                symbol = 'Adam: maxIter';
            case 'adam_alpha'
                symbol = 'Adam: alpha';
            case 'adam_beta1'
                symbol = 'Adam: beta_1';
            case 'adam_beta2'
                symbol = 'Adam: beta_2';
            case 'adam_eps'
                symbol = 'Adam: eps';
            case 'finish_maxIter'
                symbol = [localMethod ': maxIter'];
            case 'tolPG_finish'
                symbol = [localMethod ': tolPG'];
            case 'tolRelF_finish'
                symbol = [localMethod ': tolRelF'];
            case 'stallPG'
                symbol = 'Switch: stallPG';
            case 'stallStep'
                symbol = 'Switch: stallStep';
            case 'stallWindow'
                symbol = 'Switch: stallWindow';
            case 'minAdamIterBeforeSwitch'
                symbol = 'Switch: minAdamIter';
        end
        return
    end
    switch name
        case 'c1', symbol = 'c_1';
        case 'alpha0', symbol = 'alpha_0';
        case 'beta1', symbol = 'beta_1';
        case 'beta2', symbol = 'beta_2';
        case 'lambda0', symbol = 'lambda_0';
        case 'lambdaMin', symbol = 'lambda_min';
        case 'lambdaMax', symbol = 'lambda_max';
    end
end

function txt = siteOptionValueText(v)
    if ischar(v) || (isstring(v) && isscalar(v))
        txt = char(string(v));
    elseif islogical(v) && isscalar(v)
        txt = tern(v,'true','false');
    elseif isnumeric(v)
        if isscalar(v)
            value = double(v);
            if isfinite(value) && abs(value) >= 1e4
                parts = regexp(sprintf('%.16e',value), ...
                    '^(.+?)e([+-]?\d+)$','tokens','once');
                mantissa = regexprep(parts{1},'0+$','');
                mantissa = regexprep(mantissa,'\.$','');
                txt = sprintf('%se%+d',mantissa, ...
                    str2double(parts{2}));
            else
                txt = sprintf('%.16g',value);
            end
        else
            txt = mat2str(v,16);
        end
    else
        try txt = char(string(v)); catch, txt = '[]'; end
    end
end

function opts = siteTableToOpts(D,fieldNames)
    opts = struct();
    if isempty(D)
        return
    end
    if nargin < 2
        fieldNames = {}; 
    end
    valueColumn = 2;
    if size(D,2) >= 5
        valueColumn = 5;
    end
    for ii=1:size(D,1)
        if numel(fieldNames) >= ii
            name = char(string(fieldNames{ii}));
        else
            name = strtrim(char(string(D{ii,1})));
        end
        if isempty(name) ...
                || ~isvarname(name) 
            continue
        end
        raw = D{ii,valueColumn};
        if isnumeric(raw) ...
                || islogical(raw)
            val = raw;
        else
            txt = strtrim(char(string(raw)));
            if isempty(txt)
                val = [];
            elseif strcmpi(txt,'true')
                val = true;
            elseif strcmpi(txt,'false')
                val = false;
            else
                valNum = str2double(txt);
                if isfinite(valNum)
                    val = valNum;
                else
                    try 
                        val = eval(txt);
                    catch
                        val = txt; 
                    end
                end
            end
        end
        opts.(name) = val;
    end
end

function [description,minText,maxText] = ...
    siteOptionMetadata(name,value,~,~)
    key = regexprep(lower(char(name)),'[^a-z0-9]','');
    switch key
        case {'maxiter','maxiterations','imax'}
            description = 'Maximum number of optimizer iterations';
            lo = 1; hi = Inf;
        case {'tolpg','pgtol','tolprojectedgradient'}
            description = 'Stop when projected gradient norm is below this';
            lo = 0; hi = Inf;
        case {'tolrelf','reltolf','ftol','tolf'}
            description = 'Stop when relative loss change is below this';
            lo = 0; hi = Inf;
        case {'toleg','gtol','tolgrad','gradtol'}
            description = 'Gradient stopping tolerance';
            lo = 0; hi = Inf;
        case {'beps','boundeps','boundepsilon'}
            description = 'Buffer kept inside parameter bounds';
            lo = 0; hi = Inf;
        case {'c1','armijoc1'}
            description = 'Required loss decrease in line search';
            lo = 0; hi = 1;
        case {'lsrho','rho','linesearchrho'}
            description = ['Step shrink factor ' ...
                'after a rejected trial'];
            lo = 0; hi = 1;
        case {'lsmax','maxls','maxlinesearch'}
            description = ['Maximum trial steps ' ...
                'per line search'];
            lo = 1; hi = Inf;
        case {'alpha0','step0','initialstep'}
            description = ['First step length ' ...
                'tried in line search'];
            lo = 0; hi = Inf;
        case {'verbose','verbosity'}
            description = ['Print iteration ' ...
                'details (0 = no, 1 = yes)'];
            lo = 0; hi = 1;
        case {'lr','learningrate','eta'}
            description = ['Learning rate / ' ...
                'initial optimizer step size'];
            lo = 0; hi = Inf;
        case {'beta1','beta_1'}
            description = ['Smoothing of Adam ' ...
                'mean gradient'];
            lo = 0; hi = 1;
        case {'beta2','beta_2'}
            description = ['Smoothing of Adam ' ...
                'squared gradient'];
            lo = 0; hi = 1;
        case {'eps','epsilon','vareps'}
            description = ['Small denominator ' ...
                'offset for Adam'];
            lo = 0; hi = Inf;
        case {'lambda','lambda0','mu','mu0','damping','damping0'}
            description = 'Starting LM damping strength';
            lo = 0; hi = Inf;
        case {'lambdamin'}
            description = ['Lowest allowed LM ' ...
                'damping strength'];
            lo = 0; hi = Inf;
        case {'lambdamax'}
            description = ['Highest allowed LM ' ...
                'damping strength'];
            lo = 0; hi = Inf;
        case {'nu'}
            description = ['LM damping multiplier ' ...
                'after rejection'];
            lo = 1; hi = Inf;
        case {'ridge'}
            description = ['Small diagonal term ' ...
                'stabilizing Jacobian solve'];
            lo = 0; hi = Inf;
        case {'lambdaup','muup','dampingup'}
            description = ['Factor used to increase ' ...
                'damping after rejection'];
            lo = 1; hi = Inf;
        case {'lambdadown','mudown','dampingdown'}
            description = ['Factor used to decrease ' ...
                'damping after acceptance'];
            lo = 0; hi = 1;
        case {'m','memory','history','historysize'}
            description = ['Past update pairs kept ' ...
                'for curvature estimate'];
            lo = 1; hi = Inf;
        case {'alpha'}
            description = 'Adam learning rate';
            lo = 0; hi = Inf;
        case {'adammaxiter'}
            description = 'Maximum Adam warm-start iterations';
            lo = 1; hi = Inf;
        case {'adamalpha'}
            description = 'Adam warm-start learning rate';
            lo = 0; hi = Inf;
        case {'adambeta1'}
            description = 'Warm-start mean-gradient smoothing';
            lo = 0; hi = 1;
        case {'adambeta2'}
            description = 'Warm-start squared-gradient smoothing';
            lo = 0; hi = 1;
        case {'adameps'}
            description = 'Warm-start denominator safeguard';
            lo = 0; hi = Inf;
        case {'finishmaxiter'}
            description = 'Maximum local-finisher iterations';
            lo = 0; hi = Inf;
        case {'stallpg'}
            description = ['Gradient threshold ' ...
                'for warm-start stall'];
            lo = 0; hi = Inf;
        case {'stallstep'}
            description = ['Step-size threshold ' ...
                'for warm-start stall'];
            lo = 0; hi = Inf;
        case {'stallwindow'}
            description = ['Consecutive stalled ' ...
                'steps before switching'];
            lo = 1; hi = Inf;
        case {'minadamiterbeforeswitch'}
            description = 'Minimum Adam steps before finisher';
            lo = 0; hi = Inf;
        case {'finisher'}
            description = 'Local method after Adam: lbfgsb or pgd';
            minText = '-'; maxText = '-';
            return
        case {'tolpgfinish'}
            description = 'Finisher projected-gradient tolerance';
            lo = 0; hi = Inf;
        case {'tolrelffinish'}
            description = 'Finisher relative-loss tolerance';
            lo = 0; hi = Inf;
        case {'clipn','gradclip','clipnorm'}
            description = ['Gradient-norm clipping ' ...
                'threshold (0 = disabled)'];
            lo = 0; hi = Inf;
        case {'wdecay','weightdecay'}
            description = 'Weight-decay / regularization coefficient';
            lo = 0; hi = Inf;
        otherwise
            description = siteHumanizeOptionName(name);
            if islogical(value)
                lo = 0; hi = 1;
            elseif isnumeric(value) ...
                    && isscalar(value)
                if value >= 0
                    lo = 0; hi = Inf;
                else
                    lo = -Inf; hi = Inf;
                end
            else
                minText = '-'; 
                maxText = '-';
                return
            end
    end
    minText = siteLimitText(lo);
    maxText = siteLimitText(hi);
end

function txt = siteLimitText(v)
    if isinf(v)
        if v > 0
            txt = char(8734);
        else
            txt = ['-' char(8734)];
        end
    else
        txt = sprintf('%.8g',double(v));
    end
end

function value = siteParseLimit(raw)
    txt = strtrim(string(raw));
    if txt == string(char(8734))
        value = Inf;
    elseif txt == "-" + string(char(8734))
        value = -Inf;
    else
        value = str2double(txt);
    end
end

function txt = siteHumanizeOptionName(name)
    txt = regexprep(char(name),'_',' ');
    txt = regexprep(txt,'([a-z])([A-Z])','$1 $2');
    txt = strtrim(txt);
    if isempty(txt), txt = char(name); end
    txt(1) = upper(txt(1));
end

function txt = siteOptimizerHelp(method,~)
    method=max(1,min(7,round(double(method))));
    switch method
        case 1
            body = ['Projected gradient descent ' ...
                'follows the negative loss ' ...
                'gradient and projects every trial ' ...
                'point back onto the parameter bounds. ' ...
                'It is a simple first-order benchmark ' ...
                'and is useful for checking the ' ...
                'behavior of analytic gradients.'];
        case 2
            body = ['Gauss-Newton uses the residual ' ...
                'Jacobian to form a local ' ...
                'least-squares approximation. It is ' ...
                'most effective for smooth ' ...
                'objectives close to a well-behaved optimum.'];
        case 3
            body = ['Levenberg-Marquardt adds adaptive ' ...
                'damping to the Gauss-Newton ' ...
                'step. The damping stabilizes poorly ' ...
                'conditioned updates and moves ' ...
                'the method toward gradient descent when necessary.'];
        case 4
            body = ['Adam uses exponentially weighted ' ...
                'first and second gradient moments ' ...
                'to scale parameter updates. It is ' ...
                'robust to heterogeneous gradient ' ...
                'magnitudes and provides a useful ' ...
                'first-order alternative to curvature methods.'];
        case 5
            body = ['L-BFGS-B is a bounded limited-memory ' ...
                'quasi-Newton method. It builds ' ...
                'curvature information from recent ' ...
                'parameter/gradient differences while ' ...
                'respecting the hydrologic-model parameter bounds.'];
        case 6
            body = ['Preconditioned conjugate gradient ' ...
                'uses projected gradients and ' ...
                'conjugate search directions with ' ...
                'bound handling and backtracking line search. ' ...
                'Its opts structure controls convergence ' ...
                'tolerances and line-search behavior.'];
        otherwise
            body = ['The hybrid optimizer combines ' ...
                'complementary SITE search strategies ' ...
                'within one basin calibration. Its ' ...
                'opts structure determines the switching ' ...
                'and convergence behavior implemented ' ...
                'by the current hybrid minimizer.'];
    end
    txt = sprintf(['%s\n\nThe tables above show the ' ...
        'settings used by SITE. Edit only the ' ...
        'Default value column; Maximum iterations ' ...
        'is set at the top of this tab.'],body);
end

function v = localZeroToEmpty(v)
    v = double(v);
    if isempty(v) ...
            || ~isfinite(v) ...
            || v <= 0
        v = []; 
    end
end

function wanted = sitePreparedBasinNumbers(fileUniverse,basPrepared)
    raw = strip(readlines(fileUniverse));
    raw(raw=="" | startsWith(raw,"#"))=[];
    uk = siteGaugeKey(raw);
    pk = siteGaugeKey(string(basPrepared.id_gauge(:)));
    [tf,loc] = ismember(pk,uk);
    if ~all(tf)
        error('SITE_ui:PreparedBasinsNotInUniverse', ...
            ['One or more prepared training basins ' ...
            'are absent from the active universe file.']);
    end
    wanted = loc(:);
end

function key = siteGaugeKey(x)
    key = upper(strip(string(x(:))));
    key = regexprep(key,'[^A-Z0-9]','');
    numericOnly =~ cellfun('isempty', ...
        regexp(cellstr(key),'^[0-9]+$','once'));
    key(numericOnly) = regexprep(key(numericOnly), ...
        '^0+(?=[0-9])','');
end

function theta = siteExtractTheta(result,d)
    theta=[];
    if ~isstruct(result)
        return
    end
    direct = {'nTheta','ntheta','theta','Theta', ...
        'th','par','params','x','xbest','bestTheta'};
    for ii = 1:numel(direct)
        if isfield(result,direct{ii})
            v = result.(direct{ii});
            if isnumeric(v) ...
                    && numel(v)==d
                theta=double(v(:)); 
                return
            end
        end
    end
    nested = {'best','solution','optimum','final'};
    for ii = 1:numel(nested)
        if isfield(result,nested{ii}) ...
                && isstruct(result.(nested{ii}))
            theta = siteExtractTheta(result.(nested{ii}),d);
            if ~isempty(theta)
                return
            end
        end
    end
end

% ================
%  Nested builders
% ================

function siteWriteRunScript(fileName,C)
    % Prepare readable metadata before opening the destination file.
    modelText = local_model_name_from_id(C.model);
    regionCode = char(string(C.region));
    regionText = strrep(regionCode,'_','-');
    try
        regionName = region_helpers('name',regionCode);
        regionText = sprintf('%s (%s)',char(string(regionName)), ...
            regionText);
    catch
    end
    periodRows = local_export_period_rows(C.prd);
    lossText = lossName(C.loss.fnc);
    dataTypeText = local_export_data_type_text(C.loss);
    optimizerText = optName(C.alg.method);
    exportedText = char(datetime('now', ...
        'Format','dd-MMM-yyyy HH:mm:ss'));

    fid = fopen(fileName,'w','n','UTF-8');
    if fid < 0
        error('SITE_ui:ExportOpenFailed', ...
            'Could not open %s for writing.',fileName);
    end
    cleaner = onCleanup(@()fclose(fid));
    fprintf(fid,['%% ============================================' ...
        '=============================\n']);
    fprintf(fid,'%%   S I T E\n');
    fprintf(fid,'%%   Basin-Specific Calibration and Benchmarking of\n');
    fprintf(fid,'%%   Process-Based Hydrologic Models\n');
    fprintf(fid,['%% ============================================' ...
        '=============================\n']);
    fprintf(fid,'%%\n');
    fprintf(fid,'%% %-15s: %s\n','Model',modelText);
    fprintf(fid,'%% %-15s: %s\n','Region',regionText);
    fprintf(fid,'%% %-15s: %s\n','Resolution', ...
        localResolutionName(C.prd.dt));
    fprintf(fid,'%% %-15s: %d\n','Basins',numel(C.basinNumbers));
    for iRow = 1:size(periodRows,1)
        fprintf(fid,'%% %-15s: %s\n', ...
            periodRows{iRow,1},periodRows{iRow,2});
    end
    fprintf(fid,'%% %-15s: %s\n','Loss function',lossText);
    fprintf(fid,'%% %-15s: %s\n','Data type',dataTypeText);
    fprintf(fid,'%% %-15s: %s\n','Optimizer',optimizerText);
    fprintf(fid,'%% %-15s: %d\n','Trials',C.alg.n);
    fprintf(fid,'%% %-15s: %d\n','Max iterations',C.alg.i_max);
    fprintf(fid,'%% %-15s: %s\n','Exported',exportedText);
    fprintf(fid,'%%\n');
    fprintf(fid,['%% Generated by SITE-GUI. This script contains the ' ...
        'complete configuration\n']);
    fprintf(fid,['%% required to reproduce basin-specific ' ...
        'hydrologic-model calibration.\n']);
    fprintf(fid,'%%\n');
    fprintf(fid,['%% © 2026 Jasper A. Vrugt, ' ...
        'University of California, Irvine\n']);
    fprintf(fid,'%% ✉ jasper@uci.edu\n\n');
    fprintf(fid,'clear C\nC = struct();\n');
    siteWriteStructAssignments(fid,'C',C);
    fprintf(fid,'\n%%%% Run SITE\n');
    fprintf(fid,'addpath(fullfile(C.SITEhydro,''src''));\n');
    fprintf(fid,'output = run_SITE(C);\n');
    clear cleaner
end

function siteWriteLiveScript(fileName,C)
    templateFile = siteFindLiveScriptTemplate(C);
    blocks = siteLiveScriptBlocks(C);
    % A final newline creates a visible empty line inside each code cell.
    for iBlock = 1:numel(blocks)
        blocks{iBlock} = regexprep(blocks{iBlock},'[\r\n]+$','');
    end
    sage_write_mlx(templateFile,fileName,blocks);
end

function blocks = siteLiveScriptBlocks(C)
    blocks = cell(1,10);
    blocks{1} = sprintf('selectedModel = %s;\n', ...
        siteMatlabLiteral(C.model));
    blocks{2} = sprintf([ ...
        'basinNumbers = %s;\nuseParallel = %s;\n' ...
        'numWorkers = %s;\nnumberOfTrials = %s;\n' ...
        'maximumIterations = %s;\n'], ...
        siteMatlabLiteral(C.basinNumbers), ...
        siteMatlabLiteral(C.parallel), ...
        siteMatlabLiteral(C.numWorkers), ...
        siteMatlabLiteral(C.alg.n), ...
        siteMatlabLiteral(C.alg.i_max));
    blocks{3} = ['C = struct();' newline ...
        siteAssignmentsText(C, ...
        {'root','SITEhydro','SAGEhydro','region', ...
        'dirD','dirM','dirQ','file_univ'}) ...
        sprintf('addpath(fullfile(C.SITEhydro,''src''));\n')];
    blocks{4} = ['C.model = selectedModel;' newline ...
        siteAssignmentsText(C,{'mcode'})];
    blocks{5} = siteAssignmentsText(C,{'prd'});
    blocks{6} = siteAssignmentsText(C,{'meteo'});
    blocks{7} = [siteAssignmentsText(C, ...
        {'loss','alg','ode','parOverride'}) ...
        sprintf('C.alg.n = numberOfTrials;\n') ...
        sprintf('C.alg.i_max = maximumIterations;\n')];
    covered = {'root','region','dirD','dirM','dirQ','file_univ', ...
        'model','mcode','prd','meteo','loss','alg','ode', ...
        'parOverride','parallel','numWorkers','maxPending', ...
        'saveEvery','resultDir','basinNumbers'};
    extraFields = setdiff(fieldnames(C),covered,'stable');
    blocks{8} = [siteAssignmentsText(C, ...
        [{'parallel','numWorkers','maxPending', ...
          'saveEvery','resultDir'},extraFields(:).']) ...
        sprintf('C.parallel = useParallel;\n') ...
        sprintf('C.numWorkers = numWorkers;\n') ...
        sprintf('C.basinNumbers = basinNumbers;\n')];
    blocks{9} = sprintf('output = run_SITE(C);\n');
    blocks{10} = sprintf([ ...
        'fprintf(''SITE run completed for %%s.\\n'', ' ...
        'string(C.model));\n']);
end

function txt = siteAssignmentsText(C,fields)
    temporaryScript = [tempname '.m'];
    cleanup = onCleanup(@()siteDeleteTemporaryScript(temporaryScript));
    fid = fopen(temporaryScript,'w');
    if fid < 0
        error('SITE_ui:ExportOpenFailed', ...
            'Could not open temporary SITE script.');
    end
    fileCleanup = onCleanup(@()fclose(fid));
    for k = 1:numel(fields)
        name = fields{k};
        if isfield(C,name)
            siteWriteStructAssignments(fid,'C', ...
                struct(name,C.(name)));
        end
    end
    clear fileCleanup
    txt = fileread(temporaryScript);
    clear cleanup
end

function templateFile = siteFindLiveScriptTemplate(C)
    name = 'demo_SITE.mlx';
    appDir = fileparts(mfilename('fullpath'));
    candidates = { ...
        fullfile(char(C.SITEhydro),'examples',name), ...
        fullfile(appDir,'..','examples',name)};
    if isdeployed
        candidates = [candidates, { ...
            fullfile(ctfroot,'examples',name), ...
            fullfile(ctfroot,'SITEhydrology','examples',name)}];
        try
            packagedFile = which(fullfile('examples',name));
            if isempty(packagedFile)
                packagedFile = which(name);
            end
            if ~isempty(packagedFile)
                candidates = [{packagedFile},candidates];
            end
        catch
        end
    end
    for k = 1:numel(candidates)
        if isfile(candidates{k})
            templateFile = candidates{k};
            return
        end
    end
    error('SITE_ui:MissingLiveScriptTemplate', ...
        'SITE Live Script template not found: %s.',name);
end

function siteDeleteTemporaryScript(fileName)
    if isfile(fileName)
        delete(fileName);
    end
end

function siteWriteStructAssignments(fid,prefix,S0)
    names = fieldnames(S0);
    for ii=1:numel(names)
        name = names{ii};
        value = S0.(name);
        target = [prefix '.' name];
        if isstruct(value) && isscalar(value)
            if isempty(fieldnames(value))
                fprintf(fid,'%s = struct();\n',target);
            else
                siteWriteStructAssignments(fid,target,value);
            end
        else
            fprintf(fid,'%s = %s;\n',target,siteMatlabLiteral(value));
        end
    end
end

function txt = siteMatlabLiteral(value)
    if isempty(value)
        if iscell(value)
            txt = '{}';
        elseif ischar(value)
            txt = '''''';
        else
            txt = '[]';
        end
        return
    end
    if ischar(value)
        txt = ['''' strrep(value,'''','''''') ''''];
    elseif isstring(value)
        if isscalar(value)
            v = char(value);
            txt = ['''' strrep(v,'''','''''') ''''];
        else
            c = cellstr(value(:));
            parts = cellfun(@(v)['''' strrep(v,'''','''''') ''''], ...
                c,'UniformOutput',false);
            txt = ['{' strjoin(parts,',') '}'];
        end
    elseif isnumeric(value)
        txt = mat2str(value,17);
    elseif islogical(value)
        if isscalar(value)
            txt = tern(value,'true','false');
        else
            txt = ['logical(' mat2str(double(value)) ')'];
        end
    elseif iscell(value)
        parts = cell(size(value));
        for jj=1:numel(value)
            parts{jj} = siteMatlabLiteral(value{jj});
        end
        if isvector(value)
            txt = ['{' strjoin(parts(:).',',') '}'];
        else
            rows = cell(size(value,1),1);
            for rr=1:size(value,1)
                rows{rr} = strjoin(parts(rr,:),',');
            end
            txt = ['{' strjoin(rows,';') '}'];
        end
    elseif isa(value,'datetime')
        txt = sprintf('datetime(''%s'')',char(value));
    else
        error('SITE_ui:ExportUnsupportedType', ...
            'Cannot export configuration value of class %s.',class(value));
    end
end
