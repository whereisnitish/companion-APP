# Multi-stage: compile with dev dependencies, ship without them.
FROM node:22-alpine AS builder

WORKDIR /app
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json tsconfig.build.json ./
COPY src ./src
RUN npm run build

# ---------------------------------------------------------------- runtime
FROM node:22-alpine AS runtime

WORKDIR /app
ENV NODE_ENV=production
RUN apk add --no-cache openssl

COPY package*.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=builder /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=builder /app/dist ./dist
COPY prisma ./prisma

# Run unprivileged.
USER node

EXPOSE 4000
# Apply migrations before serving, so a new deploy or a fresh database just works.
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
