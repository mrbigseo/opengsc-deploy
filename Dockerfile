# syntax=docker/dockerfile:1

# ============================
# ЭТАП 1: СБОРКА (builder)
# ============================
FROM node:24-alpine AS builder

# Системные зависимости для native-модулей (better-sqlite3)
RUN apk add --no-cache git python3 make g++ gcc libc6-compat

WORKDIR /app

# Клонируем оригинальный проект (только последняя версия для скорости)
RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

# Установка зависимостей (игнорируем postinstall скрипты)
RUN npm install --ignore-scripts --legacy-peer-deps

# Генерация Prisma Client (используем временную БД для сборки)
ENV DATABASE_URL="file:/tmp/dev.db"
RUN npx prisma generate

# Сборка Next.js приложения
RUN npm run build


# ============================
# ЭТАП 2: ПРОДАКШЕН (runner)
# ============================
FROM node:24-alpine AS runner

RUN apk add --no-cache libc6-compat

WORKDIR /app

# 🔑 КРИТИЧЕСКИ ВАЖНЫЕ ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV DATABASE_URL=file:/app/data/prod.db

# Создаём пользователя для безопасности (не запускать от root)
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Копируем собранное приложение из builder-этапа
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma

# Создаём папку для SQLite и назначаем права
RUN mkdir -p /app/data && chown -R nextjs:nodejs /app/data

# 🔑 Создаём prisma.config.ts (через printf для совместимости)
RUN printf 'import { defineConfig } from "prisma/config";\n\nexport default defineConfig({\n  datasource: {\n    url: process.env.DATABASE_URL,\n  },\n});\n' > /app/prisma.config.ts

# Переключаемся на непривилегированного пользователя
USER nextjs

EXPOSE 3000

# 🔑 Запуск приложения (Prisma применит миграции автоматически при старте)
CMD ["npm", "start"]
