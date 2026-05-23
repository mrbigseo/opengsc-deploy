# syntax=docker/dockerfile:1

FROM node:22-alpine AS builder

RUN apk add --no-cache git python3 make g++ gcc libc6-compat openssl

WORKDIR /app

RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

ENV DATABASE_URL="file:/tmp/dev.db"
ENV NEXTAUTH_URL="http://localhost:3000"

RUN npm install --legacy-peer-deps
RUN npx prisma generate
RUN npm run build


FROM node:22-alpine AS runner

RUN apk add --no-cache libc6-compat openssl

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV DATABASE_URL="file:/app/data/prod.db"
ENV NEXTAUTH_URL="https://ogsc.bigseoonline.com"

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts

RUN mkdir -p /app/data

EXPOSE 3000

# Исправленная команда запуска
CMD ["sh", "-c", "npx prisma db push --accept-data-loss && npx next start -H 0.0.0.0 -p 3000"]
