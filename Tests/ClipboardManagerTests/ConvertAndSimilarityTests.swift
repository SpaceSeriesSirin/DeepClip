import XCTest
@testable import ClipboardManager

final class ConvertAndSimilarityTests: XCTestCase {

    // MARK: SmartConvert

    func testBase64RoundTrip() {
        let encoded = SmartConvert.apply(.base64Encode, to: "hello")
        XCTAssertEqual(encoded, "aGVsbG8=")
        let decoded = SmartConvert.apply(.base64Decode, to: "aGVsbG8=")
        XCTAssertEqual(decoded, "hello")
    }

    func testURLEncoding() {
        // .urlQueryAllowed percent-encodes spaces but not query separators like &.
        let encoded = SmartConvert.apply(.urlEncode, to: "a b&c")
        XCTAssertEqual(encoded, "a%20b&c")
        let decoded = SmartConvert.apply(.urlDecode, to: "a%20b%26c")
        XCTAssertEqual(decoded, "a b&c")
    }

    func testJSONFormat() {
        let formatted = SmartConvert.apply(.formatJSON, to: "{\"b\":2,\"a\":1}")
        XCTAssertNotNil(formatted)
        XCTAssertTrue(formatted!.contains("\n"))
        // sortedKeys => "a" appears before "b"
        let aIndex = formatted!.range(of: "\"a\"")!.lowerBound
        let bIndex = formatted!.range(of: "\"b\"")!.lowerBound
        XCTAssertTrue(aIndex < bIndex)
    }

    func testInvalidJSONReturnsNil() {
        XCTAssertNil(SmartConvert.apply(.formatJSON, to: "not json {"))
    }

    func testMarkdownToPlain() {
        let plain = SmartConvert.apply(.markdownToPlain, to: "# Title\n**bold** and `code`")
        XCTAssertEqual(plain, "Title\nbold and code")
    }

    // MARK: TextSimilarity

    func testLevenshtein() {
        XCTAssertEqual(TextSimilarity.levenshtein("kitten", "sitting"), 3)
        XCTAssertEqual(TextSimilarity.levenshtein("", "abc"), 3)
        XCTAssertEqual(TextSimilarity.levenshtein("same", "same"), 0)
    }

    func testNormalizedSimilarity() {
        XCTAssertEqual(TextSimilarity.normalizedSimilarity("same", "same"), 1.0, accuracy: 0.0001)
        let sim = TextSimilarity.normalizedSimilarity("hello world", "hello worle")
        XCTAssertGreaterThan(sim, 0.85)
    }

    // MARK: VectorMath

    func testCosineSimilarity() {
        XCTAssertEqual(VectorMath.cosineSimilarity([1, 0], [1, 0]), 1.0, accuracy: 0.0001)
        XCTAssertEqual(VectorMath.cosineSimilarity([1, 0], [0, 1]), 0.0, accuracy: 0.0001)
        XCTAssertEqual(VectorMath.cosineSimilarity([], [1]), 0.0)
    }

    func testVectorEncodeDecode() {
        let vector: [Double] = [0.1, 0.2, 0.3, -0.5]
        let data = VectorMath.encode(vector)
        let decoded = VectorMath.decode(data)
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded!.count, 4)
        XCTAssertEqual(decoded![3], -0.5, accuracy: 0.0001)
    }

    // MARK: FormatCleaner

    func testFormatCleanerCollapsesWhitespace() {
        let cleaned = FormatCleaner.clean("hello    world  \n\n\n\nfoo   ")
        XCTAssertEqual(cleaned, "hello world\n\nfoo")
    }

    // MARK: IntentRecognizer

    func testIntentRecognizerFindsEmailAndURL() {
        let suggestions = IntentRecognizer.analyze("Contact me at user@example.com or visit https://github.com/foo")
        XCTAssertTrue(suggestions.contains { $0.kind == .email && $0.value.contains("user@example.com") })
        XCTAssertTrue(suggestions.contains { $0.kind == .openGitHub })
    }
}
