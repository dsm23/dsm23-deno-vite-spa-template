# syntax=docker.io/docker/dockerfile:1@sha256:4a43a54dd1fedceb30ba47e76cfcf2b47304f4161c0caeac2db1c61804ea3c91

# Stage 1: Base image for dependencies and build
FROM denoland/deno:alpine-2.7.8@sha256:2f346431e89e8b92e9fb70883f218cd6afef5170509cfe348c9729478df7e327 AS base

# Install dependencies only when needed
FROM base AS deps
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
FROM nginx:1.29.7-alpine-slim@sha256:0848ca84c476868cbeb6a5c2c009a98821b8540f96c44b1ba06820db50262e35 AS runner

# Copy built static files to nginx's default public folder
COPY --from=builder /app/dist /usr/share/nginx/html
COPY --from=builder /app/nginx/nginx.conf /etc/nginx/templates/default.conf.template

# implement changes required to run NGINX as an unprivileged user
RUN sed -i '/user  nginx;/d' /etc/nginx/nginx.conf \
  && sed -i 's,\(/var\)\{0\,1\}/run/nginx.pid,/tmp/nginx.pid,' /etc/nginx/nginx.conf \
  # nginx user must own the cache and etc directory to write cache and tweak the nginx config
  && chown -R nginx /var/cache/nginx \
  && chmod -R g+w /var/cache/nginx \
  && chown -R nginx /etc/nginx \
  && chmod -R g+w /etc/nginx

USER nginx

# ENTRYPOINT [ "20-envsubst-on-templates.sh" ]

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
