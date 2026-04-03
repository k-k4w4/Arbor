import XCTest
@testable import GitViewer

final class GitDiffParserTests: XCTestCase {

    // MARK: - parseNameStatus

    func testParseNameStatusEmpty() {
        XCTAssertTrue(GitDiffParser.parseNameStatus("").isEmpty)
    }

    func testParseNameStatusModified() {
        let files = GitDiffParser.parseNameStatus("M\0src/foo.swift\0")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .modified)
        XCTAssertEqual(files[0].newPath, "src/foo.swift")
        XCTAssertNil(files[0].oldPath)
    }

    func testParseNameStatusAdded() {
        let files = GitDiffParser.parseNameStatus("A\0new_file.txt\0")
        XCTAssertEqual(files[0].status, .added)
        XCTAssertEqual(files[0].newPath, "new_file.txt")
    }

    func testParseNameStatusDeleted() {
        let files = GitDiffParser.parseNameStatus("D\0old_file.txt\0")
        XCTAssertEqual(files[0].status, .deleted)
    }

    func testParseNameStatusTypeChanged() {
        let files = GitDiffParser.parseNameStatus("T\0symlink.txt\0")
        XCTAssertEqual(files[0].status, .typeChanged)
    }

    func testParseNameStatusUnmerged() {
        let files = GitDiffParser.parseNameStatus("U\0conflict.txt\0")
        XCTAssertEqual(files[0].status, .unmerged)
    }

    func testParseNameStatusTwoCharUnmerged() {
        // git outputs UU/AA/DU etc. for unmerged entries in octopus merges
        let files = GitDiffParser.parseNameStatus("UU\0conflict.txt\0")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .unmerged)
        XCTAssertEqual(files[0].newPath, "conflict.txt")
    }

    func testParseNameStatusTwoCharAdded() {
        // AA = added by both sides (conflict); all two-char codes are unresolved conflicts → .unmerged
        let files = GitDiffParser.parseNameStatus("AA\0both_added.txt\0")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .unmerged)
    }

    func testParseNameStatusRenamed() {
        let files = GitDiffParser.parseNameStatus("R100\0old/path.swift\0new/path.swift\0")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .renamed)
        XCTAssertEqual(files[0].oldPath, "old/path.swift")
        XCTAssertEqual(files[0].newPath, "new/path.swift")
    }

    func testParseNameStatusCopied() {
        let files = GitDiffParser.parseNameStatus("C100\0original.swift\0copy.swift\0")
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .copied)
        XCTAssertEqual(files[0].oldPath, "original.swift")
        XCTAssertEqual(files[0].newPath, "copy.swift")
    }

    func testParseNameStatusMultipleFiles() {
        let files = GitDiffParser.parseNameStatus("M\0foo.swift\0A\0bar.swift\0D\0baz.swift\0")
        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files[0].status, .modified)
        XCTAssertEqual(files[0].newPath, "foo.swift")
        XCTAssertEqual(files[1].status, .added)
        XCTAssertEqual(files[1].newPath, "bar.swift")
        XCTAssertEqual(files[2].status, .deleted)
        XCTAssertEqual(files[2].newPath, "baz.swift")
    }

    func testParseNameStatusFilenameWithSpaces() {
        let files = GitDiffParser.parseNameStatus("M\0path with spaces/file.txt\0")
        XCTAssertEqual(files[0].newPath, "path with spaces/file.txt")
    }

    func testParseNameStatusFilenameWithNewline() {
        let files = GitDiffParser.parseNameStatus("A\0weird\nname.txt\0")
        XCTAssertEqual(files[0].newPath, "weird\nname.txt")
    }

    func testParseNameStatusRawBytesPreservedForLatin1Path() {
        // Simulate a Latin-1-encoded path: "été.txt" in Latin-1 is [0xE9, 0x74, 0xE9, 0x2E, 0x74, 0x78, 0x74]
        // These bytes are NOT valid UTF-8 (0xE9 is not a valid UTF-8 start/continuation here).
        let statusBytes: [UInt8] = [0x4D]       // "M"
        let nul: [UInt8] = [0x00]
        let pathBytes: [UInt8] = [0xE9, 0x74, 0xE9, 0x2E, 0x74, 0x78, 0x74]  // "été.txt" in Latin-1
        let input = Data(statusBytes + nul + pathBytes + nul)
        let files = GitDiffParser.parseNameStatus(input)
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].status, .modified)
        // rawNewPath must preserve the original bytes exactly
        XCTAssertEqual(files[0].rawNewPath, Data(pathBytes))
        // displayPath is a Latin-1 decoded string
        XCTAssertFalse(files[0].newPath.isEmpty)
    }

    func testParseNameStatusRenameAndOtherMixed() {
        let input = "R090\0old.swift\0new.swift\0M\0other.swift\0"
        let files = GitDiffParser.parseNameStatus(input)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].status, .renamed)
        XCTAssertEqual(files[1].status, .modified)
    }

    // MARK: - parseDiffContent

    private let simpleDiff = """
    diff --git a/foo.swift b/foo.swift
    index abc..def 100644
    --- a/foo.swift
    +++ b/foo.swift
    @@ -1,3 +1,4 @@
     line1
    -line2
    +line2 modified
    +new line
     line3
    """

    func testParseDiffContentEmpty() {
        XCTAssertTrue(GitDiffParser.parseDiffContent("").isEmpty)
    }

    func testParseDiffContentNoHunkHeader() {
        // Lines without @@ header are ignored
        XCTAssertTrue(GitDiffParser.parseDiffContent("just some text\n+added\n-removed").isEmpty)
    }

    func testParseDiffContentSingleHunk() {
        let hunks = GitDiffParser.parseDiffContent(simpleDiff)
        XCTAssertEqual(hunks.count, 1)
    }

    func testHunkHeaderParsed() {
        let hunks = GitDiffParser.parseDiffContent(simpleDiff)
        XCTAssertEqual(hunks[0].oldStart, 1)
        XCTAssertEqual(hunks[0].oldCount, 3)
        XCTAssertEqual(hunks[0].newStart, 1)
        XCTAssertEqual(hunks[0].newCount, 4)
    }

    func testHunkLineCount() {
        let hunks = GitDiffParser.parseDiffContent(simpleDiff)
        // " line1", "-line2", "+line2 modified", "+new line", " line3"
        XCTAssertEqual(hunks[0].lines.count, 5)
    }

    func testHunkLineTypes() {
        let lines = GitDiffParser.parseDiffContent(simpleDiff)[0].lines
        XCTAssertEqual(lines[0].type, .context)
        XCTAssertEqual(lines[1].type, .deleted)
        XCTAssertEqual(lines[2].type, .added)
        XCTAssertEqual(lines[3].type, .added)
        XCTAssertEqual(lines[4].type, .context)
    }

    func testHunkLineContents() {
        let lines = GitDiffParser.parseDiffContent(simpleDiff)[0].lines
        XCTAssertEqual(lines[0].content, "line1")
        XCTAssertEqual(lines[1].content, "line2")
        XCTAssertEqual(lines[2].content, "line2 modified")
        XCTAssertEqual(lines[3].content, "new line")
        XCTAssertEqual(lines[4].content, "line3")
    }

    func testHunkLineNumbers() {
        let lines = GitDiffParser.parseDiffContent(simpleDiff)[0].lines
        // context line1: old=1, new=1
        XCTAssertEqual(lines[0].oldLineNumber, 1)
        XCTAssertEqual(lines[0].newLineNumber, 1)
        // deleted line2: old=2, no new
        XCTAssertEqual(lines[1].oldLineNumber, 2)
        XCTAssertNil(lines[1].newLineNumber)
        // added line2 modified: no old, new=2
        XCTAssertNil(lines[2].oldLineNumber)
        XCTAssertEqual(lines[2].newLineNumber, 2)
        // added new line: no old, new=3
        XCTAssertNil(lines[3].oldLineNumber)
        XCTAssertEqual(lines[3].newLineNumber, 3)
        // context line3: old=3, new=4
        XCTAssertEqual(lines[4].oldLineNumber, 3)
        XCTAssertEqual(lines[4].newLineNumber, 4)
    }

    func testPlusPlusPlusAndMinusMinusMinusSkipped() {
        // +++ and --- (file headers) must not be parsed as diff lines
        let diff = """
        --- a/foo.swift
        +++ b/foo.swift
        @@ -1,1 +1,1 @@
        -old
        +new
        """
        let hunks = GitDiffParser.parseDiffContent(diff)
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks[0].lines.count, 2)
        XCTAssertEqual(hunks[0].lines[0].type, .deleted)
        XCTAssertEqual(hunks[0].lines[1].type, .added)
    }

    func testMultipleHunks() {
        let diff = """
        @@ -1,2 +1,2 @@
        -old1
        +new1
         ctx
        @@ -10,3 +10,2 @@
         ctx2
        -old2
        +new2
        """
        let hunks = GitDiffParser.parseDiffContent(diff)
        XCTAssertEqual(hunks.count, 2)
        XCTAssertEqual(hunks[0].oldStart, 1)
        XCTAssertEqual(hunks[1].oldStart, 10)
        XCTAssertEqual(hunks[1].newCount, 2)
    }

    func testHunkOmittedCountDefaultsToOne() {
        // @@ -5 +5 @@ means count=1 for both
        let diff = "@@ -5 +5 @@\n line"
        let hunks = GitDiffParser.parseDiffContent(diff)
        XCTAssertEqual(hunks[0].oldStart, 5)
        XCTAssertEqual(hunks[0].oldCount, 1)
        XCTAssertEqual(hunks[0].newStart, 5)
        XCTAssertEqual(hunks[0].newCount, 1)
    }

    func testCRLFNormalization() {
        let diff = "@@ -1,2 +1,2 @@\r\n-old\r\n+new\r\n ctx\r\n"
        let hunks = GitDiffParser.parseDiffContent(diff)
        XCTAssertEqual(hunks.count, 1)
        XCTAssertEqual(hunks[0].lines[0].type, .deleted)
        XCTAssertEqual(hunks[0].lines[1].type, .added)
        XCTAssertEqual(hunks[0].lines[2].type, .context)
    }

    func testDiffLineIDsAreUnique() {
        let hunks = GitDiffParser.parseDiffContent(simpleDiff)
        let ids = hunks.flatMap { $0.lines }.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testHunkIDsAreUnique() {
        let diff = """
        @@ -1,1 +1,1 @@
        -a
        +b
        @@ -10,1 +10,1 @@
        -c
        +d
        """
        let hunks = GitDiffParser.parseDiffContent(diff)
        XCTAssertNotEqual(hunks[0].id, hunks[1].id)
    }
}
