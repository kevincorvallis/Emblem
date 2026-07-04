# Homebrew cask, published to kevincorvallis/homebrew-tap.
# On each release: update version and sha256 (printed by the release workflow,
# or `shasum -a 256` the GitHub release DMG), then copy to the tap repo.
cask "emblem" do
  version "0.2.2"
  sha256 "4e95eee53cbe2e27cee9eadbf59a33d8872ea67ea8b89db2e059a6588747f947"

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
