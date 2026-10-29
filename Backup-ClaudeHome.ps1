#Requires -Version 5.1
<#
.SYNOPSIS
  Опис само с четене + резервно копие на ~/.claude и ~/.claude.json.
  Решение FAB-632/16121 т.4 (свързано с FAB-618). Пуска се ръчно ПРЕДИ инсталацията на REA.
  Версия: v3 (Клара, 27.10.2026; Астра Б1/Б2 по FAB-632/16129; сводният списък и решенията на Рачо FAB-632/16137).

.DESCRIPTION
  Чете -Source (цялото дърво, вкл. .git) и -SourceJson. НИЩО в тях не се променя (единственото
  изключение са изрично подадените параметри за проба върху ФАЛШИВ източник; виж ПРОБИ).
  Пише САМО в нова папка <BackupRoot>\<yyyyMMdd-HHmm>\ и, само при СТАТУС: ПРОВЕРЕНО и без проба,
  в <BackupRoot>\LATEST.txt.
  Git: само `rev-parse HEAD` и `branch --show-current` с GIT_OPTIONAL_LOCKS=0.
  robocopy: /E /COPY:DAT /DCOPY:T /XJ /R:1 /W:1 и /XD, /XF с пълния път на всяка връзка от описа
  (junction, symlink, друга reparse точка). Без /MIR, /MOV, /PURGE. Само /XJ не е доказателство:
  меродавна е проверката, че в копието няма нито връзка, нито съдържание на мястото на връзка.

  Пуска се само така (не в ISE, не с dot-source):
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File <път>\Backup-ClaudeHome.ps1
  Пуска се при ЗАТВОРЕНИ всички Claude Code и настолното приложение Claude. Всяка промяна в ~/.claude
  или ~/.claude.json по време на копирането дава ЧАСТИЧНО. При работеща CC копието почти винаги е ЧАСТИЧНО.
  Скриптът не спира процеси; в отчета записва само бройките им в началото и в края.

  Кодове на изход:
    0 = ПРОВЕРЕНО (LATEST.txt е обновен, освен при проба);
    1 = ЧАСТИЧНО (копие има, но не е доказано пълно; LATEST.txt не е пипан);
    2 = СПРИ (нищо не е копирано; вкл. неразрешени параметри за проба);
    3 = неочаквана грешка (ЧАСТИЧНО; LATEST.txt не е пипан).

  ПРОВЕРЕНО само ако всичко е изпълнено едновременно (Астра Б1, Б2; Рачо FAB-632/16137 т. 4):
    — няма недопустими разлики и няма разлики в „живи“ пътища (шаблоните по подразбиране са празни);
    — няма пропуснати или нечетими места;
    — claude.json.bak съвпада с източника при копирането и при повторната сверка точно преди статуса;
    — кодът на robocopy е 0–7;
    — описът на връзките (относителен път, вид, цел) е еднакъв в началото и в края, нито една цел не е „?“,
      а в копието няма връзки и съдържание от целите им. Стабилни, описани връзки допускат ПРОВЕРЕНО.
  Съдържанието на целите на връзките НЕ е част от копието; отчетът пази точния опис за ръчно възстановяване.

  -AllowedLivePatterns: по подразбиране празен (@()). Ако се подаде, само подрежда разликите в отчета;
  ПРОВЕРЕНО пак иска 0 разлики. Внимание: масив не се подава правилно през -File
  (`-File ... -AllowedLivePatterns a,b` стига като ЕДИН низ 'a,b').

  Отчетът BACKUP-REPORT.md има точни полета на отделни редове. install-rea.ps1 v4 (Test-BackupReport) ги чете:
    „- Източник: <път>“, „- Източник JSON: <път>“, „- Копие: <папката на отчета>“, „- ПРОБА: да|не“;
    раздел „## claude.json.bak“ с ред „- Размер: N B; sha256: X“;
    раздел „## MANIFEST.sha256.csv“ с ред „- sha256: X“;
    „- Липсващи в копието: N“, „- Разлики в допустими живи пътища: N“, „- Разлики НЕдопустими: N“,
    „- Пропуснати (грешки при обхождане): N“, „- Съвпадащи sha256: M от N“;
    „- Reparse точки: N — съдържанието на целите им НЕ е в копието“, „- Опис на връзките преди/след: еднакъв|РАЗЛИЧЕН“;
    един краен ред „СТАТУС: ПРОВЕРЕНО“ или „СТАТУС: ЧАСТИЧНО“.

  ПРОБИ (само върху фалшив източник; FAB-632/16137 т. 3). Параметрите са низове и минават през -File:
    -TestModifyPathAfterCopy <път>  след копирането и преди манифеста добавя един байт (LF) към съществуващ
                                    файл под -Source или към самия -SourceJson;
    -TestLinkPathAfterCopy <път> [-TestLinkTargetAfterCopy <цел>]  след копирането: ако на пътя няма нищо,
                                    създава junction към целта (добавена връзка); ако там има junction, без цел
                                    го маха (изчезнала връзка), а с цел го пренасочва (сменена цел).
    При проба отчетът пише „- ПРОБА: да“, LATEST.txt не се пипа, а install-rea.ps1 v4 отказва такъв отчет.
    Скриптът отказва проба (код 2), ако -Source, -SourceJson и -BackupRoot не са подадени изрично или
    съвпадат с истинските C:\Users\User\.claude, C:\Users\User\.claude.json, C:\Users\User\claude-backup
    (или с еквивалентите им под профила на потребителя), или са под тях.
    Пробите ВИНАГИ подават изрично -BackupRoot в пробната папка: успешна проба без пробни параметри
    иначе би писала в истинския LATEST.txt.

  ВНИМАНИЕ: копието съдържа тайни: claude.json.bak (може да носи токени), ~/.claude\.credentials.json
  (ако го има) и други токени или ключове в ~/.claude. Остава локално; не се споделя и не се качва (вкл. в GitHub).
#>
[CmdletBinding()]
param(
    [string]$Source     = (Join-Path $HOME '.claude'),
    [string]$SourceJson = (Join-Path $HOME '.claude.json'),
    [string]$BackupRoot = (Join-Path $HOME 'claude-backup'),
    [string]$Stamp      = (Get-Date -Format 'yyyyMMdd-HHmm'),
    # v3 (Астра Б1): по подразбиране празен. Само подрежда разликите; не прави непълно копие ПРОВЕРЕНО.
    [string[]]$AllowedLivePatterns = @(),
    # v3: заместват -TestHookAfterCopy (scriptblock не минава през -File). Само за проби върху фалшив източник.
    [string]$TestModifyPathAfterCopy = '',
    [string]$TestLinkPathAfterCopy = '',
    [string]$TestLinkTargetAfterCopy = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:UseLp   = $false
$script:Utf8Bom = New-Object System.Text.UTF8Encoding($true)
$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:ShareAll = [System.IO.FileShare]'ReadWrite, Delete'
$script:DestCreated = $false
$script:ReportWritten = $false
$script:IsProbe = (-not [string]::IsNullOrEmpty($TestModifyPathAfterCopy)) -or
                  (-not [string]::IsNullOrEmpty($TestLinkPathAfterCopy)) -or
                  (-not [string]::IsNullOrEmpty($TestLinkTargetAfterCopy))
$script:ProbeText = 'не'
if ($script:IsProbe) { $script:ProbeText = 'да' }

function Write-Stop([string]$msg) {
    Write-Host ('СПРИ: ' + $msg) -ForegroundColor Red
    Write-Host 'Нищо не е копирано. LATEST.txt не е пипан.'
    exit 2
}

# v2 (27.10.2026): беше LP — в Windows PowerShell 5.1 'lp' е вграден alias на Out-Printer и има предимство пред функцията.
function Get-LongPathForm([string]$p) {
    if ($script:UseLp -and -not $p.StartsWith('\\')) { return '\\?\' + $p }
    return $p
}

function Test-Under([string]$child, [string]$parent) {
    $c = $child.TrimEnd('\') + '\'
    $p = $parent.TrimEnd('\') + '\'
    return $c.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-IsReparse([System.IO.FileAttributes]$attr) {
    return (([int]($attr -band [System.IO.FileAttributes]::ReparsePoint)) -ne 0)
}

function Test-Live([string]$rel) {
    foreach ($pat in $AllowedLivePatterns) {
        if ($rel -like $pat) { return $true }
    }
    return $false
}

function Get-Sha256OfBytes([byte[]]$bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '') }
    finally { $sha.Dispose() }
}

# Чете със споделяне ReadWrite+Delete, за да не пречи на жив писател.
function Get-Sha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $fs = $null
    try {
        $fs = [System.IO.FileStream]::new((Get-LongPathForm $path), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $script:ShareAll, 1048576)
        return ([System.BitConverter]::ToString($sha.ComputeHash($fs)) -replace '-', '')
    }
    finally {
        if ($null -ne $fs) { $fs.Dispose() }
        $sha.Dispose()
    }
}

function Read-AllShared([string]$path) {
    $fs = $null
    $ms = New-Object System.IO.MemoryStream
    try {
        $fs = [System.IO.FileStream]::new((Get-LongPathForm $path), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, $script:ShareAll, 1048576)
        $fs.CopyTo($ms)
        return ,($ms.ToArray())
    }
    finally {
        if ($null -ne $fs) { $fs.Dispose() }
        $ms.Dispose()
    }
}

# v3 (сводeн т. 33): само бройки; командните редове се сравняват, не се записват. Не спира процеси.
# CC: claude.exe извън пътя на настолното приложение; node.exe с claude-code в командния ред.
# Настолно приложение Claude: Claude.exe под \AnthropicClaude\ или под \WindowsApps\...Claude...
function Get-ProcText {
    try { $procs = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop) }
    catch { return ('НЕУСТАНОВЕНО (Get-CimInstance: ' + $_.Exception.GetType().Name + ')') }
    $cc = 0; $desk = 0; $unk = 0; $nodeCc = 0; $nodeUnk = 0
    foreach ($p in $procs) {
        $n = [string]$p.Name
        if ($n -ieq 'claude.exe') {
            $path = [string]$p.ExecutablePath
            if ([string]::IsNullOrWhiteSpace($path)) { $unk++ }
            elseif (($path -match '(?i)\\AnthropicClaude\\') -or (($path -match '(?i)\\WindowsApps\\') -and ($path -match '(?i)claude'))) { $desk++ }
            else { $cc++ }
        }
        elseif ($n -ieq 'node.exe') {
            if ($null -eq $p.CommandLine) { $nodeUnk++ }
            elseif ([string]$p.CommandLine -match '(?i)claude-code') { $nodeCc++ }
        }
    }
    return ('CC claude.exe={0}; настолно приложение Claude={1}; claude.exe с неустановен път={2}; node.exe с claude-code={3}; node.exe с нечетим команден ред={4}' -f $cc, $desk, $unk, $nodeCc, $nodeUnk)
}

# Обхожда дървото, без да следва junction/symlink (описва ги отделно).
function Get-TreeInventory([string]$RootPlain) {
    $files   = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $dirSet  = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $reparse = [System.Collections.Generic.List[object]]::new()
    $errors  = [System.Collections.Generic.List[object]]::new()
    $dirCount = 0
    $rootInfo = [System.IO.DirectoryInfo]::new((Get-LongPathForm $RootPlain))
    $rootFull = $rootInfo.FullName.TrimEnd('\')
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push($rootFull)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        try {
            $entries = ([System.IO.DirectoryInfo]::new($dir)).GetFileSystemInfos()
        }
        catch {
            $relDir = $dir.Substring($rootFull.Length).TrimStart('\')
            if ($relDir -eq '') { $relDir = '.' }
            $errors.Add([pscustomobject]@{ RelativePath = $relDir; Error = $_.Exception.GetType().Name })
            continue
        }
        foreach ($e in $entries) {
            $rel = $e.FullName.Substring($rootFull.Length).TrimStart('\')
            $isDir = $e -is [System.IO.DirectoryInfo]
            if (Test-IsReparse $e.Attributes) {
                $kind = 'FILE'
                if ($isDir) { $kind = 'DIR' }
                $target = '?'
                try {
                    # Чете само метаданните на връзката (-Force), не следва целта.
                    $gi = Get-Item -LiteralPath ($RootPlain.TrimEnd('\') + '\' + $rel) -Force -ErrorAction Stop
                    if ($gi.PSObject.Properties['LinkType'] -and $gi.LinkType) { $kind = $kind + '/' + $gi.LinkType }
                    if ($gi.PSObject.Properties['Target'] -and $gi.Target) { $target = (@($gi.Target) -join ';') }
                }
                catch { $target = '?' }
                $reparse.Add([pscustomobject]@{ RelativePath = $rel; Kind = $kind; Target = $target })
                continue
            }
            if ($isDir) {
                $dirCount++
                [void]$dirSet.Add($rel)
                $stack.Push($e.FullName)
            }
            elseif ($files.ContainsKey($rel)) {
                $errors.Add([pscustomobject]@{ RelativePath = $rel; Error = 'сблъсък по главни/малки букви' })
            }
            else {
                $files[$rel] = [pscustomobject]@{ RelativePath = $rel; Bytes = [long]$e.Length; LastWriteUtcTicks = $e.LastWriteTimeUtc.Ticks }
            }
        }
    }
    return [pscustomobject]@{ Files = $files; DirSet = $dirSet; Reparse = $reparse; Errors = $errors; Dirs = $dirCount }
}

function Get-LinkMap($inv) {
    $m = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($r in $inv.Reparse) { $m[$r.RelativePath] = ($r.Kind + ' -> ' + $r.Target) }
    return ,$m
}

function Get-TotalBytes($inv) {
    $t = [long]0
    foreach ($f in $inv.Files.Values) { $t += [long]$f.Bytes }
    return $t
}

function Get-SortedKeys($dict) {
    $k = [string[]]@($dict.Keys)
    [System.Array]::Sort($k, [System.StringComparer]::OrdinalIgnoreCase)
    return ,$k
}

function Write-TextFile([string]$path, [string]$text, $enc) {
    [System.IO.File]::WriteAllText((Get-LongPathForm $path), $text, $enc)
}

try {
    Write-Host '=== Backup-ClaudeHome.ps1 v3 (FAB-632/16121 т.4; FAB-618) ===' -ForegroundColor Cyan
    Write-Host 'ВНИМАНИЕ: всяка сесия на Claude Code (и настолното приложение Claude) трябва да е ЗАТВОРЕНА.' -ForegroundColor Yellow
    Write-Host '          Скриптът НЕ я спира; всяка промяна по време на копирането дава ЧАСТИЧНО.' -ForegroundColor Yellow
    Write-Host 'ВНИМАНИЕ: копието съдържа тайни (claude.json.bak, ~/.claude\.credentials.json, ако го има, и други токени). Не го споделяй и не го качвай.' -ForegroundColor Yellow

    # ---------- Проверки преди всичко (нищо не се пише) ----------
    if ($Stamp -notmatch '^\d{8}-\d{4}$') { Write-Stop "Stamp трябва да е yyyyMMdd-HHmm, получено: $Stamp" }
    $SourceFull = [System.IO.Path]::GetFullPath($Source).TrimEnd('\')
    $JsonFull   = [System.IO.Path]::GetFullPath($SourceJson)
    $RootFull   = [System.IO.Path]::GetFullPath($BackupRoot).TrimEnd('\')
    $Dest       = $RootFull + '\' + $Stamp
    $DestTree   = $Dest + '\.claude'
    $DestJson   = $Dest + '\claude.json.bak'
    $ReportPath = $Dest + '\BACKUP-REPORT.md'
    $ManifestPath = $Dest + '\MANIFEST.sha256.csv'
    $RcLog      = $Dest + '\robocopy.log'
    $Latest     = $RootFull + '\LATEST.txt'

    # ---------- v3: пазач за пробите (истинските пътища са забранени) ----------
    $tmFull = ''; $tlFull = ''; $tgFull = ''
    if ($script:IsProbe) {
        foreach ($k in @('Source', 'SourceJson', 'BackupRoot')) {
            if (-not $PSBoundParameters.ContainsKey($k)) { Write-Stop ('ПРОБА: -' + $k + ' трябва да е подаден изрично (фалшив път в пробната папка)') }
        }
        $realHome = [Environment]::GetFolderPath('UserProfile')
        $forbidden = @(
            (Join-Path $realHome '.claude'), (Join-Path $realHome '.claude.json'), (Join-Path $realHome 'claude-backup'),
            'C:\Users\User\.claude', 'C:\Users\User\.claude.json', 'C:\Users\User\claude-backup')
        foreach ($f in $forbidden) {
            $ff = [System.IO.Path]::GetFullPath($f).TrimEnd('\')
            foreach ($p in @($SourceFull, $JsonFull, $RootFull)) {
                if (Test-Under $p $ff) { Write-Stop ('ПРОБА: истинският път е забранен: ' + $p) }
            }
        }
        if (-not [string]::IsNullOrEmpty($TestModifyPathAfterCopy)) {
            $tmFull = [System.IO.Path]::GetFullPath($TestModifyPathAfterCopy)
            $tmOk = (Test-Under $tmFull $SourceFull) -or [string]::Equals($tmFull, $JsonFull, [System.StringComparison]::OrdinalIgnoreCase)
            if (-not $tmOk) { Write-Stop 'ПРОБА: -TestModifyPathAfterCopy трябва да е под -Source или да е -SourceJson' }
            if (-not [System.IO.File]::Exists($tmFull)) { Write-Stop 'ПРОБА: -TestModifyPathAfterCopy трябва да е съществуващ файл' }
        }
        if ((-not [string]::IsNullOrEmpty($TestLinkTargetAfterCopy)) -and [string]::IsNullOrEmpty($TestLinkPathAfterCopy)) {
            Write-Stop 'ПРОБА: -TestLinkTargetAfterCopy иска и -TestLinkPathAfterCopy'
        }
        if (-not [string]::IsNullOrEmpty($TestLinkPathAfterCopy)) {
            $tlFull = [System.IO.Path]::GetFullPath($TestLinkPathAfterCopy).TrimEnd('\')
            if (-not (Test-Under $tlFull $SourceFull) -or [string]::Equals($tlFull, $SourceFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Stop 'ПРОБА: -TestLinkPathAfterCopy трябва да е под -Source'
            }
            if ([System.IO.File]::Exists($tlFull)) { Write-Stop 'ПРОБА: на -TestLinkPathAfterCopy има файл; очаква се нищо или junction' }
            if ([System.IO.Directory]::Exists($tlFull) -and -not (Test-IsReparse ([System.IO.File]::GetAttributes($tlFull)))) {
                Write-Stop 'ПРОБА: на -TestLinkPathAfterCopy има обикновена папка; очаква се нищо или junction'
            }
            if ((-not [System.IO.Directory]::Exists($tlFull)) -and [string]::IsNullOrEmpty($TestLinkTargetAfterCopy)) {
                Write-Stop 'ПРОБА: няма връзка за махане и няма цел за нова'
            }
            if (-not [string]::IsNullOrEmpty($TestLinkTargetAfterCopy)) {
                $tgFull = [System.IO.Path]::GetFullPath($TestLinkTargetAfterCopy).TrimEnd('\')
                if (-not [System.IO.Directory]::Exists($tgFull)) { Write-Stop 'ПРОБА: -TestLinkTargetAfterCopy трябва да е съществуваща папка' }
                foreach ($f in $forbidden) {
                    if (Test-Under $tgFull ([System.IO.Path]::GetFullPath($f).TrimEnd('\'))) { Write-Stop 'ПРОБА: целта на връзката е в истински път' }
                }
            }
        }
        Write-Host 'ПРОБА: фалшив източник; отчетът ще пише „- ПРОБА: да“; LATEST.txt няма да се пипа.' -ForegroundColor Magenta
    }

    if (-not [System.IO.Directory]::Exists($SourceFull)) { Write-Stop "липсва папката-източник: $SourceFull" }
    if (Test-IsReparse ([System.IO.File]::GetAttributes($SourceFull))) { Write-Stop "източникът е junction/symlink: $SourceFull" }
    if (-not [System.IO.File]::Exists($JsonFull)) { Write-Stop "липсва файлът: $JsonFull" }
    if ($RootFull.StartsWith('\\')) { Write-Stop "BackupRoot трябва да е локален диск, не UNC: $RootFull" }
    if ($RootFull -match '~\d') { Write-Stop "BackupRoot съдържа къс 8.3 път; дай пълния път: $RootFull" }
    $anc = $RootFull
    while ($anc) {
        if ([System.IO.Directory]::Exists($anc) -and (Test-IsReparse ([System.IO.File]::GetAttributes($anc)))) { Write-Stop "BackupRoot или негов родител е junction/symlink: $anc" }
        $anc = [System.IO.Path]::GetDirectoryName($anc)
    }
    if ((Test-Under $Dest $SourceFull) -or (Test-Under $SourceFull $Dest) -or (Test-Under $JsonFull $Dest)) { Write-Stop 'целевата папка и източникът се припокриват' }
    if ([System.IO.Directory]::Exists($Dest) -or [System.IO.File]::Exists($Dest)) { Write-Stop "целевата папка вече съществува: $Dest" }

    try { $script:UseLp = [System.IO.Directory]::Exists('\\?\' + $SourceFull) } catch { $script:UseLp = $false }
    $lpMode = 'обикновени пътища (дълги пътища >260 може да се окажат ПРОПУСНАТИ)'
    if ($script:UseLp) { $lpMode = 'префикс \\?\ (дълги пътища се четат)' }

    $procStart = Get-ProcText
    Write-Host ('Процеси в началото: ' + $procStart)

    # ---------- Git: само опис, само четене ----------
    $gitHead = 'няма .git'
    $gitBranch = 'няма .git'
    if ([System.IO.Directory]::Exists($SourceFull + '\.git') -or [System.IO.File]::Exists($SourceFull + '\.git')) {
        $gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
        if ($null -eq $gitCmd) {
            $gitHead = 'НЕПРОВЕРЕНО (git липсва в PATH)'
            $gitBranch = $gitHead
        }
        else {
            $oldLocks = $env:GIT_OPTIONAL_LOCKS
            $oldEap = $ErrorActionPreference
            $env:GIT_OPTIONAL_LOCKS = '0'
            $ErrorActionPreference = 'Continue'
            try {
                $h = @(& $gitCmd.Path -C $SourceFull rev-parse HEAD 2>$null)
                $hc = $LASTEXITCODE
                if ($hc -eq 0 -and $h.Count -gt 0) { $gitHead = ([string]$h[0]).Trim() } else { $gitHead = "НЕПРОВЕРЕНО (git rev-parse код $hc)" }
                $b = @(& $gitCmd.Path -C $SourceFull branch --show-current 2>$null)
                $bc = $LASTEXITCODE
                if ($bc -ne 0) { $gitBranch = "НЕПРОВЕРЕНО (git branch код $bc)" }
                elseif ($b.Count -eq 0 -or ([string]$b[0]).Trim() -eq '') { $gitBranch = '(откъснат HEAD)' }
                else { $gitBranch = ([string]$b[0]).Trim() }
            }
            finally {
                $ErrorActionPreference = $oldEap
                $env:GIT_OPTIONAL_LOCKS = $oldLocks
            }
        }
    }

    # ---------- (1) Опис преди ----------
    Write-Host '(1/6) Опис преди копирането...'
    $startLocal = Get-Date
    $pre = Get-TreeInventory $SourceFull
    $preBytes = Get-TotalBytes $pre
    $jsonLen = ([System.IO.FileInfo]::new((Get-LongPathForm $JsonFull))).Length
    $need = [long]2 * ($preBytes + $jsonLen)
    $driveRoot = [System.IO.Path]::GetPathRoot($RootFull)
    $free = ([System.IO.DriveInfo]::new($driveRoot)).AvailableFreeSpace
    Write-Host ("      файлове: {0}; байтове: {1}; .claude.json: {2} B; reparse: {3}; грешки при обхождане: {4}" -f $pre.Files.Count, $preBytes, $jsonLen, $pre.Reparse.Count, $pre.Errors.Count)
    Write-Host ("      свободно на {0}: {1} B; нужно (2x): {2} B" -f $driveRoot, $free, $need)
    if ($free -lt $need) { Write-Stop ("свободното място ({0} B) е под 2x размера ({1} B)" -f $free, $need) }

    # ---------- Създаване на НОВА целева папка ----------
    [void][System.IO.Directory]::CreateDirectory($RootFull)
    try { [void](New-Item -ItemType Directory -Path $Dest -ErrorAction Stop) }
    catch { Write-Stop "не мога да създам НОВА целева папка (вероятно вече съществува): $Dest" }
    $script:DestCreated = $true

    # ---------- (2) Копие на дървото ----------
    Write-Host '(2/6) robocopy на дървото (връзките от описа се изключват изрично с /XD и /XF)...'
    $xd = @(); $xf = @()
    foreach ($r in $pre.Reparse) {
        $full = $SourceFull + '\' + $r.RelativePath
        if ($r.Kind -like 'DIR*') { $xd += $full } else { $xf += $full }
    }
    $rcArgs = @($SourceFull, $DestTree, '/E', '/COPY:DAT', '/DCOPY:T', '/XJ', '/R:1', '/W:1', '/NP', '/NFL', '/NDL', '/BYTES', ('/UNILOG:' + $RcLog))
    if ($xd.Count -gt 0) { $rcArgs += '/XD'; $rcArgs += $xd }
    if ($xf.Count -gt 0) { $rcArgs += '/XF'; $rcArgs += $xf }
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & robocopy.exe @rcArgs | Out-Null
        $rc = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $oldEap }
    Write-Host ("      robocopy код: {0} (ПРОВЕРЕНО изисква 0-7; проверката по sha256 по-долу е задължителна)" -f $rc)

    # ---------- (3) Копие на .claude.json (без извеждане на съдържание) ----------
    Write-Host '(3/6) Копие на .claude.json -> claude.json.bak...'
    $jsonOk = $false
    $jsonTries = 0
    $jsonBakHash = ''
    $jsonParse = 'не е проверено'
    $jsonErr = ''
    $bytes = $null
    while (-not $jsonOk -and $jsonTries -lt 3) {
        $jsonTries++
        try {
            $bytes = Read-AllShared $JsonFull
            $hRead = Get-Sha256OfBytes $bytes
            [System.IO.File]::WriteAllBytes((Get-LongPathForm $DestJson), $bytes)
            $hSrcAfter = Get-Sha256 $JsonFull
            $jsonBakHash = Get-Sha256 $DestJson
            if ($hRead -eq $hSrcAfter -and $hRead -eq $jsonBakHash) { $jsonOk = $true }
            else { Start-Sleep -Milliseconds 500 }
        }
        catch {
            $jsonErr = $_.Exception.GetType().Name
            Start-Sleep -Milliseconds 500
        }
    }
    $jsonCopyOk = $jsonOk
    if ($jsonOk) {
        try { [System.IO.File]::SetLastWriteTimeUtc((Get-LongPathForm $DestJson), [System.IO.File]::GetLastWriteTimeUtc((Get-LongPathForm $JsonFull))) } catch { }
        try {
            $txt = $script:Utf8NoBom.GetString($bytes).TrimStart([char]0xFEFF)
            $null = $txt | ConvertFrom-Json -ErrorAction Stop
            $jsonParse = 'да'
        }
        catch { $jsonParse = 'не (само информативно; ConvertFrom-Json в 5.1 отказва ключове, различни само по главни/малки букви)' }
        $txt = $null
    }
    $bytes = $null

    # ---------- v3: пробна промяна (само фалшив източник, виж пазача по-горе) ----------
    if ($script:IsProbe) {
        Write-Host '      [ПРОБА] промяна след копирането и преди манифеста' -ForegroundColor Magenta
        if ($tmFull -ne '') { [System.IO.File]::AppendAllText($tmFull, "`n") }
        if ($tlFull -ne '') {
            if ([System.IO.Directory]::Exists($tlFull)) {
                # Пазачът е потвърдил, че това е reparse точка; Delete без рекурсия маха само връзката, не целта.
                [System.IO.Directory]::Delete($tlFull, $false)
            }
            if ($tgFull -ne '') { [void](New-Item -ItemType Junction -Path $tlFull -Target $tgFull -ErrorAction Stop) }
        }
    }

    # ---------- (4) Манифест на източника ----------
    Write-Host '(4/6) MANIFEST.sha256.csv (sha256 на всеки файл на източника)...'
    $post = Get-TreeInventory $SourceFull
    $postBytes = Get-TotalBytes $post
    $postKeys = Get-SortedKeys $post.Files
    $manifestHash = @{}
    $unreadableSrc = [System.Collections.Generic.List[string]]::new()
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"RelativePath","Bytes","Sha256"' + "`r`n")
    foreach ($rel in $postKeys) {
        $f = $post.Files[$rel]
        $h = ''
        try { $h = Get-Sha256 ($SourceFull + '\' + $rel) }
        catch { $h = ''; $unreadableSrc.Add($rel) }
        $manifestHash[$rel] = $h
        [void]$sb.Append('"' + $rel.Replace('"', '""') + '",' + $f.Bytes + ',"' + $h + '"' + "`r`n")
    }
    Write-TextFile $ManifestPath $sb.ToString() $script:Utf8Bom
    $sb = $null
    $manifestSha = Get-Sha256 $ManifestPath

    # ---------- (5) Проверка на копието ----------
    Write-Host '(5/6) Проверка: копието съществува, sha256 съвпада, връзките са стабилни...'
    $destInv = $null
    if ([System.IO.Directory]::Exists((Get-LongPathForm $DestTree))) { $destInv = Get-TreeInventory $DestTree }
    $destFiles = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $destDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $destErrors = [System.Collections.Generic.List[object]]::new()
    if ($null -ne $destInv) { $destFiles = $destInv.Files; $destDirs = $destInv.DirSet; $destErrors = $destInv.Errors }

    $reparseDirs = @()
    foreach ($r in $pre.Reparse) { if ($r.Kind -like 'DIR*') { $reparseDirs += $r.RelativePath } }
    foreach ($r in $post.Reparse) { if ($r.Kind -like 'DIR*') { $reparseDirs += $r.RelativePath } }

    $matched = 0
    $diffAllowed = [System.Collections.Generic.List[object]]::new()
    $diffBad = [System.Collections.Generic.List[object]]::new()
    function Add-Diff([string]$rel, [string]$kind, [bool]$canBeLive) {
        $o = [pscustomobject]@{ RelativePath = $rel; Kind = $kind }
        if ($canBeLive -and (Test-Live $rel)) { $diffAllowed.Add($o) } else { $diffBad.Add($o) }
    }

    foreach ($rel in $postKeys) {
        $mh = $manifestHash[$rel]
        if (-not $destFiles.ContainsKey($rel)) {
            if ($pre.Files.ContainsKey($rel)) { Add-Diff $rel 'ЛИПСВА В КОПИЕТО' $false }
            else { Add-Diff $rel 'НОВ СЛЕД ОПИСА, ЛИПСВА В КОПИЕТО' $true }
            continue
        }
        if ($mh -eq '') { Add-Diff $rel 'ИЗТОЧНИКЪТ НЕ СЕ ЧЕТЕ (заключен?)' $false; continue }
        $hc = ''
        try { $hc = Get-Sha256 ($DestTree + '\' + $rel) }
        catch { Add-Diff $rel 'КОПИЕТО НЕ СЕ ЧЕТЕ' $false; continue }
        if ($hc -eq $mh) { $matched++ }
        else { Add-Diff $rel 'SHA256 РАЗЛИКА (сменен по време на копирането)' $true }
    }
    foreach ($rel in (Get-SortedKeys $destFiles)) {
        if ($post.Files.ContainsKey($rel)) { continue }
        $underJunction = $false
        foreach ($rd in $reparseDirs) { if (Test-Under $rel $rd) { $underJunction = $true } }
        if ($underJunction) { Add-Diff $rel 'ПОСЛЕДВАН JUNCTION/SYMLINK (не трябва)' $false }
        elseif ($pre.Files.ContainsKey($rel)) { Add-Diff $rel 'ИЗЧЕЗНАЛ ОТ ИЗТОЧНИКА СЛЕД КОПИЕТО' $true }
        else { Add-Diff $rel 'НЕОЧАКВАН В КОПИЕТО' $true }
    }

    foreach ($rel in (Get-SortedKeys $pre.Files)) {
        if (-not $post.Files.ContainsKey($rel) -and -not $destFiles.ContainsKey($rel)) { Add-Diff $rel 'ИЗЧЕЗНАЛ ПРЕДИ КОПИЕТО' $true }
    }

    # v3 (Д7): папките (вкл. празните) също се сверяват.
    foreach ($d in $post.DirSet) {
        if (-not $destDirs.Contains($d)) { Add-Diff $d 'ПАПКА ЛИПСВА В КОПИЕТО' $true }
    }
    foreach ($d in $destDirs) {
        if ($post.DirSet.Contains($d)) { continue }
        $underJunction = $false
        foreach ($rd in $reparseDirs) { if (Test-Under $d $rd) { $underJunction = $true } }
        if ($underJunction) { Add-Diff $d 'ПОСЛЕДВАН JUNCTION/SYMLINK (папка, не трябва)' $false }
        else { Add-Diff $d 'НЕОЧАКВАНА ПАПКА В КОПИЕТО' $true }
    }

    # v3 (Астра Б2; Рачо 16137 т. 4): описът на връзките в началото и в края — по относителен път, вид и цел.
    $preLinks = Get-LinkMap $pre
    $postLinks = Get-LinkMap $post
    $linkChanges = 0
    $linkUnknown = 0
    foreach ($k in (Get-SortedKeys $preLinks)) {
        if (-not $postLinks.ContainsKey($k)) { $diffBad.Add([pscustomobject]@{ RelativePath = $k; Kind = 'ВРЪЗКА ИЗЧЕЗНАЛА' }); $linkChanges++ }
        elseif ($preLinks[$k] -ne $postLinks[$k]) { $diffBad.Add([pscustomobject]@{ RelativePath = $k; Kind = 'ВРЪЗКА СМЕНЕНА (вид или цел)' }); $linkChanges++ }
    }
    foreach ($k in (Get-SortedKeys $postLinks)) {
        if (-not $preLinks.ContainsKey($k)) { $diffBad.Add([pscustomobject]@{ RelativePath = $k; Kind = 'ВРЪЗКА ДОБАВЕНА' }); $linkChanges++ }
    }
    $unknownSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($r in (@($pre.Reparse) + @($post.Reparse))) {
        if ($r.Target -eq '?' -and $unknownSeen.Add($r.RelativePath)) {
            $diffBad.Add([pscustomobject]@{ RelativePath = $r.RelativePath; Kind = 'ВРЪЗКА С НЕИЗВЕСТНА ЦЕЛ „?“ (нечетими метаданни)' })
            $linkUnknown++
        }
    }
    # В копието не бива да има нито връзка, нито съдържание на мястото на връзка.
    $allLinkRels = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($k in $preLinks.Keys) { [void]$allLinkRels.Add($k) }
    foreach ($k in $postLinks.Keys) { [void]$allLinkRels.Add($k) }
    foreach ($k in $allLinkRels) {
        if ($destFiles.ContainsKey($k)) { $diffBad.Add([pscustomobject]@{ RelativePath = $k; Kind = 'НА МЯСТОТО НА ВРЪЗКА В КОПИЕТО ИМА ФАЙЛ' }) }
        if ($destDirs.Contains($k)) { $diffBad.Add([pscustomobject]@{ RelativePath = $k; Kind = 'НА МЯСТОТО НА ВРЪЗКА В КОПИЕТО ИМА ПАПКА' }) }
    }
    if ($null -ne $destInv) {
        foreach ($r in $destInv.Reparse) { $diffBad.Add([pscustomobject]@{ RelativePath = $r.RelativePath; Kind = 'ВРЪЗКА В КОПИЕТО (не трябва)' }) }
    }
    $linkSame = 'еднакъв'
    if ($linkChanges -gt 0) { $linkSame = 'РАЗЛИЧЕН' }

    $skipped = [System.Collections.Generic.List[object]]::new()
    foreach ($e in $pre.Errors)  { $skipped.Add([pscustomobject]@{ RelativePath = $e.RelativePath; Where = 'опис преди'; Error = $e.Error }) }
    foreach ($e in $post.Errors) { $skipped.Add([pscustomobject]@{ RelativePath = $e.RelativePath; Where = 'манифест'; Error = $e.Error }) }
    foreach ($e in $destErrors)  { $skipped.Add([pscustomobject]@{ RelativePath = $e.RelativePath; Where = 'копие'; Error = $e.Error }) }
    if ($null -eq $destInv) { $skipped.Add([pscustomobject]@{ RelativePath = '.claude'; Where = 'копие'; Error = 'папката на копието липсва' }) }

    $missingCount = 0
    foreach ($d in $diffBad) { if ($d.Kind -like '*ЛИПСВА В КОПИЕТО*') { $missingCount++ } }
    foreach ($d in $diffAllowed) { if ($d.Kind -like '*ЛИПСВА В КОПИЕТО*') { $missingCount++ } }

    $gitIsReparse = $false
    foreach ($r in $pre.Reparse) { if ($r.RelativePath -eq '.git') { $gitIsReparse = $true } }
    if ($gitIsReparse) { $diffBad.Add([pscustomobject]@{ RelativePath = '.git'; Kind = '.git е junction/symlink — не е копиран' }) }

    # v3 (Астра Б1): повторна сверка на източника .claude.json срещу claude.json.bak точно преди статуса.
    $jsonRecheck = 'не е направена (копието на JSON не е потвърдено)'
    if ($jsonCopyOk) {
        try {
            $hNow = Get-Sha256 $JsonFull
            if ($hNow -eq $jsonBakHash) { $jsonRecheck = 'съвпада' }
            else { $jsonRecheck = 'РАЗЛИКА (източникът е сменен след копирането)'; $jsonOk = $false }
        }
        catch { $jsonRecheck = 'ИЗТОЧНИКЪТ НЕ СЕ ЧЕТЕ (' + $_.Exception.GetType().Name + ')'; $jsonOk = $false }
    }

    $procEnd = Get-ProcText

    # v3 (Астра Б1): точната формула. Всяка липса, несъвпадение или неустановена проверка → ЧАСТИЧНО.
    $verified = ($diffBad.Count -eq 0) -and
                ($diffAllowed.Count -eq 0) -and
                ($skipped.Count -eq 0) -and
                $jsonOk -and
                ($rc -ge 0) -and ($rc -lt 8)
    $status = 'ЧАСТИЧНО'
    if ($verified) { $status = 'ПРОВЕРЕНО' }

    # ---------- (6) Отчет ----------
    Write-Host '(6/6) BACKUP-REPORT.md...'
    $scriptSha = 'НЕПРОВЕРЕНО'
    if ($PSCommandPath) { try { $scriptSha = Get-Sha256 $PSCommandPath } catch { } }
    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add('# BACKUP-REPORT — резервно копие на ~/.claude и ~/.claude.json')
    $L.Add('')
    $L.Add('- Решение: FAB-632/16121 т.4 (свързано с FAB-618); преди инсталацията на REA')
    $L.Add('- Начало (локално): ' + $startLocal.ToString('yyyy-MM-dd HH:mm:ss zzz'))
    $L.Add('- Край (локално): ' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))
    $L.Add('- Скрипт: ' + $PSCommandPath + ' (Backup-ClaudeHome.ps1 v3; sha256 ' + $scriptSha + ')')
    $L.Add('- Източник: ' + $SourceFull)
    $L.Add('- Източник JSON: ' + $JsonFull)
    $L.Add('- Копие: ' + $Dest)
    $L.Add('- ПРОБА: ' + $script:ProbeText)
    $L.Add('- Git HEAD на ~/.claude: ' + $gitHead)
    $L.Add('- Git клон на ~/.claude: ' + $gitBranch)
    $L.Add('- Режим на пътищата: ' + $lpMode)
    $L.Add('- Процеси в началото: ' + $procStart)
    $L.Add('- Процеси в края: ' + $procEnd)
    $L.Add('')
    $L.Add('## Опис')
    $L.Add(('- Преди: {0} файла, {1} B, {2} папки' -f $pre.Files.Count, $preBytes, $pre.Dirs))
    $L.Add(('- Свободно преди на {0}: {1} B; нужно (2x): {2} B' -f $driveRoot, $free, $need))
    $L.Add(('- robocopy код: {0} (ПРОВЕРЕНО изисква 0-7)' -f $rc))
    $L.Add(('- Манифест (след копието): {0} файла, {1} B, {2} папки' -f $post.Files.Count, $postBytes, $post.Dirs))
    $L.Add(('- Съвпадащи sha256: {0} от {1}' -f $matched, $post.Files.Count))
    $L.Add(('- Липсващи в копието: {0}' -f $missingCount))
    $L.Add(('- Разлики в допустими живи пътища: {0}' -f $diffAllowed.Count))
    $L.Add(('- Разлики НЕдопустими: {0}' -f $diffBad.Count))
    $L.Add(('- Пропуснати (грешки при обхождане): {0}' -f $skipped.Count))
    $L.Add(('- Reparse точки: {0} — съдържанието на целите им НЕ е в копието' -f $pre.Reparse.Count))
    $L.Add('- Опис на връзките преди/след: ' + $linkSame)
    $L.Add(('- Връзки с неизвестна цел „?“: {0}' -f $linkUnknown))
    $L.Add('')
    $L.Add('## claude.json.bak')
    if ([System.IO.File]::Exists((Get-LongPathForm $DestJson))) {
        $bakNow = Get-Sha256 $DestJson
        $L.Add(('- Размер: {0} B; sha256: {1}' -f ([System.IO.FileInfo]::new((Get-LongPathForm $DestJson))).Length, $bakNow))
    }
    else {
        $L.Add('- claude.json.bak НЕ е записан')
    }
    if ($jsonCopyOk) {
        $L.Add(('- Съвпада с източника при копирането: да (опит {0} от 3)' -f $jsonTries))
        $L.Add('- JSON се чете от ConvertFrom-Json: ' + $jsonParse)
    }
    else {
        $L.Add(('- Съвпада с източника при копирането: НЕ е потвърдено след {0} опита (грешка: {1})' -f $jsonTries, $jsonErr))
    }
    $L.Add('- Повторна сверка на източника точно преди статуса: ' + $jsonRecheck)
    $L.Add('')
    $L.Add('## MANIFEST.sha256.csv')
    $L.Add('- sha256: ' + $manifestSha)
    $L.Add('- Колони: RelativePath, Bytes, Sha256 (празно Sha256 = файлът не се чете)')
    $L.Add('')
    $L.Add('## Допустими живи пътища (шаблони спрямо източника)')
    if (@($AllowedLivePatterns).Count -eq 0) { $L.Add('- няма') }
    foreach ($p in $AllowedLivePatterns) { $L.Add('- `' + $p + '`') }
    $L.Add('- Разлика и в тях дава ЧАСТИЧНО (Астра Б1).')
    $L.Add('')
    $L.Add('## Връзки (junction/symlink/reparse) — описани, НЕ следвани, НЕ копирани')
    $L.Add('- Съдържанието на целите им НЕ е част от копието. Описът служи за ръчно възстановяване на връзките.')
    if ($pre.Reparse.Count -eq 0) { $L.Add('- няма (в началото)') }
    foreach ($r in $pre.Reparse) { $L.Add('- `' + $r.RelativePath + '` [' + $r.Kind + '] -> ' + $r.Target) }
    if ($linkChanges -gt 0) {
        $L.Add('')
        $L.Add('## Връзки в края (описът е РАЗЛИЧЕН)')
        if ($post.Reparse.Count -eq 0) { $L.Add('- няма') }
        foreach ($r in $post.Reparse) { $L.Add('- `' + $r.RelativePath + '` [' + $r.Kind + '] -> ' + $r.Target) }
    }
    $L.Add('')
    $L.Add('## РАЗЛИКИ — НЕдопустими')
    if ($diffBad.Count -eq 0) { $L.Add('- няма') }
    foreach ($d in $diffBad) { $L.Add('- `' + $d.RelativePath + '` — ' + $d.Kind) }
    $L.Add('')
    $L.Add('## РАЗЛИКИ — в допустими живи пътища (не са успех; копието може да е по-старо)')
    if ($diffAllowed.Count -eq 0) { $L.Add('- няма') }
    foreach ($d in $diffAllowed) { $L.Add('- `' + $d.RelativePath + '` — ' + $d.Kind) }
    $L.Add('')
    $L.Add('## ПРОПУСНАТИ')
    if ($skipped.Count -eq 0) { $L.Add('- няма') }
    foreach ($s in $skipped) { $L.Add('- `' + $s.RelativePath + '` (' + $s.Where + ') — ' + $s.Error) }
    $L.Add('')
    $L.Add('## Сигурност')
    $L.Add('- Копието съдържа тайни: claude.json.bak (може да носи токени), ~/.claude\.credentials.json (ако го има) и други токени или ключове в ~/.claude. Остава локално; не се качва (вкл. в GitHub) и не се споделя.')
    $L.Add('- Този отчет не съдържа съдържание на файлове, ключове, стойности на env или командни редове на процеси.')
    $L.Add('- LATEST.txt се обновява само при СТАТУС: ПРОВЕРЕНО и без проба, след записа на този отчет.')
    $L.Add('')
    $L.Add('СТАТУС: ' + $status)
    Write-TextFile $ReportPath (($L -join "`r`n") + "`r`n") $script:Utf8Bom
    $script:ReportWritten = $true

    if ($verified -and -not $script:IsProbe) {
        $tmp = $Dest + '\LATEST.txt.tmp'
        try {
            Write-TextFile $tmp ($Dest + "`r`n") $script:Utf8NoBom
            if ([System.IO.File]::Exists($Latest)) { [System.IO.File]::Replace($tmp, $Latest, $null) }
            else { [System.IO.File]::Move($tmp, $Latest) }
            Write-Host ('LATEST.txt -> ' + $Dest)
        }
        catch {
            $verified = $false
            $status = 'ЧАСТИЧНО'
            try { if ([System.IO.File]::Exists($tmp)) { [System.IO.File]::Delete($tmp) } } catch { }
            $L[$L.Count - 1] = '- LATEST.txt: НЕУСПЕХ при обновяване (' + $_.Exception.GetType().Name + ')'
            $L.Add('')
            $L.Add('СТАТУС: ' + $status)
            Write-TextFile $ReportPath (($L -join "`r`n") + "`r`n") $script:Utf8Bom
            Write-Host 'LATEST.txt НЕ е обновен (грешка); статусът е ЧАСТИЧНО.' -ForegroundColor Red
        }
    }
    elseif ($script:IsProbe) {
        Write-Host 'LATEST.txt НЕ е пипан (ПРОБА).' -ForegroundColor Yellow
    }
    else {
        Write-Host 'LATEST.txt НЕ е пипан (статусът не е ПРОВЕРЕНО).' -ForegroundColor Yellow
    }
    $reportSha = Get-Sha256 $ReportPath

    Write-Host ''
    Write-Host ('ОТЧЕТ: ' + $ReportPath)
    Write-Host ('SHA256 (BACKUP-REPORT.md): ' + $reportSha)
    Write-Host ('СЪВПАДАЩИ: {0} от {1}; РАЗЛИКИ допустими: {2}; НЕдопустими: {3}; ПРОПУСНАТИ: {4}; ВРЪЗКИ: {5} (опис {6})' -f $matched, $post.Files.Count, $diffAllowed.Count, $diffBad.Count, $skipped.Count, $pre.Reparse.Count, $linkSame)
    Write-Host ('Процеси в края: ' + $procEnd)
    if ($verified) {
        Write-Host ('СТАТУС: ' + $status) -ForegroundColor Green
        exit 0
    }
    Write-Host ('СТАТУС: ' + $status) -ForegroundColor Red
    exit 1
}
catch {
    $errType = $_.Exception.GetType().FullName
    $errLine = $_.InvocationInfo.ScriptLineNumber
    Write-Host ('ГРЕШКА: ' + $errType + ' (ред ' + $errLine + ')') -ForegroundColor Red
    if ($script:DestCreated -and -not $script:ReportWritten) {
        try {
            $t = '# BACKUP-REPORT — прекъснато' + "`r`n`r`n" + '- Грешка: ' + $errType + ' (ред ' + $errLine + ')' + "`r`n" + '- ПРОБА: ' + $script:ProbeText + "`r`n" + '- LATEST.txt не е пипан.' + "`r`n`r`n" + 'СТАТУС: ЧАСТИЧНО' + "`r`n"
            Write-TextFile ($Dest + '\BACKUP-REPORT.md') $t $script:Utf8Bom
            Write-Host ('ОТЧЕТ: ' + $Dest + '\BACKUP-REPORT.md')
        }
        catch { }
    }
    Write-Host 'СТАТУС: ЧАСТИЧНО (неочаквана грешка)' -ForegroundColor Red
    exit 3
}
