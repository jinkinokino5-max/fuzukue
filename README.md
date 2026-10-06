# 文机 FUZUKUE

講義の自習教材を並べた本棚。https://jinkinokino5-max.github.io/fuzukue/

| 科目 | サイト上のパス |
|---|---|
| 応用数学Ⅱ | `oyo-sugaku-2/` |
| 機械力学 | `kikai-rikigaku/` |
| 「今昔物語集」を読む | `konjaku/` |
| 電磁気学 | `denjiki/` |
| 上代文学へのいざない | `jodai/` |

## しくみ
- `docs/` が GitHub Pages の公開ルート（main ブランチ /docs）。
- `docs/index.html` が本棚（手書き）。背表紙の絵は `docs/img/spine/`、出典はページ最下部の「図版」。
- `docs/<slug>/` は各科目のローカル `output/` の完全ミラー。**ここを直接編集しない**（次の同期で上書きされる）。

## 同期
- 自動: タスクスケジューラ「FUZUKUE sync」が1時間ごと（ログオン中）に `sync.ps1` を実行。
- 手動: `pwsh C:\Users\jinki\fuzukue\sync.ps1`（`-WhatIf` で確認のみ、`-NoPush` で push しない）。
- 動き: `sources.json` の各科目を robocopy /MIR → 入口ページに「← 文机」を差し込む → 本棚のリンク先を入口に合わせる → 差分があれば commit & push。
- 元フォルダーが見つからない／html が1つもない科目は、サイト側を消さないよう飛ばす。
- ログ: `sync.log`（git 管理外）。
- 定期実行の登録・解除: `register-task.ps1`（`-Remove` で解除）。

## 科目を足すとき
1. `sources.json` に1行追加（`slug` は英小文字）。
2. `docs/index.html` の棚に `<li>` を1冊追加し、`docs/img/spine/<slug>.jpg` と `<slug>_cover.jpg` を置く。図版欄にも出典を足す。
3. `sync.ps1` を実行。
