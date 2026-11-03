APP=restreamer-dev
IMAGE=$(APP):local
UI_SRC=../Restreamer-UI
CORE_SRC=../Restreamer-Core
BUILD_UI=_build/restreamer-ui
BUILD_CORE=_build/core

.PHONY: stage-sources docker docker-compose-check deploy-datavault deploy-datavault-dry deploy-datavault-sync clean-build

stage-sources:
	@test -d "$(UI_SRC)" || (echo "Missing $(UI_SRC) — clone begunfx/restreamer-ui as Restreamer-UI" >&2; exit 1)
	@test -d "$(CORE_SRC)" || (echo "Missing $(CORE_SRC) — clone begunfx/core as Restreamer-Core" >&2; exit 1)
	rm -rf _build
	mkdir -p "$(BUILD_UI)" "$(BUILD_CORE)"
	# ditto: local copy without broken Homebrew rsync on PATH
	ditto "$(UI_SRC)" "$(BUILD_UI)"
	rm -rf "$(BUILD_UI)/.git" "$(BUILD_UI)/node_modules" "$(BUILD_UI)/build" "$(BUILD_UI)/coverage"
	ditto "$(CORE_SRC)" "$(BUILD_CORE)"
	rm -rf "$(BUILD_CORE)/.git" "$(BUILD_CORE)/core" "$(BUILD_CORE)/import" "$(BUILD_CORE)/ffmigrate"
	rm -f "$(BUILD_CORE)/test/cover.out" "$(BUILD_CORE)/test/cover.html"

docker: stage-sources
	docker build -t $(IMAGE) .

docker-compose-check:
	docker compose -f docker-compose.portainer.yml config

deploy-datavault: stage-sources
	./scripts/deploy-datavault.sh

deploy-datavault-dry: stage-sources
	./scripts/deploy-datavault.sh --dry-run

deploy-datavault-sync: stage-sources
	./scripts/deploy-datavault.sh --sync-only

clean-build:
	rm -rf _build
