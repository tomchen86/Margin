import UIKit
import XCTest

/// Margin's offer of folder access, and the system folder picker it opens.
extension DocumentBrowser {
    /// Launch arguments that make the app read files as iOS lets it on a device. The simulator does
    /// not enforce the sandbox for files outside the app (ADR-0004), so with these the app can read
    /// only the opened document, its own container, and the folders the owner granted; reading any
    /// other file fails as iOS would make it fail.
    static let deviceSandbox = ["-SimulateSandbox"]

    /// The button that offers access to the folder called `name`.
    func accessOffer(naming name: String) -> XCUIElement {
        app.buttons["Allow Access to “\(name)”"].firstMatch
    }

    /// Any button that offers folder access.
    var anyAccessOffer: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Allow Access to'")).firstMatch
    }

    /// Whether the reader shows the image whose alternative text is `alt` at its full size, which is
    /// wider than a broken image's placeholder, within `timeout` seconds.
    func readerShowsImage(_ alt: String, timeout: TimeInterval = 30) -> Bool {
        let image = app.webViews.images[alt].firstMatch
        let shown = NSPredicate { _, _ in image.exists && image.frame.width >= 150 }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: shown, object: nil)], timeout: timeout)
            == .completed
    }

    /// A 200 × 100 PNG.
    static func photo() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100), format: format).pngData { context in
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }
    }
}
