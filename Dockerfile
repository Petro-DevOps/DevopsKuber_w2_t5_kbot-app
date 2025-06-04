# ===== Stage 1: Build stage =====
FROM --platform=$BUILDPLATFORM golang:latest AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    curl \
    ca-certificates \
    build-essential \
    && rm -rf /var/lib/apt/lists/*


ARG TARGETOS
ARG TARGETARCH
ARG VERSION


ENV GOPATH=/go
ENV PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

WORKDIR /go/src/app

COPY . .
##RUN apk --no-cache add ca-certificates
### RUN go mod tidy && go mod download

RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -v -o kbot-app -ldflags "-X=github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}"


# ---------- Final stage: Linux with certs ----------
FROM scratch AS final-linux
WORKDIR /app

COPY --from=builder /go/src/app/kbot-app /app/kbot-app
COPY --from=alpine:latest /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
LABEL org.opencontainers.image.source="https://github.com/petro-devops/kbot-app"

ENTRYPOINT ["/app/kbot-app"]


# ---------- Final stage: Windows/macOS (no certs needed) ----------
FROM scratch AS final

WORKDIR /app

COPY --from=builder /go/src/app/kbot-app /app/kbot-app

LABEL org.opencontainers.image.source="https://github.com/petro-devops/kbot-app"

ENTRYPOINT ["/app/kbot-app"]