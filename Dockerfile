###################
### Build npmrun
###################

FROM rust:1-alpine AS npmrun-builder
WORKDIR /src

RUN apk add --no-cache git alpine-sdk

RUN git clone https://github.com/nexryai/npmrun.git .
RUN cargo build --release

###################
### Build app
###################

FROM node:24.7-alpine3.22 AS builder
WORKDIR /misskey

COPY .npmrc .yarnrc package.json yarn.lock ./
COPY locales/ ./locales/
COPY scripts/ ./scripts/
COPY packages/ ./packages/

RUN apk add --no-cache ca-certificates git alpine-sdk g++ build-base cmake clang vips-dev python3
RUN yarn install
RUN yarn build

RUN cd packages/backend && yarn install --production

###################
### Build runner
###################

FROM node:24.7-alpine3.22 AS runner

ARG UID="991"
ARG GID="991"

RUN apk add --no-cache ca-certificates tini curl vips vips-cpp \
	&& addgroup -g "${GID}" misskey \
	&& adduser -u "${UID}" -G misskey -D -h /misskey misskey

# Add pm2 for managing a node process
RUN npm install pm2 -g

RUN mkdir -p /var/log/misskey && chown misskey:misskey /var/log/misskey

USER misskey
WORKDIR /misskey

# Logrotate
RUN pm2 install pm2-logrotate \
  && pm2 set pm2-logrotate:max_size 10M \
  && pm2 set pm2-logrotate:retain 10 \
  && pm2 set pm2-logrotate:dateFormat YYYY-MM-DD \
  && pm2 set pm2-logrotate:rotateInterval "0 0 * * 0"

COPY --chown=misskey:misskey --from=builder /misskey/built ./built
COPY --chown=misskey:misskey --from=builder /misskey/packages/backend/node_modules ./packages/backend/node_modules
COPY --chown=misskey:misskey --from=builder /misskey/packages/backend/built ./packages/backend/built
COPY --chown=misskey:misskey package.json pm2-config.json ./
COPY --chown=misskey:misskey packages/backend/assets packages/backend/assets
COPY --chown=misskey:misskey packages/backend/migration packages/backend/migration
COPY --chown=misskey:misskey packages/backend/ormconfig.js packages/backend/package.json ./packages/backend

COPY --from=npmrun-builder /src/target/release/npmrun /usr/local/bin/npmrun

ENV NODE_ENV=production
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["npmrun", "docker:start"]
