<#
.SYNOPSIS
    MyMoney backend launcher — Windows (PowerShell 5.1+ / PowerShell 7).

.DESCRIPTION
    Полный аналог scripts/run-backend.sh:
      1) читает .env (или создаёт его с dev-дефолтами),
      2) проверяет JDK 17+ и работающий Docker,
      3) поднимает Postgres из docker-compose и ждёт статуса healthy,
      4) экспортирует переменные окружения и стартует Ktor-сервер.

    Flyway применяет миграции сам при старте приложения — отдельный шаг не нужен.

.PARAMETER Command
    start (по умолчанию) | jar | db | stop | restart | status | test | logs | psql

.EXAMPLE
    .\scripts\run-backend.ps1
.EXAMPLE
    .\scripts\run-backend.ps1 start -Detach
.EXAMPLE
    .\scripts\run-backend.ps1 -Port 9090
.EXAMPLE
    .\scripts\run-backend.ps1 stop

.NOTES
    Если PowerShell отказывается запускать скрипт («выполнение сценариев отключено»):
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
    или разово:
        powershell -ExecutionPolicy Bypass -File .\scripts\run-backend.ps1
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'jar', 'db', 'stop', 'restart', 'status', 'test', 'logs', 'psql')]
    [string]$Command = 'start',

    [Alias('p')]
    [int]$Port = 0,

    [Alias('d')]
    [switch]$Detach,

    [switch]$NoDb,
    [switch]$Clean,
    [switch]$Offline
)

$ErrorActionPreference = 'Stop'

# --- Пути -------------------------------------------------------------------

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir    = Split-Path -Parent $ScriptDir
$BackendDir = Join-Path $RootDir 'backend'
$EnvFile    = Join-Path $RootDir '.env'
$PidFile    = Join-Path $BackendDir 'build\backend.pid'
$LogFile    = Join-Path $BackendDir 'build\backend.log'
$PgContainer = 'mymoney-postgres'

# --- Вывод ------------------------------------------------------------------

function Write-Step { param([string]$m) Write-Host "==> " -ForegroundColor Blue -NoNewline; Write-Host $m -ForegroundColor White }
function Write-Info { param([string]$m) Write-Host "    $m" }
function Write-Dim  { param([string]$m) Write-Host "    $m" -ForegroundColor DarkGray }
function Write-Ok   { param([string]$m) Write-Host "    OK " -ForegroundColor Green -NoNewline; Write-Host $m }
function Write-Warn { param([string]$m) Write-Host "ПРЕДУПРЕЖДЕНИЕ: $m" -ForegroundColor Yellow }
function Die        { param([string]$m) Write-Host "ОШИБКА: $m" -ForegroundColor Red; exit 1 }

# --- .env -------------------------------------------------------------------

$DefaultEnv = @'
# Сгенерировано scripts\run-backend.ps1. Значения — только для локальной разработки.
# .env в .gitignore — реальные секреты сюда класть можно, в git они не попадут.

# === Postgres (читается docker-compose и бэкендом) ===
POSTGRES_DB=mymoney
POSTGRES_USER=mymoney
POSTGRES_PASSWORD=mymoney_dev_password
POSTGRES_PORT=5432

# === Backend ===
# APP_ENV=production включает fail-safe: сервер откажется стартовать,
# если JWT_SECRET или DB_PASSWORD остались дефолтными.
APP_ENV=development
PORT=8080
BACKEND_PORT=8080
DB_URL=jdbc:postgresql://localhost:5432/mymoney
DB_USER=mymoney
DB_PASSWORD=mymoney_dev_password
DB_POOL_SIZE=10

# === JWT ===
# Для любого не-dev окружения сгенерируйте сильный секрет (>= 32 символов).
JWT_SECRET=dev-only-change-me-in-production
JWT_ISSUER=mymoney
JWT_AUDIENCE=mymoney-mobile
JWT_ACCESS_TTL_MINUTES=15
JWT_REFRESH_TTL_DAYS=30
'@

function Import-DotEnv {
    if (-not (Test-Path $EnvFile)) {
        Write-Warn ".env не найден — создаю с dev-дефолтами: $EnvFile"
        Set-Content -Path $EnvFile -Value $DefaultEnv -Encoding UTF8
    }

    foreach ($line in Get-Content $EnvFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $idx = $trimmed.IndexOf('=')
        if ($idx -lt 1) { continue }

        $key   = $trimmed.Substring(0, $idx).Trim()
        $value = $trimmed.Substring($idx + 1)
        if ($value.Length -ge 2) {
            if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }
        # Переменные, уже заданные в окружении, имеют приоритет над .env.
        if (-not [Environment]::GetEnvironmentVariable($key, 'Process')) {
            [Environment]::SetEnvironmentVariable($key, $value, 'Process')
        }
    }

    function Set-Default([string]$name, [string]$fallback) {
        if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
            [Environment]::SetEnvironmentVariable($name, $fallback, 'Process')
        }
    }

    Set-Default 'POSTGRES_DB'       'mymoney'
    Set-Default 'POSTGRES_USER'     'mymoney'
    Set-Default 'POSTGRES_PASSWORD' 'mymoney_dev_password'
    Set-Default 'POSTGRES_PORT'     '5432'
    Set-Default 'APP_ENV'           'development'
    Set-Default 'PORT'              '8080'
    Set-Default 'DB_USER'           $env:POSTGRES_USER
    Set-Default 'DB_PASSWORD'       $env:POSTGRES_PASSWORD
    Set-Default 'DB_POOL_SIZE'      '10'
    Set-Default 'DB_URL'            "jdbc:postgresql://localhost:$($env:POSTGRES_PORT)/$($env:POSTGRES_DB)"

    if ($Port -gt 0) { $env:PORT = "$Port" }

    # Типичная ловушка: сменили POSTGRES_PORT, а DB_URL в .env остался на 5432.
    if ($env:DB_URL -match '://(localhost|127\.0\.0\.1):(\d+)/') {
        if ($Matches[2] -ne $env:POSTGRES_PORT) {
            Write-Warn "DB_URL указывает на порт $($Matches[2]), а Postgres поднимается на $($env:POSTGRES_PORT) — поправьте DB_URL в .env"
        }
    }
}

# --- Проверки окружения -----------------------------------------------------

function Assert-Java {
    $java = Get-Command java -ErrorAction SilentlyContinue
    if (-not $java) {
        Die "не найден java. Установите JDK 17+: winget install EclipseAdoptium.Temurin.17.JDK"
    }
    $versionLine = (& java -version 2>&1 | Select-Object -First 1) -as [string]
    $major = 0
    if ($versionLine -match '"(\d+)') {
        $major = [int]$Matches[1]
        if ($major -eq 1 -and $versionLine -match '"1\.(\d+)') { $major = [int]$Matches[1] }
    }
    if ($major -gt 0 -and $major -lt 17) {
        Die "нужен JDK 17+, найден $major ($versionLine). winget install EclipseAdoptium.Temurin.17.JDK"
    }
    Write-Ok "Java $major — $versionLine"
}

function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    Push-Location $RootDir
    try {
        & docker compose @Args
        if ($LASTEXITCODE -ne 0) { throw "docker compose $($Args -join ' ') завершился с кодом $LASTEXITCODE" }
    } finally { Pop-Location }
}

function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Die "не найден docker. Установите Docker Desktop: winget install Docker.DockerDesktop"
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        Die "Docker установлен, но демон не запущен. Откройте Docker Desktop и дождитесь зелёного индикатора."
    }
}

function Test-PortBusy {
    param([int]$p)
    try { return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue) }
    catch { return $false }
}

# Docker публикует порт на wildcard, а нативный Postgres — на 127.0.0.1.
# Более специфичная привязка выигрывает, поэтому «localhost:5432» уходит в
# нативный Postgres, а контейнер остаётся недостижимым — при этом healthcheck
# контейнера зелёный, и симптом выглядит как необъяснимое
# «FATAL: role "mymoney" does not exist».
function Assert-NoPortHijack {
    $pgPort = [int]$env:POSTGRES_PORT
    try {
        $conns = Get-NetTCPConnection -LocalPort $pgPort -State Listen -ErrorAction SilentlyContinue
    } catch { return }
    if (-not $conns) { return }

    foreach ($c in $conns) {
        if ($c.LocalAddress -notin @('127.0.0.1', '::1')) { continue }
        $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
        if (-not $proc -or $proc.ProcessName -notmatch 'postgres') { continue }

        Write-Host ''
        Write-Warn "порт $pgPort на localhost занят НЕ контейнером, а локальным Postgres:"
        Write-Info "  PID $($proc.Id): $($proc.Path)"
        Write-Info ''
        Write-Info 'Контейнер слушает wildcard, локальный Postgres — конкретно localhost,'
        Write-Info 'и выигрывает он. Бэкенд будет ходить в чужую базу и упадёт на'
        Write-Info "«FATAL: role `"$($env:POSTGRES_USER)`" does not exist». Два выхода:"
        Write-Info ''
        Write-Info '  1) Развести по портам (ничего не ломает) — в .env:'
        Write-Dim  '       POSTGRES_PORT=5434'
        Write-Dim  '       DB_URL=jdbc:postgresql://localhost:5434/mymoney'
        Write-Dim  '     затем: docker compose up -d --force-recreate postgres'
        Write-Info ''
        Write-Info '  2) Погасить локальный Postgres:'
        Write-Dim  '       Stop-Service postgresql-x64-16'
        Write-Host ''
        Die 'запуск остановлен, чтобы не отлаживать чужую базу'
    }
}

# `gradlew run` запускает приложение потомком Gradle-демона, а не своим, поэтому
# убийства PID из PID-файла недостаточно: JVM с сервером остаётся держать порт.
# Добиваем по слушателю порта — но только если это точно наш сервер.
function Stop-PortListener {
    $appPort = [int]$env:PORT
    try {
        $conns = Get-NetTCPConnection -LocalPort $appPort -State Listen -ErrorAction SilentlyContinue
    } catch { return }
    if (-not $conns) { return }

    foreach ($c in $conns) {
        $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
        if (-not $proc) { continue }
        $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)" -ErrorAction SilentlyContinue).CommandLine
        if ($cmdLine -and ($cmdLine -match 'mymoney\.ApplicationKt' -or $cmdLine -match 'mymoney-backend\.jar')) {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Ok "остановлен процесс сервера на порту $appPort (PID $($proc.Id))"
        }
    }
}

# --- Postgres ---------------------------------------------------------------

function Get-PgHealth {
    $out = & docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $PgContainer 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return 'absent' }
    return ($out -as [string]).Trim()
}

function Start-Postgres {
    if ($NoDb) { Write-Dim "-NoDb: Postgres не трогаем"; return }

    Write-Step 'Postgres'
    Assert-Docker

    if ((Get-PgHealth) -eq 'healthy') {
        Write-Ok "контейнер $PgContainer уже работает (порт $($env:POSTGRES_PORT))"
        Assert-NoPortHijack
        return
    }

    Write-Info 'поднимаю контейнер...'
    Invoke-Compose up -d postgres | Out-Null

    Write-Host '    жду готовности' -NoNewline
    for ($i = 0; $i -lt 60; $i++) {
        $status = Get-PgHealth
        if ($status -eq 'healthy') {
            Write-Host ''
            Write-Ok "Postgres готов — localhost:$($env:POSTGRES_PORT), база $($env:POSTGRES_DB), пользователь $($env:POSTGRES_USER)"
            Assert-NoPortHijack
            return
        }
        if ($status -in @('absent', 'exited')) {
            Write-Host ''
            Invoke-Compose logs --tail 30 postgres
            Die "контейнер Postgres не запустился (статус: $status)"
        }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ''
    Die 'Postgres не стал healthy за 60 секунд. Логи: docker compose logs postgres'
}

# --- Сервер -----------------------------------------------------------------

function Get-Gradlew {
    $gw = Join-Path $BackendDir 'gradlew.bat'
    if (-not (Test-Path $gw)) { Die "не найден $gw" }
    return $gw
}

function Assert-PortFree {
    if (Test-PortBusy ([int]$env:PORT)) {
        if (Test-Path $PidFile) {
            $storedPid = Get-Content $PidFile
            if (Get-Process -Id $storedPid -ErrorAction SilentlyContinue) {
                Die "порт $($env:PORT) занят фоновым сервером (PID $storedPid). Остановите: .\scripts\run-backend.ps1 stop"
            }
        }
        Die "порт $($env:PORT) уже занят. Освободите его или запустите с другим: .\scripts\run-backend.ps1 -Port 8081"
    }
}

function Show-EnvSummary {
    Write-Dim "APP_ENV=$($env:APP_ENV)  PORT=$($env:PORT)"
    Write-Dim "DB_URL=$($env:DB_URL)"
    if ($env:APP_ENV -eq 'production') {
        Write-Dim 'APP_ENV=production: сервер откажется стартовать с дефолтными JWT_SECRET/DB_PASSWORD'
    }
}

function Get-GradleArgs {
    param([string[]]$Base)
    if ($Offline) { return $Base + '--offline' }
    return $Base
}

function Start-GradleServer {
    Write-Step 'Сервер (Gradle)'
    Show-EnvSummary
    Assert-PortFree
    $gw = Get-Gradlew

    Push-Location $BackendDir
    try {
        if ($Clean) { & $gw (Get-GradleArgs @('clean')) }

        if ($Detach) {
            New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
            Write-Info "запускаю в фоне, лог: $LogFile"
            $args = (Get-GradleArgs @('run', '--console=plain')) -join ' '
            $proc = Start-Process -FilePath $gw -ArgumentList $args -NoNewWindow -PassThru `
                                  -RedirectStandardOutput $LogFile -RedirectStandardError "$LogFile.err"
            Set-Content -Path $PidFile -Value $proc.Id
            Wait-ForHealth
        } else {
            Write-Info 'первый запуск качает Gradle и зависимости — это 3–5 минут, дальше секунды'
            Write-Info 'остановить: Ctrl+C (Postgres продолжит работать)'
            Write-Host ''
            & $gw (Get-GradleArgs @('run', '--console=plain'))
        }
    } finally { Pop-Location }
}

function Start-JarServer {
    Write-Step 'Сборка fat jar'
    $gw = Get-Gradlew
    Push-Location $BackendDir
    try {
        if ($Clean) { & $gw (Get-GradleArgs @('clean')) }
        & $gw (Get-GradleArgs @('buildFatJar', '--console=plain'))
        if ($LASTEXITCODE -ne 0) { Die "сборка jar провалилась (код $LASTEXITCODE)" }
    } finally { Pop-Location }

    $jar = Join-Path $BackendDir 'build\libs\mymoney-backend.jar'
    if (-not (Test-Path $jar)) { Die "jar не собрался: $jar" }
    Write-Ok "собран $jar"

    Write-Step 'Сервер (jar)'
    Show-EnvSummary
    Assert-PortFree

    if ($Detach) {
        New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null
        Write-Info "запускаю в фоне, лог: $LogFile"
        $proc = Start-Process -FilePath 'java' -ArgumentList "-jar `"$jar`"" -NoNewWindow -PassThru `
                              -RedirectStandardOutput $LogFile -RedirectStandardError "$LogFile.err"
        Set-Content -Path $PidFile -Value $proc.Id
        Wait-ForHealth
    } else {
        Write-Info 'остановить: Ctrl+C'
        Write-Host ''
        & java -jar $jar
    }
}

function Wait-ForHealth {
    Write-Host '    жду /healthz' -NoNewline
    for ($i = 0; $i -lt 90; $i++) {
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:$($env:PORT)/healthz" -TimeoutSec 2 -ErrorAction Stop
            Write-Host ''
            Write-Ok "сервер отвечает: $($resp | ConvertTo-Json -Compress)"
            Write-Info "адрес: http://localhost:$($env:PORT)"
            Write-Info 'лог:   .\scripts\run-backend.ps1 logs'
            Write-Info 'стоп:  .\scripts\run-backend.ps1 stop'
            return
        } catch { }

        if (Test-Path $PidFile) {
            $storedPid = Get-Content $PidFile
            if (-not (Get-Process -Id $storedPid -ErrorAction SilentlyContinue)) {
                Write-Host ''
                if (Test-Path $LogFile) { Get-Content $LogFile -Tail 40 }
                Remove-Item $PidFile -Force
                Die "сервер упал при старте. Полный лог: $LogFile"
            }
        }
        Write-Host '.' -NoNewline
        Start-Sleep -Seconds 1
    }
    Write-Host ''
    Write-Warn "сервер не ответил за 90 секунд. Смотрите лог: $LogFile"
}

function Stop-Backend {
    Write-Step 'Остановка сервера'
    if (Test-Path $PidFile) {
        $storedPid = Get-Content $PidFile
        $proc = Get-Process -Id $storedPid -ErrorAction SilentlyContinue
        if ($proc) {
            Stop-Process -Id $storedPid -Force -ErrorAction SilentlyContinue
            Write-Ok "фоновый сервер остановлен (PID $storedPid)"
        } else {
            Write-Dim 'процесс из PID-файла уже не жив'
        }
        Remove-Item $PidFile -Force -ErrorAction SilentlyContinue
    } else {
        Write-Dim "фоновый сервер не запускался (нет $PidFile)"
    }

    Stop-PortListener

    if (-not $NoDb) {
        & docker info *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Step 'Остановка Postgres'
            Invoke-Compose stop postgres | Out-Null
            Write-Ok 'контейнер остановлен (данные сохранены в volume mymoney-postgres-data)'
        }
    }
}

function Show-Status {
    Write-Step 'Статус'
    & docker info *> $null
    if ($LASTEXITCODE -eq 0) {
        switch (Get-PgHealth) {
            'healthy' { Write-Ok "Postgres: healthy, localhost:$($env:POSTGRES_PORT)" }
            'absent'  { Write-Info 'Postgres: контейнер не создан' }
            default   { Write-Warn "Postgres: $_" }
        }
    } else {
        Write-Info 'Postgres: Docker-демон не запущен'
    }

    if (Test-Path $PidFile) {
        $storedPid = Get-Content $PidFile
        if (Get-Process -Id $storedPid -ErrorAction SilentlyContinue) {
            Write-Ok "Сервер: работает в фоне, PID $storedPid"
        } else {
            Write-Info 'Сервер: фоновый процесс не запущен'
        }
    } else {
        Write-Info 'Сервер: фоновый процесс не запущен (мог быть запущен в другом окне)'
    }

    try {
        $resp = Invoke-RestMethod -Uri "http://localhost:$($env:PORT)/healthz" -TimeoutSec 3 -ErrorAction Stop
        Write-Ok "http://localhost:$($env:PORT)/healthz -> $($resp | ConvertTo-Json -Compress)"
    } catch {
        Write-Info "http://localhost:$($env:PORT)/healthz не отвечает"
    }
}

# --- Точка входа ------------------------------------------------------------

Import-DotEnv

switch ($Command) {
    'start' {
        Assert-Java
        Start-Postgres
        Start-GradleServer
    }
    'jar' {
        Assert-Java
        Start-Postgres
        Start-JarServer
    }
    'db' {
        Start-Postgres
        Write-Host ''
        Write-Info 'Postgres поднят. Сервер запускайте из IDE (mymoney.ApplicationKt) или:'
        Write-Dim  'cd backend; .\gradlew.bat run'
    }
    'stop' { Stop-Backend }
    'restart' {
        Stop-Backend
        Write-Host ''
        Assert-Java
        Start-Postgres
        Start-GradleServer
    }
    'status' { Show-Status }
    'test' {
        Assert-Java
        Assert-Docker
        Write-Step 'Тесты бэкенда'
        Write-Info 'Testcontainers поднимет собственный Postgres — это нормально'
        $gw = Get-Gradlew
        Push-Location $BackendDir
        try { & $gw (Get-GradleArgs @('test', '--console=plain')) } finally { Pop-Location }
    }
    'logs' {
        if (-not (Test-Path $LogFile)) { Die "лога нет: $LogFile (сервер в фоне не запускался)" }
        Get-Content $LogFile -Wait -Tail 50
    }
    'psql' {
        Assert-Docker
        if ((Get-PgHealth) -ne 'healthy') { Die 'Postgres не запущен. Сначала: .\scripts\run-backend.ps1 db' }
        & docker exec -it $PgContainer psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB
    }
}
