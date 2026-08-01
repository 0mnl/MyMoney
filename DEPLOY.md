# DEPLOY — MyMoney

Полное руководство по сборке Android-приложения и хостингу бэкенда.

- [1. Сборка APK на Windows](#1-сборка-apk-на-windows)
- [2. Локальный запуск для разработки](#2-локальный-запуск-для-разработки)
- [3. Хостинг бэкенда на Arch Linux](#3-хостинг-бэкенда-на-arch-linux)
- [4. Настройка мобильного приложения для продакшн-сервера](#4-настройка-мобильного-приложения-для-продакшн-сервера)
- [5. Ротация секретов](#5-ротация-секретов)

---

## 1. Сборка APK на Windows

### 1.1 Необходимые инструменты

1. **Flutter SDK** ≥ 3.24
   - Скачать с https://docs.flutter.dev/release/archive (channel `stable`)
   - Распаковать, например, в `C:\dev\flutter`
   - Добавить `C:\dev\flutter\bin` в PATH (System Environment Variables)
   - Проверить: `flutter --version`
2. **Android Studio** (для Android SDK и Command-line Tools)
   - https://developer.android.com/studio
   - При установке принять лицензии SDK
   - В Android Studio → SDK Manager включить: `Android SDK Platform 34`, `Android SDK Build-Tools 34.0.0`, `Android SDK Command-line Tools`, `Android SDK Platform-Tools`
3. **JDK 17** (Temurin рекомендуется)
   - https://adoptium.net/temurin/releases/?version=17
   - Установщик сам пропишет `JAVA_HOME`
4. Проверить целостность окружения: `flutter doctor -v`
   - Все чекбоксы должны быть зелёные, кроме Xcode/Chrome (не нужны для Android)
   - Если `flutter doctor --android-licenses` требует ответа — ответить `y` на все

### 1.2 Сборка debug/release APK

```powershell
cd C:\Users\<you>\path\to\MyMoney\mobile
flutter pub get

# Отладочная сборка (для теста на своём телефоне через USB)
flutter build apk --debug

# Финальная релизная сборка
flutter build apk --release
```

APK будет здесь: `mobile\build\app\outputs\flutter-apk\app-release.apk`
(≈ 30–50 МБ на весь ABI-универсал).

Для минимального размера — собрать по одному ABI:
```powershell
flutter build apk --release --split-per-abi
# получите три APK: arm64-v8a / armeabi-v7a / x86_64
```

### 1.3 Подпись release APK

Debug-APK подписан ключом отладки, release — требует свой ключ.

**Шаг 1. Один раз создать keystore:**
```powershell
keytool -genkey -v -keystore C:\Users\<you>\mymoney-release.jks `
    -keyalg RSA -keysize 2048 -validity 10000 -alias mymoney
```
Пароль запомнить (менеджер паролей). Файл `mymoney-release.jks` — **никогда** не коммитить.

**Шаг 2. Создать `mobile/android/key.properties` (в .gitignore):**
```properties
storePassword=<пароль>
keyPassword=<пароль>
keyAlias=mymoney
storeFile=C:/Users/<you>/mymoney-release.jks
```

**Шаг 3. Подключить в `mobile/android/app/build.gradle`:**
```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

**Шаг 4. Пересобрать:**
```powershell
flutter build apk --release
```

### 1.4 Автоматическая сборка через GitHub Actions

Каждый push в ветку `Alpha` запускает workflow `Build APK`
(`.github/workflows/release-apk.yml`) и загружает APK как artifact.
Скачать: **Actions → Build APK → нужный run → Artifacts → mymoney-apk-\<sha\>**.

Чтобы автопубликовать APK как GitHub Release — создайте тег:
```bash
git tag v0.1.0
git push origin v0.1.0
```
Workflow прикрепит APK к странице релиза автоматически.

---

## 2. Локальный запуск для разработки

### 2.1 Требования
- Docker Desktop (Windows) или Docker Engine (Linux)
- JDK 17
- Flutter SDK ≥ 3.24
- Android-эмулятор (AVD) либо физический телефон в режиме отладки

### 2.2 Поднять Postgres
```bash
cp .env.example .env    # только один раз
docker compose up -d postgres
docker compose ps       # проверить, что healthcheck зелёный
```

### 2.3 Запустить бэкенд из IDE или командной строки
```bash
cd backend
./gradlew run
# API: http://localhost:8080
# Health: curl http://localhost:8080/healthz
```

### 2.4 Запустить приложение
```bash
cd mobile
flutter pub get
flutter run
```
На Android-эмуляторе базовый URL по умолчанию — `http://10.0.2.2:8080`
(это специальный alias эмулятора, ведущий на localhost хоста).

Для запуска на физическом телефоне (через USB):
1. Включить «Отладка по USB» в разделе «Параметры разработчика»
2. `flutter devices` — должно появиться устройство
3. `flutter run -d <device_id>`
4. В приложении: Настройки → URL бэкенда → `http://<IP-компьютера>:8080`

### 2.5 Полная prod-подобная сборка одной командой
```bash
export JWT_SECRET=$(openssl rand -base64 48)   # временный секрет только для теста
export APP_ENV=production
docker compose --profile prod up -d --build
# оба контейнера поднимутся: mymoney-postgres и mymoney-backend
```

---

## 3. Хостинг бэкенда на Arch Linux

Цель: развернуть Ktor-бэкенд на своём сервере под Arch Linux с TLS,
автозапуском и бэкапами БД. Приложение раздаётся отдельно (APK через
GitHub Releases или Telegram), сервер нужен только для семьи/синхронизации.

### 3.1 Предполагаемая конфигурация
- Свежий Arch Linux (пользователь с sudo, SSH-доступ)
- Домен, направленный A-записью на IP сервера
- Порт 80 и 443 доступны наружу
- Достаточно **1 vCPU / 1 ГБ RAM** для семьи из 2 человек

### 3.2 Подготовка сервера

```bash
# 1. Обновиться
sudo pacman -Syu --noconfirm

# 2. Установить всё нужное
sudo pacman -S --noconfirm docker docker-compose git ufw nginx certbot certbot-nginx

# 3. Включить Docker
sudo systemctl enable --now docker

# 4. Добавить себя в группу docker (перелогиниться после этого)
sudo usermod -aG docker $USER
```

### 3.3 Файервол (UFW)

```bash
sudo systemctl enable ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    
sudo ufw allow 80/tcp    
sudo ufw allow 443/tcp   
sudo ufw enable
sudo ufw status
```

Порт 8080 наружу **не открываем** — доступ идёт через nginx.

### 3.4 Клонирование и настройка

```bash
sudo mkdir -p /opt/mymoney /opt/backups
sudo chown $USER:$USER /opt/mymoney /opt/backups
git clone -b Alpha https://github.com/0mnl/MyMoney.git /opt/mymoney
cd /opt/mymoney
cp .env.example .env
```

Отредактировать `/opt/mymoney/.env`:
```bash
nano /opt/mymoney/.env
```

Ключевые значения (пример):
```env
APP_ENV=production
POSTGRES_DB=mymoney
POSTGRES_USER=mymoney
POSTGRES_PASSWORD=<64 случайных байта>
POSTGRES_PORT=5432
BACKEND_PORT=8080
DB_POOL_SIZE=10
JWT_SECRET=<openssl rand -base64 48>
JWT_ACCESS_TTL_MINUTES=15
JWT_REFRESH_TTL_DAYS=30
```

Сгенерировать секреты:
```bash
openssl rand -base64 48   # для JWT_SECRET
openssl rand -base64 32   # для POSTGRES_PASSWORD
```

**Важно:** при `APP_ENV=production` бэкенд **откажется стартовать**,
если оставить дефолтные значения `dev-only-change-me-in-production`
или `mymoney_dev_password` (см. `AppConfig.kt`). Это защита от случайной
публикации с dev-настройками.

### 3.5 Запуск

```bash
cd /opt/mymoney
docker compose --profile prod up -d --build

# Проверить логи
docker compose logs -f backend

# Проверить, что API отвечает (внутри сервера)
curl http://localhost:8080/healthz
```

### 3.6 Nginx как reverse-proxy

Создать `/etc/nginx/sites-available/mymoney` (Arch по умолчанию использует
`/etc/nginx/nginx.conf` без sites-available; проще положить конфиг в
`/etc/nginx/conf.d/mymoney.conf`):

```bash
sudo tee /etc/nginx/conf.d/mymoney.conf > /dev/null <<'EOF'
server {
    listen 80;
    server_name mymoney.example.com;

    location /.well-known/acme-challenge/ {
        root /var/lib/letsencrypt;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name mymoney.example.com;

    ssl_certificate /etc/letsencrypt/live/mymoney.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/mymoney.example.com/privkey.pem;

    client_max_body_size 5m;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}
EOF
```

Заменить `mymoney.example.com` на свой домен.

```bash
sudo systemctl enable --now nginx
sudo nginx -t
```

### 3.7 TLS через certbot

```bash
# Первый запуск — certbot сам добавит ssl-строки в конфиг nginx
sudo certbot --nginx -d mymoney.example.com \
    --agree-tos --email you@example.com --redirect

# Автопродление через systemd timer уже настроено пакетом certbot-nginx.
sudo systemctl enable --now certbot-renew.timer
sudo systemctl list-timers | grep certbot
```

Проверить снаружи:
```
curl https://mymoney.example.com/healthz
# {"status":"ok"}
```

### 3.8 Systemd-юнит для docker compose

Compose уже запущен как daemon-процессы Docker (перезапустятся сами
при перезагрузке сервера благодаря `restart: unless-stopped`).
Отдельный systemd-юнит нужен, только если хотите централизованно
рулить `systemctl start mymoney` / `systemctl status mymoney`:

```bash
sudo tee /etc/systemd/system/mymoney.service > /dev/null <<'EOF'
[Unit]
Description=MyMoney Backend (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/mymoney
ExecStart=/usr/bin/docker compose --profile prod up -d
ExecStop=/usr/bin/docker compose --profile prod down
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now mymoney.service
sudo systemctl status mymoney.service
```

### 3.9 Обновление бэкенда

```bash
cd /opt/mymoney
git pull origin Alpha
docker compose --profile prod build backend
docker compose --profile prod up -d --no-deps backend
docker compose logs -f backend | head -50   # убедиться, что стартанул чисто
```

Даунтайм — 2–5 секунд (перезапуск контейнера).

### 3.10 Бэкапы PostgreSQL

```bash
sudo tee /opt/mymoney/scripts/backup.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DATE=$(date +%Y%m%d_%H%M%S)
DEST=/opt/backups/mymoney_$DATE.sql.gz
cd /opt/mymoney
docker compose exec -T postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
    | gzip > "$DEST"
# Ротация — 30 дней
find /opt/backups -name 'mymoney_*.sql.gz' -mtime +30 -delete
echo "Backup: $DEST ($(du -h "$DEST" | cut -f1))"
EOF
sudo chmod +x /opt/mymoney/scripts/backup.sh
```

Cron каждую ночь в 03:00:
```bash
crontab -e
# добавить строку:
0 3 * * * cd /opt/mymoney && set -a && source .env && set +a && /opt/mymoney/scripts/backup.sh >> /var/log/mymoney-backup.log 2>&1
```

Восстановление:
```bash
gunzip -c /opt/backups/mymoney_20260722_030000.sql.gz \
    | docker compose exec -T postgres psql -U "$POSTGRES_USER" "$POSTGRES_DB"
```

### 3.11 Мониторинг «жив/не жив»

```bash
# Пинг API
curl -fsS https://mymoney.example.com/healthz && echo OK

# Логи бэкенда за последний час
docker compose logs --since 1h backend | tail -100

# Использование диска (в первую очередь на /var/lib/docker и /opt/backups)
df -h
du -sh /var/lib/docker /opt/backups
```

Внешний мониторинг: бесплатный UptimeRobot / Better Stack проверяет
`https://mymoney.example.com/healthz` каждые 5 минут и шлёт email при падении.

---

## 4. Настройка мобильного приложения для продакшн-сервера

### 4.1 Где меняется URL
- **Через UI (рекомендуется):** приложение → вкладка «Настройки»
  → поле «URL бэкенда» → сохранить.
  Значение хранится в `SharedPreferences` (`api.base_url`) и переживает
  перезапуски.
- **Дефолтное значение** для нового установа задано в
  `mobile/lib/core/env.dart`:
  ```dart
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',   // Android emulator → host localhost
  );
  ```

### 4.2 Собрать APK, «зашитый» под ваш сервер
```bash
cd mobile
flutter build apk --release \ --dart-define=API_BASE_URL=https://mymoney.example.com
```
Такой APK сразу открывается на нужный сервер, без ручного ввода URL.

### 4.3 Раздача APK через Telegram

1. Собрать `app-release.apk` (см. §1.2)
2. В Telegram: нажать «скрепку» → «Файл» → выбрать APK
3. В подпись сообщения включить:
   - Версию (`v0.1.0`)
   - Дату сборки
   - Изменения относительно предыдущей версии
   - SHA-256 хеш файла: `certutil -hashfile app-release.apk SHA256`
4. На стороне пользователя: разрешить установку из «неизвестных источников»
   (Settings → Apps → \<Telegram\> → «Install unknown apps»)

### 4.4 Раздача через GitHub Releases

Автоматически при пуше git-тега `v*` (см. §1.4). Пользователь идёт на
`https://github.com/0mnl/MyMoney/releases`, скачивает APK, устанавливает.

---

## 5. Ротация секретов

### 5.1 JWT_SECRET
Смена секрета инвалидирует все текущие access-токены и refresh-токены.
Пользователи будут разлогинены и должны войти заново.

```bash
# 1. Сгенерировать новый секрет
NEW_JWT=$(openssl rand -base64 48)
echo "New JWT: $NEW_JWT"

# 2. Обновить .env
sed -i "s|^JWT_SECRET=.*|JWT_SECRET=$NEW_JWT|" /opt/mymoney/.env

# 3. Перезапустить только backend
cd /opt/mymoney
docker compose --profile prod up -d --no-deps --force-recreate backend
```

**«Мягкая» ротация без разлогина** (dual-secret режим) — не поддерживается
на MVP. Если это критично, можно добавить second-secret в `AppConfig.kt`
и в `JwtTokenService.verify` пробовать оба ключа — но это дополнительная
работа за пределами текущего скоупа.

### 5.2 Пароль БД
Пароль хранится в контейнере Postgres в закодированном виде. Смена
требует alter-role внутри БД.

```bash
cd /opt/mymoney

# 1. Сгенерировать новый пароль
NEW_DB_PASS=$(openssl rand -base64 32)

# 2. Изменить пароль внутри работающего Postgres
docker compose exec postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    -c "ALTER USER $POSTGRES_USER WITH PASSWORD '$NEW_DB_PASS';"

# 3. Обновить .env
sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$NEW_DB_PASS|" .env

# 4. Перезапустить backend (у Postgres пароль уже сменили в шаге 2)
docker compose --profile prod up -d --no-deps --force-recreate backend
```

### 5.3 Android keystore

Правило номер один: **потеря keystore = потеря возможности обновить
приложение**. Google Play (и любая APK-раздача) считает разные подписи
разными приложениями.

Как хранить:
- Файл `mymoney-release.jks` — **никогда не в git**
- Мастер-копия — в менеджере паролей (Bitwarden/1Password) как attachment
- Резервная копия — на USB-накопителе в сейфе
- Пароль `storePassword` и `keyPassword` — в том же менеджере паролей
- CI (GitHub Actions) для подписи: keystore в base64 → GitHub Secret
  `ANDROID_KEYSTORE`, пароли — отдельные секреты. В workflow декодируйте
  обратно в файл. На данном этапе CI собирает **неподписанный** release APK
  (см. `.github/workflows/release-apk.yml`); подпись добавляется по мере
  необходимости.

Проверить SHA-1 отпечаток текущего keystore:
```powershell
keytool -list -v -keystore C:\Users\<you>\mymoney-release.jks -alias mymoney
```

---

## Быстрая шпаргалка

| Действие | Команда |
| --- | --- |
| Локальный dev (только БД) | `docker compose up -d postgres` |
| Локальный dev (БД + бэкенд) | `docker compose --profile prod up -d --build` |
| Логи | `docker compose logs -f backend` |
| Обновить сервер | `git pull && docker compose --profile prod up -d --build backend` |
| Бэкап вручную | `/opt/mymoney/scripts/backup.sh` |
| APK debug | `flutter build apk --debug` |
| APK release | `flutter build apk --release` |
| APK для своего сервера | `flutter build apk --release --dart-define=API_BASE_URL=https://…` |
