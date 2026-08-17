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
        let authorizationDeadline = Date().addingTimeInterval(10)
        repeat {
            app.tap()
            if handledPhotoAuthorization {
                break
            }
            RunLoop.current.run(
                until: Date().addingTimeInterval(0.25)
            )
        } while Date() < authorizationDeadline

        let result = app.staticTexts["ic067.g38.probe.result"]
        let completed = XCTNSPredicateExpectation(
            predicate: NSPredicate(
                format: "label BEGINSWITH 'IC067_G38_PROBE' OR " +
                    "label BEGINSWITH 'IC067_G38_ERROR'"
            ),
            object: result
        )
        let waitResult = XCTWaiter.wait(for: [completed], timeout: 30)
        print(
            "IC067_G38_UI permissionHandled=" +
                "\(handledPhotoAuthorization) result=\(result.label)"
        )
        XCTAssertEqual(
            waitResult,
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

final class IC067RealInteractionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // G40～G41：只能由 XCUITest 的真实双指事件进入生产手势路径。
    func testRealPinchTakeoverAndOneXReturnGeometry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ic067-real-interaction-probe"]
        app.launch()

        let viewport = app.otherElements["ic067.interaction.viewport"]
        let result = app.staticTexts["ic067.interaction.result"]
        XCTAssertTrue(viewport.waitForExistence(timeout: 10))
        XCTAssertTrue(result.waitForExistence(timeout: 10))

        viewport.pinch(withScale: 1.5, velocity: 1)
        let enlarged = waitForResult(result, timeout: 10) { label in
            self.number("takeovers", in: label) >= 1
        }
        XCTAssertLessThanOrEqual(
            number("takeoverCenterOffset", in: enlarged),
            0.5,
            enlarged
        )

        viewport.pinch(withScale: 0.5, velocity: -1)
        let returned = waitForResult(result, timeout: 10) { label in
            self.number("returns", in: label) >= 1
        }
        XCTAssertLessThanOrEqual(
            number("returnScaleDelta", in: returned),
            0.000_001,
            returned
        )
        XCTAssertLessThanOrEqual(
            number("returnFrameDeviation", in: returned),
            0.5,
            returned
        )
        XCTAssertTrue(
            returned.contains("returnVisibility=visible"),
            returned
        )
        print("IC067_G40_G41_UI \(returned)")
    }

    private func waitForResult(
        _ element: XCUIElement,
        timeout: TimeInterval,
        predicate: (String) -> Bool
    ) -> String {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            let label = element.label
            if predicate(label) {
                return label
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        XCTFail("真实交互诊断未在时限内更新：\(element.label)")
        return element.label
    }

    private func number(_ key: String, in label: String) -> Double {
        let prefix = "\(key)="
        guard let token = label.split(separator: " ").first(where: {
            $0.hasPrefix(prefix)
        }),
        let value = Double(token.dropFirst(prefix.count)) else {
            return -1
        }
        return value
    }
}
