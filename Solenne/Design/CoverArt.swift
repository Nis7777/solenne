import SwiftUI

/// Generated painterly cover for a story: a soft sky, a glowing sun and a horizon,
/// coloured by theme and varied by a seed. No network, no stock photos.
struct CoverArt: View {
    let theme: CoverTheme
    var seed: UUID = UUID.stable("cover")

    private var colors: (sky: [Color], sun: Color, ground: [Color]) {
        switch theme {
        case .dawn: ([Color(hex: 0xFCE3D3), Color(hex: 0xF4B3B4), Color(hex: 0xC98BA3)], Color(hex: 0xFFF1D6), [Color(hex: 0xB77A93), Color(hex: 0x7E4D66)])
        case .ocean: ([Color(hex: 0xF7D2B8), Color(hex: 0xC6A0B4), Color(hex: 0x5E8CA3)], Color(hex: 0xFFE7C2), [Color(hex: 0x2F6C86), Color(hex: 0x173E52)])
        case .golden: ([Color(hex: 0xFBE0A6), Color(hex: 0xF2A774), Color(hex: 0xC2626B)], Color(hex: 0xFFF4D1), [Color(hex: 0x9A4A55), Color(hex: 0x5B2638)])
        case .rose: ([Color(hex: 0xFBD9E2), Color(hex: 0xE89AB4), Color(hex: 0xA9567A)], Color(hex: 0xFFEFF2), [Color(hex: 0x8A3F5F), Color(hex: 0x4E1F36)])
        case .midnight: ([Color(hex: 0x2A2652), Color(hex: 0x4B3A78), Color(hex: 0x8C6BA0)], Color(hex: 0xF3E6F5), [Color(hex: 0x1B1838), Color(hex: 0x0E0C22)])
        case .forest: ([Color(hex: 0xF1E6C8), Color(hex: 0xC9C79B), Color(hex: 0x7F9C7D)], Color(hex: 0xFFF6DC), [Color(hex: 0x4B6F57), Color(hex: 0x223A2C)])
        case .city: ([Color(hex: 0xF4D9C9), Color(hex: 0xC7A6B9), Color(hex: 0x6E6E93)], Color(hex: 0xFFE9D2), [Color(hex: 0x40425E), Color(hex: 0x23243A)])
        case .desert: ([Color(hex: 0xFBE3BF), Color(hex: 0xF0B07D), Color(hex: 0xD27A5E)], Color(hex: 0xFFF5DE), [Color(hex: 0xB0604A), Color(hex: 0x6E3329)])
        }
    }

    /// Seed-derived numbers in 0...1 so each story's cover differs a little.
    private func value(_ index: Int) -> CGFloat {
        let bytes = withUnsafeBytes(of: seed.uuid) { Array($0) }
        return CGFloat(bytes[index % 16]) / 255
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let horizon = h * (0.55 + value(0) * 0.15)
            ZStack {
                LinearGradient(colors: colors.sky, startPoint: .top, endPoint: .bottom)

                Circle()
                    .fill(colors.sun)
                    .frame(width: w * (0.28 + value(1) * 0.18))
                    .blur(radius: w * 0.015)
                    .shadow(color: colors.sun.opacity(0.9), radius: w * 0.12)
                    .position(x: w * (0.25 + value(2) * 0.5), y: horizon - h * (0.08 + value(3) * 0.18))

                // Soft cloud bands
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: w * 0.9, height: h * 0.05)
                    .blur(radius: 10)
                    .position(x: w * (0.3 + value(4) * 0.4), y: h * (0.18 + value(5) * 0.15))
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: w * 0.7, height: h * 0.04)
                    .blur(radius: 8)
                    .position(x: w * (0.4 + value(6) * 0.4), y: h * (0.3 + value(7) * 0.12))

                // Hills / water
                HillShape(phase: value(8), amplitude: 0.05 + value(9) * 0.06)
                    .fill(LinearGradient(colors: [colors.ground[0].opacity(0.85), colors.ground[1]], startPoint: .top, endPoint: .bottom))
                    .frame(height: h - horizon + h * 0.08)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                HillShape(phase: value(10), amplitude: 0.04)
                    .fill(colors.ground[1].opacity(0.9))
                    .frame(height: (h - horizon) * 0.55)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

private struct HillShape: Shape {
    var phase: CGFloat
    var amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let a = rect.height * amplitude * 3
        p.move(to: CGPoint(x: 0, y: a * (0.5 + phase * 0.5)))
        p.addCurve(
            to: CGPoint(x: rect.width, y: a * (1 - phase * 0.6)),
            control1: CGPoint(x: rect.width * 0.35, y: -a * 0.6),
            control2: CGPoint(x: rect.width * 0.65, y: a * 1.6)
        )
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

extension Story {
    var cover: CoverArt { CoverArt(theme: theme, seed: id) }
}
