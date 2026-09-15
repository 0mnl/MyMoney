#!/usr/bin/env bash
#
# MyMoney backend launcher — macOS и Linux.
#
# Делает всё, что нужно для локального запуска Ktor-сервера:
#   1) читает .env (или создаёт его с dev-дефолтами),
#   2) проверяет JDK 17+ и работающий Docker,
#   3) поднимает Postgres из docker-compose и ждёт, пока он станет healthy,
#   4) экспортирует переменные окружения и стартует сервер.
#
# Flyway применяет миграции сам при старте приложения — отдельный шаг не нужен.
#
# Использование:  scripts/run-backend.sh [команда] [опции]
# Справка:        scripts/run-backend.sh --help
#
# Совместимость: bash 3.2 (штатный /bin/bash на macOS), zsh не требуется.

set -euo pipefail

# ─── Пути ────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
ENV_FILE="$ROOT_DIR/.env"
PID_FILE="$BACKEND_DIR/build/backend.pid"
LOG_FILE="$BACKEND_DIR/build/backend.log"
PG_CONTAINER="mymoney-postgres"

# ─── Вывод ───────────────────────────────────────────────────────────────────

if [ -t 1 ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

step() { printf '%s==>%s %s%s%s\n' "$C_BLUE" "$C_RESET" "$C_BOLD" "$1" "$C_RESET"; }
info() { printf '    %s\n' "$1"; }
dim()  { printf '    %s%s%s\n' "$C_DIM" "$1" "$C_RESET"; }
ok()   { printf '    %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '%sПРЕДУПРЕЖДЕНИЕ:%s %s\n' "$C_YELLOW" "$C_RESET" "$1" >&2; }
die()  { printf '%sОШИБКА:%s %s\n' "$C_RED" "$C_RESET" "$1" >&2; exit 1; }

# ─── Справка ─────────────────────────────────────────────────────────────────

usage() {
  cat <<'EOF'
MyMoney backend launcher (macOS / Linux)

  scripts/run-backend.sh [команда] [опции]

КОМАНДЫ
  start        Поднять Postgres и запустить сервер через Gradle (по умолчанию).
               Останавливается по Ctrl+C; Postgres при этом продолжает работать.
  jar          Собрать fat jar (shadowJar) и запустить его. Медленнее стартует
               первый раз, но ближе к тому, что уезжает в production.
  db           Поднять только Postgres, сервер не запускать (для запуска из IDE).
  stop         Остановить фоновый сервер и контейнер Postgres.
  restart      stop + start.
  status       Показать состояние Postgres, сервера и ответ /healthz.
  test         Прогнать тесты бэкенда (Testcontainers, нужен работающий Docker).
  logs         Показать лог фонового сервера (start -d), Ctrl+C для выхода.
  psql         Открыть psql внутри контейнера Postgres.

ОПЦИИ
  -p, --port N     Порт HTTP-сервера (по умолчанию PORT из .env или 8080).
  -d, --detach     Запустить сервер в фоне; лог — backend/build/backend.log.
      --no-db      Не трогать Docker вообще (Postgres уже поднят где-то ещё).
      --clean      Выполнить gradle clean перед сборкой.
      --offline    Gradle в офлайн-режиме (--offline), без похода в сеть.
  -h, --help       Эта справка.

ПРИМЕРЫ
  scripts/run-backend.sh                  # обычный запуск для разработки
  scripts/run-backend.sh start -d         # в фоне, лог в файл
  scripts/run-backend.sh -p 9090          # на другом порту
  scripts/run-backend.sh db               # только БД, сервер запускаю из IDE
  scripts/run-backend.sh status           # что вообще сейчас работает
  scripts/run-backend.sh stop             # выключить всё
EOF
}

# ─── Разбор аргументов ───────────────────────────────────────────────────────

COMMAND="start"
PORT_OVERRIDE=""
DETACH=0
USE_DB=1
CLEAN=0
GRADLE_OFFLINE=""

case "${1:-}" in
  start|jar|db|stop|restart|status|test|logs|psql) COMMAND="$1"; shift ;;
  -*|"") ;;
  *) die "неизвестная команда «$1». Запустите с --help." ;;
esac

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--port)  [ $# -ge 2 ] || die "--port требует значение"; PORT_OVERRIDE="$2"; shift 2 ;;
    --port=*)   PORT_OVERRIDE="${1#*=}"; shift ;;
    -d|--detach) DETACH=1; shift ;;
    --no-db)    USE_DB=0; shift ;;
    --clean)    CLEAN=1; shift ;;
    --offline)  GRADLE_OFFLINE="--offline"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) die "неизвестная опция «$1». Запустите с --help." ;;
  esac
done

# ─── .env ────────────────────────────────────────────────────────────────────

# .env не в git — если его нет, создаём с dev-дефолтами (совпадают с
# application.conf и docker-compose.yml, так что запуск «из коробки» работает).
create_default_env() {
  cat > "$ENV_FILE" <<'EOF'
# Сгенерировано scripts/run-backend.sh. Значения — только для локальной разработки.
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
# Для любого не-dev окружения: openssl rand -base64 48
JWT_SECRET=dev-only-change-me-in-production
JWT_ISSUER=mymoney
JWT_AUDIENCE=mymoney-mobile
JWT_ACCESS_TTL_MINUTES=15
JWT_REFRESH_TTL_DAYS=30
EOF
}

load_env() {
  if [ ! -f "$ENV_FILE" ]; then
    warn ".env не найден — создаю с dev-дефолтами: $ENV_FILE"
    create_default_env
  fi
  # Построчный разбор вместо `source`: в .env не должно быть исполняемого кода,
  # и нам не нужны сюрпризы от подстановок shell в значении пароля.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) continue ;;
    esac
    case "$line" in
      *=*) ;;
      *) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    key="$(printf '%s' "$key" | tr -d ' \t')"
    # Снимаем окружающие кавычки, если они есть.
    case "$value" in
      \"*\") value="${value#\"}"; value="${value%\"}" ;;
      \'*\') value="${value#\'}"; value="${value%\'}" ;;
    esac
    # Переменные, уже заданные в окружении, имеют приоритет над .env.
    if [ -z "$(eval "printf '%s' \"\${$key:-}\"")" ]; then
      export "$key=$value"
    fi
  done < "$ENV_FILE"

  : "${POSTGRES_DB:=mymoney}"
  : "${POSTGRES_USER:=mymoney}"
  : "${POSTGRES_PASSWORD:=mymoney_dev_password}"
  : "${POSTGRES_PORT:=5432}"
  : "${APP_ENV:=development}"
  : "${PORT:=8080}"
  : "${DB_USER:=$POSTGRES_USER}"
  : "${DB_PASSWORD:=$POSTGRES_PASSWORD}"
  : "${DB_POOL_SIZE:=10}"
  : "${DB_URL:=jdbc:postgresql://localhost:$POSTGRES_PORT/$POSTGRES_DB}"

  if [ -n "$PORT_OVERRIDE" ]; then
    PORT="$PORT_OVERRIDE"
    export PORT
  fi
  export POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD POSTGRES_PORT
  export APP_ENV PORT DB_URL DB_USER DB_PASSWORD DB_POOL_SIZE

  # Типичная ловушка: сменили POSTGRES_PORT, а DB_URL в .env остался на 5432.
  case "$DB_URL" in
    *localhost*|*127.0.0.1*)
      url_port="$(printf '%s' "$DB_URL" | sed -n 's|.*://[^:/]*:\([0-9]*\)/.*|\1|p')"
      if [ -n "$url_port" ] && [ "$url_port" != "$POSTGRES_PORT" ]; then
        warn "DB_URL указывает на порт $url_port, а Postgres поднимается на $POSTGRES_PORT — поправьте DB_URL в .env"
      fi
      ;;
  esac
}

# ─── Проверки окружения ──────────────────────────────────────────────────────

require_java() {
  if [ -z "${JAVA_HOME:-}" ] && [ -x /usr/libexec/java_home ]; then
    # macOS: JAVA_HOME обычно не выставлен, но java_home знает, где JDK.
    JAVA_HOME="$(/usr/libexec/java_home -v 17 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
    [ -n "$JAVA_HOME" ] && export JAVA_HOME
  fi

  command -v java >/dev/null 2>&1 || die "не найден java. macOS: brew install openjdk@17 · Linux: sudo apt install openjdk-17-jdk"

  version_line="$(java -version 2>&1 | head -1)"
  # [^"]* вместо .* — иначе жадный шаблон проглатывает обе кавычки строки
  # `openjdk version "17.0.20.1" 2026-08-18` и группа остаётся пустой.
  major="$(printf '%s' "$version_line" | sed -n 's/^[^"]*"\([0-9][0-9]*\).*/\1/p')"
  # Java 8 и старше: version "1.8.0_412" — реальный мажор во второй компоненте.
  [ "$major" = "1" ] && major="$(printf '%s' "$version_line" | sed -n 's/^[^"]*"1\.\([0-9][0-9]*\).*/\1/p')"

  if [ -n "$major" ] && [ "$major" -lt 17 ] 2>/dev/null; then
    die "нужен JDK 17+, найден $major ($version_line). macOS: brew install openjdk@17"
  fi
  ok "Java ${major:-?} — $version_line"
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    (cd "$ROOT_DIR" && docker compose "$@")
  elif command -v docker-compose >/dev/null 2>&1; then
    (cd "$ROOT_DIR" && docker-compose "$@")
  else
    die "не найден docker compose. Установите Docker Desktop (macOS) или docker-compose-plugin (Linux)."
  fi
}

require_docker() {
  command -v docker >/dev/null 2>&1 || die "не найден docker. macOS: скачайте Docker Desktop с docker.com"
  if ! docker info >/dev/null 2>&1; then
    die "Docker установлен, но демон не запущен. macOS: откройте Docker Desktop и дождитесь зелёного индикатора."
  fi
}

port_busy() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
  else
    return 1
  fi
}

# Docker публикует порт на wildcard (*:5432), а нативный Postgres — на
# 127.0.0.1:5432 и [::1]:5432. Более специфичная привязка выигрывает, поэтому
# «localhost:5432» уходит в нативный Postgres, а контейнер остаётся
# недостижимым — при этом healthcheck контейнера зелёный, и симптом выглядит
# как необъяснимое «FATAL: role "mymoney" does not exist».
check_port_hijack() {
  command -v lsof >/dev/null 2>&1 || return 0

  hijacker="$(lsof -nP -iTCP:"$POSTGRES_PORT" -sTCP:LISTEN 2>/dev/null \
    | awk '$1 ~ /postgres/ && ($9 ~ /^127\.0\.0\.1:/ || $9 ~ /^\[::1\]:/) { print $2; exit }')"
  [ -n "$hijacker" ] || return 0

  owner="$(ps -o command= -p "$hijacker" 2>/dev/null | head -1)"
  printf '\n'
  warn "порт $POSTGRES_PORT на localhost занят НЕ контейнером, а локальным Postgres:"
  info "  PID $hijacker: $owner"
  info ""
  info "Контейнер слушает wildcard, локальный Postgres — конкретно localhost,"
  info "и выигрывает он. Бэкенд будет ходить в чужую базу и упадёт на"
  info "«FATAL: role \"$POSTGRES_USER\" does not exist». Два выхода:"
  info ""
  info "  1) Развести по портам (ничего не ломает) — в .env:"
  dim  "       POSTGRES_PORT=5434"
  dim  "       DB_URL=jdbc:postgresql://localhost:5434/mymoney"
  dim  "     затем: docker compose up -d --force-recreate postgres"
  info ""
  info "  2) Погасить локальный Postgres:"
  dim  "       brew services stop postgresql@18   # macOS"
  dim  "       sudo systemctl stop postgresql     # Linux"
  printf '\n'
  die "запуск остановлен, чтобы не отлаживать чужую базу"
}

# ─── Postgres ────────────────────────────────────────────────────────────────

pg_health() {
  docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
    "$PG_CONTAINER" 2>/dev/null || printf 'absent'
}

start_postgres() {
  [ "$USE_DB" -eq 1 ] || { dim "--no-db: Postgres не трогаем"; return 0; }

  step "Postgres"
  require_docker

  if [ "$(pg_health)" = "healthy" ]; then
    ok "контейнер $PG_CONTAINER уже работает (порт $POSTGRES_PORT)"
    check_port_hijack
    return 0
  fi

  info "поднимаю контейнер…"
  compose up -d postgres >/dev/null

  printf '    жду готовности'
  i=0
  while [ "$i" -lt 60 ]; do
    status="$(pg_health)"
    if [ "$status" = "healthy" ]; then
      printf '\r'
      ok "Postgres готов — localhost:$POSTGRES_PORT, база $POSTGRES_DB, пользователь $POSTGRES_USER"
      check_port_hijack
      return 0
    fi
    if [ "$status" = "absent" ] || [ "$status" = "exited" ]; then
      printf '\n'
      compose logs --tail 30 postgres || true
      die "контейнер Postgres не запустился (статус: $status)"
    fi
    printf '.'
    sleep 1
    i=$((i + 1))
  done
  printf '\n'
  die "Postgres не стал healthy за 60 секунд. Логи: docker compose logs postgres"
}

# ─── Сервер ──────────────────────────────────────────────────────────────────

gradlew_cmd() {
  [ -f "$BACKEND_DIR/gradlew" ] || die "не найден $BACKEND_DIR/gradlew"
  # На свежем клоне под macOS бит +x часто теряется — чиним молча.
  [ -x "$BACKEND_DIR/gradlew" ] || chmod +x "$BACKEND_DIR/gradlew"
  printf '%s' "$BACKEND_DIR/gradlew"
}

preflight_port() {
  if port_busy "$PORT"; then
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      die "порт $PORT занят фоновым сервером (PID $(cat "$PID_FILE")). Остановите: scripts/run-backend.sh stop"
    fi
    die "порт $PORT уже занят. Освободите его или запустите с другим: scripts/run-backend.sh -p 8081"
  fi
}

print_env_summary() {
  dim "APP_ENV=$APP_ENV  PORT=$PORT"
  dim "DB_URL=$DB_URL"
  if [ "$APP_ENV" = "production" ]; then
    dim "APP_ENV=production: сервер откажется стартовать с дефолтными JWT_SECRET/DB_PASSWORD"
  fi
}

run_gradle_server() {
  step "Сервер (Gradle)"
  print_env_summary
  preflight_port
  gw="$(gradlew_cmd)"

  [ "$CLEAN" -eq 1 ] && (cd "$BACKEND_DIR" && "$gw" clean $GRADLE_OFFLINE)

  if [ "$DETACH" -eq 1 ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    info "запускаю в фоне, лог: $LOG_FILE"
    # Без подоболочки: `( cmd & )` в bash дожидается фоновой задачи перед
    # выходом и держит унаследованный stdout — терминал не отпускается.
    # stdin из /dev/null по той же причине.
    cd "$BACKEND_DIR"
    nohup "$gw" run --console=plain $GRADLE_OFFLINE >"$LOG_FILE" 2>&1 </dev/null &
    server_pid=$!
    printf '%s' "$server_pid" > "$PID_FILE"
    disown "$server_pid" 2>/dev/null || true
    cd "$ROOT_DIR"
    wait_for_health
  else
    info "первый запуск качает Gradle и зависимости — это 3–5 минут, дальше секунды"
    info "остановить: Ctrl+C (Postgres продолжит работать)"
    printf '\n'
    cd "$BACKEND_DIR" && exec "$gw" run --console=plain $GRADLE_OFFLINE
  fi
}

run_jar_server() {
  step "Сборка fat jar"
  gw="$(gradlew_cmd)"
  [ "$CLEAN" -eq 1 ] && (cd "$BACKEND_DIR" && "$gw" clean $GRADLE_OFFLINE)
  (cd "$BACKEND_DIR" && "$gw" buildFatJar --console=plain $GRADLE_OFFLINE)

  jar="$BACKEND_DIR/build/libs/mymoney-backend.jar"
  [ -f "$jar" ] || die "jar не собрался: $jar"
  ok "собран $jar"

  step "Сервер (jar)"
  print_env_summary
  preflight_port

  if [ "$DETACH" -eq 1 ]; then
    mkdir -p "$(dirname "$LOG_FILE")"
    info "запускаю в фоне, лог: $LOG_FILE"
    nohup java -jar "$jar" >"$LOG_FILE" 2>&1 </dev/null &
    server_pid=$!
    printf '%s' "$server_pid" > "$PID_FILE"
    disown "$server_pid" 2>/dev/null || true
    wait_for_health
  else
    info "остановить: Ctrl+C"
    printf '\n'
    exec java -jar "$jar"
  fi
}

wait_for_health() {
  printf '    жду /healthz'
  i=0
  while [ "$i" -lt 90 ]; do
    body="$(curl -fsS "http://localhost:$PORT/healthz" 2>/dev/null || true)"
    if [ -n "$body" ]; then
      printf '\r'
      ok "сервер отвечает: $body"
      info "адрес: http://localhost:$PORT"
      info "лог:   scripts/run-backend.sh logs"
      info "стоп:  scripts/run-backend.sh stop"
      return 0
    fi
    if [ -f "$PID_FILE" ] && ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      printf '\n'
      tail -40 "$LOG_FILE" 2>/dev/null || true
      rm -f "$PID_FILE"
      die "сервер упал при старте. Полный лог: $LOG_FILE"
    fi
    printf '.'
    sleep 1
    i=$((i + 1))
  done
  printf '\n'
  warn "сервер не ответил за 90 секунд. Смотрите лог: $LOG_FILE"
}

# `gradlew run` запускает приложение не своим потомком, а потомком Gradle-демона,
# поэтому убийства PID из PID-файла недостаточно: JVM с сервером остаётся жить и
# держать порт. Добиваем по слушателю порта — но только если это точно наш сервер,
# чтобы случайно не убить чужой процесс, занявший 8080.
kill_port_listener() {
  command -v lsof >/dev/null 2>&1 || return 0
  pids="$(lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null || true)"
  for p in $pids; do
    cmd="$(ps -o command= -p "$p" 2>/dev/null || true)"
    case "$cmd" in
      *mymoney.ApplicationKt*|*mymoney-backend.jar*)
        kill "$p" 2>/dev/null || true
        i=0
        while kill -0 "$p" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
        kill -9 "$p" 2>/dev/null || true
        ok "остановлен процесс сервера на порту $PORT (PID $p)"
        ;;
    esac
  done
}

stop_server() {
  step "Остановка сервера"
  if [ -f "$PID_FILE" ]; then
    pid="$(cat "$PID_FILE")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      i=0
      while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do sleep 1; i=$((i + 1)); done
      kill -9 "$pid" 2>/dev/null || true
      ok "фоновый сервер остановлен (PID $pid)"
    else
      dim "процесс из PID-файла уже не жив"
    fi
    rm -f "$PID_FILE"
  else
    dim "фоновый сервер не запускался (нет $PID_FILE)"
  fi

  kill_port_listener

  if [ "$USE_DB" -eq 1 ] && docker info >/dev/null 2>&1; then
    step "Остановка Postgres"
    compose stop postgres >/dev/null 2>&1 || true
    ok "контейнер остановлен (данные сохранены в volume mymoney-postgres-data)"
  fi
}

show_status() {
  step "Статус"
  if docker info >/dev/null 2>&1; then
    st="$(pg_health)"
    case "$st" in
      healthy) ok "Postgres: healthy, localhost:$POSTGRES_PORT" ;;
      absent)  info "Postgres: контейнер не создан" ;;
      *)       warn "Postgres: $st" ;;
    esac
  else
    info "Postgres: Docker-демон не запущен"
  fi

  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    ok "Сервер: работает в фоне, PID $(cat "$PID_FILE")"
  else
    info "Сервер: фоновый процесс не запущен (мог быть запущен в другом окне)"
  fi

  body="$(curl -fsS "http://localhost:$PORT/healthz" 2>/dev/null || true)"
  if [ -n "$body" ]; then
    ok "http://localhost:$PORT/healthz → $body"
  else
    info "http://localhost:$PORT/healthz не отвечает"
  fi
}

run_tests() {
  step "Тесты бэкенда"
  require_docker
  info "Testcontainers поднимет собственный Postgres — это нормально"
  gw="$(gradlew_cmd)"
  cd "$BACKEND_DIR" && exec "$gw" test --console=plain $GRADLE_OFFLINE
}

# ─── Точка входа ─────────────────────────────────────────────────────────────

load_env

case "$COMMAND" in
  start)
    require_java
    start_postgres
    run_gradle_server
    ;;
  jar)
    require_java
    start_postgres
    run_jar_server
    ;;
  db)
    start_postgres
    printf '\n'
    info "Postgres поднят. Сервер запускайте из IDE (mymoney.ApplicationKt) или:"
    dim  "cd backend && ./gradlew run"
    ;;
  stop)
    stop_server
    ;;
  restart)
    stop_server
    printf '\n'
    require_java
    start_postgres
    run_gradle_server
    ;;
  status)
    show_status
    ;;
  test)
    require_java
    run_tests
    ;;
  logs)
    [ -f "$LOG_FILE" ] || die "лога нет: $LOG_FILE (сервер в фоне не запускался)"
    exec tail -f "$LOG_FILE"
    ;;
  psql)
    require_docker
    [ "$(pg_health)" = "healthy" ] || die "Postgres не запущен. Сначала: scripts/run-backend.sh db"
    exec docker exec -it "$PG_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    ;;
esac
