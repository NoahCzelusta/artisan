cask "artisan" do
  version "0.0.2"
  sha256 "24646a52c77546f3ad3c7ecad5c5e71c2f3ed8336bcfdb0d9372cb13a0a63e12"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
