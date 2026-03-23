// LifeCompassDesignSystem.swift
// Life Compass — Premium Design System v2
//
// Feels like Calm × Apple Health × Notion.
// Calm · Slow · Breathable · Emotionally safe.
//
// Architecture
// ┌─ Tokens ──────── Color · Typography · Spacing
// ├─ Animations ──── Named curves, all 0.4–0.8 s, no snappy motion
// ├─ Modifiers ───── softAppear · cardLift · pulseGlow
// ├─ Background ──── Gradient + optional noise texture
// └─ Components ──── GlassCard · SectionHeader · PrimaryButton
//                    ProgressBar · ProgressRing

import SwiftUI

// ============================================================
// MARK: - Color Tokens
// ============================================================
//
// Prefix `lc` avoids shadowing SwiftUI's built-in `.primary`.
// Prefer these over raw Color literals throughout the app.

extension Color {

    // ── Brand ────────────────────────────────────────────────
    /// Muted slate-blue: the anchor of the palette.
    static let lcPrimary        = Color(lcHex: "#6C7AA6")

    // ── Background ───────────────────────────────────────────
    /// Deep navy — gradient top.
    static let lcBgStart        = Color(lcHex: "#0B0E1A")
    /// Warm charcoal — gradient bottom.
    static let lcBgEnd          = Color(lcHex: "#181B26")

    // ── Accents (intentionally desaturated — use opacity layers) ─
    /// Warm soft gold.
    static let lcGold           = Color(lcHex: "#C9A96E")
    /// Muted lavender.
    static let lcLavender       = Color(lcHex: "#9B8EC4")
    /// Warm beige.
    static let lcBeige          = Color(lcHex: "#D4C5B0")

    // ── Glass surface layers ──────────────────────────────────
    /// Translucent white fill — base glass depth.
    static let lcGlassFill      = Color.white.opacity(0.04)
    /// Top-edge inner highlight — simulates top light source.
    static let lcGlassHighlight = Color.white.opacity(0.11)
    /// Border stroke — restrained, not bright.
    static let lcGlassStroke    = Color.white.opacity(0.08)

    // ── Text hierarchy ────────────────────────────────────────
    static let lcTextPrimary    = Color.white
    static let lcTextSecondary  = Color.white.opacity(0.50)
    static let lcTextTertiary   = Color.white.opacity(0.28)
}

// MARK: Hex initialiser
extension Color {
    init(lcHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}

// MARK: ShapeStyle extensions
// Allows `.lcXxx` dot-shorthand inside foregroundStyle(_:) / fill(_:) etc.
// without an explicit `Color.` prefix — identical values, zero duplication.
extension ShapeStyle where Self == Color {
    static var lcPrimary:       Color { Color.lcPrimary       }
    static var lcBgStart:       Color { Color.lcBgStart       }
    static var lcBgEnd:         Color { Color.lcBgEnd         }
    static var lcGold:          Color { Color.lcGold          }
    static var lcLavender:      Color { Color.lcLavender      }
    static var lcBeige:         Color { Color.lcBeige         }
    static var lcGlassFill:     Color { Color.lcGlassFill     }
    static var lcGlassHighlight:Color { Color.lcGlassHighlight}
    static var lcGlassStroke:   Color { Color.lcGlassStroke   }
    static var lcTextPrimary:   Color { Color.lcTextPrimary   }
    static var lcTextSecondary: Color { Color.lcTextSecondary }
    static var lcTextTertiary:  Color { Color.lcTextTertiary  }
}

// ============================================================
// MARK: - Typography Scale
// ============================================================

enum LCFont {
    /// 32 pt semibold · hero headings
    /// Apply .tracking(-0.4) at the call site for tighter premium feel.
    static let largeTitle = Font.system(size: 32, weight: .semibold)

    /// 22 pt semibold · section headings
    static let header     = Font.system(size: 22, weight: .semibold)

    /// 16 pt regular · body copy
    static let body       = Font.system(size: 16, weight: .regular)

    /// 15 pt regular · insight / caption
    static let insight    = Font.system(size: 15, weight: .regular)

    /// 11 pt medium · overline labels (all-caps at call site)
    /// Apply .tracking(1.2) at the call site for wide-spaced caps.
    static let overline   = Font.system(size: 11, weight: .medium)
}

// ============================================================
// MARK: - Spacing Scale
// ============================================================
// Air, not density. Err on the side of more breathing room.

enum LCSpacing {
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 14
    static let md:  CGFloat = 20
    static let lg:  CGFloat = 32
    static let xl:  CGFloat = 48
    static let xxl: CGFloat = 64
}

// ============================================================
// MARK: - Animation System
// ============================================================
// All durations: 0.4–0.8 s. No snappy motion. Ever.

extension Animation {
    /// 0.6 s ease-out — appearing elements, opacity + offset.
    static let lcSoftAppear  = Animation.easeOut(duration: 0.60)

    /// 0.5 s ease-in-out — card scale interactions.
    static let lcCardLift    = Animation.easeInOut(duration: 0.50)

    /// 0.6 s ease-in-out — progress bar fill.
    static let lcProgressFill = Animation.easeInOut(duration: 0.60)

    /// 0.8 s ease-in-out — circular ring trim.
    static let lcRingFill    = Animation.easeInOut(duration: 0.80)

    /// 1.8 s repeating — slow glow breath.
    static let lcPulseGlow   = Animation
        .easeInOut(duration: 1.80)
        .repeatForever(autoreverses: true)
}

// ============================================================
// MARK: - View Modifiers
// ============================================================

// ── softAppear ───────────────────────────────────────────────

struct LCSoftAppearModifier: ViewModifier {
    @State private var visible = false
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 12)
            .onAppear {
                withAnimation(.lcSoftAppear.delay(delay)) { visible = true }
            }
    }
}

// ── cardLift ─────────────────────────────────────────────────

struct LCCardLiftModifier: ViewModifier {
    @State private var lifted = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(lifted ? 1 : 0.97)
            .onAppear {
                withAnimation(.lcCardLift) { lifted = true }
            }
    }
}

// ── pulseGlow ────────────────────────────────────────────────

struct LCPulseGlowModifier: ViewModifier {
    var color: Color
    var minOpacity: Double
    var maxOpacity: Double
    var minRadius:  CGFloat
    var maxRadius:  CGFloat
    @State private var glowing = false

    func body(content: Content) -> some View {
        content
            .shadow(
                color:  color.opacity(glowing ? maxOpacity : minOpacity),
                radius: glowing ? maxRadius : minRadius
            )
            .onAppear {
                withAnimation(.lcPulseGlow) { glowing = true }
            }
    }
}

// ── View extension entry points ───────────────────────────────

extension View {
    func softAppear(delay: Double = 0) -> some View {
        modifier(LCSoftAppearModifier(delay: delay))
    }

    func cardLift() -> some View {
        modifier(LCCardLiftModifier())
    }

    func pulseGlow(
        color:      Color   = .lcPrimary,
        minOpacity: Double  = 0.15,
        maxOpacity: Double  = 0.55,
        minRadius:  CGFloat = 4,
        maxRadius:  CGFloat = 20
    ) -> some View {
        modifier(LCPulseGlowModifier(
            color:      color,
            minOpacity: minOpacity,
            maxOpacity: maxOpacity,
            minRadius:  minRadius,
            maxRadius:  maxRadius
        ))
    }
}

// ============================================================
// MARK: - Background
// ============================================================

/// Reusable full-screen background.
/// `showNoise: true` overlays a subtle grain texture for depth.
struct LCBackground: View {
    var showNoise: Bool = true

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [.lcBgStart, .lcBgEnd],
                startPoint: .topLeading,
                endPoint:   .bottomTrailing
            )

            // Optional noise grain
            if showNoise {
                LCNoiseTexture(opacity: 0.028)
            }
        }
        .ignoresSafeArea()
    }
}

/// Deterministic 1-px grain texture drawn with Canvas.
/// Fixed seed → same pattern every render → no flicker.
private struct LCNoiseTexture: View {
    var opacity: Double
    var dotCount: Int = 3_200

    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 0xDEAD_BEEF_1701
            @inline(__always) func next() -> Double {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double(seed >> 11) / Double(UInt64.max >> 11)
            }
            for _ in 0..<dotCount {
                let x = next() * Double(size.width)
                let y = next() * Double(size.height)
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1.2, height: 1.2)),
                    with: .color(.white.opacity(opacity))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.screen)
    }
}

// ============================================================
// MARK: - GlassCard
// ============================================================
//
// Layered depth model (back → front):
//   1. ultraThinMaterial   — base blur + vibrancy
//   2. lcGlassFill         — slight white tint for warmth
//   3. Top-edge highlight  — simulates light source from above
//   4. Gradient stroke     — bright top-left, dim bottom-right
//   5. Glow shadow         — coloured, soft, large radius
//   6. Dark drop shadow    — anchors card to surface

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var glowColor:    Color   = .lcPrimary
    var glowOpacity:  Double  = 0.18
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(cardBackground)
    }

    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return ZStack {
            // 1. Blur base
            shape.fill(.ultraThinMaterial)

            // 2. Glass surface tint
            shape.fill(.lcGlassFill)

            // 3. Inner top-edge highlight
            shape
                .fill(
                    LinearGradient(
                        colors: [.lcGlassHighlight, .clear],
                        startPoint: .top,
                        endPoint:   .init(x: 0.5, y: 0.35)
                    )
                )

            // 4. Gradient stroke (bright top-left → dim bottom-right)
            shape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        // 5. Coloured glow
        .shadow(color: glowColor.opacity(glowOpacity), radius: 32, x: 0, y: 8)
        // 6. Dark anchor shadow
        .shadow(color: .black.opacity(0.40), radius: 14, x: 0, y: 6)
    }
}

// ============================================================
// MARK: - SectionHeader
// ============================================================

struct SectionHeader: View {
    let title:    String
    var subtitle: String? = nil
    var overline: String? = nil   // small-caps label above title

    var body: some View {
        VStack(alignment: .leading, spacing: LCSpacing.xs) {
            if let overline {
                Text(overline.uppercased())
                    .font(LCFont.overline)
                    .foregroundStyle(.lcTextTertiary)
            }

            Text(title)
                .font(LCFont.header)
                .foregroundStyle(.lcTextPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(LCFont.insight)
                    .foregroundStyle(.lcTextSecondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, LCSpacing.xs)
    }
}

// ============================================================
// MARK: - PrimaryButton
// ============================================================
//
// Intentionally restrained gradient — calm, not flashy.
// Press: scale 0.97, light haptic.

struct PrimaryButton: View {
    let label:    String
    var icon:     String?   = nil
    var gradient: [Color]   = [.lcPrimary, .lcLavender]
    var action:   () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: fire) {
            HStack(spacing: LCSpacing.xs) {
                if let icon { Image(systemName: icon) }
                Text(label).fontWeight(.semibold)
            }
            .font(LCFont.body)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .padding(.horizontal, LCSpacing.lg)
            .background(pill)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 0.97 : 1.0)
        .animation(.lcCardLift, value: pressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true  }
                .onEnded   { _ in pressed = false }
        )
    }

    private var pill: some View {
        Capsule(style: .continuous)
            .fill(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint:   .bottomTrailing
                )
                .opacity(0.85)            // intentionally dialled back
            )
            // Glow under button
            .shadow(
                color: (gradient.first ?? .lcPrimary).opacity(0.35),
                radius: 18, x: 0, y: 8
            )
    }

    private func fire() {
        let hap = UIImpactFeedbackGenerator(style: .light)   // light — calm
        hap.impactOccurred()
        action()
    }
}

// ============================================================
// MARK: - ProgressBar
// ============================================================
//
// • easeInOut(0.6) fill animation
// • Gradient fill, fully rounded ends
// • Subtle glow that appears when value is increasing

struct ProgressBar: View {
    var value:      Double
    var maximum:    Double  = 1.0
    var height:     CGFloat = 9
    var gradient:   [Color] = [.lcPrimary, .lcLavender]
    var trackColor: Color   = Color.white.opacity(0.08)
    var showGlow:   Bool    = true

    @State private var animatedFraction: Double = 0
    @State private var isIncreasing:     Bool   = false

    private var fraction: Double {
        maximum > 0 ? min(value / maximum, 1.0) : 0
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule(style: .continuous)
                    .fill(trackColor)

                // Fill
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradient,
                            startPoint: .leading,
                            endPoint:   .trailing
                        )
                    )
                    .frame(width: max(height, geo.size.width * animatedFraction))
                    // Glow on increase
                    .shadow(
                        color: showGlow && isIncreasing
                            ? (gradient.last ?? .lcPrimary).opacity(0.60)
                            : .clear,
                        radius: 10
                    )
            }
        }
        .frame(height: height)
        .onAppear { drive(to: fraction, increasing: false) }
        .onChange(of: fraction) { old, new in
            drive(to: new, increasing: new > old)
        }
    }

    private func drive(to target: Double, increasing: Bool) {
        isIncreasing = increasing
        withAnimation(.lcProgressFill) { animatedFraction = target }
        if increasing {
            // Fade glow out after fill completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeOut(duration: 0.5)) { isIncreasing = false }
            }
        }
    }
}

// ============================================================
// MARK: - ProgressRing
// ============================================================
//
// • AngularGradient arc stroke
// • Line width 8–10 pt
// • Glow pulse fires on each value update

struct ProgressRing: View {
    var value:     Double
    var maximum:   Double   = 1.0
    var size:      CGFloat  = 84
    var lineWidth: CGFloat  = 9
    var gradient:  [Color]  = [.lcPrimary, .lcLavender]
    var trackColor: Color   = Color.white.opacity(0.08)

    @State private var animatedFraction: Double = 0
    @State private var glowRadius:       CGFloat = 4
    @State private var glowOpacity:      Double  = 0.0

    private var fraction: Double {
        maximum > 0 ? min(value / maximum, 1.0) : 0
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    trackColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )

            // Arc
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(
                    AngularGradient(
                        colors: gradient,
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle:   .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                // Glow that pulses on update
                .shadow(
                    color: (gradient.last ?? .lcPrimary).opacity(glowOpacity),
                    radius: glowRadius
                )

            // Centre label
            Text("\(Int(animatedFraction * 100))%")
                .font(LCFont.insight)
                .fontWeight(.medium)
                .foregroundStyle(.lcTextPrimary)
                .contentTransition(.numericText())
        }
        .frame(width: size, height: size)
        .onAppear { animate(to: fraction) }
        .onChange(of: fraction) { _, new in
            animate(to: new)
            triggerGlowPulse()
        }
    }

    private func animate(to target: Double) {
        withAnimation(.lcRingFill) { animatedFraction = target }
    }

    private func triggerGlowPulse() {
        // Burst in, then fade out
        withAnimation(.easeOut(duration: 0.25)) {
            glowOpacity = 0.70
            glowRadius  = 18
        }
        withAnimation(.easeIn(duration: 0.55).delay(0.30)) {
            glowOpacity = 0.0
            glowRadius  = 4
        }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview("Life Compass — Design System") {
    @Previewable @State var progress: Double = 0.62

    ZStack {
        LCBackground(showNoise: true)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: LCSpacing.lg) {

                // ── Hero ─────────────────────────────────────
                VStack(alignment: .leading, spacing: LCSpacing.xs) {
                    Text("Life Compass")
                        .font(LCFont.largeTitle)
                        .foregroundStyle(.lcTextPrimary)
                    Text("Sunday, March 22")
                        .font(LCFont.insight)
                        .foregroundStyle(.lcTextTertiary)
                }
                .softAppear(delay: 0.05)

                // ── Ring card ────────────────────────────────
                GlassCard(glowColor: .lcLavender, glowOpacity: 0.22) {
                    HStack(spacing: LCSpacing.md) {
                        ProgressRing(
                            value: progress,
                            size: 96,
                            lineWidth: 9,
                            gradient: [.lcPrimary, .lcLavender]
                        )

                        VStack(alignment: .leading, spacing: LCSpacing.xs) {
                            SectionHeader(
                                title: "Weekly Goal",
                                subtitle: "You're making steady progress. Keep going.",
                                overline: "Focus"
                            )
                        }
                    }
                    .padding(LCSpacing.md)
                }
                .cardLift()
                .softAppear(delay: 0.12)

                // ── Mindfulness card ─────────────────────────
                GlassCard(glowColor: .lcGold, glowOpacity: 0.16) {
                    VStack(alignment: .leading, spacing: LCSpacing.sm) {
                        SectionHeader(
                            title: "Mindfulness",
                            subtitle: "21 of 30 days complete",
                            overline: "Streak"
                        )
                        ProgressBar(
                            value: 21, maximum: 30,
                            height: 10,
                            gradient: [.lcGold, .lcBeige]
                        )
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.20)

                // ── Sleep card ───────────────────────────────
                GlassCard(glowColor: .lcPrimary, glowOpacity: 0.14) {
                    VStack(alignment: .leading, spacing: LCSpacing.sm) {
                        SectionHeader(
                            title: "Sleep Quality",
                            subtitle: "7 h 20 min · Good",
                            overline: "Last Night"
                        )
                        ProgressBar(
                            value: 0.78, maximum: 1.0,
                            height: 10,
                            gradient: [.lcPrimary, .lcLavender]
                        )
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.26)

                // ── Palette ──────────────────────────────────
                GlassCard {
                    VStack(alignment: .leading, spacing: LCSpacing.sm) {
                        Text("COLOUR PALETTE")
                            .font(LCFont.overline)
                            .foregroundStyle(.lcTextTertiary)

                        HStack(spacing: LCSpacing.md) {
                            ForEach(
                                [
                                    ("Primary",  Color.lcPrimary),
                                    ("Gold",     Color.lcGold),
                                    ("Lavender", Color.lcLavender),
                                    ("Beige",    Color.lcBeige),
                                ],
                                id: \.0
                            ) { name, color in
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(color.opacity(0.85))
                                        .frame(width: 38, height: 38)
                                        .shadow(color: color.opacity(0.50), radius: 10)
                                    Text(name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.lcTextTertiary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(LCSpacing.md)
                }
                .softAppear(delay: 0.32)

                // ── CTA ──────────────────────────────────────
                PrimaryButton(label: "Begin Session", icon: "moon.stars") {
                    withAnimation(.lcProgressFill) {
                        progress = Double.random(in: 0.15...1.0)
                    }
                }
                .frame(maxWidth: .infinity)
                .softAppear(delay: 0.38)

                Text("Tap to update the ring and bars above.")
                    .font(LCFont.insight)
                    .foregroundStyle(.lcTextTertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .softAppear(delay: 0.44)
            }
            .padding(.horizontal, LCSpacing.md)
            .padding(.top,        LCSpacing.xl)
            .padding(.bottom,     LCSpacing.xxl)
        }
    }
    .preferredColorScheme(.dark)
}
