# 文机 FUZUKUE 同期スクリプト
# 各科目のローカル output/ を docs/<slug>/ に完全ミラーし、差分があれば commit & push する。
#   手動実行:   pwsh C:\Users\jinki\fuzukue\sync.ps1
#   確認だけ:   pwsh C:\Users\jinki\fuzukue\sync.ps1 -WhatIf     （コピーもpushもしない）
#   pushしない: pwsh C:\Users\jinki\fuzukue\sync.ps1 -NoPush
param([switch]$WhatIf, [switch]$NoPush)

$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$docs = Join-Path $repo 'docs'
$log  = Join-Path $repo 'sync.log'
$utf8 = New-Object System.Text.UTF8Encoding $false

function Log($msg) {
  $line = '{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg
  Write-Host $line
  if (-not $WhatIf) { Add-Content -LiteralPath $log -Value $line -Encoding utf8 }
}

# 科目の入口：index.html があればそれ、なければ「はじめに」、それもなければ最初の html
function Get-Entry($dir) {
  if (Test-Path -LiteralPath (Join-Path $dir 'index.html')) { return 'index.html' }
  $f = Get-ChildItem -LiteralPath $dir -File -Filter '*.html' | Sort-Object Name
  $g = $f | Where-Object Name -like 'はじめに*' | Select-Object -First 1
  if ($g) { return $g.Name }
  if ($f) { return $f[0].Name }
  return $null
}

$back = '<!--fzk-back--><p style="margin:0 0 18px;font-size:12px;letter-spacing:.2em;line-height:1.6"><a href="../index.html" style="color:#a8322a;text-decoration:none">← 文机 FUZUKUE</a></p>'

try {
  $cfg = Get-Content -LiteralPath (Join-Path $repo 'sources.json') -Raw -Encoding utf8 | ConvertFrom-Json
  $shelfPath = Join-Path $docs 'index.html'
  $shelf = [IO.File]::ReadAllText($shelfPath, $utf8)
  Log ('sync start' + $(if ($WhatIf) { ' (WhatIf)' } else { '' }))

  foreach ($s in $cfg.subjects) {
    $src = Join-Path $cfg.root $s.src
    $dst = Join-Path $docs $s.slug

    # 元フォルダーが見えない・空のときは、サイト側を消してしまわないよう飛ばす
    if (-not (Test-Path -LiteralPath $src)) { Log "SKIP $($s.slug): 元フォルダーがありません $src"; continue }
    if (-not (Get-ChildItem -LiteralPath $src -File -Filter '*.html' -Recurse | Select-Object -First 1)) {
      Log "SKIP $($s.slug): html が1つもありません $src"; continue
    }

    $rcArgs = @($src, $dst, '/MIR', '/R:1', '/W:1', '/NJH', '/NJS', '/NP', '/NDL', '/XF', 'desktop.ini', 'Thumbs.db', '.DS_Store')
    if ($WhatIf) { $rcArgs += '/L' }
    $out = & robocopy @rcArgs
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) for $($s.slug)`n$($out -join "`n")" }
    $changes = @($out | Where-Object { $_ -match '\S' })
    if ($changes.Count) { Log "$($s.slug): $($changes.Count) 件の変更候補"; $changes | ForEach-Object { Write-Host "    $($_.Trim())" } }
    if ($WhatIf) { continue }

    # 入口ページの先頭に「文机へ戻る」を差し込む（元の output/ は触らない）
    $entry = Get-Entry $dst
    if (-not $entry) { continue }
    $ep = Join-Path $dst $entry
    $html = [IO.File]::ReadAllText($ep, $utf8)
    if ($html -notmatch '<!--fzk-back-->') {
      $rx = [regex]'(<body[^>]*>)'
      $html = $rx.Replace($html, ('$1' + "`n" + $back), 1)
      [IO.File]::WriteAllText($ep, $html, $utf8)
    }

    # 本棚のリンク先と「準備中」を入口に合わせる
    $slugRx = [regex]::Escape($s.slug)
    $shelf = [regex]::Replace($shelf, "(?s)(<li[^>]*>\s*<a class=""book"" href="")$slugRx/[^""]*("".*?</li>)", {
      param($m)
      $block = $m.Groups[1].Value + "$($s.slug)/$entry" + $m.Groups[2].Value
      $block = $block -replace '<span class="soon">準備中</span>', ''
      if ($entry -ne 'index.html') {
        $block = [regex]::new('(<span class="face spine">.*?<span class="ttl">.*?</span>)').Replace($block, '$1<span class="soon">準備中</span>', 1)
      }
      $block
    })
  }

  if ($WhatIf) { Log 'WhatIf のため終了'; return }
  [IO.File]::WriteAllText($shelfPath, $shelf, $utf8)

  Push-Location $repo
  try {
    git add -A
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
      # 前回 push に失敗したコミットが残っていれば、ここで push し直す（ネットワークの一時的な不調対策）
      $ahead = (git rev-list --count origin/main..main) 2>$null
      if ($ahead -and [int]$ahead -gt 0 -and -not $NoPush) {
        Log "変更なし（未 push のコミットが $ahead 件あるので push する）"
        git push -q origin main 2>&1 | ForEach-Object { Log "  $_" }
        if ($LASTEXITCODE -ne 0) { throw 'git push failed' }
        Log 'push 完了'
      } else { Log '変更なし' }
      return
    }
    $names = git -c core.quotepath=false diff --cached --name-only
    $slugs = @($names | ForEach-Object { if ($_ -match '^docs/([^/]+)/') { $Matches[1] } } | Sort-Object -Unique)
    $msg = 'sync: {0:yyyy-MM-dd HH:mm} {1}' -f (Get-Date), ($(if ($slugs) { $slugs -join ', ' } else { 'portal' }))
    git commit -q -m $msg
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
    Log "commit: $msg ($(@($names).Count) files)"
    if (-not $NoPush) {
      git push -q origin main 2>&1 | ForEach-Object { Log "  $_" }
      if ($LASTEXITCODE -ne 0) { throw 'git push failed' }
      Log 'push 完了'
    }
  } finally { Pop-Location }
}
catch {
  Log "ERROR: $($_.Exception.Message)"
  exit 1
}
