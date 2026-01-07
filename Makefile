# Leave iOS App - Build & Deploy
#
# Required env vars (set via Mise or export):
#   TEAM_ID     - Apple Developer Team ID
#   BUNDLE_ID   - App bundle identifier (e.g., com.yourname.Leave)
#   APPLE_ID    - Apple ID email for upload
#
# Optional:
#   KEYCHAIN_PROFILE - notarytool credential name (default: AC_PASSWORD)

PROJECT      := Leave.xcodeproj
SCHEME       := Leave
CONFIG       := Release
BUILD_DIR    := build
ARCHIVE_PATH := $(BUILD_DIR)/Leave.xcarchive
EXPORT_PATH  := $(BUILD_DIR)/export
IPA_PATH     := $(EXPORT_PATH)/Leave.ipa

KEYCHAIN_PROFILE ?= AC_PASSWORD

.PHONY: all clean build export upload deploy help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Targets:"
	@echo "  build    - Build archive"
	@echo "  export   - Export IPA from archive"
	@echo "  upload   - Upload IPA to TestFlight"
	@echo "  deploy   - Full pipeline: build → export → upload"
	@echo "  clean    - Remove build artifacts"
	@echo ""
	@echo "Required env vars: TEAM_ID, BUNDLE_ID, APPLE_ID"

all: deploy

clean:
	rm -rf $(BUILD_DIR)
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME) -quiet

build: $(ARCHIVE_PATH)

$(ARCHIVE_PATH): $(wildcard Leave/**/*.swift) $(wildcard Leave/**/*.plist)
	@echo "==> Building archive..."
	@test -n "$(TEAM_ID)" || (echo "Error: TEAM_ID not set" && exit 1)
	@test -n "$(BUNDLE_ID)" || (echo "Error: BUNDLE_ID not set" && exit 1)
	@mkdir -p $(BUILD_DIR)
	xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-archivePath $(ARCHIVE_PATH) \
		-destination "generic/platform=iOS" \
		DEVELOPMENT_TEAM="$(TEAM_ID)" \
		PRODUCT_BUNDLE_IDENTIFIER="$(BUNDLE_ID)" \
		CODE_SIGN_STYLE=Automatic \
		-quiet
	@echo "==> Archive created: $(ARCHIVE_PATH)"

$(BUILD_DIR)/ExportOptions.plist:
	@test -n "$(TEAM_ID)" || (echo "Error: TEAM_ID not set" && exit 1)
	@mkdir -p $(BUILD_DIR)
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $@
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $@
	@echo '<plist version="1.0"><dict>' >> $@
	@echo '<key>method</key><string>app-store-connect</string>' >> $@
	@echo '<key>teamID</key><string>$(TEAM_ID)</string>' >> $@
	@echo '<key>uploadSymbols</key><true/>' >> $@
	@echo '<key>destination</key><string>upload</string>' >> $@
	@echo '</dict></plist>' >> $@

export: $(IPA_PATH)

$(IPA_PATH): $(ARCHIVE_PATH) $(BUILD_DIR)/ExportOptions.plist
	@echo "==> Exporting IPA..."
	xcodebuild -exportArchive \
		-archivePath $(ARCHIVE_PATH) \
		-exportPath $(EXPORT_PATH) \
		-exportOptionsPlist $(BUILD_DIR)/ExportOptions.plist \
		-quiet
	@echo "==> IPA created: $(IPA_PATH)"

upload: $(IPA_PATH)
	@echo "==> Uploading to TestFlight..."
	@test -n "$(APPLE_ID)" || (echo "Error: APPLE_ID not set" && exit 1)
	@test -n "$(TEAM_ID)" || (echo "Error: TEAM_ID not set" && exit 1)
	xcrun notarytool submit $(IPA_PATH) \
		--apple-id "$(APPLE_ID)" \
		--team-id "$(TEAM_ID)" \
		--keychain-profile "$(KEYCHAIN_PROFILE)" \
		--wait
	@echo "==> Upload complete!"

deploy: clean build export upload
	@echo "==> Deploy complete! Check App Store Connect for build status."
