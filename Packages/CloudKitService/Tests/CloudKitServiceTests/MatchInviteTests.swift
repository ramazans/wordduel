import XCTest
import CloudKit
@testable import CloudKitService

final class MatchInviteTests: XCTestCase {
    func testRoundTripThroughCKRecord() throws {
        let invite = MatchInvite(
            code: "AB23K9",
            shareURL: URL(string: "https://www.icloud.com/share/abc")!,
            hostUserRecordName: "_user-123"
        )
        let record = invite.asRecord()
        let decoded = try MatchInvite(record: record)

        XCTAssertEqual(decoded.code, invite.code)
        XCTAssertEqual(decoded.shareURL, invite.shareURL)
        XCTAssertEqual(decoded.hostUserRecordName, invite.hostUserRecordName)
        XCTAssertEqual(
            decoded.expiresAt.timeIntervalSince1970,
            invite.expiresAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testIsExpiredFalseWhenFresh() {
        let invite = MatchInvite(
            code: "AB23K9",
            shareURL: URL(string: "https://example")!,
            hostUserRecordName: "_user",
            createdAt: .now,
            ttl: 60
        )
        XCTAssertFalse(invite.isExpired)
    }

    func testIsExpiredTrueWhenPastTTL() {
        let invite = MatchInvite(
            code: "AB23K9",
            shareURL: URL(string: "https://example")!,
            hostUserRecordName: "_user",
            createdAt: Date(timeIntervalSinceNow: -120),
            ttl: 60
        )
        XCTAssertTrue(invite.isExpired)
    }

    func testMalformedRecordThrows() {
        let record = CKRecord(recordType: MatchInvite.recordType)
        // No fields set → malformed
        XCTAssertThrowsError(try MatchInvite(record: record)) { error in
            XCTAssertEqual(error as? MatchInvite.RecordError, .malformed)
        }
    }

    func testRecordIDDerivedFromCode() {
        let invite = MatchInvite(
            code: "AB23K9",
            shareURL: URL(string: "https://example")!,
            hostUserRecordName: "_user"
        )
        let record = invite.asRecord()
        XCTAssertEqual(record.recordID.recordName, "invite-AB23K9")
    }
}
