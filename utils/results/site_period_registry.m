function [periodID,period] = site_period_registry(resultDir,dtTag,prd,register)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SITE_PERIOD_REGISTRY Resolve a SITE train/evaluation period identifier.
%
% SYNOPSIS:
%   [periodID,period] = site_period_registry(resultDir,dtTag,prd,register)
%
% INPUT ARGUMENTS:
%   resultDir       regional, resolution-specific result directory
%   dtTag           temporal-resolution label
%   prd             training, evaluation, and spin-up dates
%   register        add a new period when no match exists
%
% OUTPUT ARGUMENTS:
%   periodID        identifier of the matching period
%   period          normalized period definition
%
% NOTES:
%   One registry is shared by models and meteorological choices.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if nargin < 4, register = false; end
period = local_period(prd,dtTag);
file = fullfile(resultDir,'train_eval_periods.csv');
if isfile(file)
    T = readtable(file,'TextType','string');
    required = {'period_id','signature'};
    if ~all(ismember(required,T.Properties.VariableNames))
        error('SITE:PeriodRegistryInvalid', ...
            'Unexpected columns in %s.',file);
    end
else
    T = table(zeros(0,1),strings(0,1),strings(0,1), ...
        strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
        zeros(0,1),'VariableNames',{'period_id','signature', ...
        'train_start','train_end','eval_start','eval_end', ...
        'method','spinup_days'});
end
hit = find(T.signature == period.signature,1);
if ~isempty(hit)
    periodID = double(T.period_id(hit));
    return
end
periodID = max([0;double(T.period_id)]) + 1;
if register
    if ~isfolder(resultDir), mkdir(resultDir); end
    row = {periodID,period.signature,period.trainStart, ...
        period.trainEnd,period.evalStart,period.evalEnd, ...
        period.method,period.spinup};
    T = [T; cell2table(row,'VariableNames',T.Properties.VariableNames)];
    writetable(T,file);
end
end

function period = local_period(prd,dtTag)
fields = {'method','spinup','dts','dte','des','dee'};
if ~isfield(prd,'method') || ~strcmpi(string(prd.method),'manual')
    fields = [fields,{'ds','de','block_size','train_frac', ...
        'seed','n_folds','fold'}];
end
canonical = struct('dt',char(string(dtTag)));
for i = 1:numel(fields)
    name = fields{i};
    if isfield(prd,name)
        value = prd.(name);
    else
        value = [];
    end
    if isstring(value), value = char(value); end
    canonical.(name) = value;
end
period.signature = string(jsonencode(canonical));
period.method = string(canonical.method);
period.spinup = double(canonical.spinup);
period.trainStart = local_date(canonical.dts);
period.trainEnd = local_date(canonical.dte);
period.evalStart = local_date(canonical.des);
period.evalEnd = local_date(canonical.dee);
end

function result = local_date(dmy)
result = "";
if isnumeric(dmy) && numel(dmy) == 3 && all(isfinite(dmy))
    result = string(sprintf('%04d-%02d-%02d',dmy(3),dmy(2),dmy(1)));
end
end
