# TC-JetBrainsMapleMono 字型一鍵更新工具
# 版本：v2.0
# 作用：依設定檔 TC-JBMM-Updater.ini 抓 GitHub release 最新 zip → 解壓 → 移除 Windows 裡的舊字型 → 安裝新字型（所有使用者）
# 用法：雙擊「更新TC_JBMM字型.bat」。
# 參數：-Force 強制重裝；-Tag pre 暫時改抓開發版（優先於設定檔）；-Config 指定別的設定檔；-NoPause 結束不暫停

param(
    [string]$Tag = '',
    [string]$Config = '',
    [switch]$Force,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Repo = 'bgtsai/TC-JetBrainsMapleMono'
$StateDir = Join-Path $env:ProgramData 'TC_JBMM_Updater'
if (-not $Config) { $Config = Join-Path $PSScriptRoot 'TC-JBMM-Updater.ini' }
$AllWeights = @('Thin', 'ThinItalic', 'ExtraLight', 'ExtraLightItalic', 'Light', 'LightItalic',
    'Regular', 'Italic', 'Medium', 'MediumItalic', 'SemiBold', 'SemiBoldItalic',
    'Bold', 'BoldItalic', 'ExtraBold', 'ExtraBoldItalic')
$SysFonts = Join-Path $env:WINDIR 'Fonts'
$UserFonts = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$RegHKLM = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$RegHKCU = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'

function Finish([int]$code) {
    if (-not $NoPause) { Write-Host ''; Read-Host '按 Enter 關閉' | Out-Null }
    exit $code
}

# ── 自動提權：不是系統管理員就用 RunAs 重新啟動自己（會跳一次 UAC，按「是」即可）
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Config', "`"$Config`"")
    if ($Tag) { $argList += @('-Tag', $Tag) }
    if ($Force) { $argList += '-Force' }
    if ($NoPause) { $argList += '-NoPause' }
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $argList | Out-Null
    } catch {
        Write-Host '未取得系統管理員權限，已取消。' -ForegroundColor Yellow
        Finish 1
    }
    exit 0
}

# ── 讀設定檔（INI）：[General] Tag；[Fonts] 代碼 = 字重清單 或 *
function Read-Config([string]$path) {
    if (-not (Test-Path $path)) { throw "找不到設定檔：$path（請把 TC-JBMM-Updater.ini 放在腳本同一個資料夾）" }
    $cfg = @{ Tag = 'latest'; Fonts = [ordered]@{} }
    $section = ''; $n = 0; $errs = @()
    foreach ($line in (Get-Content $path -Encoding UTF8)) {
        $n++
        $s = ($line -replace '^\s*[;#].*$', '').Trim()
        if (-not $s) { continue }
        if ($s -match '^\[(.+)\]$') { $section = $Matches[1].Trim(); continue }
        if ($s -notmatch '^([^=]+)=(.*)$') { $errs += "第 $n 行看不懂：$line"; continue }
        $k = $Matches[1].Trim(); $v = ($Matches[2] -replace '\s[;#].*$', '').Trim()
        if ($section -eq 'General') {
            if ($k -eq 'Tag') {
                if ($v -notin @('latest', 'pre')) { $errs += "第 $n 行：Tag 只能是 latest 或 pre（目前是「$v」）" } else { $cfg.Tag = $v }
            } else { $errs += "第 $n 行：[General] 不認得「$k」" }
        } elseif ($section -eq 'Fonts') {
            if ($k -notmatch '^[01]{4}$') { $errs += "第 $n 行：代碼要是 4 位的 0/1（例如 1011），目前是「$k」"; continue }
            if ($cfg.Fonts.Contains($k)) { $errs += "第 $n 行：代碼 $k 重複出現"; continue }
            if ($v -eq '*') { $cfg.Fonts[$k] = $AllWeights; continue }
            $ws = @()
            foreach ($w in ($v -split '[,，]') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) {
                $hit = $AllWeights | Where-Object { $_ -eq $w }
                if ($hit) { if ($ws -notcontains $hit) { $ws += $hit } }
                else { $errs += "第 $n 行：不認得字重「$w」" }
            }
            if ($ws.Count -eq 0) { $errs += "第 $n 行：代碼 $k 沒有指定任何字重（全部安裝請寫 *）" } else { $cfg.Fonts[$k] = $ws }
        } else { $errs += "第 $n 行：不在 [General] 或 [Fonts] 區段裡：$line" }
    }
    if ($cfg.Fonts.Count -eq 0 -and -not $errs) { $errs += '[Fonts] 區段裡沒有任何要安裝的代碼' }
    if ($errs) {
        throw ("設定檔有誤（$path）：`n  " + ($errs -join "`n  ") + "`n  可用的字重：" + ($AllWeights -join ', ') + "；全部安裝請寫 *")
    }
    return $cfg
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

Add-Type -Namespace TCJBMM -Name Native -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResource(string lpFileName);
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern bool RemoveFontResource(string lpFileName);
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, IntPtr lParam, int fuFlags, int uTimeout, out IntPtr lpdwResult);
'@

# 通用重試：遞增退避 5/15/30/60 秒，共 5 次
function Invoke-Retry([string]$desc, [scriptblock]$action) {
    $delays = @(5, 15, 30, 60)
    for ($i = 1; $i -le 5; $i++) {
        try { return & $action }
        catch {
            # 403（未認證額度用完）、404 重試也沒用，直接丟出
            if ($_.Exception.Message -match '\((403|404)\)') { throw }
            if ($i -eq 5) { throw "$desc 失敗（重試 5 次）：$($_.Exception.Message)" }
            $d = $delays[$i - 1]
            Write-Host "  ⚠ $desc 第 $i 次失敗，$d 秒後重試：$($_.Exception.Message)" -ForegroundColor Yellow
            Start-Sleep -Seconds $d
        }
    }
}

try {
    $cfg = Read-Config $Config
    if (-not $Tag) { $Tag = $cfg.Tag }
    $Codes = @($cfg.Fonts.Keys)
    $StateFile = Join-Path $StateDir "state_$Tag.json"
    # 設定內容摘要：設定檔一改就會重新安裝
    $cfgSig = ($Codes | ForEach-Object { "$_=" + ($cfg.Fonts[$_] -join ',') }) -join ';'
    Write-Host "== TC-JetBrainsMapleMono 字型更新（$Tag）==" -ForegroundColor Cyan
    foreach ($c in $Codes) {
        $ws = $cfg.Fonts[$c]
        Write-Host ("  {0}：{1}" -f $c, $(if ($ws.Count -eq $AllWeights.Count) { '全部 16 個字重' } else { $ws -join '、' }))
    }

    # 1. 查 release
    Write-Host '[1/5] 查詢 GitHub 最新版本...'
    $apiHeaders = @{ 'User-Agent' = 'TCJBMM-Updater' }
    if ($env:GITHUB_TOKEN) { $apiHeaders['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
    $rel = $null
    try {
        $rel = Invoke-Retry '查詢 release' {
            Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" -TimeoutSec 30 -Headers $apiHeaders
        }
    } catch {
        # 查不到版本（例如 GitHub API 未認證額度用完）不影響下載：改用固定下載網址，但無法判斷是否已是最新
        Write-Host "  ⚠ 無法查詢版本資訊（$($_.Exception.Message)），改為直接下載安裝" -ForegroundColor Yellow
    }
    $assets = @()
    foreach ($c in $Codes) {
        if ($rel) {
            $a = $rel.assets | Where-Object { $_.name -eq "TC-JBMM-$c.zip" }
            if (-not $a) { throw "release「$Tag」裡找不到 TC-JBMM-$c.zip" }
        } else {
            $a = [pscustomobject]@{ name = "TC-JBMM-$c.zip"; size = $null; updated_at = $null
                browser_download_url = "https://github.com/$Repo/releases/download/$Tag/TC-JBMM-$c.zip" }
        }
        $assets += $a
    }
    $stamp = if ($rel) { (($assets | ForEach-Object { "$($_.name)=$($_.updated_at)" }) -join ';') + '|' + $cfgSig } else { $null }

    $old = $null
    if (Test-Path $StateFile) { try { $old = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    $allPresent = $true
    foreach ($c in $Codes) {
        foreach ($w in $cfg.Fonts[$c]) {
            if (-not (Get-ChildItem $SysFonts -Filter "TC_JBMM_${c}_${w}*.ttf" -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -match "^TC_JBMM_${c}_${w}(_\d{14})?$" })) { $allPresent = $false }
        }
    }
    if (-not $Force -and $stamp -and $old -and $old.stamp -eq $stamp -and $allPresent) {
        Write-Host "已是最新版本（上次安裝：$($old.installed_at)），不需要更新。" -ForegroundColor Green
        Write-Host '要強制重裝請用：更新TC_JBMM字型.bat -Force'
        Finish 0
    }

    # 2. 下載
    $work = Join-Path $env:TEMP ("TCJBMM_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory $work | Out-Null
    Write-Host '[2/5] 下載...'
    foreach ($a in $assets) {
        $dest = Join-Path $work $a.name
        Invoke-Retry "下載 $($a.name)" {
            Invoke-WebRequest -Uri $a.browser_download_url -OutFile $dest -TimeoutSec 600 -UseBasicParsing -Headers @{ 'User-Agent' = 'TCJBMM-Updater' }
            $size = (Get-Item $dest).Length
            if ($a.size -and $size -ne $a.size) { throw "檔案大小不符（$size ≠ $($a.size)）" }
        } | Out-Null
        Write-Host ("  ✓ {0}（{1:N0} MB）" -f $a.name, ((Get-Item $dest).Length / 1MB))
    }

    # 3. 解壓
    Write-Host '[3/5] 解壓縮...'
    $newFonts = @()
    foreach ($a in $assets) {
        $dir = Join-Path $work ($a.name -replace '\.zip$', '')
        Expand-Archive -Path (Join-Path $work $a.name) -DestinationPath $dir -Force
        $code = $a.name -replace '^TC-JBMM-(\d{4})\.zip$', '$1'
        foreach ($w in $cfg.Fonts[$code]) {
            $ff = Get-ChildItem $dir -Filter "TC_JBMM_${code}_${w}.ttf" -Recurse | Select-Object -First 1
            if (-not $ff) { throw "TC-JBMM-$code.zip 裡沒有 TC_JBMM_${code}_${w}.ttf" }
            $newFonts += $ff
        }
    }
    Write-Host "  ✓ 依設定挑出 $($newFonts.Count) 個字型檔"

    # 4. 移除舊字型（系統與目前使用者兩處：登錄檔＋檔案）
    # 暫停 Acrobat 的字型監看程式：acrotray 收到字型變更通知會叫起 Distiller，連續觸發時會撞出「錯誤 183」
    $acroNames = @('acrotray', 'acrodist')
    $acroWasRunning = @()
    foreach ($n in $acroNames) {
        foreach ($proc in @(Get-Process -Name $n -ErrorAction SilentlyContinue)) {
            $acroWasRunning += [pscustomobject]@{ Name = $n; Path = $proc.Path }
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }
    if ($acroWasRunning.Count) { Write-Host "  （已暫停 $(($acroWasRunning.Name | Select-Object -Unique) -join '、')，安裝完會恢復 acrotray）" }

    Write-Host '[4/5] 移除舊字型...'
    $pattern = '^TC_JBMM_(' + (($Codes | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')_'
    $removed = 0; $pending = 0
    foreach ($reg in @(@{ Key = $RegHKLM; Dir = $SysFonts }, @{ Key = $RegHKCU; Dir = $UserFonts })) {
        if (-not (Test-Path $reg.Key)) { continue }
        $props = Get-ItemProperty $reg.Key
        foreach ($p in $props.PSObject.Properties) {
            if ($p.Name -like 'PS*') { continue }
            $leaf = Split-Path ([string]$p.Value) -Leaf
            if ($leaf -notmatch $pattern) { continue }
            $file = if ([IO.Path]::IsPathRooted([string]$p.Value)) { [string]$p.Value } else { Join-Path $reg.Dir $leaf }
            [TCJBMM.Native]::RemoveFontResource($file) | Out-Null
            Remove-ItemProperty -Path $reg.Key -Name $p.Name
            if (Test-Path $file) {
                try { Remove-Item $file -Force; $removed++ }
                catch {
                    [TCJBMM.Native]::MoveFileEx($file, $null, 4) | Out-Null  # 4 = MOVEFILE_DELAY_UNTIL_REBOOT
                    $pending++
                }
            } else { $removed++ }
        }
    }
    # 登錄檔沒記到、但資料夾裡殘留的同名檔
    foreach ($dir in @($SysFonts, $UserFonts)) {
        if (-not (Test-Path $dir)) { continue }
        Get-ChildItem $dir -Filter 'TC_JBMM_*.ttf' | Where-Object { $_.Name -match $pattern } | ForEach-Object {
            [TCJBMM.Native]::RemoveFontResource($_.FullName) | Out-Null
            try { Remove-Item $_.FullName -Force; $removed++ }
            catch { [TCJBMM.Native]::MoveFileEx($_.FullName, $null, 4) | Out-Null; $pending++ }
        }
    }
    Write-Host "  ✓ 已移除 $removed 個" -NoNewline
    if ($pending) { Write-Host "，$pending 個使用中、重新開機後刪除" -ForegroundColor Yellow } else { Write-Host '' }

    # 5. 安裝新字型（所有使用者）
    Write-Host '[5/5] 安裝新字型...'
    $ok = 0; $fail = @()
    $suffix = Get-Date -Format 'yyyyMMddHHmmss'
    foreach ($f in $newFonts) {
        try {
            $target = Join-Path $SysFonts $f.Name
            if (Test-Path $target) {
                # 舊檔被鎖住刪不掉：新檔換個檔名安裝，舊檔重開機後自動消失
                $target = Join-Path $SysFonts ($f.BaseName + "_$suffix" + $f.Extension)
            }
            Copy-Item $f.FullName $target -Force
            New-ItemProperty -Path $RegHKLM -Name "$($f.BaseName) (TrueType)" -Value (Split-Path $target -Leaf) -PropertyType String -Force | Out-Null
            [TCJBMM.Native]::AddFontResource($target) | Out-Null
            $ok++
        } catch { $fail += "$($f.Name)：$($_.Exception.Message)" }
    }
    $r = [IntPtr]::Zero
    [TCJBMM.Native]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$r) | Out-Null  # WM_FONTCHANGE

    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

    # 恢復 acrotray（只恢復原本有在跑的；Distiller 平常是需要時才被叫起，不主動開）
    # 先等字型變更通知處理完；用 explorer.exe 啟動，讓它以一般使用者身分執行，而不是繼承這裡的系統管理員權限
    if ($acroWasRunning.Count) {
        Start-Sleep -Seconds 5
        if (-not (Get-Process -Name 'acrodist' -ErrorAction SilentlyContinue)) {
            Remove-Item (Join-Path $env:TEMP 'Acrobat Distiller DC') -Recurse -Force -ErrorAction SilentlyContinue
        }
        foreach ($a in @($acroWasRunning | Where-Object { $_.Name -eq 'acrotray' -and $_.Path } | Select-Object -First 1)) {
            if (-not (Get-Process -Name 'acrotray' -ErrorAction SilentlyContinue)) {
                try { Start-Process explorer.exe -ArgumentList "`"$($a.Path)`""; Write-Host '  （已恢復 acrotray）' }
                catch { Write-Host "  ⚠ acrotray 恢復失敗，需要時可手動開啟 Acrobat 讓它重新啟動：$($_.Exception.Message)" -ForegroundColor Yellow }
            }
        }
    }

    Write-Host ''
    Write-Host "安裝完成：成功 $ok 個，失敗 $($fail.Count) 個" -ForegroundColor $(if ($fail.Count) { 'Yellow' } else { 'Green' })
    $fail | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    if ($pending) { Write-Host '有舊字型正在被程式使用：新字型已裝好，關閉相關程式或重新開機後舊檔會自動清除。' -ForegroundColor Yellow }
    Write-Host '已開啟的程式（例如編輯器）要重新啟動，才會讀到新字型。'

    if ($fail.Count -eq 0) {
        # 查得到版本才記錄；直接下載模式不記，下次仍會重新檢查
        if ($stamp) {
            if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory $StateDir | Out-Null }
            @{ stamp = $stamp; installed_at = (Get-Date -Format 'yyyy-MM-dd HH:mm') } | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
        }
        Finish 0
    }
    Finish 1
} catch {
    Write-Host ''
    Write-Host "錯誤：$($_.Exception.Message)" -ForegroundColor Red
    Finish 1
}
