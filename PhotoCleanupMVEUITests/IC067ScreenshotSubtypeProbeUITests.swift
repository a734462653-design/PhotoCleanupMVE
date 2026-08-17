import XCTest

final class IC067ScreenshotSubtypeProbeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCroppedScreenshotRetainsScreenshotSubtype() {
        let app = XCUIApplication()
        app.launchArguments = ["--ic067-screenshot-subtype-probe"]

        var handledPhotoAuthorization = false
        addUIInterruptionMonitor(
            withDescription: "照片访问授权"
        ) { alert in
            let allowedButtonTitles = [
                "允许完全访问",
                "允许访问所有照片",
                "Allow Full Access",
                "Allow Access to All Photos"
            ]
            for title in allowedButtonTitles {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    handledPhotoAuthorization = true
                    return true
                }
            }
            return false
        }

        app.launch()
        app.tap()

        let result = app.staticTexts["ic067.g38.probe.result"]
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label BEGINSWITH 'IC067_G38_PROBE' OR " +
                    "label BEGINSWITH 'IC067_G38_ERROR'"
            ),
            object: result
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [completed], timeout: 30),
            .completed,
            "截图子类型探针未在三十秒内返回结果"
        )
        XCTAssertTrue(
            handledPhotoAuthorization,
            "未通过真实系统弹窗授予照片访问权限"
        )
        XCTAssertTrue(
            result.label.hasPrefix("IC067_G38_PROBE") &&
                result.label.contains("afterIsScreenshot=true"),
            result.label
        )
        print(result.label)
    }
}
