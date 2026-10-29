# REA 6.8.0 — резервно копие (racho55/rea, клон racho-backup)

## Какво е
Резервно копие на REA (npm пакет `rea-agents`), инсталиран по Jira FAB-632.

Клонът racho-backup е обикновен клон с наследена история. Родителят на архивния комит е upstream комитът 160d821ac9a0310afcb8d1fc427862dd6508add5, към който сочи тагът rea-agents-6.8.0 на github.com/morluto/rea. Дървото и историята на upstream са запазени непроменени. Архивният комит само добавя файловете по-долу в корена (и skills/rea-pravilo/) и няколко реда в .gitattributes, които пазят тези файлове байт по байт.

Така клонът пази изходния код на REA при версия 6.8.0 (наследеното дърво), точния основен npm пакет rea-agents 6.8.0 (tarball) и скриптовете за инсталиране, без да зависи от компютъра, на който е направено копието.

Възстановяването още изисква достъп до npm registry: зависимостите на пакета не са в копието и се теглят от registry при инсталиране (виж „Ограничения“). Това копие не дава напълно независимо или офлайн възстановяване.

- Версия: rea-agents 6.8.0 (таг rea-agents-6.8.0 = 160d821ac9a0310afcb8d1fc427862dd6508add5)
- Източник: https://github.com/morluto/rea и https://registry.npmjs.org/rea-agents (integrity sha512-9QDeRnGqEDzABZyr04eLnBXBv/c6I9/TWu/6M0MD4pEfkySI/BIgwTODIbAReX3C1x6hjw9+Jlx4A2yUSPZ9ww==, shasum 6a2cc197e4ff7f11ba937125b3ca7e4de939906a)
- Лиценз: MIT, Copyright (c) 2026 morluto — файлът LICENSE в корена е наследеният от upstream. Той е байт по байт същият като package/LICENSE в tarball-а (sha256 798f9e4d18e49b30bf2f12696c8ced73dc4e1413da375a333d01281543a1ea8b). Пакетът носи и лицензи на трети страни в package/licenses/ вътре в tarball-а.

| Файл | sha256 |
|---|---|
| rea-agents-6.8.0.tgz (9944902 B) | 8d542ec76a9cb350584b60a6c9c088706ff812d5bb5b094c20c95b6dc25698bb |
| install-rea.ps1 (v4) | 50d4eb1daf290762d3ca8aa62bbbed3f49decdef49a67038751450fc7cb774bd |
| Backup-ClaudeHome.ps1 (v3) | c6389674246d5c5249fd927329e5fa4c85a6ffdbd3e8c200b4cce1c3ea3f769d |
| skills/rea-pravilo/SKILL.md | 215b432e8fbddf15cc171de6614cda460afb0918628cefb5a5ab7036c2a00deb |

Двата .ps1 файла са с CRLF и UTF-8 BOM. В .gitattributes са маркирани `-text`, за да не ги променя git при запис и при сваляне.

## Възстановяване
Пълно възстановяване се започва след ново проверено локално резервно копие. Команда:
powershell -NoProfile -File .\install-rea.ps1 -Source tarball -BackupReport "<пълен път до BACKUP-REPORT.md>" -BackupReportSha256 "<SHA256 на отчета>"

install-rea.ps1 v4 се пуска от обикновен PowerShell при затворени всички Claude Code сесии и настолното приложение Claude. -AcceptRunningSessions не се поддържа. При работещ Claude процес или неустановено състояние на относим процес се спира.

npm install -g .\rea-agents-6.8.0.tgz възстановява само npm пакета; не доказва пълна регистрация, профил full или успешни диагностики.

Ред на нов компютър: (1) инсталирай Claude Code и го стартирай веднъж, за да се създадат ~/.claude и ~/.claude.json; затвори го; (2) свери sha256 на Backup-ClaudeHome.ps1, после `Unblock-File .\Backup-ClaudeHome.ps1`, и го пусни: `powershell -NoProfile -File .\Backup-ClaudeHome.ps1` → код 0 и СТАТУС: ПРОВЕРЕНО; (3) свери sha256 на install-rea.ps1, после `Unblock-File .\install-rea.ps1`, и пусни командата по-горе с -LogDir <нова папка>.

Unblock-File не е заобикаляне: прави се само след сверка на хеша. ExecutionPolicy не се пипа.

## Ограничения
- Зависимостите не са заключени: tarball-ът не съдържа package/npm-shrinkwrap.json (`tar -tzf rea-agents-6.8.0.tgz package/npm-shrinkwrap.json` → не е намерен). При инсталиране зависимостите идват от npm registry.
- Заключената версия не получава поправки по сигурността. По SECURITY.md при тага: „Security fixes are provided for the latest published version of REA.“
- Не качвай личното резервно копие или claude.json.bak в GitHub.

## ВРЪЩАНЕ
Връщането се определя от провереното начално състояние (ownership.json в <LOGDIR> и rea-pravilo-ownership.json в run1-cc). За npm пакета, user-scope REA записа и всяка от двете skill папки се отбелязва: създадена, изменена или само използвана от задачата.
Премахват се само създадените от задачата компоненти, след сверка, че текущата версия и съдържание още съответстват на доставеното. Предишна инсталация и предишни skills не се деинсталират. Изменен предишен REA запис или skill се възстановява само за засегнатия компонент от неговото проверено начално състояние.
Последваща чужда промяна, друга версия или неизвестна собственост → СПРИ преди премахване. Целият .claude.json не се връща. rea uninstall не се използва.
Състояние modified_or_kept на записа: отделно възстановяване на стария запис няма; старото състояние е само в claude.json.bak.
