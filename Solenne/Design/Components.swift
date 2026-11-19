import SwiftUI

// MARK: - Glass surfaces

struct GlassBackground: ViewModifier {
    var radius: CGFloat = 24
    var opacity: Double = 0.55

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.white.opacity(opacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 0.6)
                    )
                    .shadow(color: Palette.plum.opacity(0.08), radius: 18, y: 8)
            }
    }
}

extension View {
    func glass(radius: CGFloat = 24, opacity: Double = 0.55) -> some View {
        modifier(GlassBackground(radius: radius, opacity: opacity))
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.plum
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .semibold, relativeTo: .headline))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                Capsule().fill(color.opacity(isEnabled ? 1 : 0.35))
            )
            .shadow(color: color.opacity(isEnabled ? 0.25 : 0), radius: 14, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(14, .semibold, relativeTo: .subheadline))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .glass(radius: 20, opacity: 0.7)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var mauve: PrimaryButtonStyle { PrimaryButtonStyle(color: Palette.mauve) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Round frosted icon button used for back / close / settings.
struct CircleIconButton: View {
    let systemName: String
    var label: String
    var dark = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(dark ? Color.white : Palette.ink)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(dark ? Color.white.opacity(0.18) : Color.white.opacity(0.75))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct BackButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        CircleIconButton(systemName: "chevron.left", label: "Back") { dismiss() }
    }
}

// MARK: - Chips

struct Chip: View {
    let title: String
    var selected = false
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title)
            }
            .font(.sans(13.5, .medium, relativeTo: .subheadline))
            .foregroundStyle(selected ? Color.white : Palette.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(selected ? Palette.plum : Color.white.opacity(0.7))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0 : 0.9), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Simple wrapping layout for chips and tags.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Orb (the AI guide's avatar)

struct Orb: View {
    var size: CGFloat = 96
    var breathing = true
    @State private var phase = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Palette.rose.opacity(0.35))
                .blur(radius: size * 0.25)
                .scaleEffect(phase ? 1.15 : 0.95)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0xF9DCE6), Color(hex: 0xE3A6C0), Color(hex: 0xC46C96)],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.75
                    )
                )
            Ellipse()
                .fill(Color.white.opacity(0.75))
                .frame(width: size * 0.32, height: size * 0.18)
                .blur(radius: size * 0.04)
                .offset(x: -size * 0.16, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .scaleEffect(phase ? 1.03 : 0.98)
        .onAppear {
            guard breathing else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) { phase = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Flame (streak mark)

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(to: CGPoint(x: w, y: h * 0.68),
                   control1: CGPoint(x: w * 0.62, y: h * 0.22),
                   control2: CGPoint(x: w, y: h * 0.38))
        p.addCurve(to: CGPoint(x: w * 0.5, y: h),
                   control1: CGPoint(x: w, y: h * 0.88),
                   control2: CGPoint(x: w * 0.78, y: h))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.68),
                   control1: CGPoint(x: w * 0.22, y: h),
                   control2: CGPoint(x: 0, y: h * 0.88))
        p.addCurve(to: CGPoint(x: w * 0.36, y: h * 0.3),
                   control1: CGPoint(x: 0, y: h * 0.48),
                   control2: CGPoint(x: w * 0.2, y: h * 0.42))
        p.addCurve(to: CGPoint(x: w * 0.5, y: 0),
                   control1: CGPoint(x: w * 0.44, y: h * 0.22),
                   control2: CGPoint(x: w * 0.5, y: h * 0.1))
        p.closeSubpath()
        return p
    }
}

struct Flame: View {
    var size: CGFloat = 64
    var lit = true

    var body: some View {
        ZStack {
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: lit ? [Color(hex: 0xF4A3BF), Color(hex: 0xD9608C)] : [Color(hex: 0xD8CCD2), Color(hex: 0xAA9AA3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: (lit ? Palette.rose : Color.gray).opacity(0.45), radius: size * 0.2, y: size * 0.08)
            FlameShape()
                .fill(Color.white.opacity(0.85))
                .frame(width: size * 0.4, height: size * 0.42)
                .offset(y: size * 0.24)
        }
        .frame(width: size * 0.78, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Typewriter text

/// Types its text in letter by letter, then calls `onFinished`.
struct TypewriterText: View {
    let text: String
    var font: Font = .serif(30, relativeTo: .title)
    var color: Color = Palette.ink
    var speed: Double = 0.028
    var onFinished: () -> Void = {}

    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // The full text sits underneath invisibly so the layout doesn't jump while typing.
        ZStack(alignment: .topLeading) {
            Text(text).font(font).hidden()
            Text(String(text.prefix(shown))).font(font).foregroundStyle(color)
        }
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .task(id: text) {
            shown = 0
            if reduceMotion {
                shown = text.count
            } else {
                for i in 0...text.count {
                    if Task.isCancelled { return }
                    shown = i
                    try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                }
            }
            onFinished()
        }
    }
}

struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Palette.mauve)
                    .frame(width: 7, height: 7)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000)
                phase = (phase + 1) % 3
            }
        }
        .accessibilityLabel("Solenne is thinking")
    }
}

// MARK: - Misc

struct ThinProgressBar: View {
    var value: Double
    var tint: Color = Palette.plum

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.6))
                Capsule().fill(tint).frame(width: max(4, geo.size.width * min(max(value, 0), 1)))
            }
        }
        .frame(height: 4)
        .animation(.easeInOut(duration: 0.35), value: value)
    }
}

struct SectionLabel: View {
    let title: String
    var icon: String = "sparkle"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            EyebrowLabel(title)
        }
        .foregroundStyle(Palette.inkSoft)
        .padding(.leading, 4)
    }
}

/// Header used at the top of bottom sheets: italic serif title + close button.
struct SheetHeader: View {
    let title: String
    var subtitle: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                SerifHeading(title, size: 28, alignment: .leading)
                Spacer()
                CircleIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.sans(13.5))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
    }
}

struct TextAreaField: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 110

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .font(.sans(15))
            .foregroundStyle(Palette.ink)
            .lineLimit(4...10)
            .padding(16)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.mauve.opacity(0.2)))
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.sans(15))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.8)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.mauve.opacity(0.2)))
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }
}
