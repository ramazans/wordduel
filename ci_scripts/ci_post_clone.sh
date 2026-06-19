#!/bin/sh

# Xcode Cloud post-clone hook.
#
# DURUM: ŞU AN DEVRE DIŞI. Bu projede CI/CD GitHub Actions ile yapılıyor
# (.github/workflows/testflight.yml). Xcode Cloud workflow'u App Store
# Connect'ten "Disabled" durumuna alındı, bu yüzden bu script normalde hiç
# çalışmaz. Dosya bilerek repoda tutuluyor: ileride Xcode Cloud'a dönmek
# istenirse sıfırdan yazmaya gerek kalmasın.
#
# YENİDEN ETKİNLEŞTİRMEK İÇİN:
#   1. Aşağıdaki XCODE_CLOUD_ENABLED değerini "true" yap.
#   2. App Store Connect → WordDuel → Xcode Cloud → workflow'u tekrar Enable et.
#
# Script ne işe yarar: Proje dosyası (`WordDuel.xcodeproj`) repoda tutulMAZ —
# XcodeGen onu `project.yml`'den üretir (bkz. .gitignore). Xcode Cloud klonlama
# sonrası kökte `.xcodeproj` arar; bulamazsa archive adımı "Project
# WordDuel.xcodeproj does not exist" hatasıyla fail olur. Bu script o dosyayı
# üreterek hatayı önler.

XCODE_CLOUD_ENABLED="false"

if [ "$XCODE_CLOUD_ENABLED" != "true" ]; then
    echo "Xcode Cloud bu projede devre dışı; ci_post_clone atlanıyor."
    echo "Etkinleştirmek için XCODE_CLOUD_ENABLED=\"true\" yapın."
    exit 0
fi

set -e

# Xcode Cloud script'i geçici bir konumda çalıştırır; gerçek repo kökü
# CI_PRIMARY_REPOSITORY_PATH ortam değişkeninde gelir.
cd "$CI_PRIMARY_REPOSITORY_PATH"

echo "Installing XcodeGen via Homebrew…"
brew install xcodegen

echo "Generating Xcode project from project.yml…"
xcodegen generate

echo "Done. WordDuel.xcodeproj generated."
