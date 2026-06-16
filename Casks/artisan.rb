cask "artisan" do
  version "0.0.3"
  sha256 "7a656957fd61dc2384b927ae7f568bc2f1ea3a46de184b5255e7d8948e341bbb"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
