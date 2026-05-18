import Foundation

/// A piece of personal-health info Localabs picked up from a chat
/// conversation that *could* be added to the user's profile —
/// pending the user's explicit Add tap.
///
/// Two sources feed into this shape:
///   - `userStated` (Option B): the user typed something like "I take
///     metformin" and the post-message scanner caught it.
///   - `modelRequested` (Option A): the LLM emitted a structured
///     `[PROFILE_ADD: field = "..."]` signal asking to remember a
///     fact it deemed important for personalization.
///
/// In both cases the user is the gatekeeper — nothing writes to
/// `UserProfile` without an explicit Add tap. The two sources differ
/// only in the banner copy and icon so the user knows where the
/// suggestion came from.
struct ProfileSuggestion: Identifiable, Equatable, Hashable {
    let id = UUID()
    /// Which profile field this suggestion targets. Matches the
    /// field name on `UserProfile` exactly so `apply(...)` can route
    /// without a separate switch.
    let field: Field
    /// The value to append (or set) for `field`. Already trimmed and
    /// title-cased where it makes sense.
    let value: String
    let source: Source

    enum Field: String, Codable {
        case medications
        case medicalConditions
        case familyHistory
        case smoking
        case alcohol
        case bloodType
        case age
        case biologicalSex

        /// Human-readable label for banner copy ("Add to medications").
        var label: String {
            switch self {
            case .medications:        return "medications"
            case .medicalConditions:  return "medical conditions"
            case .familyHistory:      return "family history"
            case .smoking:            return "smoking / vaping"
            case .alcohol:            return "alcohol"
            case .bloodType:          return "blood type"
            case .age:                return "age"
            case .biologicalSex:      return "biological sex"
            }
        }
    }

    enum Source: Equatable, Hashable {
        /// User explicitly stated this in their own message.
        case userStated
        /// Model requested this via a `[PROFILE_ADD: ...]` signal.
        case modelRequested
    }
}
