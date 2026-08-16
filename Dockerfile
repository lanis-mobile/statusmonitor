FROM node:22-alpine AS frontend
WORKDIR /app/frontend
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

FROM dart:stable AS backend
RUN apt-get update \
  && apt-get install -y --no-install-recommends libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY bin/ bin/
COPY lib/ lib/
RUN dart pub get --offline
RUN dart build cli --target=bin/server.dart -o /tmp/build

FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends libsqlite3-0 ca-certificates \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=backend /tmp/build/bundle/bin/server /app/bin/server
COPY --from=backend /tmp/build/bundle/lib/ /app/lib/
COPY --from=frontend /app/frontend/dist /app/frontend/dist
RUN mkdir -p /data && chown nobody:nogroup /data
ENV STATUSMONITOR_STATIC_DIR=/app/frontend/dist
ENV DATABASE_PATH=/data/status.db
ENV PORT=8080
EXPOSE 8080
VOLUME /data
USER nobody
CMD ["/app/bin/server"]
