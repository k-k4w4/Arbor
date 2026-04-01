import XCTest
@testable import GitViewer

final class GitLogParserTests: XCTestCase {
    // 40-char hex SHAs
    private let shaA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    private let shaB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
    private let shaC = "cccccccccccccccccccccccccccccccccccccccc"

    // Build a NUL-separated record followed by the RS separator.
    private func record(
        sha: String,
        parents: String = "",
        authorName: String = "Alice",
        authorEmail: String = "alice@example.com",
        authorDate: String = "2025-01-15 10:30:00 +0000",
        committerName: String = "Alice",
        committerDate: String = "2025-01-15 10:30:00 +0000",
        subject: String = "Test commit",
        body: String = "",
        decoration: String = ""
    ) -> String {
        "\(sha)\0\(parents)\0\(authorName)\0\(authorEmail)\0\(authorDate)\0\(committerName)\0\(committerDate)\0\(subject)\0\(body)\0\(decoration)\u{1E}"
    }

    // MARK: - Basic parsing

    func testParseEmptyString() {
        XCTAssertTrue(GitLogParser.parse("").isEmpty)
    }

    func testParseSingleCommit() {
        let commits = GitLogParser.parse(record(sha: shaA, subject: "Initial commit"))
        XCTAssertEqual(commits.count, 1)
        XCTAssertEqual(commits[0].id, shaA)
        XCTAssertEqual(commits[0].shortSHA, "aaaaaaa")
        XCTAssertEqual(commits[0].subject, "Initial commit")
    }

    func testParseSingleCommitSubject() {
        let commits = GitLogParser.parse(record(sha: shaA, subject: "Fix the bug"))
        XCTAssertEqual(commits[0].subject, "Fix the bug")
    }

    func testParseMultipleCommits() {
        let input = record(sha: shaA) + record(sha: shaB) + record(sha: shaC)
        let commits = GitLogParser.parse(input)
        XCTAssertEqual(commits.count, 3)
        XCTAssertEqual(commits[0].id, shaA)
        XCTAssertEqual(commits[1].id, shaB)
        XCTAssertEqual(commits[2].id, shaC)
    }

    func testParseAuthorFields() {
        let commits = GitLogParser.parse(record(
            sha: shaA,
            authorName: "Bob Smith",
            authorEmail: "bob@example.com"
        ))
        XCTAssertEqual(commits[0].authorName, "Bob Smith")
        XCTAssertEqual(commits[0].authorEmail, "bob@example.com")
    }

    func testParseCommitterName() {
        let commits = GitLogParser.parse(record(sha: shaA, committerName: "GitHub"))
        XCTAssertEqual(commits[0].committerName, "GitHub")
    }

    func testParseAuthorDate() {
        let commits = GitLogParser.parse(record(sha: shaA, authorDate: "2025-06-01 12:00:00 +0000"))
        XCTAssertNotEqual(commits[0].authorDate, Date.distantPast)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(cal.component(.year, from: commits[0].authorDate), 2025)
        XCTAssertEqual(cal.component(.month, from: commits[0].authorDate), 6)
        XCTAssertEqual(cal.component(.day, from: commits[0].authorDate), 1)
    }

    func testParseInvalidDateFallsBackToDistantPast() {
        let commits = GitLogParser.parse(record(sha: shaA, authorDate: "not-a-date"))
        XCTAssertEqual(commits[0].authorDate, Date.distantPast)
    }

    // MARK: - Parents

    func testParseNoParents() {
        let commits = GitLogParser.parse(record(sha: shaA, parents: ""))
        XCTAssertTrue(commits[0].parentSHAs.isEmpty)
    }

    func testParseSingleParent() {
        let commits = GitLogParser.parse(record(sha: shaA, parents: shaB))
        XCTAssertEqual(commits[0].parentSHAs, [shaB])
    }

    func testParseMultipleParents() {
        let commits = GitLogParser.parse(record(sha: shaA, parents: "\(shaB) \(shaC)"))
        XCTAssertEqual(commits[0].parentSHAs, [shaB, shaC])
    }

    // MARK: - Message body

    func testParseEmptyBodyUsesSubjectAsMessage() {
        let commits = GitLogParser.parse(record(sha: shaA, subject: "Subject only", body: ""))
        XCTAssertEqual(commits[0].message, "Subject only")
    }

    func testParseBodyCombinedWithSubject() {
        let commits = GitLogParser.parse(record(sha: shaA, subject: "Subject", body: "Detailed body"))
        XCTAssertEqual(commits[0].message, "Subject\n\nDetailed body")
    }

    // MARK: - SHA validation

    func testInvalidSHATooShortIsSkipped() {
        let input = "abc123\0\0Author\0email\02025-01-15 10:30:00 +0000\0Author\02025-01-15 10:30:00 +0000\0Subject\0\0\u{1E}"
        XCTAssertTrue(GitLogParser.parse(input).isEmpty)
    }

    func testInvalidSHANonHexIsSkipped() {
        let nonHexSHA = String(repeating: "g", count: 40)
        let input = record(sha: nonHexSHA)
        XCTAssertTrue(GitLogParser.parse(input).isEmpty)
    }

    func testTooFewFieldsIsSkipped() {
        // Only 5 NUL-separated fields — first guard requires >= 9
        let input = "\(shaA)\0parents\0author\0email\0date\u{1E}"
        XCTAssertTrue(GitLogParser.parse(input).isEmpty)
    }

    func testNineFieldsMissingDecorationIsSkipped() {
        // 9 fields passes the first guard (>= 9) but fails the second (>= 10, needs decoration field)
        let input = "\(shaA)\0\0Author\0email\02025-01-15 10:30:00 +0000\0Author\02025-01-15 10:30:00 +0000\0Subject\0Body\u{1E}"
        XCTAssertTrue(GitLogParser.parse(input).isEmpty)
    }

    func testInvalidCommitDoesNotAffectOthers() {
        let invalid = "bad\0\0A\0e\02025-01-15 10:30:00 +0000\0A\02025-01-15 10:30:00 +0000\0S\0\0\u{1E}"
        let input = record(sha: shaA) + invalid + record(sha: shaB)
        let commits = GitLogParser.parse(input)
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits[0].id, shaA)
        XCTAssertEqual(commits[1].id, shaB)
    }

    // MARK: - Decoration

    func testDecorationEmpty() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: ""))
        XCTAssertTrue(commits[0].refs.isEmpty)
    }

    func testDecorationHeadBranch() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "HEAD -> main"))
        XCTAssertEqual(commits[0].refs.count, 1)
        let ref = commits[0].refs[0]
        XCTAssertEqual(ref.shortName, "main")
        XCTAssertEqual(ref.refType, .localBranch)
        XCTAssertTrue(ref.isHead)
        XCTAssertEqual(ref.name, "refs/heads/main")
    }

    func testDecorationHeadAloneIsIgnored() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "HEAD"))
        XCTAssertTrue(commits[0].refs.isEmpty)
    }

    func testDecorationTag() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "tag: v1.0.0"))
        XCTAssertEqual(commits[0].refs.count, 1)
        let ref = commits[0].refs[0]
        XCTAssertEqual(ref.shortName, "v1.0.0")
        XCTAssertEqual(ref.refType, .tag)
        XCTAssertEqual(ref.name, "refs/tags/v1.0.0")
    }

    func testDecorationRemoteBranch() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "origin/main"))
        XCTAssertEqual(commits[0].refs.count, 1)
        let ref = commits[0].refs[0]
        XCTAssertEqual(ref.shortName, "main")
        XCTAssertEqual(ref.refType, .remoteBranch(remote: "origin"))
    }

    func testDecorationLocalBranchNoSlash() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "develop"))
        XCTAssertEqual(commits[0].refs.count, 1)
        let ref = commits[0].refs[0]
        XCTAssertEqual(ref.shortName, "develop")
        XCTAssertEqual(ref.refType, .localBranch)
        XCTAssertFalse(ref.isHead)
    }

    func testDecorationMultipleRefs() {
        let commits = GitLogParser.parse(record(sha: shaA, decoration: "HEAD -> main, origin/main, tag: v1.0"))
        XCTAssertEqual(commits[0].refs.count, 3)
        XCTAssertTrue(commits[0].refs[0].isHead)
        XCTAssertEqual(commits[0].refs[0].shortName, "main")
        XCTAssertEqual(commits[0].refs[1].refType, .remoteBranch(remote: "origin"))
        XCTAssertEqual(commits[0].refs[2].refType, .tag)
    }
}
