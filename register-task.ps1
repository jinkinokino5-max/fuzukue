# 文机 FUZUKUE の定期同期をタスクスケジューラに登録する（1回だけ実行）
#   pwsh C:\Users\jinki\fuzukue\register-task.ps1            … 1時間ごとに登録
#   pwsh C:\Users\jinki\fuzukue\register-task.ps1 -Remove    … 登録解除
param([switch]$Remove, [int]$Hours = 1)

$name = 'FUZUKUE sync'
if ($Remove) { Unregister-ScheduledTask -TaskName $name -Confirm:$false; "removed: $name"; return }

$pwsh   = (Get-Command pwsh).Source
$script = Join-Path $PSScriptRoot 'sync.ps1'
# conhost --headless で窓を出さずに実行する。push に既存の git 資格情報を使うため「ログオン中のみ」
$action  = New-ScheduledTaskAction -Execute 'conhost.exe' -Argument "--headless `"$pwsh`" -NoProfile -NonInteractive -File `"$script`"" -WorkingDirectory $PSScriptRoot
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours((Get-Date).Hour + 1) -RepetitionInterval (New-TimeSpan -Hours $Hours)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description '各科目の output/ を文机 FUZUKUE (GitHub Pages) にミラーして push する' -Force | Out-Null
"registered: $name（$Hours 時間ごと）"
