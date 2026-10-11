function message=site_log_context(message,isRunning)
% Standalone GUI actions align left; numbered-run detail retains indentation.
message=char(string(message));
if ~isRunning&&startsWith(message,'     ')
    message=strtrim(message);
end
end
