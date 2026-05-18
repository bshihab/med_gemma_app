import Foundation

struct UserProfile: Codable {
    var age: String = ""
    var biologicalSex: String = ""
    /// Free-form text when `biologicalSex == "Other"` — captures the
    /// user's own description instead of just storing the literal word.
    /// Empty otherwise.
    var biologicalSexOther: String = ""
    var bloodType: String = ""
    var smoking: String = ""
    var alcohol: String = ""
    /// Free-form text — captures relatives, conditions, ages of onset.
    /// e.g. "Mom: breast cancer at 50, Dad: heart attack at 65". A
    /// picker is too restrictive for the meaningful detail here
    /// (maternal vs paternal side, multiple conditions per relative).
    var familyHistory: String = ""
    var medicalConditions: String = ""
    var medications: String = ""
    var onboardingComplete: Bool = false

    private static let storageKey = "localabs_user_profile"

    static func load() -> UserProfile {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return UserProfile()
        }
        return profile
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    static func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Whether the user has supplied enough demographics for the
    /// Trends tab to attach Typical / Borderline / Outside-typical
    /// labels to their metrics. Both age and biological sex are
    /// required: population norms for resting HR, HRV, sleep, walking
    /// speed, etc. shift meaningfully with both, so colouring a status
    /// without them would be at best generic and at worst misleading
    /// (e.g. "60–80 bpm typical" is for adults in general; an athlete
    /// in their 20s vs. a 70-year-old read those numbers differently).
    /// Users who skip these fields see no status pills at all.
    var hasDemographicsForStatusLabels: Bool {
        !age.trimmingCharacters(in: .whitespaces).isEmpty
            && !biologicalSex.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Applies a chat-derived suggestion to the matching profile
    /// field. Multi-line fields (medications, conditions, family
    /// history) get a newline-separated append so the user can see
    /// the accumulated set in their profile; single-value fields
    /// (age, blood type, biological sex, smoking, alcohol) overwrite
    /// only when blank — we never replace a value the user has
    /// already filled in manually. Returns true when the profile
    /// actually changed (so callers can show "✓ Added" feedback only
    /// for real writes, not duplicates).
    mutating func apply(_ suggestion: ProfileSuggestion) -> Bool {
        let value = suggestion.value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }

        switch suggestion.field {
        case .medications:
            return appendUnique(value: value, to: \.medications)
        case .medicalConditions:
            return appendUnique(value: value, to: \.medicalConditions)
        case .familyHistory:
            return appendUnique(value: value, to: \.familyHistory)
        case .smoking:
            return setIfEmpty(value: value, on: \.smoking)
        case .alcohol:
            return setIfEmpty(value: value, on: \.alcohol)
        case .bloodType:
            return setIfEmpty(value: value, on: \.bloodType)
        case .age:
            return setIfEmpty(value: value, on: \.age)
        case .biologicalSex:
            return setIfEmpty(value: value, on: \.biologicalSex)
        }
    }

    /// Helper: append `value` as a new line to a multi-line field,
    /// skipping the write if the field already contains that value
    /// (case-insensitive). Prevents duplicate "Diabetes" / "diabetes"
    /// entries when the same suggestion comes up across multiple
    /// chats.
    private mutating func appendUnique(value: String, to keyPath: WritableKeyPath<UserProfile, String>) -> Bool {
        let current = self[keyPath: keyPath]
        let needle = value.lowercased()
        let existing = current.split(separator: "\n").map { $0.lowercased() }
        if existing.contains(needle) { return false }
        self[keyPath: keyPath] = current.isEmpty ? value : "\(current)\n\(value)"
        return true
    }

    /// Helper: set a single-value field only when it's currently
    /// empty. We never overwrite a manually-entered value with a
    /// chat-derived one — the user's explicit input is authoritative.
    private mutating func setIfEmpty(value: String, on keyPath: WritableKeyPath<UserProfile, String>) -> Bool {
        let current = self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
        guard current.isEmpty else { return false }
        self[keyPath: keyPath] = value
        return true
    }

    /// Formatted bullet list of every onboarding field that's been
    /// filled in. Inserted into both the lab-analysis prompt and the
    /// follow-up chat prompt so the model has the user's age, sex,
    /// blood type, family history, etc. as context — reference
    /// ranges for many lab values shift with these variables and the
    /// AI should weight findings accordingly. Empty fields are
    /// skipped rather than rendered as "None" so the prompt stays
    /// tight on users who only filled in a subset.
    var promptContextBullets: String {
        var lines: [String] = []
        if !age.isEmpty { lines.append("- Age: \(age)") }
        if !biologicalSex.isEmpty {
            let sex = biologicalSex == "Other" && !biologicalSexOther.isEmpty
                ? "Other (\(biologicalSexOther))"
                : biologicalSex
            lines.append("- Biological Sex: \(sex)")
        }
        if !bloodType.isEmpty { lines.append("- Blood Type: \(bloodType)") }
        if !smoking.isEmpty { lines.append("- Tobacco / E-cig: \(smoking)") }
        if !alcohol.isEmpty { lines.append("- Alcohol: \(alcohol)") }
        if !familyHistory.isEmpty { lines.append("- Family History: \(familyHistory)") }
        if !medicalConditions.isEmpty { lines.append("- Known Medical Conditions: \(medicalConditions)") }
        if !medications.isEmpty { lines.append("- Current Daily Medications: \(medications)") }
        return lines.isEmpty ? "- No profile context provided." : lines.joined(separator: "\n        ")
    }
}
