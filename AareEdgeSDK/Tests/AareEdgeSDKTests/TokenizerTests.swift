import XCTest
@testable import AareEdgeSDK

final class TokenizerTests: XCTestCase {

    func testBasicTokenization() throws {
        // Create a minimal vocab for testing
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "hello": 4,
            "world": 5,
            "test": 6,
            "##ing": 7,
            ".": 8,
            ",": 9
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let input = tokenizer.encode("Hello World")

        // Should have [CLS], hello, world, [SEP], then padding
        XCTAssertEqual(input.inputIds[0], 2) // [CLS]
        XCTAssertEqual(input.inputIds[1], 4) // hello
        XCTAssertEqual(input.inputIds[2], 5) // world
        XCTAssertEqual(input.inputIds[3], 3) // [SEP]

        // Check attention mask
        XCTAssertEqual(input.attentionMask[0], 1)
        XCTAssertEqual(input.attentionMask[1], 1)
        XCTAssertEqual(input.attentionMask[2], 1)
        XCTAssertEqual(input.attentionMask[3], 1)
        XCTAssertEqual(input.attentionMask[4], 0) // padding
    }

    func testWordPieceSubwordTokenization() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "test": 4,
            "##ing": 5,
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let input = tokenizer.encode("testing")

        // Should split "testing" into "test" + "##ing"
        XCTAssertEqual(input.inputIds[1], 4) // test
        XCTAssertEqual(input.inputIds[2], 5) // ##ing
    }

    func testPunctuationSplitting() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "hello": 4,
            ".": 5,
            ",": 6
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let input = tokenizer.encode("Hello.")

        XCTAssertEqual(input.inputIds[1], 4) // hello
        XCTAssertEqual(input.inputIds[2], 5) // .
    }

    func testUnknownTokenHandling() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "known": 4,
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let input = tokenizer.encode("unknown word")

        // Unknown words should map to [UNK]
        XCTAssertTrue(input.inputIds.contains(1))
    }

    func testOffsetMapping() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "hello": 4,
            "world": 5
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let input = tokenizer.encode("hello world")

        // [CLS] has offset (0, 0)
        XCTAssertEqual(input.offsetMapping[0].0, 0)
        XCTAssertEqual(input.offsetMapping[0].1, 0)

        // "hello" starts at 0
        XCTAssertEqual(input.offsetMapping[1].0, 0)

        // "world" starts at 6
        XCTAssertEqual(input.offsetMapping[2].0, 6)
    }

    func testMaxLengthTruncation() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "a": 4,
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 8, doLowercase: true)

        let input = tokenizer.encode("a a a a a a a a a a")

        // Should truncate to maxLength
        XCTAssertEqual(input.inputIds.count, 8)
        XCTAssertEqual(input.attentionMask.count, 8)
    }

    func testConvertIdsToTokens() throws {
        let vocab: [String: Int] = [
            "[PAD]": 0,
            "[UNK]": 1,
            "[CLS]": 2,
            "[SEP]": 3,
            "hello": 4,
            "world": 5
        ]

        let tokenizer = try WordPieceTokenizer(vocab: vocab, maxLength: 32, doLowercase: true)

        let tokens = tokenizer.convertIdsToTokens([2, 4, 5, 3])

        XCTAssertEqual(tokens, ["[CLS]", "hello", "world", "[SEP]"])
    }
}
