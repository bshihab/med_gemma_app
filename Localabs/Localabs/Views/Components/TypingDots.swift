import SwiftUI

/// iMessage-style three-dot typing indicator. Three small circles
/// bounce in sequence (left → middle → right) inside a glass
/// capsule, so the chat shows "Localabs is thinking" the same way
/// iMessage shows "the other person is typing." Used by both the
/// document follow-up chat and the trends chat.
///
/// Implementation uses `TimelineView(.animation)` rather than
/// chained `withAnimation` calls so the dots animate on
/// CADisplayLink's refresh schedule — smooth at ProMotion's 120Hz
/// on iPhone 17 without per-cycle re-scheduling.
struct TypingDots: View {
    /// Tunes the cadence. ~1.2s gives a calm, deliberate pulse
    /// that doesn't feel anxious during a long generation.
    private let cycleDuration: Double = 1.2

    var body: some View {
        TimelineView(.animation) { timeline in
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(scale(for: index, at: timeline.date))
                        .opacity(opacity(for: index, at: timeline.date))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: Capsule())
        }
    }

    /// Each dot is offset by 1/3 of a cycle so they pulse in a
    /// rolling left-to-right rhythm rather than in unison.
    private func phase(for index: Int, at date: Date) -> Double {
        let t = date.timeIntervalSinceReferenceDate
        let offset = Double(index) / 3.0
        let progress = (t / cycleDuration + offset).truncatingRemainder(dividingBy: 1)
        return progress
    }

    private func scale(for index: Int, at date: Date) -> CGFloat {
        // sin curve over the cycle — 0 at start/end, peak in
        // the middle. Mapped to [0.78, 1.20].
        let curve = sin(phase(for: index, at: date) * .pi)
        return 0.78 + 0.42 * curve
    }

    private func opacity(for index: Int, at date: Date) -> Double {
        // Slight fade alongside the scale for a softer feel.
        // Each dot dims a bit at its valley so the rolling
        // rhythm reads more clearly.
        let curve = sin(phase(for: index, at: date) * .pi)
        return 0.40 + 0.60 * curve
    }
}
