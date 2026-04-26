# syntax=docker.io/docker/dockerfile:1@sha256:2780b5c3bab67f1f76c781860de469442999ed1a0d7992a5efdf2cffc0e3d769

# Stage 1: Base image for dependencies and build
FROM denoland/deno:2.7.13@sha256:acf662cf877e9069f1bfc90156354b870a19ec022c85d93220499341991aaf1b AS base

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
FROM nginx:1.30.0-alpine-slim@sha256:2fb5d772cea6ef1a8dab525df1b9485289eee167d26af9613fce27a12c060caa AS runner

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
