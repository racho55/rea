#requires -Version 5.1
<#
.SYNOPSIS
  Инсталира или възстановява REA (npm пакет rea-agents) на Windows и го регистрира като MCP сървър "rea"
  за потребителя в Claude Code (user scope), с пълен профил на схемите.
  Версия на скрипта: v4 (Клара, 27.10.2026; ревю на Астра FAB-632/16129, сводният списък и решенията на Рачо FAB-632/16137).

.DESCRIPTION
  Решения: Jira FAB-632/16087 (пълна инсталация), 16098 (6.8.0, заключена), 16121 (резервно копие преди),
  16137 т. 2 (скриптът се пуска от Рачо от обикновен PowerShell при затворени всички Claude Code, веднага след
  резервното копие; Claude Code идва после само за проверки, GitHub копието и правилото).
  Резервно копие на REA: https://github.com/racho55/rea , клон racho-backup.
  Официални указания: github.com/morluto/rea, таг rea-agents-6.8.0, docs/installation.md и docs/cli.md.

  КАК СЕ ПУСКА (Рачо; обикновен прозорец на Windows PowerShell; всички Claude Code и настолното приложение
  Claude са затворени; веднага след Backup-ClaudeHome.ps1 v3 с код 0):
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -File <папка>\install-rea.ps1 `
      -LogDir "<нова папка за записи>" -BackupReport "<пълен път до BACKUP-REPORT.md>" -BackupReportSha256 "<sha256 на отчета>"
  -AcceptRunningSessions в v4 НЯМА (FAB-632/16137 т. 2). -LogDir трябва да е нова или празна папка.

  РЕЖИМИ (най-много един):
    (без превключвател)  пълна инсталация, стъпки 0-6.
    -DryRun              само проба: хешове на tarball-а; ако rea вече е инсталиран — rea setup --dry-run и
                         проверка на плана. Нищо не се инсталира и не се регистрира. Не иска резервно копие.
                         След пълна инсталация план „planned“ с 0 действия е успех (нищо за правене).
    -CheckBackupOnly     само проверката на резервното копие (договор А1 по-долу); изход 0 или 1. Не пише нищо.
    -VerifyOnly          само четящите проверки на готова регистрация (стъпка 6). Пише само в -LogDir.
    -SkipRegistration    инсталира npm пакета без регистрация (код 4; не е пълна инсталация).

  Стъпки: 0 предусловия (сесии, резервно копие, ~/.claude.json = claude.json.bak)
          1 Node, npm, registry, npm root -g   2 tarball и хешове   3 npm install --global <проверения tarball>
          4 rea doctor   5 rea setup --client claude_code: dry-run → проверка на плана → apply (status точно ready)
          6 проверки: rea doctor --client claude_code --skill, rea mcp doctor, claude mcp get rea (само редовете
            Scope/Status/Type), повторен dry-run (planned с 0 действия), повторен прочит на записа (command = node от
            стъпка 1; args[0] под `npm root -g`\rea-agents\), чуждите MCP записи (име и sha256) непроменени.
  Инсталира се точно провереният файл (npm install --global <път до .tgz>); зависимостите идват от npm registry
  и не са заключени от този скрипт.
  Профилът: rea setup пренася REA_MCP_INPUT_SCHEMA_PROFILE от средата на setup процеса в регистрацията
  (rea-agents 6.8.0, dist/application/SetupRegistrationEnvironment.js и SetupHost.js; по КАРТА_ПРОМЕНИ_v3).
  Скриптът НЕ прави claude mcp remove/add, НЕ обновява Node/npm, НЕ пипа други MCP сървъри, settings.json,
  hooks или permissions, НЕ редактира ~/.claude.json на ръка, НЕ трие регистрации, НЕ спира процеси и
  НЕ инсталира Ghidra/Java/JADX/Hopper.

  РАБОТЕЩИ СЕСИИ (пълна инсталация и -SkipRegistration; в стъпка 0 и наново непосредствено преди rea setup --yes):
    Скриптът СПИРА (код 1) при ВСЯКА сесия на Claude Code. От Win32_Process се ползват само Name, ExecutablePath
    и CommandLine; командният ред само се сравнява и не се печата.
      — CC: claude.exe, чийто път НЕ е на настолното приложение (напр. %USERPROFILE%\.local\bin\claude.exe или
        разширение за редактор), и node.exe, чийто команден ред съдържа claude-code (npm инсталация на CC).
      — Настолно приложение Claude (Claude Desktop): Claude.exe под %LOCALAPPDATA%\AnthropicClaude\ или под
        ...\WindowsApps\...Claude... То не е CC. Резервното копие обаче иска и то да е затворено, а може да носи
        вградени CC сесии (НЕПРОВЕРЕНО). Затова скриптът спира и при него, с отделно съобщение.
      — Неясно: claude.exe без четим път, node.exe без четим команден ред или неуспешна заявка към
        Get-CimInstance → СПИРА.
    В -DryRun, -CheckBackupOnly и -VerifyOnly сесиите само се отчитат (тези режими не пишат в ~/.claude.json).

  РЕЗЕРВНО КОПИЕ — договор А1 (Астра, FAB-632/16129); задължителен преди първата промяна; същото прави -CheckBackupOnly:
    Преди първото действие, което променя инсталацията, приеми резервното копие само ако:
    — размерът/хешът на подадения отчет са установени и SHA256 съвпада с разрешения;
    — отчетът има точно един краен статус ПРОВЕРЕНО и не е тестов отчет;
    — полетата Източник, Източник JSON и Копие сочат точно очакваните нормализирани пътища; срещане на път като
      свободен текст не е доказателство;
    — до отчета съществуват папката с копието на .claude, claude.json.bak и MANIFEST.sha256.csv;
    — хешовете на JSON копието и манифеста съвпадат с техните конкретни полета в отчета;
    — всеки ред от манифеста има уникален относителен път, размер и валиден SHA256; пътят остава вътре в копието,
      без абсолютен път, .. или преминаване през връзка;
    — действителните обикновени файлове в копието съответстват на манифеста по набор, размер и SHA256;
    — няма липсващи файлове, нечетими файлове или приети живи разлики.
    Липсващото или повредено копие не се приема само защото отчетът е останал. При отказ: стоп преди инсталация.
    Как се чете отчетът на Backup-ClaudeHome.ps1 v3: точно един ред „СТАТУС:“ и той е последният непразен ред;
    точно един ред „- ПРОБА: не“; редовете „- Източник:“, „- Източник JSON:“ и „- Копие:“ поотделно, сравнени
    като нормализирани пълни пътища с <ClaudeHome>\.claude, <ClaudeHome>\.claude.json и папката на отчета;
    „- Размер: N B; sha256: X“ в „## claude.json.bak“; „- sha256: X“ в „## MANIFEST.sha256.csv“; бройките
    „Липсващи…“, „Разлики…“ и „Пропуснати…“ = 0; „Съвпадащи sha256: N от N“; „- Опис на връзките преди/след: еднакъв“.
    Съдържание на файлове и тайни не се извежда.
    При пълна инсталация, допълнително: sha256 на сегашния ~/.claude.json трябва да е равен на claude.json.bak
    (в стъпка 0 и непосредствено преди rea setup --yes). Разлика → СТОП: някой е писал след копието.

  ИЗХОДНИ КОДОВЕ:
    0 = ГОТОВО: пълна инсталация; всички задължителни проверки минаха; ownership.json и install-result.json са записани.
        -DryRun: само проба („DRYRUN“). -CheckBackupOnly: копието е прието. -VerifyOnly: всички четящи проверки минаха.
    1 = СТОП: разлика, грешка, conflict, план извън обхвата, status различен от ready, неуспешно действие в apply,
        непроверено резервно копие, работеща или неясна сесия, неуспешен задължителен запис ПРЕДИ rea setup --yes.
    2 = инсталирано и регистрирано, но профилът в записа не е full (нищо не е поправяно).
    3 = ЧАСТИЧНО: rea setup --yes е пуснат, но задължителна проверка или задължителен запис не минаха (doctor,
        mcp doctor, claude mcp get, повторен dry-run, повторен прочит, чужди MCP записи, ownership.json,
        install-result.json). Регистрацията не е приета. В -VerifyOnly: проверка не мина.
    4 = -SkipRegistration: инсталирано без регистрация (не е пълна инсталация).
    При неуспешен задължителен запис: ненулев код, без „ГОТОВО“, без автоматично връщане или повторна регистрация,
    съобщение „ЗАПИС ЛИПСВА: <име>“ и „Извършени действия: …“.

  Хешовете по подразбиране са за 6.8.0. Диапазонът на Node по-долу е за 6.8.0.
  Свален от GitHub: първо свери sha256 на този файл с README-BACKUP.md, после Unblock-File .\install-rea.ps1
  (не се ползва -ExecutionPolicy Bypass).

  ВРЪЩАНЕ (не се изпълнява от скрипта; ръчно, по ownership.json от -LogDir):
    Връщането се определя от провереното начално състояние. За npm пакета, user-scope REA записа и всяка от
    двете skill папки се отбелязва: създадена, изменена или само използвана от задачата.
    Премахват се само създадените от задачата компоненти, след сверка, че текущата версия и съдържание още
    съответстват на доставеното. Предишна инсталация и предишни skills не се деинсталират. Изменен предишен
    REA запис или skill се възстановява само за засегнатия компонент от неговото проверено начално състояние.
    Последваща чужда промяна, друга версия или неизвестна собственост → СПРИ преди премахване. Целият
    .claude.json не се връща. rea uninstall не се използва.
    Състояние 'modified_or_kept' на записа: отделно възстановяване на стария запис НЯМА; старото му състояние е
    само в claude.json.bak на резервното копие (цял файл, който не се връща). 'unknown_before',
    'unknown_after_apply', 'setup_attempted' и 'install_attempted' са неизвестна собственост → СПРИ преди премахване.

  ПРОБИ (само фалшив дом; FAB-632/16137 т. 3):
    -ClaudeHome <фалшив дом> -ProbeFakeHome -ProbeShimDir <папка с шимове> и изричен -LogDir.
    npm.cmd и claude трябва да сочат шимовете в -ProbeShimDir (rea.cmd също, щом се намира); иначе СТОП.
    При -ProbeFakeHome сесиите се отчитат, но не спират; install-result.json пише probe=true.
    Друг -ClaudeHome без -ProbeFakeHome е разрешен само с -CheckBackupOnly.
.EXAMPLE
  powershell -NoProfile -File .\install-rea.ps1 -CheckBackupOnly -BackupReport "C:\Users\User\claude-backup\20261027-1500\BACKUP-REPORT.md" -BackupReportSha256 <sha256>
.EXAMPLE
  powershell -NoProfile -File .\install-rea.ps1 -LogDir "C:\Users\User\Desktop\for-claude\rea-install-20261027-run1" -BackupReport "<...>\BACKUP-REPORT.md" -BackupReportSha256 <sha256>
.EXAMPLE
  powershell -NoProfile -File .\install-rea.ps1 -Source tarball -DryRun -LogDir "<нова папка>"
.EXAMPLE
  powershell -NoProfile -File .\install-rea.ps1 -VerifyOnly -LogDir "<нова папка>"
#>
[CmdletBinding()]
param(
    [string]$Version = '6.8.0',
    [ValidateSet('npm', 'tarball')]
    [string]$Source = 'npm',
    [string]$TarballPath = '',
    [string]$TarballUrl = 'https://github.com/racho55/rea/raw/racho-backup/rea-agents-6.8.0.tgz',
    [string]$ExpectedSha256 = '8d542ec76a9cb350584b60a6c9c088706ff812d5bb5b094c20c95b6dc25698bb',
    [string]$ExpectedIntegrity = 'sha512-9QDeRnGqEDzABZyr04eLnBXBv/c6I9/TWu/6M0MD4pEfkySI/BIgwTODIbAReX3C1x6hjw9+Jlx4A2yUSPZ9ww==',
    [string]$ExpectedShasum = '6a2cc197e4ff7f11ba937125b3ca7e4de939906a',
    [long]$ExpectedSize = 9944902,
    [string]$Registry = 'https://registry.npmjs.org/',
    [ValidateSet('full', 'compact')]
    [string]$SchemaProfile = 'full',
    [string]$LogDir = '',
    [string]$BackupReport = '',
    [string]$BackupReportSha256 = '',
    [string]$ClaudeHome = '',
    [switch]$CheckBackupOnly,
    [switch]$VerifyOnly,
    [switch]$SkipRegistration,
    [switch]$DryRun,
    [switch]$ProbeFakeHome,
    [string]$ProbeShimDir = ''
)

$script:BoundKeys = @($PSBoundParameters.Keys)
$script:SelfPath = $PSCommandPath

& {
    Set-StrictMode -Version 2.0
    # v4 (Астра А3): собствените файлови операции и cmdlet-ите спират при грешка.
    # Continue се ползва само локално в Invoke-Native (native команди с изрична проверка на кода).
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $script:ScriptVersion = 'install-rea.ps1 v4'
    $script:Stopping = $false
    $script:ApplyStarted = $false
    $script:Own = $null
    $script:LogPath = $null
    $script:Mode = 'install'
    $script:Probe = $false
    $script:ShimFull = ''
    $script:SelfSha = 'НЕПРОВЕРЕНО'
    $script:TgzPath = ''
    $script:BackupInfo = ''
    $script:BackupJsonSha = ''
    $script:ForeignBefore = '?'
    $script:NodeExe = ''
    $script:NodeExecPath = ''
    $script:NpmCmd = ''
    $script:NpmRootG = ''
    $script:ProbeBase = ''
    $script:ReaCmd = ''
    $script:ClaudeExe = ''
    $script:UseLp = $false
    $script:RealProfile = [Environment]::GetFolderPath('UserProfile')

    # Чете само mcpServers от <ClaudeHome>\.claude.json (път в argv[2]). За rea: command, args, имената на
    # ключовете в env и профила. За всеки чужд запис: само името и sha256 на каноничния му JSON. Без стойности.
    $script:ReadEntryJs = @'
'use strict';
const fs = require('fs');
const crypto = require('crypto');
const p = process.argv[2];
function canon(v) {
  if (Array.isArray(v)) { return '[' + v.map(canon).join(',') + ']'; }
  if (v && typeof v === 'object') {
    return '{' + Object.keys(v).sort().map(function (k) { return JSON.stringify(k) + ':' + canon(v[k]); }).join(',') + '}';
  }
  return JSON.stringify(v === undefined ? null : v);
}
let text;
try { text = fs.readFileSync(p, 'utf8'); } catch (e) { console.log(JSON.stringify({ present: false, file: false, foreign: [] })); process.exit(0); }
if (text.charCodeAt(0) === 0xFEFF) { text = text.slice(1); }
let j;
try { j = JSON.parse(text); } catch (e) { console.log(JSON.stringify({ present: false, file: true, error: 'parse_failed' })); process.exit(2); }
const servers = (j && typeof j.mcpServers === 'object' && j.mcpServers && !Array.isArray(j.mcpServers)) ? j.mcpServers : {};
const foreign = Object.keys(servers).filter(function (k) { return k !== 'rea'; }).sort().map(function (k) {
  return { name: k, sha256: crypto.createHash('sha256').update(canon(servers[k]), 'utf8').digest('hex') };
});
const e = Object.prototype.hasOwnProperty.call(servers, 'rea') ? servers.rea : null;
if (!e || typeof e !== 'object') { console.log(JSON.stringify({ present: false, file: true, foreign: foreign })); process.exit(0); }
const env = (e.env && typeof e.env === 'object') ? e.env : {};
console.log(JSON.stringify({ present: true, file: true, type: e.type || null, command: e.command || null,
  args: Array.isArray(e.args) ? e.args : [], env_keys: Object.keys(env),
  profile: typeof env.REA_MCP_INPUT_SCHEMA_PROFILE === 'string' ? env.REA_MCP_INPUT_SCHEMA_PROFILE : null,
  foreign: foreign }));
'@

    function Write-Step([string]$Message) {
        Write-Host ('== ' + $Message) -ForegroundColor Cyan
    }
    function Invoke-Native([string]$Exe, [string[]]$Arguments, [string]$StderrFile) {
        # А3: Continue само тук, около native командата; кодът се връща и се проверява изрично от викащия.
        $ErrorActionPreference = 'Continue'
        if ($null -eq $Arguments) { $Arguments = @() }
        $global:LASTEXITCODE = -999
        if ([string]::IsNullOrEmpty($StderrFile)) { $out = & $Exe @Arguments }
        else { $out = & $Exe @Arguments 2> $StderrFile }
        $code = $LASTEXITCODE
        return [pscustomobject]@{ Code = $code; Raw = ($out | Out-String) }
    }
    function Get-HexLower([byte[]]$Bytes) {
        return ([System.BitConverter]::ToString($Bytes) -replace '-', '').ToLowerInvariant()
    }
    function Get-LpForm([string]$P) {
        if ($script:UseLp -and -not $P.StartsWith('\\')) { return ('\\?\' + $P) }
        return $P
    }
    function Get-FileSha256([string]$Path) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $fs = $null
        try {
            $fs = [System.IO.FileStream]::new((Get-LpForm $Path), [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, ([System.IO.FileShare]'ReadWrite, Delete'), 1048576)
            return (Get-HexLower $sha.ComputeHash($fs))
        }
        finally {
            if ($null -ne $fs) { $fs.Dispose() }
            $sha.Dispose()
        }
    }
    function Get-Sha256OrEmpty([string]$Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
        return (Get-FileSha256 $Path)
    }
    function Test-Prop($Obj, [string]$Name) {
        if ($null -eq $Obj) { return $false }
        return ($null -ne $Obj.PSObject.Properties[$Name])
    }
    function ConvertFrom-JsonOrNull([string]$Raw) {
        if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
        try { return ($Raw | ConvertFrom-Json -ErrorAction Stop) } catch { return $null }
    }
    function Test-SamePath([string]$A, [string]$B) {
        if ([string]::IsNullOrWhiteSpace($A) -or [string]::IsNullOrWhiteSpace($B)) { return $false }
        try {
            $fa = [System.IO.Path]::GetFullPath($A).TrimEnd('\')
            $fb = [System.IO.Path]::GetFullPath($B).TrimEnd('\')
        } catch { return $false }
        return [string]::Equals($fa, $fb, [System.StringComparison]::OrdinalIgnoreCase)
    }
    function Test-Under([string]$Child, [string]$Parent) {
        # true само ако Child е строго под Parent (нормализирани пълни пътища).
        if ([string]::IsNullOrWhiteSpace($Child) -or [string]::IsNullOrWhiteSpace($Parent)) { return $false }
        try {
            $c = [System.IO.Path]::GetFullPath($Child).TrimEnd('\') + '\'
            $p = [System.IO.Path]::GetFullPath($Parent).TrimEnd('\') + '\'
        } catch { return $false }
        if ($c.Length -le $p.Length) { return $false }
        return $c.StartsWith($p, [System.StringComparison]::OrdinalIgnoreCase)
    }
    function Get-SkillState([string]$Dir) {
        $m = Join-Path $Dir 'SKILL.md'
        if (-not (Test-Path -LiteralPath $Dir)) { return [ordered]@{ exists = $false; skill_sha256 = '' } }
        return [ordered]@{ exists = $true; skill_sha256 = (Get-Sha256OrEmpty $m) }
    }

    # --- Задължителни записи (А3): грешка → throw 'ЗАПИС ЛИПСВА: …' -----------------------------
    function Save-Text([string]$Name, [string]$Text) {
        if ($null -eq $script:LogPath) { throw ('ЗАПИС ЛИПСВА: ' + $Name + ' (няма папка за записи)') }
        $p = Join-Path $script:LogPath $Name
        try {
            [System.IO.File]::WriteAllText($p, $Text, (New-Object System.Text.UTF8Encoding($false)))
        } catch {
            throw ('ЗАПИС ЛИПСВА: ' + $Name + ' (' + $_.Exception.GetType().Name + ')')
        }
        return $p
    }
    function Save-Ownership {
        if ($null -eq $script:Own) { return }
        $null = Save-Text 'ownership.json' ($script:Own | ConvertTo-Json -Depth 6)
    }
    function Get-ActionsText {
        if ($null -eq $script:Own) { return ('няма промени по инсталацията; rea setup --yes пуснат: ' + $script:ApplyStarted) }
        return ('npm пакет: ' + $script:Own.npm_package.state + '; запис mcpServers.rea: ' + $script:Own.rea_entry.state +
                '; skill reverse-engineer-anything: ' + $script:Own.skill_reverse_engineer_anything.state +
                '; rea setup --yes пуснат: ' + $script:ApplyStarted)
    }
    function Save-Result([int]$Code, [string]$Status, [string]$Message) {
        if ($null -eq $script:LogPath) { return }
        $r = [ordered]@{
            script = $script:ScriptVersion
            script_sha256 = $script:SelfSha
            mode = $script:Mode
            probe = $script:Probe
            exit_code = $Code
            status = $Status
            message = $Message
            actions = (Get-ActionsText)
            apply_started = $script:ApplyStarted
            tarball_path = $script:TgzPath
            backup = $script:BackupInfo
            log_dir = $script:LogPath
            finished_local = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
        }
        $null = Save-Text 'install-result.json' ($r | ConvertTo-Json -Depth 4)
    }
    function Stop-Rea([string]$Message) {
        Write-Host ('СТОП: ' + $Message) -ForegroundColor Red
        if (-not $script:Stopping) {
            $script:Stopping = $true
            try { Save-Ownership } catch { Write-Host ([string]$_.Exception.Message) -ForegroundColor Red }
            try { Save-Result 1 'СТОП' $Message } catch { Write-Host ([string]$_.Exception.Message) -ForegroundColor Red }
        }
        Write-Host ('Извършени действия: ' + (Get-ActionsText)) -ForegroundColor Yellow
        Write-Host 'Без автоматично връщане и без повторна регистрация.' -ForegroundColor Yellow
        exit 1
    }
    function Exit-Rea([int]$Code, [string]$Status, [string]$Message, [string]$Color) {
        # Задължителните записи първо. Неуспех → throw → външният catch (ненулев код, без ГОТОВО).
        Save-Ownership
        Save-Result $Code $Status $Message
        Write-Host ($Status + ' (код ' + $Code + '): ' + $Message) -ForegroundColor $Color
        exit $Code
    }

    # --- Сесии (16137 т. 2) -------------------------------------------------------------------
    function Get-ClaudeSessions {
        $res = [ordered]@{ ok = $true; why = ''; cc = 0; desktop = 0; unknown_claude = 0; node_cc = 0; node_unknown = 0 }
        try { $procs = @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop) }
        catch {
            $res['ok'] = $false
            $res['why'] = $_.Exception.GetType().Name
            return [pscustomobject]$res
        }
        foreach ($p in $procs) {
            $name = [string]$p.Name
            if ($name -ieq 'claude.exe') {
                $path = [string]$p.ExecutablePath
                if ([string]::IsNullOrWhiteSpace($path)) { $res['unknown_claude'] = $res['unknown_claude'] + 1 }
                elseif (($path -match '(?i)\\AnthropicClaude\\') -or (($path -match '(?i)\\WindowsApps\\') -and ($path -match '(?i)claude'))) { $res['desktop'] = $res['desktop'] + 1 }
                else { $res['cc'] = $res['cc'] + 1 }
            }
            elseif ($name -ieq 'node.exe') {
                if ($null -eq $p.CommandLine) { $res['node_unknown'] = $res['node_unknown'] + 1 }
                elseif ([string]$p.CommandLine -match '(?i)claude-code') { $res['node_cc'] = $res['node_cc'] + 1 }
            }
        }
        return [pscustomobject]$res
    }
    function Format-Sessions($S) {
        if (-not $S.ok) { return ('НЕУСТАНОВЕНО (Get-CimInstance: ' + $S.why + ')') }
        return ('CC claude.exe=' + $S.cc + '; настолно приложение Claude=' + $S.desktop + '; claude.exe с неустановен път=' +
                $S.unknown_claude + '; node.exe с claude-code=' + $S.node_cc + '; node.exe с нечетим команден ред=' + $S.node_unknown)
    }
    function Assert-NoSessions([string]$When) {
        $s = Get-ClaudeSessions
        Write-Host ('Процеси (' + $When + '): ' + (Format-Sessions $s))
        if ($script:Probe) {
            Write-Host 'ПРОБА (фалшив дом): сесиите се отчитат, но не спират.' -ForegroundColor Magenta
            return
        }
        if (-not $s.ok) { Stop-Rea ('процесите не са установени (Get-CimInstance: ' + $s.why + ') ' + $When + '. Неясно → СТОП. Нищо не е регистрирано.') }
        $why = @()
        if (($s.cc + $s.node_cc) -gt 0) { $why += 'работи Claude Code' }
        if ($s.desktop -gt 0) { $why += 'работи настолното приложение Claude (не е CC, но трябва да е затворено)' }
        if (($s.unknown_claude + $s.node_unknown) -gt 0) { $why += 'има процес с неустановена самоличност (неясно → СТОП)' }
        if ($why.Count -gt 0) {
            Stop-Rea (($why -join '; ') + ' ' + $When + '. Затвори всички Claude Code и настолното приложение и пусни отново от обикновен PowerShell. Скриптът не спира процеси.')
        }
    }
    function Assert-JsonMatchesBackup([string]$When) {
        if ($script:BackupJsonSha -eq '') { Stop-Rea 'няма приет sha256 на claude.json.bak' }
        $now = Get-Sha256OrEmpty $script:ClaudeJson
        if ($now -ne $script:BackupJsonSha) {
            Stop-Rea ('~/.claude.json не е същият като claude.json.bak на резервното копие (' + $When + '). Някой е писал след копието; нужно е ново проверено копие. Регистрацията не е започната.')
        }
        Write-Host ('~/.claude.json = claude.json.bak (' + $When + ')')
    }

    # --- npm, rea, claude -----------------------------------------------------------------------
    function Get-InstalledReaVersion {
        $r = Invoke-Native $script:NpmCmd @('ls', '--global', 'rea-agents', '--depth=0', '--json') ''
        if ($r.Code -ne 0 -and $r.Code -ne 1) { Stop-Rea ('npm ls --global върна ' + $r.Code) }
        if ([string]::IsNullOrWhiteSpace($r.Raw)) { return $null }
        $j = ConvertFrom-JsonOrNull $r.Raw
        if ($null -eq $j) { Stop-Rea 'npm ls --global не върна JSON' }
        if (-not (Test-Prop $j 'dependencies')) { return $null }
        if (-not (Test-Prop $j.dependencies 'rea-agents')) { return $null }
        return [string]$j.dependencies.'rea-agents'.version
    }
    function Resolve-ReaCmd {
        $c = @(Get-Command rea.cmd -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $c) { Stop-Rea 'няма rea.cmd в PATH' }
        if ($script:Probe -and -not (Test-Under $c.Source $script:ShimFull)) { Stop-Rea 'ПРОБА: rea.cmd не е шимът от -ProbeShimDir' }
        $script:ReaCmd = $c.Source
    }
    function Resolve-ClaudeCmd {
        $c = @(Get-Command claude -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $c) {
            if ($null -ne (Get-Command claude -ErrorAction SilentlyContinue)) { Stop-Rea 'claude се намира само като скрипт (.ps1); нужен е claude.exe или claude.cmd' }
            Stop-Rea 'няма claude в PATH'
        }
        if ($script:Probe -and -not (Test-Under $c.Source $script:ShimFull)) { Stop-Rea 'ПРОБА: claude не е шимът от -ProbeShimDir' }
        $script:ClaudeExe = $c.Source
    }
    function Get-ReaEntry([string]$Name) {
        $js = Join-Path $script:LogPath 'read-rea-entry.js'
        if (-not (Test-Path -LiteralPath $js)) { $null = Save-Text 'read-rea-entry.js' $script:ReadEntryJs }
        $r = Invoke-Native $script:NodeExe @($js, $script:ClaudeJson) ''
        $raw = $r.Raw.Trim()
        $null = Save-Text $Name $raw
        if ($r.Code -ne 0) { return $null }
        return (ConvertFrom-JsonOrNull $raw)
    }
    function Get-ForeignText($Entry) {
        if ($null -eq $Entry) { return '?' }
        if (-not (Test-Prop $Entry 'foreign')) { return '?' }
        $parts = @()
        foreach ($f in @($Entry.foreign)) {
            if ($null -eq $f) { continue }
            $parts += ([string]$f.name + '=' + [string]$f.sha256)
        }
        return ($parts -join ';')
    }
    function Get-ForeignNames($Entry) {
        if (($null -eq $Entry) -or (-not (Test-Prop $Entry 'foreign'))) { return '?' }
        $n = @(@($Entry.foreign) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_.name })
        if ($n.Count -eq 0) { return 'няма' }
        return ($n -join ', ')
    }
    function Get-EntryProfile($Entry) {
        if (($null -eq $Entry) -or (-not (Test-Prop $Entry 'profile')) -or ($null -eq $Entry.profile)) { return '' }
        return [string]$Entry.profile
    }
    function Test-EntryOrigin($Entry) {
        # С3: command е node от стъпка 1 (пълен път); args[0] е под `npm root -g`\rea-agents\.
        if (($null -eq $Entry) -or (-not [bool]$Entry.present)) { return 'записът липсва' }
        $cmd = [string]$Entry.command
        if (-not ((Test-SamePath $cmd $script:NodeExe) -or (Test-SamePath $cmd $script:NodeExecPath))) {
            return ('command (' + $cmd + ') не е node от стъпка 1 (' + $script:NodeExe + ')')
        }
        $a = @($Entry.args)
        if ($a.Count -lt 1) { return 'args е празен' }
        $pkgRoot = Join-Path $script:NpmRootG 'rea-agents'
        if (-not (Test-Under ([string]$a[0]) $pkgRoot)) { return ('args[0] не е под ' + $pkgRoot + '\') }
        return ''
    }
    function Invoke-ReaJson([string]$Name, [string[]]$Arguments) {
        # Пуска rea.cmd с профила от параметъра; връща код, суров текст и обект (или $null).
        $prev = $env:REA_MCP_INPUT_SCHEMA_PROFILE
        try {
            $env:REA_MCP_INPUT_SCHEMA_PROFILE = $SchemaProfile
            $r = Invoke-Native $script:ReaCmd $Arguments ''
        } finally {
            if ($null -eq $prev) { Remove-Item Env:REA_MCP_INPUT_SCHEMA_PROFILE -ErrorAction SilentlyContinue }
            else { $env:REA_MCP_INPUT_SCHEMA_PROFILE = $prev }
        }
        $null = Save-Text $Name $r.Raw
        return [pscustomobject]@{ Code = $r.Code; Raw = $r.Raw; Json = (ConvertFrom-JsonOrNull $r.Raw) }
    }
    function Test-SetupPlan($Plan) {
        # Връща '' при допустим план; иначе причината за отказ. 0 действия е допустимо (С11).
        if ($null -eq $Plan) { return 'невалиден JSON' }
        if ($Plan -is [System.Array]) { return 'JSON не е обект' }
        if (-not (Test-Prop $Plan 'status')) { return 'липсва status' }
        if (-not ($Plan.status -is [string])) { return 'status не е string' }
        if ($Plan.status -ne 'planned') { return ('status=' + $Plan.status + ', очаква се planned') }
        if (-not (Test-Prop $Plan 'plannedActions')) { return 'липсва plannedActions' }
        if ($null -eq $Plan.plannedActions) { return 'plannedActions е null' }
        foreach ($a in @($Plan.plannedActions)) {
            if ($null -eq $a) { return 'празно действие' }
            $id = ''; $kind = ''; $target = ''
            if (Test-Prop $a 'id') { $id = [string]$a.id }
            if (Test-Prop $a 'kind') { $kind = [string]$a.kind }
            if (Test-Prop $a 'target') { $target = [string]$a.target }
            if (($kind -eq 'configure_client') -and ($id -eq 'configure_client:claude_code')) {
                if (-not (Test-SamePath $target $script:ClaudeJson)) { return ('configure_client с чужд target: ' + $target) }
                if (Test-Prop $a 'backupPath') {
                    $bp = [string]$a.backupPath
                    $leaf = [System.IO.Path]::GetFileName($bp)
                    $dirOk = Test-SamePath ([System.IO.Path]::GetDirectoryName($bp)) $script:ClaudeHomeFull
                    if ((-not $dirOk) -or ($leaf -notmatch '^\.claude\.json\.rea\.backup(\.[0-9a-f]{64}\.recovery)?$')) {
                        return ('configure_client с чужд backupPath: ' + $bp)
                    }
                }
                continue
            }
            if (($kind -eq 'install_skill') -and ($id -eq 'install_skill:claude_code')) {
                if (-not (Test-SamePath $target $script:ReaSkillDir)) { return ('install_skill с чужд target: ' + $target) }
                continue
            }
            return ('действие извън обхвата: kind=' + $kind + ', id=' + $id + ', target=' + $target)
        }
        return ''
    }
    function Get-PlanCount($Plan) {
        return @(@($Plan.plannedActions) | Where-Object { $null -ne $_ }).Count
    }
    function Test-ApplyResult($Apply, [string]$Raw) {
        if ($Raw -match '"reason"\s*:\s*"conflict"') { return 'conflict (друг процес е писал в .claude.json)' }
        if ($null -eq $Apply) { return 'невалиден JSON' }
        if ($Apply -is [System.Array]) { return 'JSON не е обект' }
        if (-not (Test-Prop $Apply 'status')) { return 'липсва status' }
        if (-not ($Apply.status -is [string])) { return 'status не е string' }
        if ($Apply.status -ne 'ready') { return ('status=' + $Apply.status + ', очаква се точно ready') }
        if (Test-Prop $Apply 'remediation') {
            if ($null -ne $Apply.remediation -and [string]$Apply.remediation -ne '') { return 'има remediation' }
        }
        # С2: точното поле за резултата по действия в 6.8.0 е НЕПРОВЕРЕНО. Консервативна текстова евристика тук;
        # меродавна е проверката в стъпка 6: повторен dry-run трябва да е planned с 0 действия.
        if ($Raw -match '"(status|outcome|result)"\s*:\s*"(failed|failure|error)"') { return 'има действие с неуспешен изход (евристика по текста)' }
        return ''
    }
    function Test-DoctorJson($Res, [bool]$NeedAdapter) {
        if ($Res.Code -ne 0) { return ('exit ' + $Res.Code) }
        $j = $Res.Json
        if ($null -eq $j) { return 'невалиден JSON' }
        if (-not (Test-Prop $j 'healthy')) { return 'липсва healthy' }
        if (-not ($j.healthy -is [bool])) { return 'healthy не е булево' }
        if (-not $j.healthy) { return 'healthy=false' }
        if ($NeedAdapter) {
            if (-not (Test-Prop $j 'adapter')) { return 'липсва adapter' }
            if ([string]$j.adapter -ne 'production-stdio') { return ('adapter=' + [string]$j.adapter) }
        }
        return ''
    }
    function Get-McpGetLines([string]$Raw) {
        # С9: от изхода на `claude mcp get rea` се пазят само редовете Scope, Status и Type.
        return ,@(@($Raw -split "`r?`n") | Where-Object { $_ -match '^\s*(Scope|Status|Type)\s*:' } | ForEach-Object { $_.Trim() })
    }
    function Test-McpGet([string[]]$Lines) {
        $status = @($Lines | Where-Object { $_ -match '^\s*Status\s*:' })
        $scope = @($Lines | Where-Object { $_ -match '^\s*Scope\s*:' })
        if ($status.Count -ne 1) { return 'няма точно един ред Status (непознат формат)' }
        if ($scope.Count -ne 1) { return 'няма точно един ред Scope (непознат формат)' }
        $s = $status[0]
        if ($s -match '(?i)disconnected|not\s+connected|failed|error|pending|needs') { return ('Status: ' + $s.Trim()) }
        if ($s -notmatch '(?i)\bconnected\b') { return ('Status: ' + $s.Trim()) }
        if ($scope[0] -notmatch '(?i)\buser\b') { return ('Scope: ' + $scope[0].Trim()) }
        return ''
    }

    # --- Резервно копие (договор А1) -------------------------------------------------------------
    function Get-OneField([string[]]$Lines, [string]$Pattern) {
        $m = @()
        foreach ($l in $Lines) { if ($l -match $Pattern) { $m += [string]$Matches[1] } }
        if ($m.Count -ne 1) { return $null }
        return ([string]$m[0]).Trim()
    }
    function Get-SectionLines([string[]]$Lines, [string]$Header) {
        $out = New-Object System.Collections.Generic.List[string]
        $in = $false
        $seen = 0
        foreach ($l in $Lines) {
            if ($l -match '^## ') {
                if ($l.Trim() -eq $Header) { $in = $true; $seen++ } else { $in = $false }
                continue
            }
            if ($in) { $out.Add($l) }
        }
        if ($seen -ne 1) { return $null }
        return ,($out.ToArray())
    }
    function Get-CopyInventory([string]$Root) {
        # Обхожда копието, без да следва връзки. Всяка връзка, нечетима папка или сблъсък → Problems.
        $files = [System.Collections.Generic.Dictionary[string,long]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $problems = 0
        $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
        $stack = [System.Collections.Generic.Stack[string]]::new()
        $stack.Push($rootFull)
        while ($stack.Count -gt 0) {
            $dir = $stack.Pop()
            try { $entries = ([System.IO.DirectoryInfo]::new((Get-LpForm $dir))).GetFileSystemInfos() }
            catch { $problems++; continue }
            foreach ($e in $entries) {
                $full = $e.FullName
                if ($full.StartsWith('\\?\')) { $full = $full.Substring(4) }
                $rel = $full.Substring($rootFull.Length).TrimStart('\')
                if ((([int]($e.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) -ne 0)) { $problems++; continue }
                if ($e -is [System.IO.DirectoryInfo]) { $stack.Push($full) }
                elseif ($files.ContainsKey($rel)) { $problems++ }
                else { $files[$rel] = [long]$e.Length }
            }
        }
        return [pscustomobject]@{ Files = $files; Problems = $problems }
    }
    function Test-BackupReport([string]$Path, [string]$Sha) {
        $script:BackupInfo = ''
        $script:BackupJsonSha = ''
        if ([string]::IsNullOrWhiteSpace($Path)) { return 'не е подаден -BackupReport' }
        if ($Sha -notmatch '^[0-9a-fA-F]{64}$') { return '-BackupReportSha256 не е sha256 (64 шестнадесетични знака)' }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 'отчетът липсва' }
        $reportFull = [System.IO.Path]::GetFullPath($Path)
        $bytes = [System.IO.File]::ReadAllBytes($reportFull)
        if ($bytes.Length -le 0) { return 'отчетът е празен' }
        # v4 (адвокат 3, К1): името не бива да е $sha — PowerShell не различава $sha от параметъра [string]$Sha.
        $hasher = [System.Security.Cryptography.SHA256]::Create()
        try { $h = Get-HexLower $hasher.ComputeHash($bytes) } finally { $hasher.Dispose() }
        if ($h -ne $Sha.ToLowerInvariant()) { return ('sha256 на отчета (' + $bytes.Length + ' B) е ' + $h + ' и не съвпада с подадения') }
        try { $text = (New-Object System.Text.UTF8Encoding($false, $true)).GetString($bytes) } catch { return 'отчетът не е валиден UTF-8' }
        if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) { $text = $text.Substring(1) }
        $lines = @($text -split "`r?`n")

        $st = @($lines | Where-Object { $_ -match '^\s*СТАТУС:' })
        if ($st.Count -ne 1) { return ('редовете „СТАТУС:“ са ' + $st.Count + '; очаква се точно един') }
        $last = ''
        foreach ($l in $lines) { if ($l.Trim() -ne '') { $last = $l.Trim() } }
        if ($last -ne 'СТАТУС: ПРОВЕРЕНО') { return 'крайният статус не е точно „СТАТУС: ПРОВЕРЕНО“' }
        $probe = Get-OneField $lines '^- ПРОБА:\s*(.*?)\s*$'
        if ($null -eq $probe) { return 'няма точно един ред „- ПРОБА:“ (нужен е отчет от Backup-ClaudeHome.ps1 v3)' }
        if ($probe -ne 'не') { return ('тестов отчет („- ПРОБА: ' + $probe + '“)') }

        $copyDir = [System.IO.Path]::GetDirectoryName($reportFull)
        $expSrc = Join-Path $script:ClaudeHomeFull '.claude'
        $expJson = Join-Path $script:ClaudeHomeFull '.claude.json'
        if (-not (Test-SamePath (Get-OneField $lines '^- Източник:\s*(.+?)\s*$') $expSrc)) { return ('полето „- Източник:“ не е точно ' + $expSrc + ' (или не е точно един ред)') }
        if (-not (Test-SamePath (Get-OneField $lines '^- Източник JSON:\s*(.+?)\s*$') $expJson)) { return ('полето „- Източник JSON:“ не е точно ' + $expJson + ' (или не е точно един ред)') }
        if (-not (Test-SamePath (Get-OneField $lines '^- Копие:\s*(.+?)\s*$') $copyDir)) { return 'полето „- Копие:“ не е папката на отчета (или не е точно един ред)' }

        $zero = [ordered]@{
            'Липсващи в копието' = '^- Липсващи в копието:\s*(\d+)\s*$'
            'Разлики в допустими живи пътища' = '^- Разлики в допустими живи пътища:\s*(\d+)\s*$'
            'Разлики НЕдопустими' = '^- Разлики НЕдопустими:\s*(\d+)\s*$'
            'Пропуснати (грешки при обхождане)' = '^- Пропуснати \(грешки при обхождане\):\s*(\d+)\s*$'
        }
        foreach ($k in @($zero.Keys)) {
            $v = Get-OneField $lines $zero[$k]
            if ($v -ne '0') { return ('„' + $k + '“ не е точно 0 (или не е точно един ред)') }
        }
        $mv = @($lines | Where-Object { $_ -match '^- Съвпадащи sha256:\s*\d+\s+от\s+\d+\s*$' })
        if ($mv.Count -ne 1) { return 'няма точно един ред „- Съвпадащи sha256: M от N“' }
        $null = $mv[0] -match '(\d+)\s+от\s+(\d+)'
        if ($Matches[1] -ne $Matches[2]) { return '„Съвпадащи sha256“ не е N от N' }
        if ((Get-OneField $lines '^- Опис на връзките преди/след:\s*(.+?)\s*$') -ne 'еднакъв') { return '„- Опис на връзките преди/след“ не е „еднакъв“' }
        $rpLine = @($lines | Where-Object { $_ -match '^- Reparse точки:\s*\d+\s*—' })
        if ($rpLine.Count -ne 1) { return 'няма точно един ред „- Reparse точки: N — …“' }

        $treeDir = Join-Path $copyDir '.claude'
        $bak = Join-Path $copyDir 'claude.json.bak'
        $man = Join-Path $copyDir 'MANIFEST.sha256.csv'
        if (-not [System.IO.Directory]::Exists($treeDir)) { return 'до отчета няма папка .claude' }
        if (-not [System.IO.File]::Exists($bak)) { return 'до отчета няма claude.json.bak' }
        if (-not [System.IO.File]::Exists($man)) { return 'до отчета няма MANIFEST.sha256.csv' }
        foreach ($p in @($copyDir, $treeDir, $bak, $man)) {
            if ((([int]([System.IO.File]::GetAttributes($p) -band [System.IO.FileAttributes]::ReparsePoint)) -ne 0)) {
                return ('връзка вместо обикновен файл или папка: ' + [System.IO.Path]::GetFileName($p))
            }
        }
        try { $script:UseLp = [System.IO.Directory]::Exists('\\?\' + $treeDir) } catch { $script:UseLp = $false }

        $secJ = Get-SectionLines $lines '## claude.json.bak'
        if ($null -eq $secJ) { return 'няма точно един раздел „## claude.json.bak“' }
        $jl = @($secJ | Where-Object { $_ -match '^- Размер:\s*\d+\s*B;\s*sha256:\s*[0-9A-Fa-f]{64}\s*$' })
        if ($jl.Count -ne 1) { return 'в „## claude.json.bak“ няма точно един ред „- Размер: N B; sha256: X“' }
        $null = $jl[0] -match '^- Размер:\s*(\d+)\s*B;\s*sha256:\s*([0-9A-Fa-f]{64})\s*$'
        $jSize = [long]$Matches[1]
        $jSha = ([string]$Matches[2]).ToLowerInvariant()
        if (([System.IO.FileInfo]::new($bak)).Length -ne $jSize) { return 'размерът на claude.json.bak не е равен на полето в отчета' }
        if ((Get-FileSha256 $bak) -ne $jSha) { return 'sha256 на claude.json.bak не е равен на полето в отчета' }

        $secM = Get-SectionLines $lines '## MANIFEST.sha256.csv'
        if ($null -eq $secM) { return 'няма точно един раздел „## MANIFEST.sha256.csv“' }
        $ml = @($secM | Where-Object { $_ -match '^- sha256:\s*[0-9A-Fa-f]{64}\s*$' })
        if ($ml.Count -ne 1) { return 'в „## MANIFEST.sha256.csv“ няма точно един ред „- sha256: X“' }
        $null = $ml[0] -match '([0-9A-Fa-f]{64})'
        $mSha = ([string]$Matches[1]).ToLowerInvariant()
        if ((Get-FileSha256 $man) -ne $mSha) { return 'sha256 на MANIFEST.sha256.csv не е равен на полето в отчета' }

        try { $rows = @(Import-Csv -LiteralPath $man -Encoding UTF8) } catch { return 'MANIFEST.sha256.csv не се чете като CSV' }
        $want = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $badChars = [System.IO.Path]::GetInvalidPathChars()
        foreach ($r in $rows) {
            foreach ($c in @('RelativePath', 'Bytes', 'Sha256')) { if (-not (Test-Prop $r $c)) { return ('в манифеста липсва колона ' + $c) } }
            $rel = [string]$r.RelativePath
            if ([string]::IsNullOrWhiteSpace($rel)) { return 'празен път в манифеста' }
            if (($rel.IndexOfAny($badChars) -ge 0) -or ($rel.IndexOfAny([char[]]@('/', ':', '*', '?')) -ge 0)) { return 'неразрешен знак в път от манифеста' }
            if ($rel.StartsWith('\') -or [System.IO.Path]::IsPathRooted($rel)) { return 'абсолютен път в манифеста' }
            foreach ($part in $rel.Split('\')) { if ($part -eq '' -or $part -eq '.' -or $part -eq '..') { return 'път с „..“, „.“ или празен компонент в манифеста' } }
            if (-not (Test-Under ([System.IO.Path]::Combine($treeDir, $rel)) $treeDir)) { return 'път извън копието в манифеста' }
            if ($want.ContainsKey($rel)) { return 'повторен път в манифеста' }
            $b = [string]$r.Bytes
            if ($b -notmatch '^\d+$') { return 'невалиден размер в манифеста' }
            $s = [string]$r.Sha256
            if ($s -notmatch '^[0-9A-Fa-f]{64}$') { return 'невалиден или празен sha256 в манифеста (нечетим файл)' }
            $want[$rel] = [pscustomobject]@{ Bytes = [long]$b; Sha = $s.ToLowerInvariant() }
        }

        Write-Host ('      сверявам копието с манифеста: ' + $want.Count + ' файла...')
        $inv = Get-CopyInventory $treeDir
        if ($inv.Problems -gt 0) { return ('в копието има ' + $inv.Problems + ' връзки, нечетими папки или сблъсъци') }
        if ($inv.Files.Count -ne $want.Count) { return ('файловете в копието са ' + $inv.Files.Count + ', а в манифеста ' + $want.Count) }
        $n = 0
        foreach ($rel in @($want.Keys)) {
            if (-not $inv.Files.ContainsKey($rel)) { return 'файл от манифеста липсва в копието' }
            if ($inv.Files[$rel] -ne $want[$rel].Bytes) { return 'размер в копието не съвпада с манифеста' }
            $hc = ''
            try { $hc = Get-FileSha256 ([System.IO.Path]::Combine($treeDir, $rel)) } catch { return 'файл в копието не се чете' }
            if ($hc -ne $want[$rel].Sha) { return 'sha256 в копието не съвпада с манифеста' }
            $n++
            if (($n % 2000) -eq 0) { Write-Host ('      сверени ' + $n + ' от ' + $want.Count) }
        }
        $script:BackupJsonSha = $jSha
        $script:BackupInfo = ('копие ' + $copyDir + '; ' + $want.Count + ' файла в манифеста и в копието (набор, размер и sha256 съвпадат); ' + $rpLine[0].Substring(2))
        return ''
    }

    # --- Стъпка 6 (обща за пълната инсталация и -VerifyOnly) ---------------------------------------
    function Invoke-RegistrationChecks {
        $fails = @()
        $entry = Get-ReaEntry 'rea-entry.json'
        if ($null -eq $entry) { $fails += 'записът mcpServers.rea не се чете (виж rea-entry.json)' }
        elseif (-not [bool]$entry.present) { $fails += 'няма mcpServers.rea в ~/.claude.json (вероятно презаписано от друга сесия); не повтаряй регистрацията' }
        else {
            Write-Host ('rea: command=' + [string]$entry.command + '; env ключове: ' + (@($entry.env_keys) -join ', '))
            $w = Test-EntryOrigin $entry
            if ($w -ne '') { $fails += ('запис: ' + $w) }
        }
        $chk = Invoke-ReaJson 'doctor-claude.json' @('doctor', '--client', 'claude_code', '--skill', '--json')
        $w = Test-DoctorJson $chk $false
        if ($w -ne '') { $fails += ('rea doctor --client claude_code --skill: ' + $w) }
        $md = Invoke-ReaJson 'rea-mcp-doctor.json' @('mcp', 'doctor', '--json')
        $w = Test-DoctorJson $md $true
        if ($w -ne '') { $fails += ('rea mcp doctor: ' + $w) }
        $g = Invoke-Native $script:ClaudeExe @('mcp', 'get', 'rea') ''
        $getLines = Get-McpGetLines $g.Raw
        $null = Save-Text 'claude-mcp-get-rea.txt' ((@($getLines) -join "`r`n") + "`r`n")
        if ($g.Code -ne 0) { $fails += ('claude mcp get rea: exit ' + $g.Code) }
        else { $w = Test-McpGet $getLines; if ($w -ne '') { $fails += ('claude mcp get rea: ' + $w) } }
        $p2 = Invoke-ReaJson 'setup-plan-after.json' @('setup', '--client', 'claude_code', '--dry-run', '--json')
        if ($p2.Code -ne 0) { $fails += ('повторен rea setup --dry-run: exit ' + $p2.Code) }
        else {
            $w = Test-SetupPlan $p2.Json
            if ($w -ne '') { $fails += ('повторен dry-run: ' + $w) }
            else {
                $n2 = Get-PlanCount $p2.Json
                if ($n2 -ne 0) { $fails += ('повторен dry-run: остават ' + $n2 + ' действия (очаква се 0; виж setup-plan-after.json)') }
                else { Write-Host 'Повторен dry-run: planned, 0 действия.' }
            }
        }
        $entry2 = Get-ReaEntry 'rea-entry-final.json'
        if (($null -eq $entry2) -or (-not [bool]$entry2.present)) { $fails += 'повторен прочит: записът липсва или не се чете' }
        else {
            $w = Test-EntryOrigin $entry2
            if ($w -ne '') { $fails += ('повторен прочит: ' + $w) }
            if (($null -ne $entry) -and [bool]$entry.present) {
                $same = ([string]$entry2.command -eq [string]$entry.command) -and ((@($entry2.args) -join "`n") -eq (@($entry.args) -join "`n"))
                if (-not $same) { $fails += 'повторен прочит: command/args са се променили' }
            }
        }
        return [pscustomobject]@{ Fails = $fails; First = $entry; Final = $entry2 }
    }

    try {
        # --- Режим и дом --------------------------------------------------------------------------
        $modes = @()
        if ($CheckBackupOnly) { $modes += 'CheckBackupOnly' }
        if ($VerifyOnly) { $modes += 'VerifyOnly' }
        if ($DryRun) { $modes += 'DryRun' }
        if ($SkipRegistration) { $modes += 'SkipRegistration' }
        if ($modes.Count -gt 1) { Stop-Rea ('режимите са взаимно изключващи се: ' + ($modes -join ', ')) }
        if ($modes.Count -eq 1) { $script:Mode = $modes[0] }
        $changing = ($script:Mode -eq 'install') -or ($script:Mode -eq 'SkipRegistration')

        if ([string]::IsNullOrWhiteSpace($ClaudeHome)) { $ClaudeHome = $script:RealProfile }
        $script:ClaudeHomeFull = [System.IO.Path]::GetFullPath($ClaudeHome).TrimEnd('\')
        $script:ClaudeJson = Join-Path $script:ClaudeHomeFull '.claude.json'
        $script:ReaSkillDir = Join-Path $script:ClaudeHomeFull '.claude\skills\reverse-engineer-anything'
        $isFakeHome = -not (Test-SamePath $script:ClaudeHomeFull $script:RealProfile)
        if (-not [string]::IsNullOrEmpty($script:SelfPath)) {
            try { $script:SelfSha = Get-FileSha256 $script:SelfPath } catch { $script:SelfSha = 'НЕПРОВЕРЕНО' }
        }
        Write-Host ($script:ScriptVersion + ' (sha256 ' + $script:SelfSha + '); режим: ' + $script:Mode)
        Write-Host ('PowerShell ' + $PSVersionTable.PSVersion.ToString())

        if ($script:Mode -eq 'CheckBackupOnly') {
            Write-Step '0. Само проверка на резервното копие (-CheckBackupOnly; нищо не се записва)'
            $bk = Test-BackupReport $BackupReport $BackupReportSha256
            if ($bk -ne '') { Stop-Rea ('резервното копие не е прието: ' + $bk + '.') }
            Write-Host ('Резервно копие: ПРИЕТО. ' + $script:BackupInfo) -ForegroundColor Green
            exit 0
        }

        if ((-not $ProbeFakeHome) -and (-not [string]::IsNullOrWhiteSpace($ProbeShimDir))) { Stop-Rea '-ProbeShimDir се подава само заедно с -ProbeFakeHome' }
        if ($ProbeFakeHome) {
            if (-not $isFakeHome) { Stop-Rea '-ProbeFakeHome иска фалшив -ClaudeHome, различен от профила на потребителя' }
            if ((Test-SamePath $script:ClaudeHomeFull (Join-Path $script:RealProfile '.claude')) -or (Test-Under $script:ClaudeHomeFull (Join-Path $script:RealProfile '.claude'))) {
                Stop-Rea 'фалшивият -ClaudeHome е в истинския ~/.claude'
            }
            if ($script:BoundKeys -notcontains 'LogDir') { Stop-Rea '-ProbeFakeHome иска изричен -LogDir' }
            if ([string]::IsNullOrWhiteSpace($ProbeShimDir) -or (-not (Test-Path -LiteralPath $ProbeShimDir -PathType Container))) { Stop-Rea '-ProbeFakeHome иска съществуваща -ProbeShimDir' }
            $script:ShimFull = [System.IO.Path]::GetFullPath($ProbeShimDir).TrimEnd('\')
            # v4 (адвокат 3, С11): в пробата всичко (шимове, tarball, записи, npm root -g) е под папката на фалшивия дом.
            $script:ProbeBase = [System.IO.Path]::GetDirectoryName($script:ClaudeHomeFull)
            if (-not (Test-Under $script:ShimFull $script:ProbeBase)) { Stop-Rea 'ПРОБА: -ProbeShimDir трябва да е под папката на фалшивия -ClaudeHome' }
            if (($Source -ne 'tarball') -or [string]::IsNullOrWhiteSpace($TarballPath)) { Stop-Rea 'ПРОБА: иска -Source tarball и -TarballPath' }
            if (-not (Test-Under ([System.IO.Path]::GetFullPath($TarballPath)) $script:ProbeBase)) { Stop-Rea 'ПРОБА: -TarballPath трябва да е под папката на фалшивия -ClaudeHome' }
            if (-not (Test-Under ([System.IO.Path]::GetFullPath($LogDir)) $script:ProbeBase)) { Stop-Rea 'ПРОБА: -LogDir трябва да е под папката на фалшивия -ClaudeHome' }
            $script:Probe = $true
        }

        if ([string]::IsNullOrWhiteSpace($LogDir)) { $LogDir = Join-Path $env:TEMP ('rea-install-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
        $logFull = [System.IO.Path]::GetFullPath($LogDir).TrimEnd('\')
        if ([System.IO.File]::Exists($logFull)) { Stop-Rea ('-LogDir е файл: ' + $logFull) }
        if ([System.IO.Directory]::Exists($logFull) -and (@([System.IO.Directory]::EnumerateFileSystemEntries($logFull)).Count -gt 0)) {
            Stop-Rea ('папката за записи вече съществува и не е празна: ' + $logFull + '. Дай нова папка.')
        }
        [void][System.IO.Directory]::CreateDirectory($logFull)
        $script:LogPath = $logFull
        Write-Host ('Записи: ' + $script:LogPath)
        if ($script:Probe) { Write-Host ('ПРОБА: фалшив дом ' + $script:ClaudeHomeFull + '; шимове ' + $script:ShimFull) -ForegroundColor Magenta }
        if ($script:Mode -eq 'DryRun') { Write-Host 'DRYRUN: само проба; нищо не се инсталира и не се регистрира.' -ForegroundColor Yellow }

        # --- 0. Предусловия -------------------------------------------------------------------------
        Write-Step '0. Предусловия'
        if (-not [string]::IsNullOrEmpty($env:CLAUDE_CONFIG_DIR)) { Stop-Rea 'CLAUDE_CONFIG_DIR е зададен; скриптът работи само с профила по подразбиране' }
        if ($changing) { Assert-NoSessions 'в стъпка 0, преди всяка промяна' }
        else { $s0 = Get-ClaudeSessions; Write-Host ('Процеси (само отчет, режим ' + $script:Mode + '): ' + (Format-Sessions $s0)) }
        if ($isFakeHome -and (-not $script:Probe)) {
            Stop-Rea ('-ClaudeHome ' + $script:ClaudeHomeFull + ' не е профилът на потребителя; разрешено е само с -ProbeFakeHome и -ProbeShimDir (или с -CheckBackupOnly)')
        }
        if ($changing) {
            $bk = Test-BackupReport $BackupReport $BackupReportSha256
            if ($bk -ne '') { Stop-Rea ('резервното копие не е прието: ' + $bk + '. Нищо не е променено.') }
            Write-Host ('Резервно копие: ПРИЕТО. ' + $script:BackupInfo)
            Assert-JsonMatchesBackup 'в стъпка 0'
        } else {
            Write-Host ('Режим ' + $script:Mode + ': резервното копие не се проверява (няма промени).')
        }

        # --- 1. Node, npm, registry -------------------------------------------------------------------
        Write-Step '1. Node.js, npm и registry'
        $nodeCmd = @(Get-Command node -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $nodeCmd) { Stop-Rea 'няма node в PATH; инсталирай Node.js (отделно решение)' }
        $script:NodeExe = $nodeCmd.Source
        $npmCmd = @(Get-Command npm.cmd -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
        if ($null -eq $npmCmd) { Stop-Rea 'няма npm.cmd в PATH' }
        $script:NpmCmd = $npmCmd.Source
        if ($script:Probe -and (-not (Test-Under $script:NpmCmd $script:ShimFull))) { Stop-Rea 'ПРОБА: npm.cmd не е шимът от -ProbeShimDir' }
        if ($script:Probe) { Resolve-ClaudeCmd }
        $managers = @()
        if (($script:NodeExe -match '\\nvm\\|nvm4w|\\\.nvm\\') -or (-not [string]::IsNullOrEmpty($env:NVM_HOME))) { $managers += 'nvm' }
        if (($script:NodeExe -match '\\Volta\\') -or (-not [string]::IsNullOrEmpty($env:VOLTA_HOME))) { $managers += 'volta' }
        if (($script:NodeExe -match 'fnm') -or (-not [string]::IsNullOrEmpty($env:FNM_DIR))) { $managers += 'fnm' }
        $managerText = 'няма'
        if ($managers.Count -gt 0) { $managerText = ($managers -join ', ') }
        Write-Host ('node: ' + $script:NodeExe + ' (менажер на версии: ' + $managerText + ')')
        if ($managers.Count -gt 0) {
            Write-Host 'Внимание: регистрацията сочи абсолютния път до node; смяна на версията през менажера може да я счупи.' -ForegroundColor Yellow
        }
        $nv0 = Invoke-Native $script:NodeExe @('-v') ''
        if ($nv0.Code -ne 0) { Stop-Rea ('node -v върна ' + $nv0.Code) }
        $nodeRaw = $nv0.Raw.Trim()
        if ($nodeRaw -notmatch '^v(\d+)\.(\d+)\.(\d+)$') { Stop-Rea ('неразпозната или предварителна версия на Node: ' + $nodeRaw) }
        $nv = [System.Version]('{0}.{1}.{2}' -f $Matches[1], $Matches[2], $Matches[3])
        # engines.node на rea-agents 6.8.0: ^22.23.4 || ^24.22.1 || >=26.12.1
        $nodeOk = (($nv.Major -eq 22) -and ($nv -ge [System.Version]'22.23.4')) -or
                  (($nv.Major -eq 24) -and ($nv -ge [System.Version]'24.22.1')) -or
                  ($nv -ge [System.Version]'26.12.1')
        if (-not $nodeOk) { Stop-Rea ('Node ' + $nodeRaw + ' е извън ^22.23.4 || ^24.22.1 || >=26.12.1; Node не се обновява без отделно решение') }
        $ep = Invoke-Native $script:NodeExe @('-p', 'process.execPath') ''
        if ($ep.Code -eq 0) { $script:NodeExecPath = $ep.Raw.Trim() }
        Write-Host ('node ' + $nodeRaw + ' - в диапазона; process.execPath: ' + $script:NodeExecPath)
        $npmV = Invoke-Native $script:NpmCmd @('-v') ''
        if ($npmV.Code -ne 0) { Stop-Rea ('npm -v върна ' + $npmV.Code) }
        Write-Host ('npm ' + $npmV.Raw.Trim())
        $reg = Invoke-Native $script:NpmCmd @('config', 'get', 'registry') ''
        if ($reg.Code -ne 0) { Stop-Rea ('npm config get registry върна ' + $reg.Code) }
        $regRaw = $reg.Raw.Trim()
        if ($regRaw.TrimEnd('/') -ne $Registry.TrimEnd('/')) { Stop-Rea ('npm registry е "' + $regRaw + '", очаква се ' + $Registry + ' (официалният източник)') }
        Write-Host ('registry ' + $regRaw)
        $root = Invoke-Native $script:NpmCmd @('root', '-g') ''
        if (($root.Code -ne 0) -or [string]::IsNullOrWhiteSpace($root.Raw)) { Stop-Rea ('npm root -g върна ' + $root.Code) }
        $script:NpmRootG = $root.Raw.Trim()
        if ($script:Probe -and (-not (Test-Under $script:NpmRootG $script:ProbeBase))) { Stop-Rea 'ПРОБА: npm root -g не е под пробната папка' }
        Write-Host ('npm root -g: ' + $script:NpmRootG)
        if (($Source -eq 'npm') -and ($script:Mode -ne 'VerifyOnly')) {
            $view = Invoke-Native $script:NpmCmd @('view', ('rea-agents@' + $Version), 'version') ''
            if ($view.Code -ne 0) { Stop-Rea ('npm view върна ' + $view.Code + ' (няма достъп до registry?)') }
            if ($view.Raw.Trim() -ne $Version) { Stop-Rea ('npm registry върна "' + $view.Raw.Trim() + '" вместо ' + $Version) }
        }
        $installed = Get-InstalledReaVersion

        # --- -VerifyOnly: само стъпка 6 -------------------------------------------------------------
        if ($script:Mode -eq 'VerifyOnly') {
            Write-Step '6. Само четящи проверки (-VerifyOnly)'
            if ($installed -ne $Version) { Exit-Rea 3 'НЕ МИНА' ('rea-agents ' + $Version + ' не е инсталиран глобално (npm ls: "' + [string]$installed + '")') 'Red' }
            Resolve-ReaCmd
            Resolve-ClaudeCmd
            $vchk = Invoke-RegistrationChecks
            $vfails = @($vchk.Fails)
            if ($vfails.Count -gt 0) {
                foreach ($f in $vfails) { Write-Host ('НЕ МИНА: ' + $f) -ForegroundColor Red }
                Exit-Rea 3 'НЕ МИНА' ('проверките на регистрацията не минаха (' + $vfails.Count + '). Нищо не е поправяно. Записи: ' + $script:LogPath) 'Red'
            }
            $vpf = Get-EntryProfile $vchk.Final
            if ($vpf -ne $SchemaProfile) { Exit-Rea 2 'ЧАСТИЧНО' ('профилът в mcpServers.rea е "' + $vpf + '", не ' + $SchemaProfile + '. Записи: ' + $script:LogPath) 'Yellow' }
            Exit-Rea 0 'ПРОВЕРЕНО' ('само четене: rea-agents ' + $installed + '; записът, doctor, mcp doctor, claude mcp get, повторният dry-run (0 действия) и повторният прочит минаха; чужди MCP записи: ' + (Get-ForeignNames $vchk.Final) + '. Записи: ' + $script:LogPath) 'Green'
        }

        # --- Начално състояние за ВРЪЩАНЕ (ownership.json) ------------------------------------------
        $entryBefore = Get-ReaEntry 'rea-entry-before.json'
        $beforePresent = 'unknown'
        if ($null -ne $entryBefore) { if ([bool]$entryBefore.present) { $beforePresent = 'present' } else { $beforePresent = 'absent' } }
        $script:ForeignBefore = Get-ForeignText $entryBefore
        $npmState = 'absent_before'
        if ($null -ne $installed) { $npmState = 'present_before' }
        $script:Own = [ordered]@{
            script = $script:ScriptVersion
            script_sha256 = $script:SelfSha
            mode = $script:Mode
            probe = $script:Probe
            claude_home = $script:ClaudeHomeFull
            backup_report = $BackupReport
            npm_package = [ordered]@{ before = $installed; after = $null; state = $npmState }
            rea_entry = [ordered]@{
                before_present = $beforePresent
                claude_json_sha256_before = (Get-Sha256OrEmpty $script:ClaudeJson)
                claude_json_sha256_after_apply = ''
                claude_json_sha256_final = ''
                state = 'unchanged'
            }
            skill_reverse_engineer_anything = [ordered]@{ before = (Get-SkillState $script:ReaSkillDir); after = $null; state = 'unchanged' }
            skill_rea_pravilo = [ordered]@{ note = 'копира се от Claude Code по промпта (т. 6), не от скрипта' }
            foreign_mcp_names_before = (Get-ForeignNames $entryBefore)
            foreign_mcp_unchanged = $null
        }
        if ($beforePresent -eq 'unknown') { $script:Own.rea_entry.state = 'unknown_before' }
        Save-Ownership
        if ($beforePresent -eq 'unknown') {
            Stop-Rea '~/.claude.json не се чете или не се парсва (виж rea-entry-before.json); собствеността на записа mcpServers.rea е неустановима. Нищо не е променено.'
        }
        if (($null -ne $installed) -and ($installed -ne $Version)) { Stop-Rea ('вече е инсталиран rea-agents ' + $installed + '; смяна на версията е отделно решение') }
        if ($null -ne $installed) {
            Write-Host ('rea-agents ' + $installed + ' вече е инсталиран - инсталацията се пропуска.') -ForegroundColor Yellow
            Write-Host 'Внимание: произходът от проверения tarball е НЕПРОВЕРЕН.' -ForegroundColor Yellow
            $script:Own.npm_package.state = 'used_existing'
        }

        # --- 2. Точният tarball и хешовете ------------------------------------------------------------
        Write-Step '2. Tarball и хешове'
        $pkgDir = Join-Path $script:LogPath 'pkg'
        [void][System.IO.Directory]::CreateDirectory($pkgDir)
        $tgz = ''
        if ($Source -eq 'npm') {
            $pk = Invoke-Native $script:NpmCmd @('pack', ('rea-agents@' + $Version), '--pack-destination', $pkgDir, '--json') ''
            if ($pk.Code -ne 0) { Stop-Rea ('npm pack върна ' + $pk.Code) }
            $null = Save-Text 'npm-pack.json' $pk.Raw
            $packAll = ConvertFrom-JsonOrNull $pk.Raw
            if ($null -eq $packAll) { Stop-Rea 'npm pack не върна JSON' }
            $pack = @($packAll)[0]
            foreach ($pp in @('integrity', 'shasum', 'filename')) { if (-not (Test-Prop $pack $pp)) { Stop-Rea ('npm pack: липсва ' + $pp) } }
            if ([string]$pack.integrity -ne $ExpectedIntegrity) { Stop-Rea ('npm pack integrity ' + $pack.integrity + ' <> ' + $ExpectedIntegrity) }
            if ([string]$pack.shasum -ne $ExpectedShasum) { Stop-Rea ('npm pack shasum ' + $pack.shasum + ' <> ' + $ExpectedShasum) }
            $tgz = Join-Path $pkgDir ([string]$pack.filename)
        } elseif (-not [string]::IsNullOrWhiteSpace($TarballPath)) {
            if (-not (Test-Path -LiteralPath $TarballPath -PathType Leaf)) { Stop-Rea ('липсва -TarballPath: ' + $TarballPath) }
            $tgz = [System.IO.Path]::GetFullPath($TarballPath)
        } else {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
            $tgz = Join-Path $pkgDir ('rea-agents-' + $Version + '.tgz')
            try { Invoke-WebRequest -Uri $TarballUrl -OutFile $tgz -UseBasicParsing -ErrorAction Stop }
            catch { Stop-Rea ('свалянето от ' + $TarballUrl + ' не успя (' + $_.Exception.GetType().Name + ')') }
        }
        if (-not (Test-Path -LiteralPath $tgz -PathType Leaf)) { Stop-Rea ('липсва tarball: ' + $tgz) }
        $script:TgzPath = $tgz
        $size = (Get-Item -LiteralPath $tgz).Length
        $sha256 = Get-FileSha256 $tgz
        $fs = [System.IO.File]::OpenRead($tgz)
        try {
            $h512 = [System.Security.Cryptography.SHA512]::Create()
            $integrity = 'sha512-' + [Convert]::ToBase64String($h512.ComputeHash($fs))
        } finally { $fs.Dispose() }
        $fs = [System.IO.File]::OpenRead($tgz)
        try {
            $h1 = [System.Security.Cryptography.SHA1]::Create()
            $shasum = Get-HexLower $h1.ComputeHash($fs)
        } finally { $fs.Dispose() }
        if ($size -ne $ExpectedSize) { Stop-Rea ('размер ' + $size + ' B <> ' + $ExpectedSize + ' B') }
        if ($sha256 -ne $ExpectedSha256.ToLowerInvariant()) { Stop-Rea ('sha256 ' + $sha256 + ' <> ' + $ExpectedSha256) }
        if ($integrity -ne $ExpectedIntegrity) { Stop-Rea ('integrity ' + $integrity + ' <> ' + $ExpectedIntegrity) }
        if ($shasum -ne $ExpectedShasum.ToLowerInvariant()) { Stop-Rea ('shasum ' + $shasum + ' <> ' + $ExpectedShasum) }
        Write-Host ('tarball ' + $tgz + ' (' + $size + ' B)')
        Write-Host ('sha256 ' + $sha256 + ' - съвпада; integrity и shasum - съвпадат')

        # --- 3. Глобална инсталация на проверения файл -------------------------------------------------
        Write-Step '3. npm install --global <проверения tarball>'
        if ($null -eq $installed) {
            if ($script:Mode -eq 'DryRun') {
                Exit-Rea 0 'DRYRUN' 'tarball-ът е проверен; инсталацията не се изпълнява, а стъпки 4-6 искат инсталиран rea. Нищо не е променено.' 'Yellow'
            }
            $script:Own.npm_package.state = 'install_attempted'
            Save-Ownership
            $ni = Invoke-Native $script:NpmCmd @('install', '--global', $tgz) ''
            $null = Save-Text 'npm-install.txt' $ni.Raw
            Write-Host $ni.Raw
            if ($ni.Code -ne 0) { Stop-Rea ('npm install --global върна ' + $ni.Code + ' - виж npm-install.txt; състоянието на npm пакета е install_attempted (неизвестно)') }
            $installed = Get-InstalledReaVersion
            if ($installed -ne $Version) { Stop-Rea ('след инсталацията npm ls показва "' + $installed + '"') }
            $script:Own.npm_package.state = 'created'
        }
        $script:Own.npm_package.after = $installed
        Save-Ownership
        Resolve-ReaCmd
        Write-Host ('rea-agents ' + $installed + ' е инсталиран; rea.cmd: ' + $script:ReaCmd)

        # --- 4. rea doctor (общ; само запис - healthy=false без анализатори е очаквано) ----------------
        Write-Step '4. rea doctor --json'
        $docErrFile = Join-Path $script:LogPath 'doctor-stderr.txt'
        $doc0 = Invoke-Native $script:ReaCmd @('doctor', '--json') $docErrFile
        $null = Save-Text 'doctor.json' $doc0.Raw
        $docErr = ''
        if (Test-Path -LiteralPath $docErrFile) { $docErr = (Get-Content -LiteralPath $docErrFile -Raw -ErrorAction SilentlyContinue) | Out-String }
        if (($doc0.Raw -match 'ERR_MODULE_NOT_FOUND') -or ($docErr -match 'ERR_MODULE_NOT_FOUND')) {
            Write-Host 'ERR_MODULE_NOT_FOUND: провери историята на защитата на Windows (Windows Security > Protection history) и логовете на инсталацията. Не изключвай защитата и не преименувай файлове (docs/installation.md).' -ForegroundColor Yellow
            Stop-Rea 'REA не стартира (ERR_MODULE_NOT_FOUND) - виж doctor.json и doctor-stderr.txt'
        }
        $doc = ConvertFrom-JsonOrNull $doc0.Raw
        if ($null -eq $doc) { Stop-Rea ('rea doctor не върна JSON (exit ' + $doc0.Code + '); REA не стартира - виж doctor.json и doctor-stderr.txt') }
        $healthy = ''
        if (Test-Prop $doc 'healthy') { $healthy = [string]$doc.healthy }
        Write-Host ('rea doctor exit ' + $doc0.Code + ', healthy=' + $healthy + ' (общият doctor само се записва)')

        if ($script:Mode -eq 'SkipRegistration') {
            Exit-Rea 4 'БЕЗ РЕГИСТРАЦИЯ' ('rea-agents ' + $installed + ' е инсталиран; регистрацията е пропусната. Това НЕ е пълна инсталация. Записи: ' + $script:LogPath) 'Yellow'
        }

        # --- 5. Регистрация в Claude Code (user scope) -------------------------------------------------
        Write-Step ('5. rea setup --client claude_code (профил ' + $SchemaProfile + ')')
        Resolve-ClaudeCmd
        Write-Host ('claude: ' + $script:ClaudeExe)
        $plan = Invoke-ReaJson 'setup-plan.json' @('setup', '--client', 'claude_code', '--dry-run', '--json')
        if ($plan.Code -ne 0) { Stop-Rea ('rea setup --dry-run върна ' + $plan.Code + ' - виж setup-plan.json') }
        $planWhy = Test-SetupPlan $plan.Json
        if ($planWhy -ne '') { Stop-Rea ('планът на setup е отказан: ' + $planWhy + ' - виж setup-plan.json. Нищо не е приложено.') }
        $planN = Get-PlanCount $plan.Json
        Write-Host ('План: ' + $planN + ' действия, всички в обхвата.')
        if ($script:Mode -eq 'DryRun') {
            $extra = ''
            if ($planN -eq 0) { $extra = ' Нищо за правене: rea вече е инсталиран и регистриран (planned, 0 действия).' }
            Exit-Rea 0 'DRYRUN' ('планът е проверен и записан в setup-plan.json; нищо не е приложено.' + $extra) 'Yellow'
        }
        Assert-NoSessions 'непосредствено преди rea setup --yes'
        Assert-JsonMatchesBackup 'непосредствено преди rea setup --yes'
        if ($script:Probe) { Resolve-ReaCmd }
        $shaBefore = Get-Sha256OrEmpty $script:ClaudeJson
        $null = Save-Text 'claude-json-sha256-before.txt' $shaBefore
        Write-Host ('sha256 на ~/.claude.json преди setup: ' + $shaBefore)
        $script:Own.rea_entry.state = 'setup_attempted'
        $script:Own.skill_reverse_engineer_anything.state = 'setup_attempted'
        Save-Ownership
        $script:ApplyStarted = $true
        $apply = Invoke-ReaJson 'setup-apply.json' @('setup', '--client', 'claude_code', '--yes', '--json')
        # Собствеността за ВРЪЩАНЕ се записва веднага след apply, и при неуспех.
        $entryAfterApply = Get-ReaEntry 'rea-entry-after-apply.json'
        $bp = [string]$script:Own.rea_entry.before_present
        if ($null -eq $entryAfterApply) { $script:Own.rea_entry.state = 'unknown_after_apply' }
        else {
            $ap = [bool]$entryAfterApply.present
            if (($bp -eq 'absent') -and $ap) { $script:Own.rea_entry.state = 'created' }
            elseif (($bp -eq 'present') -and $ap) { $script:Own.rea_entry.state = 'modified_or_kept' }
            elseif (($bp -eq 'present') -and (-not $ap)) { $script:Own.rea_entry.state = 'missing_after_setup' }
            else { $script:Own.rea_entry.state = 'unchanged' }
        }
        $script:Own.rea_entry.claude_json_sha256_after_apply = (Get-Sha256OrEmpty $script:ClaudeJson)
        $script:Own.skill_reverse_engineer_anything.after = (Get-SkillState $script:ReaSkillDir)
        $sb = $script:Own.skill_reverse_engineer_anything.before
        $sa = $script:Own.skill_reverse_engineer_anything.after
        if ((-not $sb.exists) -and $sa.exists) { $script:Own.skill_reverse_engineer_anything.state = 'created' }
        elseif ($sb.exists -and $sa.exists -and ($sb.skill_sha256 -ne $sa.skill_sha256)) { $script:Own.skill_reverse_engineer_anything.state = 'modified' }
        elseif ($sb.exists -and $sa.exists) { $script:Own.skill_reverse_engineer_anything.state = 'used_existing' }
        else { $script:Own.skill_reverse_engineer_anything.state = 'unchanged' }
        Save-Ownership
        if ($apply.Code -ne 0) { Stop-Rea ('rea setup --yes върна ' + $apply.Code + ' - виж setup-apply.json и ownership.json') }
        $applyWhy = Test-ApplyResult $apply.Json $apply.Raw
        if ($applyWhy -ne '') { Stop-Rea ('rea setup не е приет: ' + $applyWhy + ' - виж setup-apply.json и ownership.json. Не повтаряй веднага.') }
        Write-Host 'rea setup status=ready'

        # --- 6. Проверки (всички задължителни за код 0) ------------------------------------------------
        Write-Step '6. Проверка на регистрацията'
        $chk = Invoke-RegistrationChecks
        $fails = @($chk.Fails)
        $fa = Get-ForeignText $entryAfterApply
        $ff = Get-ForeignText $chk.Final
        if ($fa -ne $script:ForeignBefore) { $fails += 'чужди MCP записи: различни преди и след apply (по име и sha256 на каноничния JSON; стойности не се извеждат)' }
        if ($ff -ne $script:ForeignBefore) { $fails += 'чужди MCP записи: различни преди apply и при финалния прочит' }
        $script:Own.foreign_mcp_unchanged = (($fa -eq $script:ForeignBefore) -and ($ff -eq $script:ForeignBefore))
        if ($script:Own.foreign_mcp_unchanged) { Write-Host ('Чужди MCP записи (име и sha256): непроменени - ' + (Get-ForeignNames $chk.Final)) }
        $shaAfter = Get-Sha256OrEmpty $script:ClaudeJson
        $null = Save-Text 'claude-json-sha256-after.txt' $shaAfter
        $script:Own.rea_entry.claude_json_sha256_final = $shaAfter

        $profileNow = Get-EntryProfile $chk.Final
        $prov = ''
        if ($script:Own.npm_package.state -eq 'used_existing') { $prov = ' Внимание: rea-agents е бил инсталиран преди задачата; произходът от проверения tarball е НЕПРОВЕРЕН.' }
        if ($fails.Count -gt 0) {
            foreach ($f in $fails) { Write-Host ('НЕ МИНА: ' + $f) -ForegroundColor Red }
            Exit-Rea 3 'ЧАСТИЧНО' ('rea-agents ' + $installed + ' е инсталиран; регистрацията е записана, но НЕ е приета. Не повтаряй регистрацията.' + $prov + ' Записи: ' + $script:LogPath) 'Yellow'
        }
        if ($profileNow -ne $SchemaProfile) {
            Exit-Rea 2 'ЧАСТИЧНО' ('в записа mcpServers.rea профилът е "' + $profileNow + '", не ' + $SchemaProfile + '. Скриптът не прави remove/add; нужна е отделна поправка по решение.' + $prov + ' Записи: ' + $script:LogPath) 'Yellow'
        }
        Exit-Rea 0 'ГОТОВО' ('rea-agents ' + $installed + ' е инсталиран; rea е регистриран (user scope, профил ' + $SchemaProfile + '); doctor, mcp doctor, claude mcp get, повторният dry-run (0 действия) и повторният прочит минаха; чуждите MCP записи са непроменени. Видимост в нова сесия на Claude Code - НЕПРОВЕРЕНО до нов старт.' + $prov + ' Записи: ' + $script:LogPath) 'Green'
        Stop-Rea 'вътрешна грешка: краят на скрипта е достигнат без изход'
    }
    catch {
        $msg = [string]$_.Exception.Message
        $code = 1
        if ($script:ApplyStarted) { $code = 3 }
        if ($msg.StartsWith('ЗАПИС ЛИПСВА:')) { Write-Host $msg -ForegroundColor Red }
        else { Write-Host ('НЕОЧАКВАНА ГРЕШКА: ' + $_.Exception.GetType().FullName + ' (ред ' + $_.InvocationInfo.ScriptLineNumber + ')') -ForegroundColor Red }
        Write-Host ('Извършени действия: ' + (Get-ActionsText)) -ForegroundColor Yellow
        Write-Host ('Не е ГОТОВО (код ' + $code + '). Без автоматично връщане и без повторна регистрация.') -ForegroundColor Yellow
        if (-not $script:Stopping) {
            $script:Stopping = $true
            $why = $_.Exception.GetType().FullName
            if ($msg.StartsWith('ЗАПИС ЛИПСВА:')) { $why = $msg }
            try { Save-Result $code 'ГРЕШКА' $why } catch { }
        }
        exit $code
    }
}
