# TC-JetBrainsMapleMono 字型一鍵更新工具
# 版本：v1.0
# 作用：抓 GitHub release 最新 zip → 解壓 → 移除 Windows 裡的舊字型 → 安裝新字型（所有使用者）
# 用法：雙擊「更新TC_JBMM字型.bat」。參數：-Force 強制重裝；-Tag pre 改抓開發版；-NoPause 結束不暫停

param(
    [string]$Tag = 'latest',
    [string[]]$Codes = @('1011', '1111'),
    [switch]$Force,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$Repo = 'bgtsai/TC-JetBrainsMapleMono'
$StateDir = Join-Path $env:ProgramData 'TC_JBMM_Updater'
$StateFile = Join-Path $StateDir "state_$Tag.json"
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
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Tag', $Tag, '-Codes', ($Codes -join ','))
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
# 從提權後的參數字串還原陣列（-Codes 1011,1111 會被當成一個字串）
$Codes = @($Codes | ForEach-Object { $_ -split ',' } | Where-Object { $_ })

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
            if ($i -eq 5) { throw "$desc 失敗（重試 5 次）：$($_.Exception.Message)" }
            $d = $delays[$i - 1]
            Write-Host "  ⚠ $desc 第 $i 次失敗，$d 秒後重試：$($_.Exception.Message)" -ForegroundColor Yellow
            Start-Sleep -Seconds $d
        }
    }
}

try {
    Write-Host "== TC-JetBrainsMapleMono 字型更新（$Tag；代碼 $($Codes -join '、')）==" -ForegroundColor Cyan

    # 1. 查 release
    Write-Host '[1/5] 查詢 GitHub 最新版本...'
    $rel = Invoke-Retry '查詢 release' {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/tags/$Tag" -TimeoutSec 30 -Headers @{ 'User-Agent' = 'TCJBMM-Updater' }
    }
    $assets = @()
    foreach ($c in $Codes) {
        $a = $rel.assets | Where-Object { $_.name -eq "TC-JBMM-$c.zip" }
        if (-not $a) { throw "release「$Tag」裡找不到 TC-JBMM-$c.zip" }
        $assets += $a
    }
    $stamp = ($assets | ForEach-Object { "$($_.name)=$($_.updated_at)" }) -join ';'

    $old = $null
    if (Test-Path $StateFile) { try { $old = Get-Content $StateFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    $allPresent = $true
    foreach ($c in $Codes) {
        if (-not (Get-ChildItem $SysFonts -Filter "TC_JBMM_${c}_*.ttf" -ErrorAction SilentlyContinue)) { $allPresent = $false }
    }
    if (-not $Force -and $old -and $old.stamp -eq $stamp -and $allPresent) {
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
            if ($size -ne $a.size) { throw "檔案大小不符（$size ≠ $($a.size)）" }
        } | Out-Null
        Write-Host ("  ✓ {0}（{1:N0} MB）" -f $a.name, ($a.size / 1MB))
    }

    # 3. 解壓
    Write-Host '[3/5] 解壓縮...'
    $newFonts = @()
    foreach ($a in $assets) {
        $dir = Join-Path $work ($a.name -replace '\.zip$', '')
        Expand-Archive -Path (Join-Path $work $a.name) -DestinationPath $dir -Force
        $newFonts += Get-ChildItem $dir -Filter 'TC_JBMM_*.ttf' -Recurse
    }
    if ($newFonts.Count -eq 0) { throw 'zip 裡沒有找到字型檔' }
    Write-Host "  ✓ 共 $($newFonts.Count) 個字型檔"

    # 4. 移除舊字型（系統與目前使用者兩處：登錄檔＋檔案）
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

    Write-Host ''
    Write-Host "安裝完成：成功 $ok 個，失敗 $($fail.Count) 個" -ForegroundColor $(if ($fail.Count) { 'Yellow' } else { 'Green' })
    $fail | ForEach-Object { Write-Host "  ✗ $_" -ForegroundColor Red }
    if ($pending) { Write-Host '有舊字型正在被程式使用：新字型已裝好，關閉相關程式或重新開機後舊檔會自動清除。' -ForegroundColor Yellow }
    Write-Host '已開啟的程式（例如編輯器）要重新啟動，才會讀到新字型。'

    if ($fail.Count -eq 0) {
        if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory $StateDir | Out-Null }
        @{ stamp = $stamp; installed_at = (Get-Date -Format 'yyyy-MM-dd HH:mm') } | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
        Finish 0
    }
    Finish 1
} catch {
    Write-Host ''
    Write-Host "錯誤：$($_.Exception.Message)" -ForegroundColor Red
    Finish 1
}
