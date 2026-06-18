cask "artisan" do
  version "0.0.5"
  sha256 "4791e88dc84d572c97bc66963267c621d5b6b3cc08d42d7f337d9a4dc042ae60"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
