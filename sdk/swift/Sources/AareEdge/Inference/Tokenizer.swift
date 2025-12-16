// Tokenizer
// Text tokenization for NER model inference

import Foundation

/// Token with metadata
public struct Token {
    public let text: String
    public let startIndex: Int
    public let endIndex: Int
    public let tokenIndex: Int

    public var range: Range<Int> {
        startIndex..<endIndex
    }
}

/// Tokenization result
public struct TokenizationResult {
    public let tokens: [Token]
    public let inputIds: [Int]
    public let attentionMask: [Int]
    public let wordIds: [Int?]

    public var length: Int {
        tokens.count
    }
}

/// Simple tokenizer for NER inference
/// This implements basic word-piece tokenization similar to BERT/RoBERTa
public class Tokenizer {

    // Special token IDs (following HuggingFace convention)
    public static let padTokenId = 0
    public static let unkTokenId = 1
    public static let clsTokenId = 2
    public static let sepTokenId = 3
    public static let maskTokenId = 4

    // Special tokens
    public static let padToken = "[PAD]"
    public static let unkToken = "[UNK]"
    public static let clsToken = "[CLS]"
    public static let sepToken = "[SEP]"
    public static let maskToken = "[MASK]"

    private let vocabulary: [String: Int]
    private let reverseVocabulary: [Int: String]
    private let maxLength: Int
    private let doLowerCase: Bool

    public init(
        vocabularyPath: URL? = nil,
        maxLength: Int = 512,
        doLowerCase: Bool = true
    ) {
        self.maxLength = maxLength
        self.doLowerCase = doLowerCase

        // Load vocabulary if provided, otherwise use basic vocabulary
        if let path = vocabularyPath,
           let vocab = try? Self.loadVocabulary(from: path) {
            self.vocabulary = vocab
        } else {
            self.vocabulary = Self.createBasicVocabulary()
        }

        self.reverseVocabulary = Dictionary(uniqueKeysWithValues: vocabulary.map { ($1, $0) })
    }

    /// Tokenize text for NER inference
    /// - Parameters:
    ///   - text: Input text
    ///   - padding: Whether to pad to max length
    ///   - truncation: Whether to truncate to max length
    /// - Returns: Tokenization result
    public func tokenize(
        text: String,
        padding: Bool = true,
        truncation: Bool = true
    ) -> TokenizationResult {
        // Normalize text
        var normalizedText = text
        if doLowerCase {
            normalizedText = normalizedText.lowercased()
        }

        // Split into words
        let words = Self.basicTokenize(normalizedText)

        // Convert to subword tokens
        var tokens: [Token] = []
        var inputIds: [Int] = [Self.clsTokenId]
        var wordIds: [Int?] = [nil] // CLS token has no word ID
        var currentPosition = 0

        for (wordIndex, word) in words.enumerated() {
            // Find word position in original text
            guard let range = (text as NSString).range(of: word, range: NSRange(location: currentPosition, length: text.count - currentPosition)) else {
                continue
            }

            let wordStart = range.location
            let wordEnd = range.location + range.length

            // Tokenize word into subwords
            let subwordTokens = wordpieceTokenize(word)

            for (subIndex, subtoken) in subwordTokens.enumerated() {
                let tokenId = vocabulary[subtoken] ?? Self.unkTokenId

                // Calculate token position (approximate for subwords)
                let tokenStart = wordStart + (subIndex * word.count / subwordTokens.count)
                let tokenEnd = min(wordEnd, tokenStart + (word.count / subwordTokens.count))

                tokens.append(Token(
                    text: subtoken,
                    startIndex: tokenStart,
                    endIndex: tokenEnd,
                    tokenIndex: tokens.count + 1
                ))

                inputIds.append(tokenId)
                wordIds.append(wordIndex)
            }

            currentPosition = wordEnd
        }

        // Add SEP token
        inputIds.append(Self.sepTokenId)
        wordIds.append(nil)

        // Truncate if needed
        if truncation && inputIds.count > maxLength {
            inputIds = Array(inputIds.prefix(maxLength - 1)) + [Self.sepTokenId]
            tokens = Array(tokens.prefix(maxLength - 2))
            wordIds = Array(wordIds.prefix(maxLength))
        }

        // Pad if needed
        let attentionMask = Array(repeating: 1, count: inputIds.count)
        if padding && inputIds.count < maxLength {
            let padCount = maxLength - inputIds.count
            inputIds.append(contentsOf: Array(repeating: Self.padTokenId, count: padCount))
            wordIds.append(contentsOf: Array(repeating: nil, count: padCount))
        }

        let finalAttentionMask = padding
            ? attentionMask + Array(repeating: 0, count: maxLength - attentionMask.count)
            : attentionMask

        return TokenizationResult(
            tokens: tokens,
            inputIds: inputIds,
            attentionMask: finalAttentionMask,
            wordIds: wordIds
        )
    }

    /// Decode token IDs back to text
    public func decode(_ tokenIds: [Int]) -> String {
        let tokens = tokenIds.compactMap { reverseVocabulary[$0] }
            .filter { !["[PAD]", "[CLS]", "[SEP]"].contains($0) }

        return tokens.joined(separator: " ")
            .replacingOccurrences(of: " ##", with: "")
    }

    // MARK: - Private Helpers

    private static func basicTokenize(_ text: String) -> [String] {
        // Split on whitespace and punctuation
        let pattern = #"\w+|[^\w\s]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text.components(separatedBy: .whitespacesAndNewlines)
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        return matches.map { nsText.substring(with: $0.range) }
    }

    private func wordpieceTokenize(_ word: String) -> [String] {
        // Simple wordpiece tokenization
        // In production, this would use the actual wordpiece algorithm
        var tokens: [String] = []
        var remaining = word

        while !remaining.isEmpty {
            var found = false

            // Try to find longest match in vocabulary
            for length in (1...min(remaining.count, 20)).reversed() {
                let prefix = String(remaining.prefix(length))
                let token = tokens.isEmpty ? prefix : "##\(prefix)"

                if vocabulary.keys.contains(token) {
                    tokens.append(token)
                    remaining = String(remaining.dropFirst(length))
                    found = true
                    break
                }
            }

            if !found {
                // Use first character as unknown
                tokens.append(tokens.isEmpty ? String(remaining.prefix(1)) : "##\(remaining.prefix(1))")
                remaining = String(remaining.dropFirst())
            }
        }

        return tokens
    }

    private static func loadVocabulary(from url: URL) throws -> [String: Int] {
        let data = try Data(contentsOf: url)

        // Try JSON format first
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Int] {
            return json
        }

        // Try text format (one token per line)
        let content = String(data: data, encoding: .utf8) ?? ""
        let tokens = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        return Dictionary(uniqueKeysWithValues: tokens.enumerated().map { ($1, $0) })
    }

    private static func createBasicVocabulary() -> [String: Int] {
        var vocab: [String: Int] = [
            padToken: padTokenId,
            unkToken: unkTokenId,
            clsToken: clsTokenId,
            sepToken: sepTokenId,
            maskToken: maskTokenId
        ]

        // Add common words and characters
        let commonTokens = [
            // Lowercase letters
            "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
            "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
            // Digits
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
            // Common punctuation
            ".", ",", "!", "?", ":", ";", "-", "/", "@", "#", "$", "%", "&", "*",
            "(", ")", "[", "]", "{", "}", "'", "\"", "`",
            // Common words
            "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
            "of", "with", "by", "from", "as", "is", "was", "are", "were", "be",
            "been", "being", "have", "has", "had", "do", "does", "did",
            // Medical terms
            "patient", "doctor", "hospital", "medical", "health", "diagnosis",
            "treatment", "medication", "date", "name", "address", "phone", "email"
        ]

        for (index, token) in commonTokens.enumerated() {
            vocab[token] = index + 5
        }

        // Add wordpiece continuations
        for token in commonTokens {
            vocab["##\(token)"] = vocab.count
        }

        return vocab
    }
}

// MARK: - BPE Tokenizer (Alternative Implementation)

/// Byte-Pair Encoding tokenizer for modern transformers
public class BPETokenizer {

    private let merges: [(String, String)]
    private let vocabulary: [String: Int]
    private let maxLength: Int

    public init(
        mergesPath: URL? = nil,
        vocabularyPath: URL? = nil,
        maxLength: Int = 512
    ) {
        self.maxLength = maxLength

        // Load merges and vocabulary if provided
        if let path = mergesPath,
           let loadedMerges = try? Self.loadMerges(from: path) {
            self.merges = loadedMerges
        } else {
            self.merges = []
        }

        if let path = vocabularyPath,
           let vocab = try? Self.loadVocabulary(from: path) {
            self.vocabulary = vocab
        } else {
            self.vocabulary = Self.createBasicVocabulary()
        }
    }

    public func tokenize(text: String) -> TokenizationResult {
        // BPE tokenization implementation
        // This is a simplified version; full implementation would use the merges table
        let basicTokenizer = Tokenizer(maxLength: maxLength)
        return basicTokenizer.tokenize(text: text)
    }

    private static func loadMerges(from url: URL) throws -> [(String, String)] {
        let content = try String(contentsOf: url, encoding: .utf8)
        return content.components(separatedBy: .newlines)
            .compactMap { line -> (String, String)? in
                let parts = line.split(separator: " ")
                guard parts.count == 2 else { return nil }
                return (String(parts[0]), String(parts[1]))
            }
    }

    private static func loadVocabulary(from url: URL) throws -> [String: Int] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: Int].self, from: data)
    }

    private static func createBasicVocabulary() -> [String: Int] {
        // Use the same basic vocabulary as Tokenizer
        Tokenizer.createBasicVocabulary()
    }
}
