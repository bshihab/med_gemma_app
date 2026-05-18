import SwiftUI

/// Drives the "Add to your profile?" popup that appears whenever a
/// chat surfaces a new `ProfileSuggestion` — either from the
/// user-message scanner (Option B) or from a `[PROFILE_ADD: …]`
/// signal the model emitted (Option A).
///
/// Suggestions are held in a FIFO queue on the caller's `@State`.
/// The modifier presents a SwiftUI alert bound to `queue.first`:
///
///   - "Add" → applies the suggestion via `UserProfile.apply(...)`,
///     persists, removes from queue. If the queue still has items,
///     SwiftUI immediately re-presents the alert with the next one.
///   - "Skip" → just removes the head item.
///
/// Replaced the previous inline-banner UI. Users were missing
/// banners that sat under chat bubbles — especially when the AI's
/// reply above said something reassuring like "I'll keep that in
/// mind", which read as confirmation that the fact was already
/// saved. A modal alert is unmissable and forces an explicit
/// decision.
struct ProfileSuggestionAlertModifier: ViewModifier {
    @Binding var queue: [ProfileSuggestion]

    func body(content: Content) -> some View {
        content.alert(
            "Add to your profile?",
            isPresented: Binding(
                get: { !queue.isEmpty },
                set: { presenting in
                    // The alert can be dismissed via its buttons
                    // only — the buttons already pop from the queue.
                    // This setter exists to satisfy the API; we
                    // intentionally ignore programmatic dismissal so
                    // the queue is the single source of truth.
                    if !presenting && !queue.isEmpty {
                        // SwiftUI sometimes calls this on re-render
                        // even when we want to stay presented for the
                        // next item. No-op if the queue still has
                        // something — the binding will become true
                        // again on the next render.
                    }
                }
            ),
            presenting: queue.first
        ) { suggestion in
            Button("Add to Profile") {
                applyAndAdvance(suggestion)
            }
            Button("Skip", role: .cancel) {
                advance()
            }
        } message: { suggestion in
            Text(messageFor(suggestion))
        }
    }

    /// Writes the suggestion to UserProfile (via the field-aware
    /// apply method that dedupes and respects manual entries) then
    /// removes the head item so the next suggestion in the queue
    /// can present.
    private func applyAndAdvance(_ suggestion: ProfileSuggestion) {
        var profile = UserProfile.load()
        if profile.apply(suggestion) {
            profile.save()
        }
        advance()
    }

    /// Pops the head item. Safe even if the queue raced and is now
    /// empty (rare, but possible if multiple alerts get scheduled
    /// at once).
    private func advance() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }

    /// Alert body copy. User-stated suggestions get a "You
    /// mentioned …" framing; model-requested ones get a "Localabs
    /// suggests adding …" framing so the user knows where the
    /// suggestion came from.
    private func messageFor(_ suggestion: ProfileSuggestion) -> String {
        let value = suggestion.value
        let displayValue = value.count > 60 ? "\(value.prefix(60))…" : value
        switch suggestion.source {
        case .userStated:
            return "You mentioned \"\(displayValue)\" in chat.\n\nAdd this to your \(suggestion.field.label)?"
        case .modelRequested:
            return "Localabs suggests adding \"\(displayValue)\" to your \(suggestion.field.label).\n\nThis helps future answers reference your real context — you stay in control of what's saved."
        }
    }
}

extension View {
    /// Attaches the profile-suggestion popup queue to a view. The
    /// queue is a binding the caller owns; this modifier just
    /// presents alerts bound to the head item and pops on each
    /// user decision.
    func profileSuggestionAlert(queue: Binding<[ProfileSuggestion]>) -> some View {
        modifier(ProfileSuggestionAlertModifier(queue: queue))
    }
}
