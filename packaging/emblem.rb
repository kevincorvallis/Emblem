# Homebrew cask, published to kevincorvallis/homebrew-tap.
# On each release: update version and sha256 (printed by the release workflow,
# or `shasum -a 256` the GitHub release DMG), then copy to the tap repo.
cask "emblem" do
  version "0.2.3"
  sha256 "3c1e853ca82fab9f53a0424edf1893c2b9ca48649dea9f8442e942f30b662b38"

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
