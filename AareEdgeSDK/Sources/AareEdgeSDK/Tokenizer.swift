import Foundation

/// WordPiece tokenizer compatible with DistilBERT/BERT models.
///
/// This tokenizer implements the WordPiece algorithm used by BERT-family models.
/// It handles vocabulary lookup, subword tokenization, and special token management.
public final class WordPieceTokenizer {

    // MARK: - Properties

    /// Vocabulary mapping from token string to ID
    public let vocab: [String: Int]

    /// Reverse vocabulary mapping from ID to token string
    public let idToToken: [Int: String]

    /// Special tokens
    public let clsToken = "[CLS]"
    public let sepToken = "[SEP]"
    public let padToken = "[PAD]"
    public let unkToken = "[UNK]"

    /// Special token IDs
    public let clsTokenId: Int
    public let sepTokenId: Int
    public let padTokenId: Int
    public let unkTokenId: Int

    /// Maximum sequence length
    public let maxLength: Int

    /// Whether to lowercase input text
    public let doLowercase: Bool

    // MARK: - Initialization

    /// Initialize tokenizer with a vocabulary file.
    /// - Parameters:
    ///   - vocabURL: URL to vocab.txt file
    ///   - maxLength: Maximum sequence length (default: 512)
    ///   - doLowercase: Whether to lowercase input (default: true for uncased models)
    public init(vocabURL: URL, maxLength: Int = 512, doLowercase: Bool = true) throws {
        let vocabText = try String(contentsOf: vocabURL, encoding: .utf8)
        let lines = vocabText.components(separatedBy: .newlines)

        var vocab: [String: Int] = [:]
        var idToToken: [Int: String] = [:]

        for (index, line) in lines.enumerated() {
            let token = line.trimmingCharacters(in: .whitespaces)
            if !token.isEmpty {
                vocab[token] = index
                idToToken[index] = token
            }
        }

        self.vocab = vocab
        self.idToToken = idToToken
        self.maxLength = maxLength
        self.doLowercase = doLowercase

        // Get special token IDs
        guard let clsId = vocab[clsToken],
              let sepId = vocab[sepToken],
              let padId = vocab[padToken],
              let unkId = vocab[unkToken] else {
            throw TokenizerError.missingSpecialTokens
        }

        self.clsTokenId = clsId
        self.sepTokenId = sepId
        self.padTokenId = padId
        self.unkTokenId = unkId
    }

    /// Initialize tokenizer with vocabulary dictionary.
    /// - Parameters:
    ///   - vocab: Dictionary mapping tokens to IDs
    ///   - maxLength: Maximum sequence length
    ///   - doLowercase: Whether to lowercase input
    public init(vocab: [String: Int], maxLength: Int = 512, doLowercase: Bool = true) throws {
        self.vocab = vocab
        self.idToToken = Dictionary(uniqueKeysWithValues: vocab.map { ($1, $0) })
        self.maxLength = maxLength
        self.doLowercase = doLowercase

        guard let clsId = vocab[clsToken],
              let sepId = vocab[sepToken],
              let padId = vocab[padToken],
              let unkId = vocab[unkToken] else {
            throw TokenizerError.missingSpecialTokens
        }

        self.clsTokenId = clsId
        self.sepTokenId = sepId
        self.padTokenId = padId
        self.unkTokenId = unkId
    }

    // MARK: - Tokenization

    /// Tokenize input text and return encoded input for the model.
    /// - Parameter text: Input text to tokenize
    /// - Returns: TokenizedInput containing input IDs, attention mask, and offset mapping
    public func encode(_ text: String) -> TokenizedInput {
        let processedText = doLowercase ? text.lowercased() : text

        // Basic tokenization (split on whitespace and punctuation)
        let basicTokens = basicTokenize(processedText)

        // WordPiece tokenization with offset tracking
        var inputIds: [Int] = [clsTokenId]
        var attentionMask: [Int] = [1]
        var offsetMapping: [(Int, Int)] = [(0, 0)] // CLS token has no offset

        var currentOffset = 0

        for token in basicTokens {
            let (wordpieceTokens, wordpieceIds) = wordpieceTokenize(token)

            // Find token position in original text
            if let range = processedText.range(of: token, range: processedText.index(processedText.startIndex, offsetBy: currentOffset)..<processedText.endIndex) {
                let startOffset = processedText.distance(from: processedText.startIndex, to: range.lowerBound)
                let endOffset = processedText.distance(from: processedText.startIndex, to: range.upperBound)

                var tokenStartOffset = startOffset
                for (i, wpToken) in wordpieceTokens.enumerated() {
                    let wpLength = wpToken.hasPrefix("##") ? wpToken.count - 2 : wpToken.count
                    let tokenEndOffset = min(tokenStartOffset + wpLength, endOffset)

                    inputIds.append(wordpieceIds[i])
                    attentionMask.append(1)
                    offsetMapping.append((tokenStartOffset, tokenEndOffset))

                    tokenStartOffset = tokenEndOffset
                }

                currentOffset = endOffset
            }

            // Check if we're approaching max length
            if inputIds.count >= maxLength - 1 {
                break
            }
        }

        // Add SEP token
        inputIds.append(sepTokenId)
        attentionMask.append(1)
        offsetMapping.append((0, 0)) // SEP token has no offset

        // Pad to max length
        let paddingLength = maxLength - inputIds.count
        if paddingLength > 0 {
            inputIds.append(contentsOf: Array(repeating: padTokenId, count: paddingLength))
            attentionMask.append(contentsOf: Array(repeating: 0, count: paddingLength))
            offsetMapping.append(contentsOf: Array(repeating: (0, 0), count: paddingLength))
        }

        return TokenizedInput(
            inputIds: inputIds,
            attentionMask: attentionMask,
            offsetMapping: offsetMapping,
            originalText: text
        )
    }

    /// Convert token IDs back to tokens.
    /// - Parameter ids: Array of token IDs
    /// - Returns: Array of token strings
    public func convertIdsToTokens(_ ids: [Int]) -> [String] {
        return ids.map { idToToken[$0] ?? unkToken }
    }

    // MARK: - Private Methods

    /// Basic tokenization: split on whitespace and punctuation.
    private func basicTokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""

        for char in text {
            if char.isWhitespace {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else if isPunctuation(char) {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
                tokens.append(String(char))
            } else {
                currentToken.append(char)
            }
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    /// WordPiece tokenization for a single word.
    private func wordpieceTokenize(_ word: String) -> ([String], [Int]) {
        var tokens: [String] = []
        var ids: [Int] = []

        var start = word.startIndex

        while start < word.endIndex {
            var end = word.endIndex
            var foundSubword = false

            while start < end {
                let substring = String(word[start..<end])
                let candidate = start == word.startIndex ? substring : "##\(substring)"

                if let tokenId = vocab[candidate] {
                    tokens.append(candidate)
                    ids.append(tokenId)
                    foundSubword = true
                    break
                }

                end = word.index(before: end)
            }

            if !foundSubword {
                // Character not in vocab, use UNK
                tokens.append(unkToken)
                ids.append(unkTokenId)
                start = word.index(after: start)
            } else {
                start = end
            }
        }

        return (tokens, ids)
    }

    /// Check if character is punctuation.
    private func isPunctuation(_ char: Character) -> Bool {
        let punctuationSet = CharacterSet.punctuationCharacters
        return char.unicodeScalars.allSatisfy { punctuationSet.contains($0) }
    }
}

// MARK: - Supporting Types

/// Tokenized input ready for model inference.
public struct TokenizedInput {
    /// Token IDs for the model
    public let inputIds: [Int]

    /// Attention mask (1 for real tokens, 0 for padding)
    public let attentionMask: [Int]

    /// Mapping from token index to character offsets in original text
    public let offsetMapping: [(Int, Int)]

    /// Original input text
    public let originalText: String

    /// Number of real (non-padding) tokens
    public var realTokenCount: Int {
        attentionMask.filter { $0 == 1 }.count
    }
}

/// Tokenizer errors.
public enum TokenizerError: Error, LocalizedError {
    case missingSpecialTokens
    case vocabFileNotFound
    case invalidVocabFormat

    public var errorDescription: String? {
        switch self {
        case .missingSpecialTokens:
            return "Vocabulary is missing required special tokens ([CLS], [SEP], [PAD], [UNK])"
        case .vocabFileNotFound:
            return "Vocabulary file not found"
        case .invalidVocabFormat:
            return "Invalid vocabulary file format"
        }
    }
}
