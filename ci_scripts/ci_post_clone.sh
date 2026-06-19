#!/bin/sh

# Xcode Cloud post-clone hook.
#
# Proje dosyası (`WordDuel.xcodeproj`) repoda tutulMAZ — XcodeGen onu
# `project.yml`'den üretir (bkz. .gitignore). Xcode Cloud repoyu klonladıktan
# sonra kökte `.xcodeproj` arar; bulamazsa "Project WordDuel.xcodeproj does not
# exist at the root of the repository" hatasıyla build fail olur.
#
# Bu script Xcode Cloud tarafından klonlama biter bitmez otomatik çalışır ve
# projeyi üreterek archive adımının dosyayı bulmasını sağlar.

set -e

# Xcode Cloud script'i geçici bir konumda çalıştırır; gerçek repo kökü
# CI_PRIMARY_REPOSITORY_PATH ortam değişkeninde gelir.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Installing XcodeGen via Homebrew…"
brew install xcodegen

echo "Generating Xcode project from project.yml…"
xcodegen generate

echo "Done. WordDuel.xcodeproj generated."
