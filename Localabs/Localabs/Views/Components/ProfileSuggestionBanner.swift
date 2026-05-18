import SwiftUI

/// Inline glass banner rendered under a chat bubble when Localabs
/// noticed a profile-worthy fact in the conversation. Two flavors,
/// distinguished by the suggestion's `source`:
///
///   - `.userStated` — the user typed something like "I take
///     metformin" and the post-message scanner caught it. Banner
///     copy: *"Add 'metformin' to your medications?"*
///   - `.modelRequested` — the model emitted a `[PROFILE_ADD: …]`
///     signal asking to remember a fact for future personalization.
///     Banner copy: *"Localabs suggests adding 'metformin' …"*
///
/// The user is always in control: Add writes to UserProfile, Dismiss
/// removes the banner without touching the profile. After Add, the
/// banner briefly shows a ✓ confirmation before dismissing itself.
struct ProfileSuggestionBanner: View {
    let suggestion: ProfileSuggestion
    /// Called once when the user taps Add OR Dismiss — caller is
    /// responsible for removing the banner from its state.
    var onDecision: (Decision) -> Void

    enum Decision { case added, dismissed }

    @State private var didAdd: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Source-distinguishing icon. Person-plus for user-stated
            // (the user is the source), sparkles for model-requested
            // (Localabs is the source). Keeps the user oriented to
            // why this banner appeared without needing to read the
            // body copy.
            Image(systemName: didAdd ? "checkmark.circle.fill" : sourceIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(didAdd ? .green : sourceTint)
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 1) {
                Text(didAdd ? "Added to your profile" : headline)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !didAdd {
                    Text("Add to \(suggestion.field.label)?")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            if !didAdd {
                Button {
                    didAdd = true
                    // Brief ✓ confirmation, then bubble back up so the
                    // caller can remove the banner from its state.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        onDecision(.added)
                    }
                } label: {
                    Text("Add")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .glassEffect(
                            .regular.tint(sourceTint.opacity(0.85)).interactive(),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onDecision(.dismissed)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
    }

    /// Banner headline — quotes the value so the user sees exactly
    /// what would be saved before they tap Add. Falls back to the
    /// raw value if it's too long to inline.
    private var headline: String {
        let value = suggestion.value
        let display = value.count > 50 ? "\(value.prefix(50))…" : value
        switch suggestion.source {
        case .userStated:
            return "Add \"\(display)\" to your profile?"
        case .modelRequested:
            return "Localabs suggests remembering \"\(display)\""
        }
    }

    private var sourceIcon: String {
        switch suggestion.source {
        case .userStated:     return "person.crop.circle.badge.plus"
        case .modelRequested: return "sparkles"
        }
    }

    private var sourceTint: Color {
        switch suggestion.source {
        case .userStated:     return .blue
        case .modelRequested: return .yellow
        }
    }
}
