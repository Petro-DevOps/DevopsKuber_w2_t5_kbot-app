APP=$(shell basename -s .git $(shell git remote get-url origin))
REGISTRY=ghcr.io/petro-devops/kbot-app
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
BUILD_DIR = builds


# Variables for manual build
GOOS ?= 
GOARCH ?= 

# Load platform values if they exist
-include .platform_env

# Export to make available to subshells
export GOOS
export GOARCH


format:
	gofmt ./

lint:
	golint

test:
	go test -v

get:
	go get

# can be used for manual build 
build: format get
	@echo "Building for: GOOS=$(GOOS), GOARCH=$(GOARCH)"
	gofmt -s -w . && go get ./... && CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -x -o $(BUILD_DIR)/kbot-app-$(GOOS)-$(GOARCH) -ldflags "-X="github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}

#build-platform: format get 
#	@echo "Building for: GOOS=$(GOOS), GOARCH=$(GOARCH)"
#	export GOOS=$(GOOS)
#	export GOARCH=$(GOARCH)
#	@echo "Exported variables values are: GOOS=$(GOOS), GOARCH=$(GOARCH)"
#	CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build -v -o $(BUILD_DIR)/$(APP)-$(GOOS)-$(GOARCH) -ldflags "-X=github.com/Petro-DevOps/kbot-app/cmd.appVersion=${VERSION}"

#platform-specific targets
linux: 
	$(MAKE) build-platform GOOS=linux GOARCH=amd64
	@echo 'GOOS=linux' > .platform_env
	@echo 'GOARCH=amd64' >> .platform_env
	@echo "Exported variables values into platform_env file target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"

linux_arm64: 
	$(MAKE) build-platform GOOS=linux GOARCH=arm64
	@echo 'GOOS=linux' > .platform_env
	@echo 'GOARCH=arm64' >> .platform_env
	@echo "Exported variables values into platform_env file target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"

darwin: 
	$(MAKE) build-platform GOOS=darwin GOARCH=amd64
	@echo "Exported variables values in "darwin" target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"
	@echo 'GOOS=darwin' > .platform_env
	@echo 'GOARCH=amd64' >> .platform_env
	@echo "Exported variables values into platform_env file target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"

darwin_arm64:
	$(MAKE) build-platform GOOS=darwin GOARCH=arm64
	@echo 'GOOS=darwin' > .platform_env
	@echo 'GOARCH=arm64' >> .platform_env
	@echo "Exported variables values into platform_env file target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"

windows:
	$(MAKE) build-platform GOOS=windows GOARCH=amd64
	@echo 'GOOS=windows' > .platform_env
	@echo 'GOARCH=amd64' >> .platform_env
	@echo "Exported variables values into platform_env file target are: GOOS=$(GOOS), GOARCH=$(GOARCH)"

# Збірка для всіх основних платформ
build-all:
	$(MAKE) linux
	$(MAKE) linux_arm64
	$(MAKE) darwin
	$(MAKE) darwin_arm64
	$(MAKE) windows

# Автоматичний вибір цільового образу для Dockerfile
#docker_target = $(if $(findstring linux,$(GOOS)),final-linux,final)

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


image: build
	@echo "Building Docker image for: GOOS=$(GOOS), GOARCH=$(GOARCH), version=$(VERSION)"
	docker build \
		--platform=$(GOOS)/$(GOARCH) \
		--build-arg TARGETOS=$(GOOS) \
		--build-arg TARGETARCH=$(GOARCH) \
		--build-arg VERSION=$(VERSION) \
		--target=$(DOCKER_TARGET) \
		-t $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH) .


push: image
	@echo "Pushing image to: $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH)"
	docker push $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH)


clean:
	rm -rf $(BUILD_DIR)
	-docker rmi $(REGISTRY):$(VERSION)-$(GOOS)-$(GOARCH) 2>/dev/null || true