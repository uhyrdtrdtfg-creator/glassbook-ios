import SwiftUI

/// 6 named Aurora palettes, one per V1.0 screen.
/// Mirrors the HTML spec: radial-gradient spots layered over a vertical linear base.
enum AuroraPalette: String, CaseIterable {
    case home      // bg-aurora-a · warm peach → lavender
    case add       // bg-aurora-b · pink / mint / amber
    case bills     // bg-aurora-c · sky / blush / lilac
    case stats     // bg-aurora-d · amber / rose / periwinkle
    case budget    // bg-aurora-e · lavender / apricot
    case profile   // bg-aurora-f · sky / coral
    case importBlue   // flow 1
    case importPurple // flow 2
    case importAmber  // flow 3
    case importMint   // flow 4
}

struct AuroraBackground: View {
    let palette: AuroraPalette

    var body: some View {
        ZStack {
            base
            ForEach(Array(spots.enumerated()), id: \.offset) { _, spot in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [spot.color, spot.color.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: spot.radius
                        )
                    )
                    .frame(width: spot.radius * 2, height: spot.radius * 2)
                    .position(x: spot.x, y: spot.y)
            }
        }
        .ignoresSafeArea()
    }

    private var base: some View {
        LinearGradient(colors: baseColors, startPoint: .top, endPoint: .bottom)
    }

    // MARK: — per-palette recipes
    private var baseColors: [Color] {
        switch palette {
        case .home:      return [Color(hex: 0xFDE4D0), Color(hex: 0xE8E2FF)]
        case .add:       return [Color(hex: 0xFFE8F1), Color(hex: 0xFFF4E0)]
        case .bills:     return [Color(hex: 0xE8F4FF), Color(hex: 0xFCE8F4)]
        case .stats:     return [Color(hex: 0xFFF0D4), Color(hex: 0xE4E8FF)]
        case .budget:    return [Color(hex: 0xECE4FF), Color(hex: 0xFFE8DC)]
        case .profile:   return [Color(hex: 0xDCECFF), Color(hex: 0xFFF0EA)]
        case .importBlue:   return [Color(hex: 0xE4EEFF), Color(hex: 0xF0FFE8)]
        case .importPurple: return [Color(hex: 0xEBE4FF), Color(hex: 0xFFECF2)]
        case .importAmber:  return [Color(hex: 0xFFF0D4), Color(hex: 0xE8E4FF)]
        case .importMint:   return [Color(hex: 0xE4FFF0), Color(hex: 0xFFF0E4)]
        }
    }

    private struct Spot { let x, y, radius: CGFloat; let color: Color }

    private var spots: [Spot] {
        let W: CGFloat = UIScreen.main.bounds.width
        let H: CGFloat = UIScreen.main.bounds.height
        switch palette {
        case .home:
            return [
                Spot(x: W*0.15, y: H*0.08, radius: W*0.8, color: Color(hex: 0xFFB199).opacity(0.55)),
                Spot(x: W*0.85, y: H*0.18, radius: W*0.85, color: Color(hex: 0x9CC0FF).opacity(0.55)),
                Spot(x: W*0.50, y: H*0.78, radius: W*0.95, color: Color(hex: 0xD4A5FF).opacity(0.45)),
            ]
        case .add:
            return [
                Spot(x: W*0.80, y: H*0.10, radius: W*0.85, color: Color(hex: 0xFFB4E0).opacity(0.55)),
                Spot(x: W*0.20, y: H*0.40, radius: W*0.85, color: Color(hex: 0xA8E4D2).opacity(0.55)),
                Spot(x: W*0.70, y: H*0.90, radius: W*0.90, color: Color(hex: 0xFFD89C).opacity(0.5)),
            ]
        case .bills:
            return [
                Spot(x: W*0.30, y: H*0.15, radius: W*0.85, color: Color(hex: 0xB8E6FF).opacity(0.55)),
                Spot(x: W*0.85, y: H*0.55, radius: W*0.85, color: Color(hex: 0xFFC0D9).opacity(0.55)),
                Spot(x: W*0.15, y: H*0.88, radius: W*0.90, color: Color(hex: 0xD5C6FF).opacity(0.5)),
            ]
        case .stats:
            return [
                Spot(x: W*0.75, y: H*0.12, radius: W*0.8,  color: Color(hex: 0xFFD46B).opacity(0.5)),
                Spot(x: W*0.20, y: H*0.35, radius: W*0.8,  color: Color(hex: 0xFFAEC1).opacity(0.55)),
                Spot(x: W*0.60, y: H*0.88, radius: W*0.95, color: Color(hex: 0xA8C0FF).opacity(0.5)),
            ]
        case .budget:
            return [
                Spot(x: W*0.20, y: H*0.20, radius: W*0.9,  color: Color(hex: 0xC8B5FF).opacity(0.55)),
                Spot(x: W*0.85, y: H*0.70, radius: W*0.85, color: Color(hex: 0xFFC8A8).opacity(0.55)),
            ]
        case .profile:
            return [
                Spot(x: W*0.50, y: H*0.15, radius: W*1.0,  color: Color(hex: 0xA8D8FF).opacity(0.55)),
                Spot(x: W*0.90, y: H*0.85, radius: W*0.9,  color: Color(hex: 0xFFC0B5).opacity(0.5)),
            ]
        case .importBlue:
            return [
                Spot(x: W*0.20, y: H*0.15, radius: W*0.85, color: Color(hex: 0x9CC0FF).opacity(0.55)),
                Spot(x: W*0.85, y: H*0.80, radius: W*0.9,  color: Color(hex: 0xA8E4D2).opacity(0.5)),
                Spot(x: W*0.50, y: H*0.50, radius: W*0.95, color: Color(hex: 0xD4A5FF).opacity(0.4)),
            ]
        case .importPurple:
            return [
                Spot(x: W*0.30, y: H*0.20, radius: W*0.85, color: Color(hex: 0xC8B5FF).opacity(0.55)),
                Spot(x: W*0.75, y: H*0.85, radius: W*0.85, color: Color(hex: 0xFFB4CC).opacity(0.55)),
            ]
        case .importAmber:
            return [
                Spot(x: W*0.15, y: H*0.18, radius: W*0.75, color: Color(hex: 0xFFD46B).opacity(0.55)),
                Spot(x: W*0.85, y: H*0.55, radius: W*0.8,  color: Color(hex: 0x9CC0FF).opacity(0.5)),
                Spot(x: W*0.60, y: H*0.90, radius: W*0.9,  color: Color(hex: 0xD4A5FF).opacity(0.45)),
            ]
        case .importMint:
            return [
                Spot(x: W*0.50, y: H*0.30, radius: W*1.0,  color: Color(hex: 0xA8E4D2).opacity(0.6)),
                Spot(x: W*0.20, y: H*0.80, radius: W*0.9,  color: Color(hex: 0xFFC8A8).opacity(0.5)),
                Spot(x: W*0.85, y: H*0.85, radius: W*0.85, color: Color(hex: 0xB8C8FF).opacity(0.5)),
            ]
        }
    }
}

#Preview("Aurora palettes") {
    TabView {
        ForEach(AuroraPalette.allCases, id: \.self) { p in
            AuroraBackground(palette: p)
                .overlay(Text(p.rawValue).font(.title2).fontWeight(.medium))
                .tag(p)
        }
    }
    .tabViewStyle(.page)
}
