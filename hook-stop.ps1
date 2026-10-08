# Claude Code の Stop フック（~/.claude/settings.json から呼ばれる）
# Claude の応答が終わるたびに呼ばれ、作業フォルダが ClaudeOS 配下のときだけ sync.ps1 を走らせる。
# sync.ps1 は差分があるときだけ commit & push するので、教材を作った（output/ を変えた）ときだけ GitHub が更新される。
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
$cwd = ''
try { $cwd = ($raw | ConvertFrom-Json).cwd } catch {}
if (-not $cwd) { $cwd = (Get-Location).Path }
if ($cwd -notlike 'C:\Users\jinki\ClaudeOS*') { exit 0 }

# 同時に2つ走らないようにする（前の同期がまだ動いていれば今回は見送る）
$lock = Join-Path $PSScriptRoot '.hook.lock'
if ((Test-Path $lock) -and ((Get-Date) - (Get-Item $lock).LastWriteTime).TotalMinutes -lt 10) { exit 0 }
Set-Content -LiteralPath $lock -Value $PID
try {
  & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'sync.ps1') *> $null
} finally {
  Remove-Item -LiteralPath $lock -Force
}
exit 0
