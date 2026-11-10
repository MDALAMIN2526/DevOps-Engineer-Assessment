# syntax=docker/dockerfile:1.7

# ------------------------------------------------------------------------------
# Stage 1: Build the static Go binary
# ------------------------------------------------------------------------------
FROM golang:1.23.6-alpine3.21 AS builder

# Create unprivileged non-root user (UID/GID 10001)
RUN addgroup -g 10001 -S appuser && \
    adduser -u 10001 -S -G appuser -h /home/appuser -s /sbin/nologin appuser

WORKDIR /src

# Leverage Docker layer caching for Go modules
COPY app/go.mod app/go.sum ./
RUN go mod download && go mod verify

# Copy application source code
COPY app/ ./

# Build static binary with compiler optimizations and symbol stripping
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -trimpath \
    -ldflags="-s -w -extldflags '-static'" \
    -o /bin/app \
    ./cmd/server

# ------------------------------------------------------------------------------
# Stage 2: Minimal hardened production runtime image
# ------------------------------------------------------------------------------
FROM alpine:3.21.3

# Install ca-certificates and tzdata
# hadolint ignore=DL3018
RUN apk add --no-cache ca-certificates tzdata

# Copy non-root user credentials from builder
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group

# Copy compiled static binary
COPY --from=builder /bin/app /bin/app

# OCI standard container annotations
LABEL org.opencontainers.image.title="devops-assessment-service" \
      org.opencontainers.image.description="Production-grade cloud-native web service with Prometheus metrics and structured logging" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="MD. AL-AMIN <amin252646@gmail.com>" \
      org.opencontainers.image.source="https://github.com/MDALAMIN2526/DevOps-Engineer-Assessment" \
      org.opencontainers.image.licenses="MIT"

# Default runtime configuration
ENV PORT=8080 \
    LOG_LEVEL=INFO \
    ENVIRONMENT=production \
    APP_VERSION=1.0.0

# Expose standard application port
EXPOSE 8080

# Enforce non-root execution
USER 10001:10001

# Healthcheck for container liveness and readiness
HEALTHCHECK --interval=15s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:8080/health || exit 1

ENTRYPOINT ["/bin/app"]
