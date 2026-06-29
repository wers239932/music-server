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
                                          │ «нужны треки»
                                          ▼
                               ┌──────────────────────┐
                               │  Lidarr YT Downloader│
                               │  (angrido/...)       │
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
│   └── metube/
└── data/                         # медиаконтент (gitignored)
    ├── downloads/
    │   ├── metube/                # сырые загрузки из MeTube
    │   └── lidarr-yt/             # сырые загрузки из Lidarr YT Downloader
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
mkdir -p config/{navidrome,music-assistant,lidarr,metube,downloader-scripts} \
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

1. Откройте **http://\<ваш-ip\>:8686**
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

### 6. Добавить артистов в Lidarr

1. Перейдите в **Artists → Add New**
2. Найдите артиста, нажмите **Add**
3. Включите **«Monitor All Albums»**
4. Lidarr YT Downloader автоматически найдёт и скачает недостающие альбомы с YouTube

### 7. Настроить Navidrome

1. Откройте **http://\<ваш-ip\>:4533**
2. Создайте аккаунт администратора
3. **Settings → Settings**:
   - Папка музыки: `/music` (уже прописана)
4. **Settings → User Profile → Integrations**:
   - Введите логин/пароль **Last.fm** для скробблинга
5. Нажмите **Scan** — музыка из `/data/music` появится в интерфейсе

### 8. Настроить Music Assistant

1. Откройте **http://\<ваш-ip\>:8095**
2. Пройдите первичную настройку
3. **Music Providers → Add Provider**:
   - Тип: **Subsonic / Navidrome**
   - URL: `http://navidrome:4533` (внутренняя сеть Docker!)
   - Логин/пароль администратора Navidrome
4. **Metadata Providers**:
   - Включите **LastFM Recommendations**
   - Включите **LastFM Scrobbler**
   - Введите Last.fm API-ключи

### 9. Использовать MeTube (ручная загрузка)

1. Откройте **http://\<ваш-ip\>:8081**
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
Lidarr (база артистов/альбомов)
  │
  │ «У этого артиста не хватает альбома X»
  ▼
Lidarr YouTube Downloader
  │
  │ Ищет на YouTube → Скачивает аудио → Назначает ID3-теги (MusicBrainz)
  ▼
/data/downloads/lidarr-yt/  (сырой файл)
  │
  │ Lidarr подхватывает, переименовывает, проставляет обложку
  ▼
/data/music/Artist/Album/  (готовый трек в библиотеке)
  │
  │ Navidrome сканирует и добавляет в каталог
  ▼
Веб-интерфейс Navidrome / мобильные клиенты
```

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
  └─ Автоматический: metube-organize.sh (см. ниже)
      ▼
/data/music/_Unsorted/  (или в правильную структуру)
      ▼
  Navidrome подхватит при следующем сканировании
```

---

## 🔧 Дополнительно: скрипт организации MeTube-загрузок

Скрипт `config/downloader-scripts/metube-organize.sh` мониторит папку MeTube и перемещает файлы в `_Unsorted`:

```bash
# Запуск (в фоне)
bash config/downloader-scripts/metube-organize.sh &

# Или через cron (каждые 5 минут)
crontab -e
# Добавить: */5 * * * * /srv/music-stack/config/downloader-scripts/metube-organize.sh
```

---

## 📊 Порты

| Сервис | Порт | Назначение |
|---|---|---|
| Navidrome | 4533 | Веб-плеер + Subsonic API |
| Music Assistant | 8095 | Рекомендации и оркестрация |
| Lidarr | 8686 | Управление библиотекой |
| MeTube | 8081 | Ручной загрузчик YouTube |

---

## ⚠️ Ограничения

1. **Качество аудио с YouTube** — до 256 kbps (AAC/Opus), не FLAC. Для аудиофилов рекомендуется использовать другие источники.
2. **Точность поиска** — Lidarr YT Downloader может скачать кавер вместо оригинала.
3. **MeTube файлы** — не имеют ID3-тегов; требуется ручная обработка или скрипт.
4. **Lidarr YT Downloader** — образ `angrido/lidarr-youtube-downloader` может быть недоступен; в этом случае соберите из исходников (см. комментарии в docker-compose.yml).

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
