import Foundation

/// Extracts `ProfileSuggestion`s from chat content. Two surfaces:
///
///   1. **User-message scanner** (`extractFromUserMessage`): regex
///      patterns over the user's own typed text. Catches explicit
///      self-statements like "I take metformin" or "I have type 2
///      diabetes." Purely pattern-based — never asks the model.
///
///   2. **Model-signal parser** (`extractFromModelOutput`): looks for
///      `[PROFILE_ADD: <field> = "<value>"]` markers the chat prompt
///      instructs the model to emit when it needs profile info. The
///      parser returns the cleaned text (markers stripped) plus the
///      suggestions it found, so the chat bubble shows natural prose
///      to the user without the bracketed signals leaking through.
///
/// Both surfaces are pure functions — no I/O, no async, no model
/// calls. The actual UI banners + apply-to-profile logic live in the
/// chat views; this service only knows how to identify candidates.
enum ProfileSuggestionService {

    // MARK: - User-stated scanner (Option B)

    /// Scans a user-typed chat message for self-statements that look
    /// like profile-worthy facts. The patterns are intentionally
    /// conservative — better to miss a marginal case than to surface
    /// a confusing "Add 'Tuesday' to your medications?" banner.
    /// Each match becomes a `.userStated` suggestion.
    static func extractFromUserMessage(_ text: String) -> [ProfileSuggestion] {
        // Lowercase once, but keep `text` around for capturing the
        // original-case medication name / condition.
        let lowered = text.lowercased()
        var found: [ProfileSuggestion] = []

        // — Medications — "I take X" / "I'm on X" / "I'm taking X"
        let medPatterns = [
            #"i\s+take\s+([a-z][a-z0-9\-\s]{2,40}?)(?:\s+(?:for|every|daily|each|once|twice|in|to)|[.,!?\n]|$)"#,
            #"i'?m\s+(?:on|taking)\s+([a-z][a-z0-9\-\s]{2,40}?)(?:\s+(?:for|every|daily|each|once|twice|in|to)|[.,!?\n]|$)"#,
            #"prescribed\s+([a-z][a-z0-9\-\s]{2,40}?)(?:\s+(?:for|every|daily|each|once|twice|in|to)|[.,!?\n]|$)"#
        ]
        for pattern in medPatterns {
            for value in captures(pattern, in: lowered, original: text) {
                let cleaned = cleanFragment(value)
                guard isPlausibleMedicationOrCondition(cleaned) else { continue }
                found.append(ProfileSuggestion(field: .medications, value: cleaned, source: .userStated))
            }
        }

        // — Conditions — "I have X" / "I was diagnosed with X" / "I have
        //   been diagnosed with X". Defends against pronouns ("I have
        //   a question") via plausibility check.
        let conditionPatterns = [
            #"i\s+have\s+([a-z][a-z0-9\-\s]{2,50}?)(?:\s+(?:and|but|so|since|because|that|which|now|recently)|[.,!?\n]|$)"#,
            #"diagnosed\s+with\s+([a-z][a-z0-9\-\s]{2,50}?)(?:\s+(?:and|but|in|at|since|recently)|[.,!?\n]|$)"#,
            #"i'?m\s+(?:diabetic|hypertensive|asthmatic|hypothyroid|hyperthyroid)"#
        ]
        for pattern in conditionPatterns {
            for value in captures(pattern, in: lowered, original: text) {
                let cleaned = cleanFragment(value)
                guard isPlausibleMedicationOrCondition(cleaned) else { continue }
                found.append(ProfileSuggestion(field: .medicalConditions, value: cleaned, source: .userStated))
            }
            // Adjective-form mentions ("I'm diabetic") — captured by
            // the third pattern, expanded into the canonical noun.
            if pattern.contains("diabetic") {
                if lowered.contains("i'm diabetic") || lowered.contains("i am diabetic") {
                    found.append(ProfileSuggestion(field: .medicalConditions, value: "Diabetes", source: .userStated))
                }
                if lowered.contains("i'm hypertensive") || lowered.contains("i am hypertensive") {
                    found.append(ProfileSuggestion(field: .medicalConditions, value: "Hypertension", source: .userStated))
                }
                if lowered.contains("i'm asthmatic") || lowered.contains("i am asthmatic") {
                    found.append(ProfileSuggestion(field: .medicalConditions, value: "Asthma", source: .userStated))
                }
            }
        }

        // — Smoking / vaping — phrasing-based
        if matchesAny(lowered, [
            #"i\s+smoke\b"#,
            #"i'?m\s+a\s+smoker"#,
            #"i\s+vape\b"#,
            #"i\s+use\s+(an?\s+)?(e[\-\s]?cig|vape)"#
        ]) {
            let value: String
            if lowered.contains("vape") || lowered.contains("e-cig") || lowered.contains("ecig") || lowered.contains("e cig") {
                value = "Vapes / E-cigs"
            } else {
                value = "Smokes"
            }
            found.append(ProfileSuggestion(field: .smoking, value: value, source: .userStated))
        }

        // — Alcohol — fast triggers; quantitative parsing is overkill.
        if matchesAny(lowered, [
            #"i\s+drink\s+(?:alcohol|wine|beer|whiskey|liquor|spirits)"#,
            #"i'?m\s+a\s+(?:drinker|social\s+drinker)"#
        ]) {
            found.append(ProfileSuggestion(field: .alcohol, value: "Drinks alcohol", source: .userStated))
        }

        // — Family history — "my mom/dad/mother/father/sister/brother has X"
        let famPattern = #"my\s+(mom|dad|mother|father|brother|sister|grandma|grandpa|grandfather|grandmother|aunt|uncle)\s+(?:has|had)\s+([a-z][a-z0-9\-\s]{2,50}?)(?:[.,!?\n]|$)"#
        if let regex = try? NSRegularExpression(pattern: famPattern, options: []) {
            let nsRange = NSRange(lowered.startIndex..., in: lowered)
            let matches = regex.matches(in: lowered, range: nsRange)
            for match in matches {
                guard match.numberOfRanges >= 3,
                      let relRange = Range(match.range(at: 1), in: lowered),
                      let conditionRange = Range(match.range(at: 2), in: lowered)
                else { continue }
                let relative = String(lowered[relRange]).capitalized
                let condition = cleanFragment(String(lowered[conditionRange]))
                guard isPlausibleMedicationOrCondition(condition) else { continue }
                let formatted = "\(relative): \(condition)"
                found.append(ProfileSuggestion(field: .familyHistory, value: formatted, source: .userStated))
            }
        }

        // — Age — "I'm 34" / "I am 34 years old"
        if let age = firstCapture(#"i'?m\s+(\d{1,3})(?:\s+years?\s+old)?\b"#, in: lowered) ??
                     firstCapture(#"i\s+am\s+(\d{1,3})(?:\s+years?\s+old)?\b"#, in: lowered) {
            if let ageInt = Int(age), (10...120).contains(ageInt) {
                found.append(ProfileSuggestion(field: .age, value: age, source: .userStated))
            }
        }

        // Dedupe by (field, value) so multi-pattern matches don't
        // produce two identical banners.
        return dedupe(found)
    }

    // MARK: - Model-signal parser (Option A)

    /// Result tuple from a model-output parse. `cleanedText` has all
    /// `[PROFILE_ADD: ...]` markers stripped so the chat bubble shows
    /// natural prose; `suggestions` is what to surface as banners.
    struct ParsedModelOutput {
        let cleanedText: String
        let suggestions: [ProfileSuggestion]
    }

    /// Strips `[PROFILE_ADD: <field> = "<value>"]` markers out of a
    /// model response and converts each one into a `.modelRequested`
    /// suggestion. Unknown field names are silently dropped (the
    /// model occasionally hallucinates field names — better to drop
    /// than to surface a confusing banner). The cleaned text is what
    /// the chat bubble should display.
    static func extractFromModelOutput(_ text: String) -> ParsedModelOutput {
        // Pattern: [PROFILE_ADD: <key> = "<value>"]
        // - <key> is one of the known field names (case-insensitive)
        // - <value> is a double-quoted string, no nested quotes
        // Whitespace inside the brackets is forgiving so minor model
        // drift ("[PROFILE_ADD:foo='bar']") doesn't break parsing.
        let pattern = #"\[\s*PROFILE_ADD\s*:\s*([a-zA-Z_]+)\s*=\s*[\"']([^\"'\]]+)[\"']\s*\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ParsedModelOutput(cleanedText: text, suggestions: [])
        }

        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        var suggestions: [ProfileSuggestion] = []

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let keyRange = Range(match.range(at: 1), in: text),
                  let valueRange = Range(match.range(at: 2), in: text)
            else { continue }
            let key = String(text[keyRange])
            let rawValue = String(text[valueRange])
            guard let field = fieldFromModelKey(key) else { continue }
            let cleanedValue = cleanFragment(rawValue)
            guard !cleanedValue.isEmpty else { continue }
            suggestions.append(ProfileSuggestion(field: field, value: cleanedValue, source: .modelRequested))
        }

        // Strip all markers from the visible text. Replacement is the
        // empty string — the model is instructed to make the prose
        // self-contained without the marker, so removal leaves clean
        // sentences behind.
        let cleaned = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: nsRange,
            withTemplate: ""
        )
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return ParsedModelOutput(cleanedText: cleaned, suggestions: dedupe(suggestions))
    }

    // MARK: - Internals

    /// Maps a model-emitted key to a `ProfileSuggestion.Field`. We
    /// accept a few synonyms so small models that drift slightly
    /// ("medication" vs "medications") still produce a valid
    /// suggestion instead of dropping it.
    private static func fieldFromModelKey(_ raw: String) -> ProfileSuggestion.Field? {
        switch raw.lowercased() {
        case "medications", "medication", "meds":                        return .medications
        case "medicalconditions", "medical_conditions",
             "conditions", "condition", "diagnoses", "diagnosis":        return .medicalConditions
        case "familyhistory", "family_history", "familyhx", "family":    return .familyHistory
        case "smoking", "tobacco", "vape", "vaping":                     return .smoking
        case "alcohol":                                                  return .alcohol
        case "bloodtype", "blood_type":                                  return .bloodType
        case "age":                                                      return .age
        case "biologicalsex", "biological_sex", "sex", "gender":         return .biologicalSex
        default:                                                         return nil
        }
    }

    /// Returns every capture-group-1 value for `pattern` in `lowered`,
    /// mapped back to the original case from `original`. Returns
    /// empty on regex compile failure (silently — extraction failure
    /// is not user-facing).
    private static func captures(_ pattern: String, in lowered: String, original: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(lowered.startIndex..., in: lowered)
        var values: [String] = []
        for match in regex.matches(in: lowered, range: nsRange) {
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: lowered)
            else { continue }
            // Map the lowered range to original-case using string
            // indices (the two strings are character-for-character
            // identical save for case).
            if let originalRange = Range(match.range(at: 1), in: original) {
                values.append(String(original[originalRange]))
            } else {
                values.append(String(lowered[range]))
            }
        }
        return values
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }

    private static func matchesAny(_ text: String, _ patterns: [String]) -> Bool {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: nsRange) != nil { return true }
        }
        return false
    }

    /// Trims, normalizes whitespace, and title-cases obvious common-
    /// noun captures so the banner reads like "Type 2 diabetes" not
    /// "type 2 diabetes". Leaves acronyms (BUN, A1C) alone if they
    /// were already uppercase in the source.
    private static func cleanFragment(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?\"'"))
            .replacingOccurrences(of: "  ", with: " ")
        // Title-case first letter, leave the rest. We don't try to be
        // clever about "diabetes mellitus" → "Diabetes Mellitus" —
        // sentence-case feels less robotic and more like how users
        // actually write conditions in their profile.
        guard let first = trimmed.first else { return "" }
        return first.uppercased() + trimmed.dropFirst()
    }

    /// Rejects fragments that are too short, too generic, or clearly
    /// non-condition (pronouns, articles, common stopwords) so the
    /// "I have a question" → "Add 'a question' to conditions?" trap
    /// doesn't happen.
    private static func isPlausibleMedicationOrCondition(_ value: String) -> Bool {
        let lowered = value.lowercased()
        guard value.count >= 3 else { return false }
        let blocked: Set<String> = [
            "a question", "questions", "a problem", "an issue", "issues",
            "a concern", "concerns", "a question about", "a doubt",
            "no idea", "trouble", "the same", "this", "that",
            "to ask", "to know", "to see", "to check",
            "it", "them", "one", "some", "any"
        ]
        if blocked.contains(lowered) { return false }
        if blocked.contains(where: { lowered.hasPrefix($0 + " ") }) { return false }
        return true
    }

    /// Drops duplicate suggestions targeting the same (field, value)
    /// pair so multi-pattern hits don't surface two identical banners.
    private static func dedupe(_ suggestions: [ProfileSuggestion]) -> [ProfileSuggestion] {
        var seen = Set<String>()
        var out: [ProfileSuggestion] = []
        for s in suggestions {
            let key = "\(s.field.rawValue):\(s.value.lowercased())"
            if seen.insert(key).inserted {
                out.append(s)
            }
        }
        return out
    }
}
