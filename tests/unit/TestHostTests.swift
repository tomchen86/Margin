import Foundation
import Testing

/// The hosted test targets run inside the Margin app, so `Bundle.main` is the app.
@Suite struct TestHostTests {
    @Test func testsRunInsideTheApp() {
        #expect(Bundle.main.bundleIdentifier == "io.github.tomchen86.Margin")
    }
}
