# ===== Stage 1: Build stage =====
FROM --platform=$BUILDPLATFORM golang:latest AS builder

# Build-time arguments
ARG TARGETPLATFORM
ARG VERSION=dev-test-001

# Print platform
RUN echo "Building for platform: $TARGETPLATFORM"
RUN echo "App version: $VERSION"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git build-essential curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /go/src/app

# Copy source code
COPY . .

# Run gofmt, get modules, and build
RUN gofmt -s -w ./ && \
    go mod tidy && \
    go get && \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -v -o kbot-app -ldflags "-X=github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}"


# ---------- Final stage: Linux with certs ----------
FROM scratch AS final-linux
WORKDIR /app

COPY --from=builder /go/src/app/kbot-app /app/kbot-app
COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
#LABEL org.opencontainers.image.source="https://github.com/petro-devops/kbot-app"

ENTRYPOINT ["/app/kbot-app"]


# ---------- Final stage: Windows/macOS (no certs needed) ----------
FROM scratch AS final

WORKDIR /app

COPY --from=builder /go/src/app/kbot-app /app/kbot-app

#LABEL org.opencontainers.image.source="https://github.com/petro-devops/kbot-app"

ENTRYPOINT ["/app/kbot-app"]