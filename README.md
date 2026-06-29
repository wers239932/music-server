# 🎵 Music Stack — Автономный музыкальный стриминг с загрузкой из YouTube

Полностью автономный музыкальный сервис в Docker. Стримит вашу коллекцию, даёт умные рекомендации на основе прослушиваний и **автоматически скачивает недостающую музыку с YouTube** с правильными ID3-тегами и обложками.

---

## 🏗 Архитектура

```
┌─────────────┐     Subsonic API     ┌───────────────────┐
│  Navidrome   │◄────────────────────│  Music Assistant   │
│  :4533       │                      │  :8095             │
│  (плеер)     │                      │  (рекомендации)    │
└──────┬───────┘                      └───────────────────┘
       │                                       ▲
       │ /music (ro)                           │ скробблы
       ▼                                       │
┌──────────────┐     API       ┌──────────────────────┐
│  /data/music │◄──────────────│  Lidarr  :8686       │
│  (библиотека)│               │  (менеджер коллекции)│
└──────────────┘               └──────────┬───────────┘
                                          │ «missing tracks»
                                          ▼
                               ┌──────────────────────┐
                               │  Lidarr YT Downloader│
                               │  angrido/lidarr-     │
                               │  downloader  :5005   │
                               │  → YouTube → /data   │
                               └──────────────────────┘

┌──────────────────────┐
│  MeTube  :8081       │  ← ручная загрузка YouTube-ссылок
│  (yt-dlp веб-UI)     │     → /data/downloads/metube
└──────────────────────┘
```

---

## 📂 Структура папок

```
music-stack/
├── docker-compose.yml
├── .env                          # (gitignored) реальные ключи
├── .env.copy                     # шаблон переменных
├── config/                       # конфиги сервисов (gitignored)
│   ├── navidrome/
│   ├── music-assistant/
│   ├── lidarr/
│   ├── lidarr-yt/                 # конфиг веб-UI загрузчика
│   └── downloader-scripts/
└── data/                         # медиаконтент (gitignored)
    ├── downloads/
    │   ├── metube/                # сырые загрузки из MeTube
    │   └── lidarr-yt/             # временные файлы загрузчика
    └── music/                    # организованная библиотека
        ├── Artist Name/
        │   └── Album Name/
        │       ├── 01 - Track.mp3
        │       └── cover.jpg
        └── ...
```

---

## 🚀 Быстрый старт

### 1. Подготовка

```bash
git clone https://github.com/wers239932/music-server.git /srv/music-stack
cd /srv/music-stack

# Создать структуру папок
mkdir -p config/{navidrome,music-assistant,lidarr,lidarr-yt,downloader-scripts} \
         data/music \
         data/downloads/{metube,lidarr-yt}

# Скопировать шаблон переменных
cp .env.copy .env
```

### 2. Заполнить `.env`

```bash
nano .env
```

| Переменная | Откуда взять |
|---|---|
| `LASTFM_API_KEY` / `LASTFM_SECRET` | [last.fm/api/account/create](https://www.last.fm/api/account/create) |
| `LIDARR_API_KEY` | Появится **после** первого запуска Lidarr (шаг 4) |
| `TZ` | Ваш часовой пояс (по умолчанию `Europe/Moscow`) |

> 💡 `LIDARR_API_KEY` можно оставить пустым на первом запуске — вставите позже.

### 3. Запустить стек

```bash
docker compose up -d
```

Проверить статус:

```bash
docker compose ps
```

Все 5 контейнеров должны быть `running` (кроме `lidarr-yt`, который ждёт `LIDARR_API_KEY`).

### 4. Настроить Lidarr и получить API-ключ

1. Откройте **http://<ваш-ip>:8686**
2. Пройдите первичную настройку (язык, путь к музыке)
3. **Settings → General** → скопируйте **API Key**
4. Вставьте его в `.env`:
   ```bash
   nano .env   # LIDARR_API_KEY=вставленный_ключ
   ```
5. Перезапустите загрузчик:
   ```bash
   docker compose restart lidarr-youtube-downloader
   ```

### 5. Настроить Media Management в Lidarr

**Settings → Media Management:**

| Параметр | Значение |
|---|---|
| Root Folder | `/data/music` |
| Rename Tracks | ✅ Включено |
| Standard Track Format | `{Artist Name}/{Album Title}/{track number} - {track title}` |

**Settings → Metadata:**

- Включите **Last.fm** (используйте те же API-ключи, что в `.env`)

### 6. Настроить Lidarr YouTube Downloader (веб-UI)

1. Откройте **http://<ваш-ip>:5005**
2. Основные настройки уже заданы через переменные окружения
3. В **Settings** (веб-UI) можно настроить:
   - Формат аудио (MP3/M4A/Opus)
   - Параллельные загрузки (1–5)
   - Порог совпадения (match score)
   - Запрещённые слова (remix, live, cover, karaoke…)
   - Автозагрузку по расписанию (scheduler)
   - Уведомления (Telegram / Discord)

**Рекомендация:** включите **Lidarr Download Client** режим (Settings → Lidarr Download Client → Enable). Это зарегистрирует загрузчик как нативный индексер + download client внутри Lidarr — тогда Lidarr сам будет инициировать поиск и импорт.

### 7. Добавить артистов в Lidarr

1. Перейдите в **Artists → Add New**
2. Найдите артиста, нажмите **Add**
3. Включите **«Monitor All Albums»**
4. Lidarr YouTube Downloader автоматически найдёт и скачает недостающие альбомы с YouTube

### 8. Настроить Navidrome

1. Откройте **http://<ваш-ip>:4533**
2. Создайте аккаунт администратора
3. **Settings → Settings**:
   - Папка музыки: `/music` (уже прописана)
4. **Settings → User Profile → Integrations**:
   - Введите логин/пароль **Last.fm** для скробблинга
5. Нажмите **Scan** — музыка из `/data/music` появится в интерфейсе

### 9. Настроить Music Assistant

1. Откройте **http://<ваш-ip>:8095**
2. Пройдите первичную настройку
3. **Music Providers → Add Provider**:
   - Тип: **Subsonic / Navidrome**
   - URL: `http://navidrome:4533` (внутренняя сеть Docker!)
   - Логин/пароль администратора Navidrome
4. **Metadata Providers**:
   - Включите **LastFM Recommendations**
   - Включите **LastFM Scrobbler**
   - Введите Last.fm API-ключи

### 10. Использовать MeTube (ручная загрузка)

1. Откройте **http://<ваш-ip>:8081**
2. Вставьте ссылку на YouTube-видео / плейлист
3. В выпадающем списке выберите **Audio → mp3** (или другой формат)
4. Файл сохранится в `data/downloads/metube/`
5. **Важно:** файлы из MeTube **не имеют** правильных ID3-тегов.
   - Переместите вручную: `data/downloads/metube/файл.mp3` → `data/music/Artist/Album/01 - Track.mp3`
   - Или используйте скрипт `config/downloader-scripts/metube-organize.sh` (см. ниже)

---

## 🔗 Интеграция модулей (как всё работает вместе)

### Цепочка автоматической загрузки

```
Lidarr (база артистов/альбомов, мониторинг)
  │
  │ API: /wanted/missing → «У артиста X не хватает альбома Y»
  ▼
Lidarr YouTube Downloader (:5005)
  │
  │ 1. Sync — забирает missing-треки из Lidarr API
  │ 2. Search — ищет до 15 кандидатов на YouTube через yt-dlp
  │ 3. Score — ранжирует по совпадению названия (50%), длительности (25%),
  │    официальный канал (15%), просмотры; фильтрует remix/live/cover
  │ 4. Verify — (опц.) AcoustID fingerprint через fpcalc
  │ 5. Tag — Mutagen пишет ID3 (title, artist, album, year, MusicBrainz IDs)
  │    + встраивает обложку 3000×3000 из iTunes
  │ 6. Import — копирует в /data/music, вызывает Lidarr RefreshArtist
  ▼
/data/music/Artist/Album/  (готовый трек с тегами и обложкой)
  │
  │ Navidrome сканирует и добавляет в каталог
  ▼
Веб-интерфейс Navidrome / мобильные клиенты (Subsonic API)
```

### Альтернативный режим: Lidarr Download Client

Вместо того чтобы загрузчик сам пушел файлы, его можно зарегистрировать **внутри Lidarr** как нативный индексер + SABnzbd download client. Тогда Lidarr сам инициирует поиск, grabs и импорт.

**Настройка:**

1. В **Lidarr YT Downloader → Settings → Lidarr Download Client**: включить, сгенерировать API-ключ
2. В **Lidarr → Settings → Indexers → + → Newznab (custom)**:
   - URL: `http://lidarr-yt:5000`
   - API Path: `/api/newznab/api`
   - API Key: сгенерированный ключ
3. В **Lidarr → Settings → Download Clients → + → SABnzbd**:
   - Host: `lidarr-yt`, Port: `5000`
   - URL Base: `/api/sabnzbd`
   - API Key: тот же ключ
   - Category: `music`
4. В **Lidarr → Settings → Media Management**: включить **Completed Download Handling**

### Цепочка скробблинга и рекомендаций

```
Пользователь слушает трек в Navidrome
  │
  ├─→ Last.fm (скроббл: «прослушал Artist — Track»)
  │     └─→ Music Assistant читает историю ←→ выдаёт «Похожие артисты»
  │
  └─→ Music Assistant (через Subsonic API) ←→ показывает статистику
```

### Ручная загрузка через MeTube

```
Пользователь вставляет YouTube-ссылку в MeTube
  │
  ▼
/data/downloads/metube/файл.mp3  (без тегов)
  │
  ├─ Ручной перенос + тегирование (mp3tag, kid3, etc.)
  └─ Автоматический: metube-organize.sh → /data/music/_Unsorted/
      ▼
  Navidrome подхватит при следующем сканировании
```

---

## 🔧 Дополнительно

### Скрипт организации MeTube-загрузок

`config/downloader-scripts/metube-organize.sh` перемещает файлы из MeTube в `_Unsorted`:

```bash
# Разовый запуск
bash config/downloader-scripts/metube-organize.sh

# Через cron (каждые 5 минут)
crontab -e
# */5 * * * * /srv/music-stack/config/downloader-scripts/metube-organize.sh
```

### YouTube cookies (рекомендуется для загрузчика)

Если YouTube возвращает «Sign in to confirm you're not a bot»:

1. Установите расширение **Get cookies.txt LOCALLY**
2. Откройте приватное окно, войдите в **одноразовый** Google-аккаунт
3. Экспортируйте cookies в Netscape-формате как `cookies.txt`
4. Добавьте в docker-compose.yml:
   ```yaml
   volumes:
     - ./cookies.txt:/cookies/cookies.txt
   environment:
     - YT_COOKIES_FILE=/cookies/cookies.txt
   ```

---

## 📊 Порты

| Сервис | Порт | Назначение |
|---|---|---|
| Navidrome | 4533 | Веб-плеер + Subsonic API |
| Music Assistant | 8095 | Рекомендации и оркестрация |
| Lidarr | 8686 | Управление библиотекой |
| Lidarr YT Downloader | 5005 | Веб-UI загрузчика + управление |
| MeTube | 8081 | Ручной загрузчик YouTube |

---

## ⚠️ Ограничения

1. **Качество аудио с YouTube** — до 256 kbps (AAC/Opus), не FLAC.
2. **Точность поиска** — загрузчик скорирует до 15 кандидатов, но может скачать кавер вместо оригинала.
3. **MeTube файлы** — не имеют ID3-тегов; требуется ручная обработка или скрипт.
4. **YouTube ограничения** — при частых запросах может потребоваться cookies-файл (см. выше).

---

## 🛠 Полезные команды

```bash
# Посмотреть логи
docker compose logs -f navidrome
docker compose logs -f lidarr-yt

# Перезапуск конкретного сервиса
docker compose restart lidarr-youtube-downloader

# Обновить все образы и перезапустить
docker compose pull && docker compose up -d

# Принудительное сканирование Navidrome (через API)
curl -X POST http://localhost:4533/api/scan?subsonic_salt=x&subsonic_token=y
```
