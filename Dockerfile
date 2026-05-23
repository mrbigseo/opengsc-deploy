# syntax=docker/dockerfile:1

# ============================
# ЭТАП 1: СБОРКА
# ============================
# ИЗМЕНЕНО: node:22-alpine (вместо 20), так как проект требует Node >= 22
FROM node:22-alpine AS builder

# Системные зависимости
RUN apk add --no-cache git python3 make g++ gcc libc6-compat openssl

WORKDIR /app

# Клонируем проект
RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

# Задаём переменные для сборки
ENV DATABASE_URL="file:/tmp/dev.db"
ENV NEXTAUTH_URL="http://localhost:3000"

# Устанавливаем зависимости
RUN npm install --legacy-peer-deps

# Генерируем Prisma клиент
RUN npx prisma generate

# Собираем Next.js
RUN npm run build


# ============================
# ЭТАП 2: ПРОДАКШЕН
# ============================
# ИЗМЕНЕНО: node:22-alpine
FROM node:22-alpine AS runner

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV DATABASE_URL="file:/app/data/prod.db"
# Замените на свой домен
ENV NEXTAUTH_URL="https://ogsc.bigseoonline.com"

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma

RUN mkdir -p /app/data && chown -R nextjs:nodejs /app/data

USER nextjs

EXPOSE 3000

# Команда запуска с миграцией
CMD npx prisma migrate deploy && npx next start -H 0.0.0.0 -p 3000
