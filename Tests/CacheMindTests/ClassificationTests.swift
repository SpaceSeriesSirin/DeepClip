import XCTest
@testable import CacheMind

final class ClassificationTests: XCTestCase {

    func testPlainText() {
        XCTAssertEqual(ContentClassifier.classify(text: "Hello, this is just some text."), .text)
        XCTAssertEqual(ContentClassifier.classify(text: "Buy milk and eggs"), .text)
    }

    func testURLDetection() {
        XCTAssertEqual(ContentClassifier.classify(text: "https://github.com/groue/GRDB.swift"), .url)
        XCTAssertEqual(ContentClassifier.classify(text: "http://example.com"), .url)
        XCTAssertEqual(ContentClassifier.classify(text: "x.com/elonmusk"), .url)
        XCTAssertEqual(ContentClassifier.classify(text: "github.com"), .url)
        // Text with a space is not a bare URL.
        XCTAssertNotEqual(ContentClassifier.classify(text: "visit github.com today"), .url)
    }

    func testTerminalDetection() {
        XCTAssertEqual(ContentClassifier.classify(text: "$ ls -la"), .terminal)
        XCTAssertEqual(ContentClassifier.classify(text: "git commit -m \"hi\""), .terminal)
        XCTAssertEqual(ContentClassifier.classify(text: "brew install sqlite"), .terminal)
        XCTAssertEqual(ContentClassifier.classify(text: "sudo rm -rf /tmp/x"), .terminal)
        XCTAssertEqual(ContentClassifier.classify(text: "#!/bin/bash\necho hello"), .terminal)
        XCTAssertEqual(ContentClassifier.classify(text: "cat file.txt | grep foo"), .terminal)
    }

    func testCodeDetection() {
        let swift = """
        func add(_ a: Int, _ b: Int) -> Int {
            return a + b
        }
        """
        XCTAssertEqual(ContentClassifier.classify(text: swift), .code)

        let js = """
        function greet(name) {
            console.log("hi " + name);
        }
        """
        XCTAssertEqual(ContentClassifier.classify(text: js), .code)

        let json = "{\"a\": 1, \"b\": [1,2,3]}"
        XCTAssertEqual(ContentClassifier.classify(text: json), .code)
    }

    func testURLDomainExtraction() {
        XCTAssertEqual(URLHelper.domain(from: "https://x.com/elonmusk"), "x.com")
        XCTAssertEqual(URLHelper.domain(from: "https://www.github.com/foo"), "github.com")
        XCTAssertEqual(URLHelper.domain(from: "x.com/realdonaldtrump"), "x.com")
        XCTAssertEqual(URLHelper.domain(from: "http://sub.example.co.uk/path"), "sub.example.co.uk")
    }
}
