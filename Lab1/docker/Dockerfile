FROM node:22-bookworm AS builder

WORKDIR /app

COPY mywebapp/package*.json mywebapp/pnpm-lock.yaml* ./

RUN npm install -g pnpm

RUN pnpm install --frozen-lockfile

RUN npm install -g prisma@6.19.2

COPY mywebapp/prisma ./prisma

RUN npx prisma generate

COPY mywebapp/src ./src
COPY mywebapp/tsconfig*.json mywebapp/nest-cli.json ./

RUN pnpm run build

FROM node:22-alpine

RUN addgroup -g 1001 -S nodejs && \
  adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

COPY --from=builder /app/package*.json /app/pnpm-lock.yaml* ./

RUN npm install -g pnpm

RUN pnpm install --prod --frozen-lockfile
RUN pnpm add prisma@6.19.2 @prisma/client@6.19.2

COPY --from=builder /app/dist ./dist
COPY mywebapp/prisma ./prisma

USER root
RUN apk add --no-cache openssl wget

RUN chown -R nodejs:nodejs /app

USER nodejs

EXPOSE 5200

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=5 \
  CMD node -e "require('http').get('http://localhost:5200/health/alive', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); })"

CMD ["sh", "-c", "npx prisma generate && npx prisma db push && node dist/src/main.js"]