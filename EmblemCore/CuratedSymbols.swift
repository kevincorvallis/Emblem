import Foundation

extension SymbolCatalog {
    /// Folder-appropriate symbols shown by default in the browser. Also serves as
    /// the fallback catalog if CoreGlyphs.bundle parsing ever fails.
    public static let curated: [String] = [
        // Folders
        "folder.fill", "folder", "folder.fill.badge.plus", "folder.fill.badge.gearshape",
        "folder.fill.badge.person.crop", "folder.fill.badge.questionmark",
        "questionmark.folder.fill", "externaldrive.fill", "internaldrive.fill",
        "opticaldiscdrive.fill", "archivebox.fill", "archivebox", "tray.fill",
        "tray.full.fill", "tray.2.fill", "shippingbox.fill", "shippingbox",

        // Markers
        "star.fill", "star", "star.circle.fill", "heart.fill", "heart",
        "bookmark.fill", "bookmark", "flag.fill", "flag", "tag.fill", "tag",
        "pin.fill", "mappin", "checkmark.circle.fill", "checkmark.seal.fill",
        "seal.fill", "shield.fill", "shield.lefthalf.filled", "crown.fill",
        "sparkles", "bolt.fill", "flame.fill", "leaf.fill", "snowflake",
        "sun.max.fill", "moon.fill", "cloud.fill", "drop.fill",

        // Documents & knowledge
        "doc.fill", "doc.text.fill", "doc.richtext.fill", "doc.on.doc.fill",
        "doc.badge.gearshape.fill", "note.text", "text.book.closed.fill",
        "book.fill", "books.vertical.fill", "book.closed.fill", "magazine.fill",
        "newspaper.fill", "graduationcap.fill", "pencil", "highlighter",
        "paperclip", "envelope.fill", "signature", "list.bullet.rectangle.fill",
        "calendar", "clock.fill", "deskclock.fill",

        // Media
        "photo.fill", "photo.stack.fill", "camera.fill", "video.fill", "film.fill",
        "film.stack.fill", "play.rectangle.fill", "music.note", "music.note.list",
        "waveform", "mic.fill", "speaker.wave.2.fill", "headphones", "tv.fill",
        "gamecontroller.fill", "dice.fill", "puzzlepiece.fill", "paintbrush.fill",
        "paintpalette.fill", "photo.artframe", "theatermasks.fill",

        // Development & work
        "terminal.fill", "apple.terminal.fill", "chevron.left.forwardslash.chevron.right",
        "curlybraces", "hammer.fill", "wrench.and.screwdriver.fill", "screwdriver.fill",
        "gearshape.fill", "gearshape.2.fill", "cpu.fill", "memorychip.fill",
        "server.rack", "network", "antenna.radiowaves.left.and.right",
        "keyboard.fill", "desktopcomputer", "laptopcomputer", "display",
        "swift", "ladybug.fill", "testtube.2", "atom", "function", "sum",
        "chart.bar.fill", "chart.pie.fill", "chart.line.uptrend.xyaxis",
        "briefcase.fill", "case.fill", "latch.2.case.fill", "building.2.fill",
        "building.columns.fill", "banknote.fill", "dollarsign.circle.fill",
        "creditcard.fill", "cart.fill", "bag.fill", "gift.fill",

        // Places & life
        "house.fill", "globe", "globe.americas.fill", "map.fill", "airplane",
        "car.fill", "bicycle", "tram.fill", "sailboat.fill", "tent.fill",
        "mountain.2.fill", "beach.umbrella.fill", "fork.knife", "cup.and.saucer.fill",
        "wineglass.fill", "birthday.cake.fill", "cross.case.fill", "pills.fill",
        "dumbbell.fill", "figure.run", "sportscourt.fill", "trophy.fill",
        "medal.fill", "graduationcap.circle.fill", "pawprint.fill", "fish.fill",
        "bird.fill", "tortoise.fill", "hare.fill", "ant.fill",

        // People & communication
        "person.fill", "person.2.fill", "person.3.fill", "person.crop.circle.fill",
        "figure.2.and.child.holdinghands", "bubble.left.fill", "bubble.left.and.bubble.right.fill",
        "phone.fill", "video.bubble.left.fill", "hand.raised.fill", "hands.clap.fill",

        // Security & storage
        "lock.fill", "lock.open.fill", "key.fill", "eye.slash.fill",
        "trash.fill", "arrow.down.circle.fill", "arrow.up.circle.fill",
        "icloud.fill", "arrow.triangle.2.circlepath", "clock.arrow.circlepath",
        "wifi", "bolt.horizontal.fill", "battery.100percent",

        // Misc
        "lightbulb.fill", "lamp.desk.fill", "bell.fill", "megaphone.fill",
        "scissors", "eyedropper.halffull", "ruler.fill", "level.fill",
        "binoculars.fill", "magnifyingglass", "link", "infinity", "asterisk",
        "number", "at", "command", "option", "power",
    ]
}
