# dola-pool Docker 镜像：包含 Patchright Chromium 和虚拟显示器，支持浏览器加号。
# 数据（账号、数据库、成片、参考图）全部在 /data，挂成数据卷，升级镜像不丢。
FROM python:3.12-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8000 \
    DOLA_DB_PATH=/data/tasks.db \
    DOLA_POOL_DB_PATH=/data/pool_usage.db \
    DOLA_DOWNLOAD_DIR=/data/downloads \
    DOLA_REFERENCE_FILE_DIR=/data/refs \
    DOLA_THUMB_DIR=/data/thumbs \
    DOLA_PURE_API=1

# node：bdms 签名器（需 16+，bookworm 自带 18）；ffmpeg：成片转码 / ffprobe 复核时长
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs ffmpeg ca-certificates curl libglib2.0-0 xvfb xauth \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt deploy-extra-requirements.txt ./
RUN pip install -r requirements.txt -r deploy-extra-requirements.txt \
    && patchright install --with-deps chromium \
    && xvfb-run -a python -c "from patchright.sync_api import sync_playwright; p=sync_playwright().start(); b=p.chromium.launch(headless=False, args=['--no-sandbox']); page=b.new_page(); page.goto('data:text/html,ok'); assert page.title() == ''; b.close(); p.stop()" \
    && rm -rf /var/lib/apt/lists/*

COPY . .
RUN chmod +x docker/entrypoint.sh

EXPOSE 8000
VOLUME ["/data"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1
ENTRYPOINT ["/app/docker/entrypoint.sh"]
