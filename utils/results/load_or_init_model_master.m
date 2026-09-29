function model_master = load_or_init_model_master(file_model_master, ...
    IDs,model_names)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LOAD_OR_INIT_MODEL_MASTER Load or initialize master performance table
%
% SYNOPSIS:
%  model_master = load_or_init_model_master(file_model_master, ...
%       IDs,model_names)
%
% INPUT ARGUMENTS:
%   file_model_master   full path to master CSV file
%   IDs                 Kx1 list of regional basin IDs
%   model_names         cell or string list of model names
%
% OUTPUT ARGUMENTS:
%   model_master        table with one row per basin
%
% NOTES:
%   USGS_ID is retained as the on-disk column for legacy files.
% FILE FORMAT:
%   USGS_ID
%   NSEt_<model1>  NSEv_<model1>  range_id_<model1>
%   NSEt_<model2>  NSEv_<model2>  range_id_<model2>
%   ...
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    IDs = string(IDs(:));
    K = numel(IDs);
    model_names = string(model_names(:));
    
    % -------------------------
    % Build target table layout
    % -------------------------
    model_master = table();
    model_master.USGS_ID = IDs;
    [model_master.USGS_ID,~] = sort(model_master.USGS_ID);
    
    for i = 1:numel(model_names)
        m = matlab.lang.makeValidName( ...
            char(model_names(i)));
        model_master.(['NSEt_' m]) = nan(K,1);
        model_master.(['NSEv_' m]) = nan(K,1);
        model_master.(['range_id_' m]) = nan(K,1);
    end
    
    % -------------------------
    % Load existing file if any
    % -------------------------
    if ~isfile(file_model_master)
        writetable(model_master, ...
            file_model_master);
        return
    end
    
    Told = readtable(file_model_master, ...
        'VariableNamingRule','preserve');
    
    if ~ismember('USGS_ID',Told.Properties.VariableNames)
        warning(['      Warning: load_or_init_model_master: ' ...
            'existing file missing ' ...
            'USGS_ID. Reinitializing file.']);
        writetable(model_master, ...
            file_model_master);
        return
    end
    
    Told.USGS_ID = string(Told.USGS_ID(:));
    
    % -------------------------
    % Copy matching old columns
    % -------------------------
    [tf,loc] = ismember(model_master.USGS_ID, ...
        Told.USGS_ID);
    
    for j = 1:numel(model_master.Properties.VariableNames)
        vn = model_master.Properties.VariableNames{j};
    
        if strcmp(vn,'USGS_ID')
            continue
        end
    
        if ismember(vn,Told.Properties.VariableNames)
            oldv = Told.(vn);
            v = nan(K,1);
    
            try
                v(tf) = double(oldv(loc(tf)));
            catch ME
                warning(['      Warning: load_or_init_model_master: ' ...
                    'could not read ' ...
                    'column "%s" from existing file (%s).'], ...
                    vn,ME.message);
            end
    
            model_master.(vn) = v;
        end
    end
    
    % --------------------------
    % Write back normalized file
    % --------------------------
    writetable(model_master,file_model_master);
end
