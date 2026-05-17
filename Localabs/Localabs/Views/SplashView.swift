import SwiftUI
import UIKit

/// Animated splash screen shown briefly when the app launches. Plays
/// a subtle pulse on the heart logo, then zooms into the heart while
/// fading to white before handing off to ContentView. Mirrors what
/// the iOS launch screen renders statically so the transition from
/// system-level launch to app-level splash is visually seamless.
struct SplashView: View {
    /// Called when the zoom animation completes. The parent should
    /// flip its state to dismiss the splash and reveal ContentView.
    var onComplete: () -> Void

    /// Toggled once in .onAppear to fire the keyframe timeline. A
    /// single keyframeAnimator drives ALL animated values (pulse,
    /// zoom, opacity) off CADisplayLink — that's what lets SwiftUI
    /// request ProMotion's high refresh rate on iPhone 17. The old
    /// chained DispatchQueue + withAnimation pattern fired ~10
    /// independent short animations and never qualified for the
    /// 120Hz path, so the splash felt like it was running at 30fps.
    @State private var animationTrigger: Bool = false

    /// All animated values bundled into one struct so a single
    /// `keyframeAnimator` block can drive them as a coordinated
    /// timeline. Each property gets its own KeyframeTrack below.
    private struct Beats {
        var heartScale: CGFloat = 1.0
        var zoomScale: CGFloat = 1.0
        var contentOpacity: Double = 1.0
        var wordmarkOpacity: Double = 1.0
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            // Single keyframeAnimator drives the entire splash —
            // pulse + zoom + opacity on one timeline. The animator
            // schedules against CADisplayLink, which is what
            // qualifies for ProMotion's 120Hz refresh on iPhone 17.
            // Inside the animator's content builder, the chip and
            // heart are stacked separately so heartScale only
            // applies to the heart (chip + pins stay still during
            // the pulse).
            ZStack {
                LocalabsLogo(layer: .chipOnly)
                    .keyframeAnimator(
                        initialValue: Beats(),
                        trigger: animationTrigger
                    ) { content, beats in
                        content
                            .overlay(
                                LocalabsLogo(layer: .heartOnly)
                                    .scaleEffect(beats.heartScale, anchor: .center)
                            )
                            .scaleEffect(beats.zoomScale, anchor: .center)
                            .opacity(beats.contentOpacity)
                    } keyframes: { _ in
                        // Heartbeat: 5 accelerating pulses, then a
                        // hold while the zoom takes over. Durations
                        // ~40% longer than the previous version —
                        // earlier timing felt rushed; now the user
                        // has time to register each beat before the
                        // tempo shifts.
                        KeyframeTrack(\.heartScale) {
                            // beat 1 — slow (~45 bpm)
                            CubicKeyframe(1.10, duration: 0.45)
                            CubicKeyframe(1.00, duration: 0.45)
                            // beat 2 — ~65 bpm
                            CubicKeyframe(1.13, duration: 0.32)
                            CubicKeyframe(1.00, duration: 0.32)
                            // beat 3 — ~95 bpm
                            CubicKeyframe(1.17, duration: 0.22)
                            CubicKeyframe(1.00, duration: 0.22)
                            // beat 4 — ~140 bpm
                            CubicKeyframe(1.22, duration: 0.14)
                            CubicKeyframe(1.00, duration: 0.14)
                            // beat 5 — ~200 bpm (racing) — hold the
                            // peak so it merges into the zoom.
                            CubicKeyframe(1.30, duration: 0.10)
                        }

                        // Zoom holds at 1.0 through the pulses, then
                        // accelerates to 22× over 0.8s. EaseIn for the
                        // "flying in" feel.
                        KeyframeTrack(\.zoomScale) {
                            LinearKeyframe(1.0, duration: 2.62)
                            CubicKeyframe(22.0, duration: 0.80)
                        }

                        // Splash opacity stays full through pulse +
                        // zoom; fades to 0 only at the end, after
                        // the white heart has filled the screen.
                        KeyframeTrack(\.contentOpacity) {
                            LinearKeyframe(1.0, duration: 3.17)
                            CubicKeyframe(0.0, duration: 0.25)
                        }

                        // Wordmark fades out at the moment the racing
                        // pulse hits, so it doesn't visually compete
                        // with the zoom that follows.
                        KeyframeTrack(\.wordmarkOpacity) {
                            LinearKeyframe(1.0, duration: 2.20)
                            CubicKeyframe(0.0, duration: 0.30)
                        }
                    }
            }

            // Wordmark is OUTSIDE the keyframeAnimator's content
            // intentionally — it has its own opacity track that
            // happens to share `wordmarkOpacity`, but it doesn't
            // need to share the zoom/pulse transforms.
            Text("Localabs")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .offset(y: 140)
                .keyframeAnimator(
                    initialValue: 1.0,
                    trigger: animationTrigger
                ) { content, opacity in
                    content.opacity(opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        LinearKeyframe(1.0, duration: 1.55)
                        CubicKeyframe(0.0, duration: 0.25)
                    }
                }
        }
        .onAppear {
            animationTrigger.toggle()
            // Total keyframe runtime ~3.42s with the slower pacing
            // (~40% longer beats). Fire onComplete just past the
            // end so the last frame renders before ContentView
            // takes over.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.45) {
                onComplete()
            }
        }
    }
}

/// Localabs · Option C logo, drawn entirely in SwiftUI so it stays
/// crisp through the 12× zoom animation. Layout matches the brand
/// spec: blue-gradient rounded-square "chip", a clean white heart
/// centered inside, 5 rectangular pins on each of the four sides
/// extending outward, and faint horizontal/vertical trace strokes
/// inside the chip that feed in from each pin.
struct LocalabsLogo: View {
    enum Layer {
        case full
        /// Chip body + pins + traces. No heart. Used when exporting
        /// PNGs for Icon Composer — the chip becomes one layer of
        /// the layered `.icon` file.
        case chipOnly
        /// Just the white heart, positioned where it would sit in
        /// the full logo. Transparent everywhere else. Stacked on
        /// top of `.chipOnly` it reproduces the full logo.
        case heartOnly
    }

    var size: CGFloat = 140
    /// Scale applied to just the heart, so the splash can pulse the
    /// heart by itself while the chip + pins stay still. Default 1.0
    /// (no pulse) for non-animated use.
    var heartScale: CGFloat = 1.0
    /// Which subset of the logo to render. Defaults to the full
    /// composite for the splash + any other in-app usage; the export
    /// tool flips this to `.chipOnly` / `.heartOnly` to save layered
    /// PNGs for Icon Composer.
    var layer: Layer = .full

    var body: some View {
        // Both PNG assets are exported from Icon Composer at
        // 1024×1024 with the same canvas alignment — the heart sits
        // exactly where it should over the chip — so stacking them
        // in a ZStack at matching frame sizes reproduces the full
        // logo with zero positioning math. Image() with .resizable()
        // is rendered as a GPU texture, so scaling it (for the
        // splash's pulse and zoom) is a hardware texture-sample op
        // rather than a vector re-rasterization — that's what makes
        // the splash animation smooth at any scale.
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
