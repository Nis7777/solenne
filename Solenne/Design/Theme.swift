import SwiftUI
import CoreText

// MARK: - Colours

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum Palette {
    static let cream = Color(hex: 0xF8EDE6)
    static let blush = Color(hex: 0xE2A9BF)
    static let plum = Color(hex: 0x5A2338)
    static let mauve = Color(hex: 0x9E6F82)
    static let rose = Color(hex: 0xD9819E)
    static let ink = Color(hex: 0x3B1F2B)
    static let inkSoft = Color(hex: 0x3B1F2B, opacity: 0.62)
    static let inkFaint = Color(hex: 0x3B1F2B, opacity: 0.38)
    static let paper = Color(hex: 0xFFF9F5)
}

// MARK: - Type

enum Fonts {
    /// Registers the bundled TTFs once at launch so `Font.custom` can find them.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

enum SansWeight: String {
    case regular = "PlusJakartaSans-Regular"
    case medium = "PlusJakartaSans-Medium"
    case semibold = "PlusJakartaSans-SemiBold"
    case bold = "PlusJakartaSans-Bold"
}

extension Font {
    static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("InstrumentSerif-Regular", size: size, relativeTo: style)
    }

    static func serifItalic(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("InstrumentSerif-Italic", size: size, relativeTo: style)
    }

    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

/// Serif heading where words wrapped in *asterisks* are set in italic,
/// e.g. `SerifHeading("what do you want to *manifest?*")`.
struct SerifHeading: View {
    let text: String
    var size: CGFloat = 34
    var color: Color = Palette.ink
    var alignment: TextAlignment = .center

    init(_ text: String, size: CGFloat = 34, color: Color = Palette.ink, alignment: TextAlignment = .center) {
        self.text = text
        self.size = size
        self.color = color
        self.alignment = alignment
    }

    var body: some View {
        Text(Self.styled(text, size: size))
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineSpacing(-2)
    }

    static func styled(_ text: String, size: CGFloat) -> AttributedString {
        var result = AttributedString()
        for (index, part) in text.components(separatedBy: "*").enumerated() where !part.isEmpty {
            var run = AttributedString(part)
            run.font = index.isMultiple(of: 2) ? .serif(size) : .serifItalic(size)
            result += run
        }
        return result
    }
}

/// Small uppercase label with wide tracking ("DAILY REFRESH IN").
struct EyebrowLabel: View {
    let text: String
    var color: Color = Palette.inkSoft

    init(_ text: String, color: Color = Palette.inkSoft) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.sans(10.5, .semibold, relativeTo: .caption2))
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

// MARK: - Background

struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Palette.cream, Color(hex: 0xF1D3D9), Palette.blush],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

extension View {
    /// The cream-to-pink gradient that sits behind every screen.
    func solenneBackground() -> some View {
        background(GradientBackground())
    }
}
