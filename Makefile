APP=$(shell basename -s .git $(shell git remote get-url origin))
REGISTRY=ghcr.io/petro-devops/kbot-app
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
BUILD_DIR = builds

# Variables for manual build
#GOOS ?= 
#GOARCH ?= 

# Load platform values if they exist
#-include .platform_env

# Fallback-safe way to get host OS and Arch
UNAME_S := $(shell uname -s 2>/dev/null || echo Unknown)
UNAME_M := $(shell uname -m 2>/dev/null || echo unknown)

# Normalize OS
ifeq ($(UNAME_S),Linux)
  GOOS := linux
else ifeq ($(findstring MINGW,$(UNAME_S)),MINGW)
  GOOS := windows
else ifeq ($(findstring MSYS,$(UNAME_S)),MSYS)
  GOOS := windows
else ifeq ($(UNAME_S),Darwin)
  GOOS := darwin
else
  GOOS := unknown
endif

# Normalize Arch
ifeq ($(UNAME_M),x86_64)
  GOARCH := amd64
else ifeq ($(UNAME_M),aarch64)
  GOARCH := arm64
else
  GOARCH := unknown
endif

export GOOS
export GOARCH

# Git version fallback
#VERSION=$(shell git describe --tags --abbrev=0)

export VERSION

.PHONY: image


format:
	gofmt -s -w ./

lint:
	golint

test:
	go test -v

get:
	go get

# can be used for manual build 
build: 
	@echo "Building for: GOOS=$(GOOS), GOARCH=$(GOARCH)"
	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -x -o $(BUILD_DIR)/kbot-app-$(GOOS)-$(GOARCH) -ldflags "-X="github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}

#build-platform: format get 
#	@echo "Building for: GOOS=$(GOOS), GOARCH=$(GOARCH)"
#	export GOOS=$(GOOS)
#	export GOARCH=$(GOARCH)
#	@echo "Exported variables values are: GOOS=$(GOOS), GOARCH=$(GOARCH)"
#	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -o $(BUILD_DIR)/$(APP)-$(GOOS)-$(GOARCH) -ldflags "-X=github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}"

#platform-specific targets
linux: 
	$(MAKE) build GOOS=linux GOARCH=amd64

linux_arm64: 
	$(MAKE) build GOOS=linux GOARCH=arm64

darwin: 
	$(MAKE) build GOOS=darwin GOARCH=amd64

darwin_arm64:
	$(MAKE) build GOOS=darwin GOARCH=arm64

windows:
	$(MAKE) build GOOS=windows GOARCH=amd64

# build all binaries 
build-all:
	$(MAKE) linux
	$(MAKE) linux_arm64
	$(MAKE) darwin
	$(MAKE) darwin_arm64
	$(MAKE) windows

## Updating OS\arch for Darwin Docker Image
ifneq (,$(filter $(GOOS),linux linux_arm64))
DOCKER_TARGET=final-linux
endif

ifeq ($(GOOS),windows)
DOCKER_TARGET=final
endif

ifeq ($(GOOS),darwin)
DOCKER_TARGET=final-linux
GOOS=linux
GOARCH=amd64
platform=$(GOOS)/$(GOARCH)
endif

ifeq ($(GOOS),darwin_arm64)
DOCKER_TARGET=final-linux
GOOS=linux
GOARCH=arm64
platform=$(GOOS)/$(GOARCH)
endif


#image:
#	@echo "Building Docker image for: GOOS=$(GOOS), GOARCH=$(GOARCH), version=$(VERSION)"
#	docker build \
		--platform=$(GOOS)/$(GOARCH) \
		--build-arg TARGETOS=$(GOOS) \
		--build-arg TARGETARCH=$(GOARCH) \
		--build-arg VERSION=$(VERSION) \
		--target=$(DOCKER_TARGET) \
		-t $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH) .

image:
	@echo "Building Docker image for: GOOS=$(GOOS), GOARCH=$(GOARCH), VERSION=$(VERSION)"
	docker build \
		--platform=$(GOOS)/$(GOARCH) \
		--build-arg TARGETOS=$(GOOS) \
		--build-arg TARGETARCH=$(GOARCH) \
		--build-arg VERSION=$(VERSION) \
		-t $(REGISTRY):$(VERSION)-$(subst /,-,$(PLATFORM)) \
		.


push: image
	@echo "Pushing image to: $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH)"
	docker push $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH)


clean:
	rm -rf $(BUILD_DIR)
	-docker rmi $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH) 2>/dev/null || true