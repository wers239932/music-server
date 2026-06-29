FROM python:3.12-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg git && \
    pip install --no-cache-dir yt-dlp && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Установка lidarr-youtube-downloader из популярного форка
RUN pip install --no-cache-dir \
    git+https://github.com/N4TH4N088/lidarr-youtube-downloader.git@main

# git больше не нужен в runtime
RUN apt-get purge -y --auto-remove git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENTRYPOINT ["lidarr-youtube-downloader"]
