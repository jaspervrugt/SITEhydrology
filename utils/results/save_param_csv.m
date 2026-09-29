function save_param_csv(param,file_param)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SAVE_PARAM_CSV Save basin parameters and best NSE scores to CSV.
%
% SYNOPSIS: save_param_csv(param,file_param)
%
% INPUT ARGUMENTS:
%   param       basin IDs, best scores, and optimum parameters
%   file_param  output filename
%
% OUTPUT ARGUMENTS:
%   None; the function writes file_param.
%
% NOTES:
%   USGS_ID is retained as the on-disk column for legacy files.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Written by Jasper A. Vrugt
% UC Irvine
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

d = size(param.theta,2);

T = table(param.USGS_ID, param.NSEt_best, param.NSEv_best, ...
    'VariableNames', {'USGS_ID','NSEt_best','NSEv_best'});

for j = 1:d
    T.("theta_"+j) = param.theta(:,j);
end

writetable(T,file_param);
end
