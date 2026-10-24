import AppKit
import XCTest
@testable import ClipStash

final class AppResourcesTests: XCTestCase {
    func testPackagedLogoLoads() throws {
        let image = try XCTUnwrap(AppResources.logo)
        XCTAssertTrue(image.isValid)
        XCTAssertGreaterThan(image.size.width, 0)
        XCTAssertGreaterThan(image.size.height, 0)
    }
}
