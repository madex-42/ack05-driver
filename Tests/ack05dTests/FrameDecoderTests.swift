import XCTest
import Foundation
@testable import ack05d

final class FrameDecoderTests: XCTestCase {
    private func frame(b2: UInt8 = 0, b3: UInt8 = 0, b7: UInt8 = 0) -> Data {
        Data([0x02, 0xf0, b2, b3, 0, 0, 0, b7, 0, 0])
    }

    func testPressThenRelease() {
        var d = FrameDecoder()
        XCTAssertEqual(d.decode(frame(b2: 0x01)), [.press(.b1)])
        XCTAssertEqual(d.decode(frame(b2: 0x01)), [])  // unchanged state: no repeat
        XCTAssertEqual(d.decode(frame()), [.release(.b1)])
    }

    func testWheelPulses() {
        var d = FrameDecoder()
        XCTAssertEqual(d.decode(frame(b7: 0x01)), [.wheel(.cw)])
        XCTAssertEqual(d.decode(frame(b7: 0x02)), [.wheel(.ccw)])
    }

    func testBatteryAndReconnect() {
        var d = FrameDecoder()
        XCTAssertEqual(d.decode(Data([0x02, 0xf2, 0, 87, 1])), [.battery(percent: 87, charging: true)])
        XCTAssertEqual(d.decode(Data([0x02, 0xf8, 0, 0])), [.reconnect])
    }

    /// A fresh decoder (as created after a link drop) reports a still-held button as a new press.
    func testFreshDecoderSeesHeldButtonAsPress() {
        var old = FrameDecoder()
        _ = old.decode(frame(b2: 0x01))
        var fresh = FrameDecoder()
        XCTAssertEqual(fresh.decode(frame(b2: 0x01)), [.press(.b1)])
    }

    func testShortOrUnknownFramesIgnored() {
        var d = FrameDecoder()
        XCTAssertEqual(d.decode(Data([0x02, 0xf0])), [])
        XCTAssertEqual(d.decode(Data([0x01, 0xf0, 0, 0])), [])
        XCTAssertEqual(d.decode(Data([0x02, 0x99, 0, 0])), [])
    }
}
