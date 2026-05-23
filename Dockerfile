# syntax=docker/dockerfile:1

FROM node:24-alpine AS builder

RUN apk add --no-cache git python3 make g++ gcc libc6-compat

WORKDIR /app
RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

# 🔑 1. Сначала задаём DATABASE_URL для Prisma
ENV DATABASE_URL="file:/tmp/dev.db"

# 🔑 2. Игнорируем скрипты при установке, чтобы избежать раннего prisma generate
RUN npm install --ignore-scripts --legacy-peer-deps

# 🔑 3. Явно запускаем prisma generate с уже заданной DATABASE_URL
RUN npx prisma generate

RUN npm run build


FROM node:24-alpine AS runner

RUN apk add --no-cache libc6-compat

WORKDIR /app

# 🔑 КРИТИЧЕСКИ ВАЖНЫЕ ПЕРЕМЕННЫЕ
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV DATABASE_URL=file:/app/data/prod.db
ENV NEXTAUTH_URL=https://ogsc.bigseoonline.com

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

CMD ["npx", "next", "start", "-H", "0.0.0.0", "-p", "3000"]
