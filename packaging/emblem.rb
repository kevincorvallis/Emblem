# Homebrew cask for a personal tap (e.g. kevincorvallis/homebrew-tap).
# Update version + sha256 on each release:
#   shasum -a 256 build/Emblem-<version>.dmg
cask "emblem" do
  version "0.1.0"
  sha256 :no_check # replace with the DMG's sha256 once a release exists

  url "https://github.com/kevincorvallis/Emblem/releases/download/v#{version}/Emblem-#{version}.dmg"
  name "Emblem"
  desc "Custom icons for Finder sidebar folders"
  homepage "https://github.com/kevincorvallis/Emblem"

  depends_on macos: ">= :sonoma"

  app "Emblem.app"

  caveats <<~EOS
    Emblem is not notarized. On first launch, right-click Emblem.app and
    choose Open, then confirm the dialog.
  EOS

  zap trash: [
    "~/Library/Application Support/Emblem",
  ]
end
