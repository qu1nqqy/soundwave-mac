# Команды soundwave-mac. `make` или `make help` — список.

APP      := build/Soundwave.app
# Чем подписывать .app. Постоянная подпись нужна, чтобы macOS не забывала выданные разрешения
# (управление Music, запись звука) после каждой пересборки. В CI — ad-hoc: `make app SIGN_ID=-`.
SIGN_ID  ?= Apple Development
SOURCES  := Sources Tests Package.swift

# Собираем тулчейном Xcode, даже если xcode-select смотрит на Command Line Tools:
# у CLT бывает сломан плагин макросов Swift Testing («plugin for module 'TestingMacros' not found»).
XCODE := /Applications/Xcode.app/Contents/Developer
ifneq ($(wildcard $(XCODE)),)
export DEVELOPER_DIR ?= $(XCODE)
endif

.DEFAULT_GOAL := help
.PHONY: help build test app run install fmt lint check clean

help: ## показать этот список
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  \033[36m%-8s\033[0m %s\n", $$1, $$2}'

build: ## собрать (release)
	swift build -c release

test: ## тесты SoundwaveCore
	swift test

app: build ## собрать build/Soundwave.app и подписать
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp "$$(swift build -c release --show-bin-path)/Soundwave" $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/
	codesign --force --sign "$(SIGN_ID)" $(APP)

run: app ## пересобрать и запустить (старый экземпляр закрывается)
	-pkill -x Soundwave
	open $(APP)

install: app ## положить в /Applications
	rm -rf /Applications/Soundwave.app
	cp -R $(APP) /Applications/

fmt: ## отформатировать код
	swift format -i -r $(SOURCES)

lint: ## проверить форматирование
	swift format lint --strict -r $(SOURCES)

check: lint test app ## всё, что гоняет CI

clean: ## удалить всё собранное
	rm -rf .build build
