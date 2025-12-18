import Foundation

/// Mock PHI detector that uses regex patterns for testing purposes.
/// This is a fallback when the ML model is not available or not trained.
public final class MockPHIDetector {

    public init() {}

    /// Detect PHI using regex patterns
    public func detect(_ text: String) -> PHIDetectionResult {
        var entities: [PHIEntity] = []

        // SSN pattern: XXX-XX-XXXX
        let ssnPattern = #"\b\d{3}-\d{2}-\d{4}\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: ssnPattern, type: "SSN"))

        // Phone pattern: (XXX) XXX-XXXX or XXX-XXX-XXXX or XXX.XXX.XXXX
        let phonePattern = #"\b(?:\(\d{3}\)\s*|\d{3}[-.])\d{3}[-.]?\d{4}\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: phonePattern, type: "PHONE"))

        // Email pattern
        let emailPattern = #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: emailPattern, type: "EMAIL"))

        // Date patterns: MM/DD/YYYY, DD/MM/YYYY, Month DD, YYYY
        let datePattern = #"\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\w+\s+\d{1,2},?\s+\d{4}|\d{4}-\d{2}-\d{2})\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: datePattern, type: "DATE"))

        // MRN pattern: MRN: XXXXX or MED-XXXXX or A-XXXXX
        let mrnPattern = #"\b(?:MRN:?\s*|MED-|A-)[A-Z0-9-]{5,}\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: mrnPattern, type: "MRN"))

        // Address pattern (simple: number + street name)
        let addressPattern = #"\b\d+\s+[\w\s]+(?:Street|St|Avenue|Ave|Road|Rd|Boulevard|Blvd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl)\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: addressPattern, type: "LOCATION"))

        // ZIP code in address context
        let zipPattern = #"\b[A-Z]{2}\s+\d{5}(?:-\d{4})?\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: zipPattern, type: "LOCATION"))

        // Account/Insurance ID: alphanumeric patterns with dashes
        let accountPattern = #"\b(?:Plan\s*#|ID:|Insurance:|Account:)\s*[A-Z0-9-]{8,}\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: accountPattern, type: "ACCOUNT"))

        // Name patterns (simple heuristic: Title + Capitalized words)
        let namePattern = #"\b(?:Patient|Dr\.|Doctor|Mr\.|Mrs\.|Ms\.)\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: namePattern, type: "NAME"))

        // Common first names followed by last names (simple list)
        let commonNamePattern = #"\b(?:John|Jane|Michael|Sarah|David|Mary|Robert|Jennifer|William|Linda|James|Patricia|Richard|Elizabeth|Thomas|Barbara)\s+[A-Z][a-z]+\b"#
        entities.append(contentsOf: findMatches(in: text, pattern: commonNamePattern, type: "NAME"))

        // Sort entities by start offset
        entities.sort { $0.startOffset < $1.startOffset }

        return PHIDetectionResult(
            text: text,
            entities: entities,
            tokenCount: text.split(separator: " ").count
        )
    }

    private func findMatches(in text: String, pattern: String, type: String) -> [PHIEntity] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        return matches.map { match in
            let range = match.range
            let matchedText = nsString.substring(with: range)

            return PHIEntity(
                type: type,
                text: matchedText,
                startOffset: range.location,
                endOffset: range.location + range.length,
                confidence: 0.95 // Mock confidence
            )
        }
    }
}
