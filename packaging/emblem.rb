# Homebrew cask, published to kevincorvallis/homebrew-tap.
# On each release: update version and sha256 (printed by the release workflow,
# or `shasum -a 256` the GitHub release DMG), then copy to the tap repo.
cask "emblem" do
  version "0.2.0"
  sha256 :no_check # replaced with the release DMG's sha256 after the asset is published

  url "https://github.com/kevincorvallis/Emblem/releases/download/v#{version}/Emblem-#{version}.dmg"
  name "Emblem"
  desc "Custom icons for Finder sidebar folders"
  homepage "https://github.com/kevincorvallis/Emblem"

  depends_on macos: ">= :sonoma"

  app "Emblem.app"

  zap trash: [
    "~/Library/Application Support/Emblem",
  ]
end
