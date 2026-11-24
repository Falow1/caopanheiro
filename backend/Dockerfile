# Servidor do backend da branch dev-banco-fly na Fly.io (docs/DEVOPS.md).
# Só as dependências de produção do lockfile; os scripts de instalação ficam
# desligados, como na instalação local.
FROM node:24.22.1-slim
ENV NODE_ENV=production COREPACK_ENABLE_DOWNLOAD_PROMPT=0
WORKDIR /app
COPY package.json pnpm-lock.yaml ./
RUN corepack enable \
  && pnpm install --prod --frozen-lockfile --ignore-scripts --store-dir /tmp/pnpm-store \
  && rm -rf /tmp/pnpm-store /root/.cache
COPY src ./src
COPY server ./server
USER node
EXPOSE 8080
CMD ["node", "server/main.js"]
