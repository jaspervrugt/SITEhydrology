function names = site_parameter_names(symbols)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%SITE_PARAMETER_NAMES Convert LaTeX model symbols to table-safe names.
%
% SYNOPSIS:
%   names = site_parameter_names(symbols)
%
% INPUT ARGUMENTS:
%   symbols         original model-parameter symbols
%
% OUTPUT ARGUMENTS:
%   names           valid, readable MATLAB table variable names
%
% NOTES:
%   The original symbols remain unchanged in the parameter-range registry.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

symbols = string(symbols(:));
names = strings(size(symbols));

for i = 1:numel(symbols)
    name = char(symbols(i));
    name = strrep(name,'$','');
    name = regexprep(name,'\\mathrm\s*\{([^}]*)\}','$1');
    name = regexprep(name,'\\rm\s*','');
    name = regexprep(name,'\\([A-Za-z]+)','$1');
    name = strrep(name,',','_');
    name = strrep(name,'{','');
    name = strrep(name,'}','');
    name = regexprep(name,'\s+','');
    name = regexprep(name,'_+','_');
    name = regexprep(name,'^_|_$','');
    names(i) = string(matlab.lang.makeValidName(name));
end

names = string(matlab.lang.makeUniqueStrings(cellstr(names)));
end
