FROM node:22-alpine

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
