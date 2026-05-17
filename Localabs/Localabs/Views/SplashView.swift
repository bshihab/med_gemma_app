import SwiftUI
import UIKit

/// Animated splash with a "content emerging from the heart" reveal.
/// The splash sits on top of ContentView (composed by the parent in
/// a ZStack) and renders a white + chip overlay with a heart-shaped
/// HOLE punched through it. During the pulse phase the hole is
/// small (a heartbeat-sized window) — then in the zoom phase the
/// hole grows past the screen, so ContentView naturally fills the
/// visible area. No fade-out is needed at the end: once the hole
/// exceeds the screen, the splash is invisible, and the parent can
/// dismiss it silently.
///
/// Every animation is GPU-driven: the splash overlay is a flat
/// raster, the chip is an Image, the mask scale is a hardware
/// texture sample. Each animated property uses its own
/// `keyframeAnimator` with the same trigger so SwiftUI requests
/// ProMotion's 120Hz refresh on iPhone 17.
struct SplashView: View {
    var onComplete: () -> Void

    @State private var animationTrigger: Bool = false

    /// Chip's base render size before zoom — matches the brand
    /// mark's natural sticker size on iPhone screens.
    private let chipBase: CGFloat = 160
    /// Heart hole base diameter — matches the brand's heart-inside-
    /// chip proportions.
    private let heartBase: CGFloat = 60

    var body: some View {
        ZStack {
            // White + chip overlay with a heart-shaped hole. The
            // chip is an animatable Image (scaleEffect + opacity);
            // the hole is inside a mask closure with its own
            // keyframeAnimator that drives the pulse + portal-scale
            // sequence as one continuous track.
            chipOverlay
                .mask {
                    Rectangle()
                        .ignoresSafeArea()
                        .overlay { heartHole }
                        .compositingGroup()
                }

            wordmark
        }
        .onAppear {
            animationTrigger.toggle()
            // Total keyframe runtime ~1.62s. Fire onComplete just
            // past the end — by that point the heart hole has
            // exceeded any iPhone screen by ~6×, so the parent
            // dismissing the splash is invisible (ContentView is
            // already fully visible).
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                onComplete()
            }
        }
    }

    // MARK: - Subviews

    private var chipOverlay: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Image("LocalabsChip")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: chipBase, height: chipBase)
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: animationTrigger
                ) { content, scale in
                    content.scaleEffect(scale, anchor: .center)
                } keyframes: { _ in
                    KeyframeTrack {
                        // Holds at 1.0 through the pulses, then
                        // grows during the zoom so the chip flies
                        // past the camera.
                        LinearKeyframe(1.0, duration: 1.07)
                        CubicKeyframe(8.0, duration: 0.55)
                    }
                }
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: animationTrigger
                ) { content, opacity in
                    content.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack {
                        // Chip fades out as the zoom begins so it
                        // doesn't visually compete with the
                        // expanding heart hole.
                        LinearKeyframe(1.0, duration: 1.20)
                        CubicKeyframe(0.0, duration: 0.35)
                    }
                }
        }
        .compositingGroup()
    }

    private var heartHole: some View {
        Image(systemName: "heart.fill")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: heartBase, height: heartBase)
            .keyframeAnimator(
                initialValue: 1.0,
                trigger: animationTrigger
            ) { content, scale in
                content.scaleEffect(scale, anchor: .center)
            } keyframes: { _ in
                // Single track that pulses 5× then ramps past the
                // screen. Combining the pulse and the zoom into
                // one keyframe sequence keeps the transition
                // seamless — the racing pulse peak hands off
                // directly into the zoom acceleration with no gap.
                KeyframeTrack {
                    // beat 1 — ~75 bpm
                    CubicKeyframe(1.18, duration: 0.20)
                    CubicKeyframe(1.00, duration: 0.20)
                    // beat 2 — ~105 bpm
                    CubicKeyframe(1.22, duration: 0.14)
                    CubicKeyframe(1.00, duration: 0.14)
                    // beat 3 — ~150 bpm
                    CubicKeyframe(1.26, duration: 0.10)
                    CubicKeyframe(1.00, duration: 0.10)
                    // beat 4 — ~200 bpm
                    CubicKeyframe(1.30, duration: 0.07)
                    CubicKeyframe(1.00, duration: 0.07)
                    // beat 5 — racing peak, holds briefly
                    CubicKeyframe(1.35, duration: 0.05)
                    // ZOOM — heart hole grows past the screen.
                    // 60× makes it exceed any iPhone screen by ~6×,
                    // so the user sees ContentView with no visible
                    // hole boundary at the end of the animation.
                    CubicKeyframe(60.0, duration: 0.55)
                }
            }
            .blendMode(.destinationOut)
    }

    private var wordmark: some View {
        Text("Localabs")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)
            .offset(y: 130)
            .keyframeAnimator(
                initialValue: 1.0,
                trigger: animationTrigger
            ) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1.0, duration: 0.95)
                    CubicKeyframe(0.0, duration: 0.20)
                }
            }
    }
}

/// Layered logo built from the user's brand PNGs. Kept around so
/// the existing LogoExportTool + Profile "Export Logo Layers" dev
/// button can still produce per-layer renders without re-introducing
/// the SwiftUI vector recreation.
struct LocalabsLogo: View {
    enum Layer {
        case full
        case chipOnly
        case heartOnly
    }

    var size: CGFloat = 140
    var heartScale: CGFloat = 1.0
    var layer: Layer = .full

    var body: some View {
        ZStack {
            if layer != .heartOnly {
                Image("LocalabsChip")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            }
            if layer != .chipOnly {
                Image("LocalabsHeart")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .scaleEffect(heartScale, anchor: .center)
            }
        }
        .frame(width: size, height: size)
    }
}
