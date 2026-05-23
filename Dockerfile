# syntax=docker/dockerfile:1

# ============================
# ЭТАП 1: СБОРКА
# ============================
FROM node:24-alpine AS builder

# Системные зависимости для компиляции native-модулей
RUN apk add --no-cache git python3 make g++ gcc libc6-compat

WORKDIR /app

# Клонируем проект
RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

# 🔑 КРИТИЧЕСКИ: задаём DATABASE_URL ДО npm install
# Это нужно для prisma generate в postinstall скрипте
ENV DATABASE_URL="file:/tmp/dev.db"

# 🔑 Устанавливаем зависимости БЕЗ --ignore-scripts
# better-sqlite3 скомпилируется автоматически
RUN npm install --legacy-peer-deps

# Явно генерируем Prisma клиент (на всякий случай)
RUN npx prisma generate

# Собираем Next.js
RUN npm run build


# ============================
# ЭТАП 2: ПРОДАКШЕН
# ============================
FROM node:24-alpine AS runner

RUN apk add --no-cache libc6-compat

WORKDIR /app

# 🔑 ВСЕ необходимые переменные окружения
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV DATABASE_URL=file:/app/data/prod.db
ENV NEXTAUTH_URL=https://ogsc.bigseoonline.com

# Создаём пользователя для безопасности
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Копируем собранное приложение
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma

# Создаём папку для БД и назначаем права
RUN mkdir -p /app/data && chown -R nextjs:nodejs /app/data

# Переключаемся на непривилегированного пользователя
USER nextjs

EXPOSE 3000

# 🔑 Запускаем приложение
CMD ["npx", "next", "start", "-H", "0.0.0.0", "-p", "3000"]
