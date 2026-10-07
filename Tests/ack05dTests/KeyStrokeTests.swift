import XCTest
import CoreGraphics
@testable import ack05d

final class KeyStrokeTests: XCTestCase {
    func testChord() throws {
        let ks = try XCTUnwrap(KeyStroke("shift+cmd+4"))
        guard case .key(let code, let flags) = ks.kind else { return XCTFail("expected chord") }
        XCTAssertEqual(code, 21)
        XCTAssertEqual(flags, [.maskShift, .maskCommand])
    }

    func testModifierOnly() throws {
        let ks = try XCTUnwrap(KeyStroke("shift"))
        XCTAssertTrue(ks.isModifierOnly)
        XCTAssertEqual(ks.heldFlags, .maskShift)
    }

    func testRightSideModifier() throws {
        let ks = try XCTUnwrap(KeyStroke("rshift"))
        guard case .modifier(let mods) = ks.kind else { return XCTFail("expected modifier") }
        XCTAssertEqual(mods.map(\.code), [60])
    }

    func testTrailingPlusKey() throws {
        for spec in ["cmd++", "+", "cmd+plus"] {
            let ks = try XCTUnwrap(KeyStroke(spec), spec)
            XCTAssertFalse(ks.isModifierOnly, spec)
        }
        guard case .key(let code, let flags) = try XCTUnwrap(KeyStroke("cmd++")).kind else { return XCTFail() }
        XCTAssertEqual(code, 24)
        XCTAssertEqual(flags, .maskCommand)
    }

    func testMalformedSpecsRejected() {
        for spec in ["", "  ", "shift+", "cmd+a+b", "cmd+nope", "nope", "cmd++a", "+ +"] {
            XCTAssertNil(KeyStroke(spec), "should reject \"\(spec)\"")
        }
    }

    func testCapsLockAndFnUnsupported() {
        XCTAssertNil(KeyStroke("capslock"))
        XCTAssertNil(KeyStroke("fn"))
    }

    func testCaseAndWhitespaceInsensitive() throws {
        let ks = try XCTUnwrap(KeyStroke(" CMD + F5 "))
        guard case .key(let code, _) = ks.kind else { return XCTFail() }
        XCTAssertEqual(code, 96)
    }
}
