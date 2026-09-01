.PHONY: mac app release clean help

FLUTTER ?= flutter
SYMBOLS ?= build/symbols

help:
	@echo "make mac      - macOS release 应用"
	@echo "make app      - Android 分 ABI release APK（常用）"
	@echo "make release  - 体积最小的 arm64-v8a APK（混淆+裁剪）"
	@echo "make clean    - flutter clean"

mac:
	$(FLUTTER) build macos --release
	@echo "→ build/macos/Build/Products/Release/njupt_flutter.app"

app:
	$(FLUTTER) build apk --release --split-per-abi --tree-shake-icons
	@echo "→ build/app/outputs/flutter-apk/app-*-release.apk"

# 最精简：仅 arm64、混淆、剥离调试符号、图标 tree-shake；配合 R8/shrinkResources
release:
	mkdir -p $(SYMBOLS)
	$(FLUTTER) build apk --release \
		--split-per-abi \
		--target-platform=android-arm64 \
		--obfuscate \
		--split-debug-info=$(SYMBOLS) \
		--tree-shake-icons
	@echo "→ build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
	@echo "  symbols: $(SYMBOLS)/"

clean:
	$(FLUTTER) clean
