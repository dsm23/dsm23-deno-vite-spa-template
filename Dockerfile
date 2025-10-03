# syntax=docker.io/docker/dockerfile:1@sha256:dabfc0969b935b2080555ace70ee69a5261af8a8f1b4df97b9e7fbcf6722eddf

# Stage 1: Base image for dependencies and build
FROM denoland/deno:alpine-2.5.3@sha256:02906830d9ae490e12001624fd4fcb3dbf949cfde89ce5ee021259836cde88c8 AS base

# Install dependencies only when needed
FROM base AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
# RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package manager lock files
COPY deno.json deno.lock ./

# Install dependencies
RUN deno install --frozen

# Stage 2: Build stage
FROM base AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build the Vite project
RUN deno task build

# Stage 3: Production image
FROM nginx:1.27.3-alpine3.20-slim@sha256:5a56ae385906c5b43ccc99379bce883aa93dc0556d7f705ba501d819925e8fa1 AS runner

# Copy built static files to nginx's default public folder
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=builder /app/nginx/nginx.conf /etc/nginx/templates/default.conf.template

# implement changes required to run NGINX as an unprivileged user
RUN sed -i '/user  nginx;/d' /etc/nginx/nginx.conf \
    && sed -i 's,/var/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
# nginx user must own the cache and etc directory to write cache and tweak the nginx config
    && chown -R nginx /var/cache/nginx \
    && chmod -R g+w /var/cache/nginx \
    && chown -R nginx /etc/nginx \
    && chmod -R g+w /etc/nginx \
# change the placeholder js file in html
    && chown -R nginx /usr/share/nginx/html

USER nginx

# ENTRYPOINT [ "20-envsubst-on-templates.sh" ]

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
