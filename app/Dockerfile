# Digest fijado para que el build sea reproducible.
FROM node:22-alpine@sha256:1314fb30ec37592d5845e5a160d522c0e680972aa534549940b8d73bde88481a

ARG AUDIT_BUILD_MARKER=FLAG{huella_en_la_imagen}
LABEL org.audithub.build-marker="${AUDIT_BUILD_MARKER}"

ENV NODE_ENV=production

WORKDIR /app

COPY --chown=node:node package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=node:node server.js ./
COPY --chown=node:node public ./public

USER node

EXPOSE 3000

CMD ["node", "server.js"]
