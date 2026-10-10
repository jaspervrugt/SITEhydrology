param(
    [ValidateSet('Sync','SaveCredential','Install','Library')][string]$Action='Sync',
    [string]$StateRoot=(Join-Path $env:LOCALAPPDATA 'SITEhydrology\benchmark-sync')
)
$ErrorActionPreference='Stop'
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$Utf8=New-Object System.Text.UTF8Encoding($false)
$Repo='jaspervrugt/SITEhydrology'
$ApiRoot='https://api.github.com/repos/'+$Repo
function Write-Atomic([string]$Path,[string]$Text) {
    $parent=Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $temp=Join-Path $parent ([Guid]::NewGuid().ToString()+'.tmp')
    try {
        [IO.File]::WriteAllText($temp,$Text,$Utf8)
        if([IO.File]::Exists($Path)){$backup=$temp+".previous";[IO.File]::Replace($temp,$Path,$backup);[IO.File]::Delete($backup)}
        else{[IO.File]::Move($temp,$Path)}
    } finally {if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}
function Get-Digest([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try {return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}
    finally {$sha.Dispose()}
}
function Convert-Canonical($Value) {
    if($null -eq $Value){return $null}
    if($Value -is [System.Collections.IDictionary]) {
        $out=[ordered]@{}
        foreach($key in @($Value.Keys | Sort-Object)){ $out[$key]=Convert-Canonical $Value[$key] }
        return $out
    }
    if($Value -is [pscustomobject]) {
        $out=[ordered]@{}
        foreach($key in @($Value.PSObject.Properties.Name | Sort-Object)){ $out[$key]=Convert-Canonical $Value.$key }
        return $out
    }
    if(($Value -is [System.Collections.IEnumerable]) -and !($Value -is [string])) {
        $out=@();foreach($item in $Value){$out+=,(Convert-Canonical $item)}
        return ,$out
    }
    return $Value
}
function Get-ProfileJson($Value) {
    $identity=Convert-Canonical $Value
    $identity.Remove('thMin');$identity.Remove('thMax')
    return ($identity | ConvertTo-Json -Depth 100 -Compress)
}
function Get-CanonicalJson($Value){return (Convert-Canonical $Value | ConvertTo-Json -Depth 100 -Compress)}
function Save-Credential([string]$Text) {
    Add-Type -AssemblyName System.Security
    $bytes=$Utf8.GetBytes($Text)
    try {
        $encrypted=[Security.Cryptography.ProtectedData]::Protect($bytes,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
        Write-Atomic (Join-Path $StateRoot 'credential.dpapi') ([Convert]::ToBase64String($encrypted))
    } finally {[Array]::Clear($bytes,0,$bytes.Length)}
}
function Read-Credential {
    Add-Type -AssemblyName System.Security
    $path=Join-Path $StateRoot 'credential.dpapi'
    if(!(Test-Path -LiteralPath $path)){return $null}
    $encrypted=[Convert]::FromBase64String([IO.File]::ReadAllText($path))
    $bytes=[Security.Cryptography.ProtectedData]::Unprotect($encrypted,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
    try {return $Utf8.GetString($bytes)}
    finally {[Array]::Clear($bytes,0,$bytes.Length)}
}
function Call-GitHub([string]$Method,[string]$Url,$Body=$null,[string]$Token='') {
    if(!$Url.StartsWith('https://api.github.com/')){throw 'Unexpected API host'}
    $headers=@{'Accept'='application/vnd.github+json';'X-GitHub-Api-Version'='2022-11-28';'User-Agent'='SITEhydrology-benchmark-sync'}
    if($Token){$headers.Authorization='Bearer '+$Token}
    $args=@{Uri=$Url;Method=$Method;Headers=$headers;TimeoutSec=45;UseBasicParsing=$true}
    if($null -ne $Body){$args.Body=$Utf8.GetBytes(($Body | ConvertTo-Json -Depth 100 -Compress));$args.ContentType='application/json; charset=utf-8'}
    return Invoke-RestMethod @args
}
function Get-ContentJson([string]$Path,[string]$Token='') {
    $obj=Call-GitHub 'GET' ($ApiRoot+'/contents/'+$Path) $null $Token
    return ($Utf8.GetString([Convert]::FromBase64String(($obj.content -replace '\s',''))) | ConvertFrom-Json)
}
function Get-Snapshot([string]$Profile) {
    try {$index=Get-ContentJson 'benchmarks/index.json'}
    catch {
        if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404){return $null}
        throw
    }
    $entry=$index.profiles.$Profile
    if($null -eq $entry){return $null}
    if($entry.sha256 -notmatch '^[0-9a-f]{64}$'){throw 'Invalid snapshot checksum'}
    $expected='snapshots/'+$Profile+'/'+$entry.sha256+'.json'
    if($entry.path -cne $expected){throw 'Invalid snapshot path'}
    $url='https://raw.githubusercontent.com/'+$Repo+'/main/benchmarks/'+$expected
    if($entry.downloadUrl){
        $expectedUrl='https://github.com/'+$Repo+'/releases/download/site-benchmarks/'+$Profile+'_'+$entry.sha256+'.json'
        if($entry.downloadUrl -cne $expectedUrl){throw 'Invalid snapshot URL'}
        $url=$expectedUrl
    }
    $temp=Join-Path $StateRoot ([Guid]::NewGuid().ToString()+'.download')
    try {
        Invoke-WebRequest -Uri $url -OutFile $temp -TimeoutSec 60 -UseBasicParsing | Out-Null
        if((Get-Item -LiteralPath $temp).Length -gt 20MB){throw 'Snapshot too large'}
        $bytes=[IO.File]::ReadAllBytes($temp)
        if((Get-Digest $bytes) -cne $entry.sha256){throw 'Snapshot checksum mismatch'}
        $snapshot=$Utf8.GetString($bytes) | ConvertFrom-Json
        if($snapshot.schema -ne 1 -or $snapshot.profile -cne $Profile){throw 'Snapshot identity mismatch'}
        return $snapshot
    } finally {if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp}}
}
function Select-Improvements($Payload,$Snapshot,$Approved) {
    if($null -ne $Snapshot -and (Get-ProfileJson $Snapshot.contract) -cne (Get-ProfileJson $Payload.contract)){throw 'Different benchmark contract'}
    $incumbents=@{}
    if($null -ne $Snapshot){foreach($r in @($Snapshot.records)){$incumbents[$r.basin+'|'+$r.metric]=$r}}
    $allowed=@{};foreach($id in @($Approved.basinIds)){$allowed[[string]$id]=$true}
    $directions=@{};for($j=0;$j -lt @($Approved.contract.metrics).Count;$j++){$directions[$Approved.contract.metrics[$j]]=[bool]$Approved.contract.maximize[$j]}
    $keep=@();$seen=@{}
    foreach($r in @($Payload.records)) {
        if(!$allowed.ContainsKey([string]$r.basin)){continue}
        if(!$directions.ContainsKey([string]$r.metric)){throw 'Unknown benchmark metric'}
        $key=$r.basin+'|'+$r.metric
        if($seen.ContainsKey($key)){throw 'Duplicate basin metric'};$seen[$key]=$true
        $value=[double]$r.train
        if([double]::IsNaN($value) -or [double]::IsInfinity($value)){throw 'Nonfinite score'}
        $old=$incumbents[$key]
        if($null -eq $old -or ($directions[$r.metric] -and $value -gt [double]$old.train) -or (!$directions[$r.metric] -and $value -lt [double]$old.train)){$keep+=,$r}
    }
    return ,$keep
}
function Submit-Payload($Payload,[string]$Token) {
    $manifest=Get-ContentJson 'benchmarks/profiles.json'
    $approved=$null
    foreach($p in @($manifest.profiles)){if($p.enabled -and (Get-ProfileJson $p.contract) -ceq (Get-ProfileJson $Payload.contract)){$approved=$p;break}}
    if($null -eq $approved){return @{state='unapproved'}}
    if($approved.id -notmatch '^[a-z][a-z0-9_]{0,99}$'){throw 'Invalid profile ID'}
    if($null -eq $Payload.localReferenceCheck -or $Payload.localReferenceCheck.mode -cne 'local_reference'){return @{state='reference_required'}}
    $Payload.contract=$approved.contract
    $snapshot=Get-Snapshot $approved.id
    $Payload.records=Select-Improvements $Payload $snapshot $approved
    if(@($Payload.records).Count -eq 0){return @{state='current'}}
    $Payload | Add-Member -NotePropertyName profile -NotePropertyValue $approved.id -Force
    $body=Get-CanonicalJson $Payload;$bytes=$Utf8.GetBytes($body)
    if($bytes.Length -gt 20MB){throw 'Submission too large'}
    $hash=Get-Digest $bytes
    $account=Call-GitHub 'GET' 'https://api.github.com/user' $null $Token
    $login=[string]$account.login
    if($login -notmatch '^[A-Za-z0-9-]+$'){throw 'Invalid GitHub account'}
    $repoRoot=$ApiRoot
    if($login -cne 'jaspervrugt') {
        $fork=Call-GitHub 'POST' ($ApiRoot+'/forks') @{default_branch_only=$true} $Token
        $repoRoot='https://api.github.com/repos/'+$fork.full_name
        $ready=$false
        for($i=0;$i -lt 15;$i++){try{$null=Call-GitHub 'GET' ($repoRoot+'/git/ref/heads/main') $null $Token;$ready=$true;break}catch{Start-Sleep -Seconds 2}}
        if(!$ready){throw 'Fork not ready'}
    }
    $base=Call-GitHub 'GET' ($ApiRoot+'/git/ref/heads/main') $null $Token
    $branch='site-benchmark-'+$hash.Substring(0,20)
    try {$null=Call-GitHub 'GET' ($repoRoot+'/git/ref/heads/'+$branch) $null $Token}
    catch {
        if(!$_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404){throw}
        $null=Call-GitHub 'POST' ($repoRoot+'/git/refs') @{ref='refs/heads/'+$branch;sha=$base.object.sha} $Token
    }
    $path='benchmarks/inbox/'+$hash+'.json'
    try {$existing=Call-GitHub 'GET' ($repoRoot+'/contents/'+$path+'?ref='+$branch) $null $Token}
    catch {
        if(!$_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404){throw}
        $existing=$null
    }
    if($null -eq $existing){
        $null=Call-GitHub 'PUT' ($repoRoot+'/contents/'+$path) @{message='Propose verified SITE benchmark improvements';content=[Convert]::ToBase64String($bytes);branch=$branch} $Token
    } else {
        if((Get-Digest ([Convert]::FromBase64String(($existing.content -replace '\s','')))) -cne $hash){throw 'Existing contribution differs'}
    }
    $head=$login+':'+$branch
    $prs=@(Call-GitHub 'GET' ($ApiRoot+'/pulls?state=open&head='+[Uri]::EscapeDataString($head)) $null $Token)
    if($prs.Count -eq 0){
        $pr=Call-GitHub 'POST' ($ApiRoot+'/pulls') @{title='SITE benchmark contribution: '+$approved.id;head=$head;base='main';draft=$true;body='Generated by the compiled SITE GUI. Independent verification is required before publication.'} $Token
    } else {$pr=$prs[0]}
    return @{state='submitted';url=$pr.html_url}
}
function Refresh-Credential($Auth) {
    $reply=Invoke-RestMethod -Uri 'https://github.com/login/oauth/access_token' -Method Post -Headers @{Accept='application/json'} -ContentType 'application/x-www-form-urlencoded' -Body @{client_id=$Auth.clientId;grant_type='refresh_token';refresh_token=$Auth.refresh_token} -TimeoutSec 30 -UseBasicParsing
    if(!$reply.access_token){throw 'Sign-in renewal unavailable'}
    $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $new=@{clientId=$Auth.clientId;access_token=$reply.access_token}
    if($reply.refresh_token){$new.refresh_token=$reply.refresh_token}
    if($reply.expires_in){$new.expiresAt=$now+[double]$reply.expires_in}
    if($reply.refresh_token_expires_in){$new.refreshExpiresAt=$now+[double]$reply.refresh_token_expires_in}
    Save-Credential ($new | ConvertTo-Json -Compress)
    return $new.access_token
}
function Resolve-Credential($Config) {
    $raw=Read-Credential
    if(!$raw){return $null}
    # Earlier pilot credentials were access-token-only. Preserve compatibility.
    if(!$raw.StartsWith('{')){return $raw}
    $auth=$raw | ConvertFrom-Json
    if($auth.clientId -cne $Config.clientId){throw 'Credential application differs'}
    $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if($auth.expiresAt -and $now -ge ([double]$auth.expiresAt-120)) {
        if(!$auth.refresh_token -or ($auth.refreshExpiresAt -and $now -ge [double]$auth.refreshExpiresAt)){throw 'Sign-in required'}
        return Refresh-Credential $auth
    }
    return $auth.access_token
}
function Invoke-Sync {
    $config=Join-Path $StateRoot 'site_benchmark_github.json'
    if(!(Test-Path -LiteralPath $config)){return}
    $cfg=[IO.File]::ReadAllText($config) | ConvertFrom-Json
    if(!$cfg.enabled){return}
    if($cfg.owner -cne 'jaspervrugt' -or $cfg.repository -cne 'SITEhydrology'){throw 'Unexpected repository'}
    try {$token=Resolve-Credential $cfg}
    catch {Write-Atomic (Join-Path $StateRoot 'last-status.json') '{"state":"pending","message":"Sign-in renewal unavailable; pending results retained."}';return}
    if(!$token){return}
    $queue=Join-Path $StateRoot 'pending'
    if(!(Test-Path -LiteralPath $queue)){return}
    foreach($file in @(Get-ChildItem -LiteralPath $queue -Filter '*.json' -File)) {
        try {
            if($file.Length -gt 20MB){throw 'Pending payload too large'}
            $bytes=[IO.File]::ReadAllBytes($file.FullName);$digest=Get-Digest $bytes
            $statusFile=Join-Path $StateRoot ('status/'+$file.Name)
            if(Test-Path -LiteralPath $statusFile){
                $old=[IO.File]::ReadAllText($statusFile) | ConvertFrom-Json
                if($old.digest -ceq $digest -and $old.state -in @('submitted','current')){continue}
            }
            $payload=$Utf8.GetString($bytes) | ConvertFrom-Json
            if($payload.schema -ne 1 -or $payload.origin -cne 'SITE_compiled_GUI'){throw 'Invalid contribution'}
            $result=Submit-Payload $payload $token
            $result.digest=$digest;$result.checked=[DateTime]::UtcNow.ToString('o')
            Write-Atomic $statusFile ($result | ConvertTo-Json -Depth 10 -Compress)
        } catch {
            # Keep the original payload. Never log API bodies or credentials.
            Write-Atomic (Join-Path $StateRoot 'last-status.json') (@{state='pending';checked=[DateTime]::UtcNow.ToString('o');message='Connection, sign-in, or verification configuration unavailable; pending results retained.'} | ConvertTo-Json -Compress)
            return
        }
    }
}
function Install-Task {
    $script=Join-Path $StateRoot 'site_benchmark_sync.ps1'
    if(!(Test-Path -LiteralPath $script)){throw 'Missing sync helper'}
    $args='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$script+'" -Action Sync -StateRoot "'+$StateRoot+'"'
    $taskAction=New-ScheduledTaskAction -Execute (Join-Path $PSHOME 'powershell.exe') -Argument $args
    $trigger=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 15)
    $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $suffix=(Get-Digest ($Utf8.GetBytes($StateRoot))).Substring(0,12)
    Register-ScheduledTask -TaskName ('SITE benchmark sync '+$suffix) -Action $taskAction -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
}
if($Action -eq 'Library'){return}
[IO.Directory]::CreateDirectory($StateRoot) | Out-Null
switch($Action){
    'SaveCredential' {Save-Credential ([Console]::In.ReadToEnd());break}
    'Install' {Install-Task;break}
    'Sync' {
        $name='Local\SITEBenchmarkSync'+(Get-Digest ($Utf8.GetBytes($StateRoot))).Substring(0,24)
        $mutex=New-Object Threading.Mutex($false,$name)
        $held=$false
        try {try{$held=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true};if($held){Invoke-Sync}}
        finally{if($held){$mutex.ReleaseMutex()};$mutex.Dispose()}
    }
}
