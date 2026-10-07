import XCTest
@testable import ack05d

final class ConfigTests: XCTestCase {
    func testDecodeOverlayObject() throws {
        let json = """
        {
          "overlay": {
            "command": "~/.local/bin/hud",
            "textSize": 24.0,
            "padding": 16.0,
            "position": {
              "x": 50.0,
              "y": 80.0
            },
            "durationMs": 1200.0
          },
          "buttons": {},
          "wheelModes": []
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(Config.self, from: json)
        let overlay = try XCTUnwrap(config.overlay)
        XCTAssertEqual(overlay.command, "~/.local/bin/hud")
        XCTAssertEqual(overlay.textSize, 24.0)
        XCTAssertEqual(overlay.padding, 16.0)
        XCTAssertEqual(overlay.durationMs, 1200.0)
        XCTAssertEqual(overlay.position?.x, 50.0)
        XCTAssertEqual(overlay.position?.y, 80.0)
    }

    func testDecodeOverlayOmittedOrPartial() throws {
        let json = """
        {
          "buttons": {},
          "wheelModes": []
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(Config.self, from: json)
        XCTAssertNil(config.overlay)

        let partialJson = """
        {
          "overlay": {
            "textSize": 20.0
          },
          "buttons": {},
          "wheelModes": []
        }
        """.data(using: .utf8)!

        let partialConfig = try JSONDecoder().decode(Config.self, from: partialJson)
        let overlay = try XCTUnwrap(partialConfig.overlay)
        XCTAssertEqual(overlay.textSize, 20.0)
        XCTAssertNil(overlay.command)
        XCTAssertNil(overlay.padding)
        XCTAssertNil(overlay.durationMs)
        XCTAssertNil(overlay.position)
    }
}

