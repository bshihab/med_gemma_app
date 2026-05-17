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
