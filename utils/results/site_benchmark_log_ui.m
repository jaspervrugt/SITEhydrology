function site_benchmark_log_ui(logFcn,message)
% Short benchmark status lines aligned with SITE checkpoint messages.
message=char(string(message));
message=strrep(message,'Shared benchmarks: automatically submitting completed default-setting fits for verification; verified improvements can update GitHub.', ...
    'Shared benchmarks: submitting completed fits for verification. Verified improvements update GitHub.');
message=strrep(message,'Shared benchmarks: downloaded latest verified results; ', ...
    'Shared benchmarks: latest verified results downloaded. ');
message=strrep(message,'Shared benchmarks: pending results can retry after SITE closes while you are signed in to Windows.', ...
    'Shared benchmarks: pending results queued for retry. Retry can continue after SITE closes while Windows remains signed in.');
message=strrep(message,'Shared benchmarks: submission was not completed. The pending results are preserved locally for retry.', ...
    'Shared benchmarks: submission incomplete. Pending results are saved locally for retry.');
message=strrep(message,'Shared benchmarks: proposed update submitted: ', ...
    'Shared benchmarks: contribution submitted. ');
% Split only sentence endings followed by whitespace, never URL dots.
lines=regexp(message,'(?<=[.])\s+|;\s+','split');
for k=1:numel(lines)
    if ~isempty(strtrim(lines{k}))
        logFcn(['    ' strtrim(lines{k})]);
    end
end
end
