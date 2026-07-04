# Homebrew cask, published to kevincorvallis/homebrew-tap.
# On each release: update version and sha256 (printed by the release workflow,
# or `shasum -a 256` the GitHub release DMG), then copy to the tap repo.
cask "emblem" do
  version "0.2.5"
  sha256 "ba99d4419d3d5cbc5ab15492b9a9046cbacaf5e22095eefcd1f2edfbddd876c8"

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
