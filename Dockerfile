FROM node:20-alpine3.19 AS builder

ARG NODE_ENV=production

WORKDIR /misskey

RUN apk add --no-cache ca-certificates git alpine-sdk g++ build-base cmake clang libressl-dev vips-dev python3

COPY .npmrc .yarnrc package.json yarn.lock ./
COPY assets/ ./assets/
COPY locales/ ./locales/
COPY scripts/ ./scripts/
COPY packages/ ./packages/
RUN yarn install && yarn build

FROM node:20-alpine3.19 AS runner

ARG UID="991"
ARG GID="991"

RUN apk add --no-cache ca-certificates tini curl vips vips-cpp \
	&& addgroup -g "${GID}" misskey \
	&& adduser -u "${UID}" -G misskey -D -h /misskey misskey

USER misskey
WORKDIR /misskey

COPY --chown=misskey:misskey --from=builder /misskey/built ./built
COPY --chown=misskey:misskey --from=builder /misskey/packages/backend/node_modules ./packages/backend/node_modules
COPY --chown=misskey:misskey --from=builder /misskey/packages/backend/built ./packages/backend/built
COPY --chown=misskey:misskey docker-entrypoint.sh ./
COPY --chown=misskey:misskey packages/backend/assets packages/backend/assets
COPY --chown=misskey:misskey packages/backend/migration packages/backend/migration
COPY --chown=misskey:misskey packages/backend/ormconfig.js packages/backend/package.json ./packages/backend

ENV NODE_ENV=production
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./docker-entrypoint.sh"]
