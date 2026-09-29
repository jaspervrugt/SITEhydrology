function param = load_or_init_param(file_param,IDs,d)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%LOAD_OR_INIT_PARAM Load a regional basin-parameter table.
%
% SYNOPSIS: param = load_or_init_param(file_param,IDs,d)
%
% INPUT ARGUMENTS:
%   file_param  filename overview file NSEt/NSEv for all models & basins
%   IDs         Kx1 list of regional basin IDs
%   d           # model parameters
%
% OUTPUT ARGUMENTS:
%   param       parameter values and scores for all requested basins
%
% NOTES:
%   USGS_ID is retained as the on-disk column for legacy files.
% FILE FORMAT:
%   USGS_ID   NSEt_best   NSEv_best   range_id   theta_1 ... theta_d
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

IDs = string(IDs(:));
IDs = sort(IDs);
K = numel(IDs);

% -------------------------
% initialize default struct
% -------------------------
param = struct();
param.USGS_ID = IDs;
param.NSEt_best = nan(K,1);
param.NSEv_best = nan(K,1);
param.range_id = nan(K,1);

for j = 1:d
    param.(sprintf('theta_%d',j)) = nan(K,1);
end

% -------------------------
% read existing file if any
% -------------------------
if ~isfile(file_param)
    return
end

T = readtable(file_param, ...
    'VariableNamingRule','preserve');

if ~ismember('USGS_ID',T.Properties.VariableNames)
    warning(['      Warning: load_or_init_param: file "%s" has ' ...
        'no USGS_ID column. Reinitializing.'],file_param);
    return
end

oldID = string(T.USGS_ID(:));
[tf,loc] = ismember(IDs,oldID);

if ismember('NSEt_best',T.Properties.VariableNames)
    x = nan(K,1);
    x(tf) = double(T.NSEt_best(loc(tf)));
    param.NSEt_best = x;
end

if ismember('NSEv_best',T.Properties.VariableNames)
    x = nan(K,1);
    x(tf) = double(T.NSEv_best(loc(tf)));
    param.NSEv_best = x;
end

if ismember('range_id',T.Properties.VariableNames)
    x = nan(K,1);
    x(tf) = double(T.range_id(loc(tf)));
    param.range_id = x;
end

for j = 1:d
    vn = sprintf('theta_%d',j);
    if ismember(vn,T.Properties.VariableNames)
        x = nan(K,1);
        x(tf) = double(T.(vn)(loc(tf)));
        param.(vn) = x;
    end
end

end
