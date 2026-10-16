# ---- stage 1: build the static bundle --------------------------------------
FROM node:22-alpine AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html vite.config.js ./
COPY src ./src
RUN npm run build

# ---- stage 2: serve it with an unprivileged nginx ---------------------------
FROM nginxinc/nginx-unprivileged:1.29-alpine
# Pipeline run 1 was stopped by Trivy: the 1.27 tag's alpine 3.21 packages had 42 fixable HIGH/CRITICAL
# CVEs (openssl, musl, zlib...). Newer tag + apply the distro's security updates at build time.
USER root
RUN apk upgrade --no-cache
USER 101
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
# The base image already sets USER 101 and listens on 8080.
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/ >/dev/null || exit 1
