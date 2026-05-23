# syntax=docker/dockerfile:1
FROM node:24-alpine AS builder

RUN apk add --no-cache git python3 make g++ gcc libc6-compat

WORKDIR /app
RUN git clone --depth 1 https://github.com/fenjo26/opengsc.git .

RUN npm install --ignore-scripts --legacy-peer-deps

ENV DATABASE_URL="file:/tmp/dev.db"
RUN npx prisma generate

RUN npm run build

FROM node:24-alpine AS runner
RUN apk add --no-cache libc6-compat
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000
ENV DATABASE_URL=file:/app/data/prod.db

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma

RUN mkdir -p /app/data && chown -R nextjs:nodejs /app/data

# 🔑 Создаём правильный prisma.config.ts
RUN echo 'import { defineConfig } from "prisma/config";\n\nexport default defineConfig({\n  datasource: {\n    url: process.env.DATABASE_URL,\n  },\n});' > /app/prisma.config.ts

USER nextjs
EXPOSE 3000

CMD ["sh", "-c", "npx prisma migrate deploy && npm start"]
