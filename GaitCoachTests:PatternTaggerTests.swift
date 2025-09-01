import XCTest
@testable import GaitCoach

final class PatternTaggerTests: XCTestCase {
    private func has(_ tag: String, in tags: [String]) -> Bool { tags.contains(tag) }

    func testNoTagsWhenVerySlow() {
        let m = SessionMetrics(cadenceSPM: 50, mlSwayRMS: 0.15, avgStepTime: 1.2, cvStepTime: 0.20)
        let tags = makePatternTags(metrics: m, baseline: nil)
        XCTAssertTrue(tags.isEmpty)
    }

    func testTrendelenburgByHighMLAbsolute() {
        let m = SessionMetrics(cadenceSPM: 90, mlSwayRMS: 0.12, avgStepTime: 0.8, cvStepTime: 0.05)
        let tags = makePatternTags(metrics: m, baseline: nil)
        XCTAssertTrue(has(GaitTag.trendelenburgLike, in: tags))
    }

    func testAntalgicByHighCVAndLowerCadence() {
        let m = SessionMetrics(cadenceSPM: 95, mlSwayRMS: 0.05, avgStepTime: 0.7, cvStepTime: 0.10)
        let tags = makePatternTags(metrics: m, baseline: nil)
        XCTAssertTrue(has(GaitTag.antalgic, in: tags))
    }

    func testAtaxicByHighMLAndHighCV() {
        let m = SessionMetrics(cadenceSPM: 90, mlSwayRMS: 0.11, avgStepTime: 0.8, cvStepTime: 0.14)
        let tags = makePatternTags(metrics: m, baseline: nil)
        XCTAssertTrue(has(GaitTag.ataxicWideBased, in: tags))
    }

    func testShufflingShortStepsProxy() {
        let m = SessionMetrics(cadenceSPM: 120, mlSwayRMS: 0.06, avgStepTime: 0.5, cvStepTime: 0.08)
        let tags = makePatternTags(metrics: m, baseline: nil)
        XCTAssertTrue(has(GaitTag.shufflingShortSteps, in: tags))
    }

    func testBaselineRelativeMLIncreaseTriggersTrendelenburg() {
        let base = Baseline(
            date: Date(),              // <- date comes first
            avgStepTime: 0.7,
            cvStepTime: 0.05,
            mlSwayRMS: 0.06,
            asymStepTimePct: 6.0
        )

        let m = SessionMetrics(cadenceSPM: 90, mlSwayRMS: 0.08, avgStepTime: 0.7, cvStepTime: 0.05)
        let tags = makePatternTags(metrics: m, baseline: base)
        XCTAssertTrue(tags.contains(GaitTag.trendelenburgLike))
    }
}

