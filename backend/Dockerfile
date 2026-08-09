FROM node:22-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-alpine AS runtime

ENV NODE_ENV=production
WORKDIR /app

RUN addgroup -S flourtrack && adduser -S flourtrack -G flourtrack

COPY package*.json ./
RUN npm install --omit=dev && npm cache clean --force

COPY --from=build /app/dist ./dist

USER flourtrack
EXPOSE 8080

CMD ["node", "dist/server.js"]
