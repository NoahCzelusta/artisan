cask "artisan" do
  version "0.0.4"
  sha256 "1f615dd2ad56495709344bbcac639979a7d201057a83a5495978c93e308e96bc"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
