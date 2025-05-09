
# --------------------------------------------------------------------------------------

GIT_SHA := $(shell git -c log.showSignature=false rev-parse HEAD 2>/dev/null)
GIT_TAG := $(shell bash -c 'TAG=$$(git -c log.showSignature=false \
	describe --tags --exact-match --abbrev=0 $(GIT_SHA) 2>/dev/null); echo "$${TAG:-dev}"')

LDFLAGS=-s -w \
        -X github.com/mozilla/psa-checker/cmd/psa-checker.version=$(GIT_TAG) \
        -X github.com/mozilla/psa-checker/cmd/psa-checker.commit=$(GIT_SHA) \
		-X github.com/mozilla/psa-checker/cmd/psa-checker.date=$(date +"%Y-%m-%dT%H:%M:%S%z") \
		-X github.com/mozilla/psa-checker/cmd/psa-checker.builtBy="makefile"

# --------------------------------------------------------------------------------------

TARGET_BIN=psa-checker
MAIN_DIR=./
#CONTAINER_IMAGE=quay.io/mozilla/psa-checker

.PHONY: all
all: upgrade build run test test-e2e

.PHONY: upgrade
upgrade:
	go mod tidy

.PHONY: mod_download
mod_download:
	go mod download

.PHONY: build
build:
	go build -ldflags "$(LDFLAGS)" -o ./release/${TARGET_BIN} ${MAIN_DIR}/main.go

build-release: mod_download vet test-noginkgo
	CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -o ./release/${TARGET_BIN} ${MAIN_DIR}/main.go

# strip ./release/${TARGET_BIN}

run:
	cd ./release && ./${TARGET_BIN} --level restricted --filename ../test/multi.yaml ||:

# Lint

lint: lint-go lint-yaml

lint-go:
	golangci-lint run

lint-yaml:
	yamllint .

#lint-containerfile:
#	hadolint build/Containerfile

# Tests

test:
	ginkgo -randomize-all -randomize-suites -fail-on-pending -trace -race -cover -r -vv

test-noginkgo:
	go test -v ./... -args -ginkgo.v

vet:
	go vet -v

test-e2e:
	@echo "" ; echo "End to end tests"
	@cd ./test && ./test-success.sh || ( echo "[  error  ] Compliant manifests test error" && exit 1 )
	@cd ./test && ./test-fail.sh || ( echo "[  error  ] Non compliant manifests test error" && exit 1 )

# dependencies

dependencies:
	go version
	ginkgo version
	golangci-lint --version
	yamllint --version
	hadolint --version
	yaml --version

install_ginkgo:
	go install -mod=mod github.com/onsi/ginkgo/v2/ginkgo
	go get github.com/onsi/gomega/...

install_golangci-lint:
	brew install golangci-lint
	brew upgrade golangci-lint

install_yamllint:
	pip install --user yamllint

install_yaml:
	pip install --user ruamel.yaml.cmd

# Container targets
#
#container-build:
#	@echo "Building container image"
#	@if groups $$USER | grep -q '\bdocker\b'; then RUNSUDO="" ; else RUNSUDO="sudo" ; fi && \
#	    $$RUNSUDO docker build -f build/Containerfile -t ${CONTAINER_IMAGE} .
#
#container-run:
#	@echo "Running container image"
#	@if groups $$USER | grep -q '\bdocker\b'; then RUNSUDO="" ; else RUNSUDO="sudo" ; fi && \
#	    $$RUNSUDO docker run --rm -it \
#		-v "$$(pwd)"/test/in.yaml:/bin/in.yaml \
#		-u $$(id -u $${USER}):$$(id -g $${USER}) \
#		${CONTAINER_IMAGE}
#
## push the container image
#push:
#	${RUNSUDO} docker push ${CONTAINER_IMAGE}
#
## pull the container image
#pull:
#	${RUNSUDO} docker pull ${CONTAINER_IMAGE}
