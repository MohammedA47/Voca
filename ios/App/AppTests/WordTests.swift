import XCTest

// Word, Phonetics, and Level are compiled directly into this module from Word.swift.
// No @testable import — AppTests is a non-hosted unit-test bundle with no App dependency.

// MARK: - Structural Decoding Tests

final class WordDecodingTests: XCTestCase {

    // MARK: Helpers

    private func decode(_ json: String) throws -> Word {
        try JSONDecoder().decode(Word.self, from: Data(json.utf8))
    }

    // MARK: Minimal / Full Word Values

    func testDecodeMinimalWord() throws {
        let w = try decode("""
            {"id":"t-001","word":"test","type":"noun","level":"A1","phonetics":{}}
            """)
        XCTAssertEqual(w.id, "t-001")
        XCTAssertEqual(w.word, "test")
        XCTAssertEqual(w.type, "noun")
        XCTAssertEqual(w.level, "A1")
        XCTAssertNil(w.examples)
        XCTAssertNil(w.definition)
        XCTAssertNil(w.example)
        XCTAssertNil(w.synonyms)
    }

    func testDecodeFullWord() throws {
        let w = try decode("""
            {"id":"t-002","word":"run","type":"verb","level":"B1",
             "phonetics":{"us":"/rʌn/","uk":"/rʌn/"},
             "examples":["She runs daily."],"definition":"Move at speed.",
             "example":"Run!","synonyms":["sprint"]}
            """)
        XCTAssertEqual(w.id, "t-002")
        XCTAssertEqual(w.phonetics.us, "/rʌn/")
        XCTAssertEqual(w.phonetics.uk, "/rʌn/")
        XCTAssertEqual(w.examples, ["She runs daily."])
        XCTAssertEqual(w.definition, "Move at speed.")
        XCTAssertEqual(w.example, "Run!")
        XCTAssertEqual(w.synonyms, ["sprint"])
    }

    // MARK: Phonetics Optional Combinations

    func testPhoneticsBothAbsent() throws {
        let w = try decode(#"{"id":"t-003","word":"x","type":"noun","level":"A1","phonetics":{}}"#)
        XCTAssertNil(w.phonetics.us)
        XCTAssertNil(w.phonetics.uk)
    }

    func testPhoneticsBothNull() throws {
        let w = try decode(#"{"id":"t-003b","word":"x","type":"noun","level":"A1","phonetics":{"us":null,"uk":null}}"#)
        XCTAssertNil(w.phonetics.us)
        XCTAssertNil(w.phonetics.uk)
    }

    func testPhoneticsOnlyUS() throws {
        let w = try decode(#"{"id":"t-004","word":"x","type":"noun","level":"A1","phonetics":{"us":"/x/"}}"#)
        XCTAssertEqual(w.phonetics.us, "/x/")
        XCTAssertNil(w.phonetics.uk)
    }

    func testPhoneticsOnlyUK() throws {
        let w = try decode(#"{"id":"t-005","word":"x","type":"noun","level":"A1","phonetics":{"uk":"/x/"}}"#)
        XCTAssertNil(w.phonetics.us)
        XCTAssertEqual(w.phonetics.uk, "/x/")
    }

    // MARK: Optional Field — Null vs Absent vs Empty

    func testNullExamplesDecodesNil() throws {
        let w = try decode(#"{"id":"t-006","word":"x","type":"noun","level":"A1","phonetics":{},"examples":null}"#)
        XCTAssertNil(w.examples)
    }

    func testEmptyExamplesArrayDecodes() throws {
        let w = try decode(#"{"id":"t-007","word":"x","type":"noun","level":"A1","phonetics":{},"examples":[]}"#)
        XCTAssertEqual(w.examples, [])
    }

    func testNullDefinitionDecodesNil() throws {
        let w = try decode(#"{"id":"t-008","word":"x","type":"noun","level":"A1","phonetics":{},"definition":null}"#)
        XCTAssertNil(w.definition)
    }

    // MARK: Malformed — Missing Required Fields

    func testMissingIdThrows() {
        XCTAssertThrowsError(
            try decode(#"{"word":"x","type":"noun","level":"A1","phonetics":{}}"#)
        )
    }

    func testMissingWordThrows() {
        XCTAssertThrowsError(
            try decode(#"{"id":"t-009","type":"noun","level":"A1","phonetics":{}}"#)
        )
    }

    func testMissingTypeThrows() {
        XCTAssertThrowsError(
            try decode(#"{"id":"t-010","word":"x","level":"A1","phonetics":{}}"#)
        )
    }

    func testMissingLevelThrows() {
        XCTAssertThrowsError(
            try decode(#"{"id":"t-011","word":"x","type":"noun","phonetics":{}}"#)
        )
    }

    func testMissingPhoneticsThrows() {
        XCTAssertThrowsError(
            try decode(#"{"id":"t-012","word":"x","type":"noun","level":"A1"}"#)
        )
    }
}

// MARK: - Bundled JSON Dataset Tests
//
// Using a separate class so that setUpWithError failures affect only these tests.
// setUpWithError() throws — a missing or undecodable resource file is an explicit
// test failure, never a silent empty-array vacuous pass.

final class WordBundledJSONTests: XCTestCase {

    private var allWords: [Word] = []

    override func setUpWithError() throws {
        try super.setUpWithError()
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            bundle.url(forResource: "oxford_vocabulary", withExtension: "json"),
            "oxford_vocabulary.json must be present in AppTests bundle — check Resources build phase"
        )
        let data = try Data(contentsOf: url)
        allWords = try JSONDecoder().decode([Word].self, from: data)
        // Fail immediately if decode somehow produced an empty array; avoids vacuous passes below.
        guard !allWords.isEmpty else {
            throw XCTSkip("oxford_vocabulary.json decoded to an empty array")
        }
    }

    // Verifies the dataset is non-trivially populated.
    func testDatasetIsNonEmpty() {
        XCTAssertFalse(allWords.isEmpty, "Dataset must contain at least one word")
    }

    // No two words share an ID; also validates each ID is nonempty and trimmed.
    func testAllIdsUniqueNonEmptyTrimmed() {
        var seen = Set<String>()
        for w in allWords {
            let trimmed = w.id.trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(trimmed.isEmpty, "Empty id found in dataset")
            XCTAssertEqual(w.id, trimmed, "Untrimmed whitespace in id: '\(w.id)'")
            XCTAssertTrue(seen.insert(trimmed).inserted, "Duplicate id: '\(w.id)'")
        }
    }

    // Every word string is nonempty and has no leading/trailing whitespace.
    func testAllWordStringsNonEmptyTrimmed() {
        for w in allWords {
            let trimmed = w.word.trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(trimmed.isEmpty, "Empty word for id=\(w.id)")
            XCTAssertEqual(w.word, trimmed, "Untrimmed whitespace in word '\(w.word)' for id=\(w.id)")
        }
    }

    // Every type string is nonempty and trimmed.
    func testAllTypesNonEmptyTrimmed() {
        for w in allWords {
            let trimmed = w.type.trimmingCharacters(in: .whitespaces)
            XCTAssertFalse(trimmed.isEmpty, "Empty type for id=\(w.id)")
            XCTAssertEqual(w.type, trimmed, "Untrimmed whitespace in type '\(w.type)' for id=\(w.id)")
        }
    }

    // Every level is one of the six CEFR values.
    func testAllLevelsAreValidCEFR() {
        let validLevels: Set<Level> = ["A1", "A2", "B1", "B2", "C1", "C2"]
        let invalid = allWords.filter { !validLevels.contains($0.level) }
        XCTAssertTrue(
            invalid.isEmpty,
            "Invalid CEFR levels found: \(invalid.prefix(5).map { "\($0.id)=\($0.level)" })"
        )
    }
}
