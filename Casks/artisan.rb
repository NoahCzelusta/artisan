cask "artisan" do
  version "0.0.1"
  sha256 "6dda8267067ad7efa7cfc33b2c7e61f1ec55701853714a3d2763d94328c4e72c"

  url "https://github.com/NoahCzelusta/artisan/releases/download/v#{version}/Artisan-v#{version}-macos-arm64.zip"
  name "Artisan"
  desc "Fast native macOS editor for quick file edits"
  homepage "https://github.com/NoahCzelusta/artisan"

  depends_on macos: :sonoma

  app "Artisan.app"
  binary "artisan"
end
