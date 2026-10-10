function range_id = get_or_register_param_range(file_param_ranges, ...
    par_names,th_min,th_max)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%GET_OR_REGISTER_PARAM_RANGE Register parameter bounds and return range ID
%
% SYNOPSIS:
%  range_id = get_or_register_param_range(file_param_ranges, ...
%      par_names,th_min,th_max)
%
% INPUT ARGUMENTS:
%   file_param_ranges   csv file with stored parameter ranges
%   par_names           dx1 string/cell array with parameter names
%   th_min              dx1 vector with lower bounds
%   th_max              dx1 vector with upper bounds
%
% OUTPUT ARGUMENTS:
%   range_id            integer identifier of parameter-range set
%
% NOTES:
%   File format:
%   range_id   n_par   symbol   th_min   th_max
%
% Each parameter range set occupies d rows, one row per parameter.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

par_names = string(par_names(:));
th_min = double(th_min(:));
th_max = double(th_max(:));
d = numel(par_names);
assert(all(isfinite(th_min)&isfinite(th_max)&th_min<th_max), ...
    'SITE:InvalidParameterRange','Bounds must be finite and strictly increasing.');

if numel(th_min) ~= d ...
        || numel(th_max) ~= d
    error(['      Error: get_or_register_param_range: ' ...
        'Size mismatch between parameter names and bounds.']);
end

% -----------------------------------------------------------
% Read existing parameter-range table or initialize empty one
% -----------------------------------------------------------
if isfile(file_param_ranges)
    T = readtable(file_param_ranges, ...
        'VariableNamingRule','preserve');
else
    T = table( ...
        zeros(0,1), ...
        zeros(0,1), ...
        strings(0,1), ...
        zeros(0,1), ...
        zeros(0,1), ...
        'VariableNames',{'range_id','n_par', ...
        'symbol','th_min','th_max'});
end

% ------------------------------------------------
% Force expected variable types for existing table
% ------------------------------------------------
req = {'range_id','n_par', ...
    'symbol','th_min','th_max'};
if ~all(ismember(req,T.Properties.VariableNames))
    error(['      Error: get_or_register_param_range: ' ...
        'Existing file has unexpected columns.']);
end

T.range_id = double(T.range_id);
T.n_par = double(T.n_par);
T.symbol = string(T.symbol);
T.th_min = double(T.th_min);
T.th_max = double(T.th_max);

% A parameter-schema change (for example GCHM 36 -> 30 parameters) is not
% another range configuration. Retire the obsolete registry so active files
% contain only the current model's parameters. The timestamped backup keeps
% the historical registry recoverable.
if ~isempty(T)
    idsExisting = unique(T.range_id(:)).';
    schemaMatch = false;
    for ridExisting = idsExisting
        Ti = T(T.range_id == ridExisting,:);
        [~,ordExisting] = sort(Ti.n_par);
        Ti = Ti(ordExisting,:);
        if height(Ti) == d ...
                && isequal(string(Ti.symbol(:)),par_names)
            schemaMatch = true;
            break
        end
    end
    if ~schemaMatch
        backup = local_backup_name(file_param_ranges);
        [ok,message] = movefile(file_param_ranges,backup,'f');
        if ~ok
            error('SITE:ParameterRangeMigrationFailed', ...
                'Cannot archive obsolete parameter ranges: %s',message);
        end
        fprintf('SITE: archived obsolete parameter ranges to %s.\n',backup);
        T = T([],:);
    end
end

% --------------------------
% Check whether range exists
% --------------------------
range_id = NaN; %#ok

if ~isempty(T)
    ids = unique(T.range_id(:)).';
    for rid = ids

        Ti = T(T.range_id == rid,:);
        if height(Ti) ~= d
            continue
        end

        [~,ord] = sort(Ti.n_par);
        Ti = Ti(ord,:);

        same_names = isequal(string( ...
            Ti.symbol(:)),par_names);
        same_min = isequal(double(Ti.th_min(:)),th_min);
        same_max = isequal(double(Ti.th_max(:)),th_max);

        if same_names && same_min && same_max
            range_id = rid;
            return
        end
    end
end

% ----------------------------
% Register new parameter range
% ----------------------------
if isempty(T)
    range_id = 1;
else
    range_id = max(double(T.range_id)) + 1;
end

Tnew = table( ...
    repmat(double(range_id),d,1), ...
    (1:d).', ...
    string(par_names), ...
    double(th_min), ...
    double(th_max), ...
    'VariableNames',{'range_id','n_par', ...
    'symbol','th_min','th_max'});

T = [T; Tnew];

% force correct column types before writing
T.range_id = double(T.range_id);
T.n_par = double(T.n_par);
T.symbol = string(T.symbol);
T.th_min = double(T.th_min);
T.th_max = double(T.th_max);

writetable(T,file_param_ranges);
end

function backup = local_backup_name(file)
[folder,name,ext] = fileparts(file);
stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
backup = fullfile(folder,[name '_obsolete_' stamp ext '.bak']);
end
