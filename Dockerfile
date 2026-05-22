# syntax=docker/dockerfile:1
FROM node:24-alpine AS builder

# Системные зависимости для native-модулей
RUN apk add --no-cache git python3 make g++ gcc libc6-compat

WORKDIR /app
# Клонируем оригинальный проект прямо во время сборки
RUN git clone https://github.com/fenjo26/opengsc.git .

# Установка и сборка
RUN npm ci --ignore-scripts
RUN npx prisma generate
RUN npm run build

# Финальный образ
FROM node:24-alpine AS runner
RUN apk add --no-cache libc6-compat
WORKDIR /app
ENV NODE_ENV=production PORT=3000

# Безопасность: запускаем от непривилегированного пользователя
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# Копируем собранное приложение
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma

# Папка для SQLite
RUN mkdir -p /app/data && chown -R nextjs:nodejs /app/data

USER nextjs
EXPOSE 3000
CMD ["sh", "-c", "npx prisma migrate deploy && npm start"]
