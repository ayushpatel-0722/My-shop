# Common project commands. Run `make help` to list them.
.DEFAULT_GOAL := help

FLUTTER ?= flutter
DART    ?= dart
DEVICE  ?=
D       := $(if $(DEVICE),-d $(DEVICE),)

.PHONY: help setup get l10n run run-uat run-prod run-mock web format format-check analyze test coverage check clean \
        build-apk build-appbundle build-web functions-install functions-deploy rules-deploy

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: get functions-install ## Install all dependencies (Flutter + Cloud Functions)

get: ## Fetch Flutter packages
	$(FLUTTER) pub get

l10n: ## Regenerate localization classes from lib/app/l10n/*.arb
	$(FLUTTER) gen-l10n

run: ## Run the app against Firebase (DEVICE=<id> to pick a device)
	$(FLUTTER) run $(D)

run-uat: ## Run the UAT flavor
	$(FLUTTER) run $(D) --flavor uat -t lib/main_uat.dart

run-prod: ## Run the PROD flavor
	$(FLUTTER) run $(D) --flavor prod -t lib/main_prod.dart

run-mock: ## Run with the in-memory mock repository (no Firebase needed)
	$(FLUTTER) run $(D) --dart-define=USE_MOCK_DATA=true

web: ## Run in Chrome on port 8080
	$(FLUTTER) run -d chrome --web-port 8080

format: ## Format Dart code
	$(DART) format lib test

format-check: ## Fail if Dart code is not formatted
	$(DART) format --output=none --set-exit-if-changed lib test

analyze: ## Static analysis
	$(FLUTTER) analyze

test: ## Run all tests
	$(FLUTTER) test

coverage: ## Run tests with coverage (output: coverage/lcov.info)
	$(FLUTTER) test --coverage

check: format-check analyze test ## Everything CI should run

clean: ## Remove build artifacts and re-fetch packages
	$(FLUTTER) clean
	$(FLUTTER) pub get

build-apk: ## Build release APK
	$(FLUTTER) build apk --release

build-appbundle: ## Build release Android App Bundle
	$(FLUTTER) build appbundle --release

build-web: ## Build release web bundle
	$(FLUTTER) build web --release

functions-install: ## Install Cloud Functions dependencies
	cd functions && npm install

functions-deploy: ## Deploy Cloud Functions
	firebase deploy --only functions

rules-deploy: ## Deploy Firestore/Realtime DB/Storage rules and indexes
	firebase deploy --only firestore,database,storage
