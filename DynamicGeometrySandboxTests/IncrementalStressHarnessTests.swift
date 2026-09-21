import DynamicGeometry
import Foundation
import Testing

@testable import DynamicGeometrySandbox

@Suite("Incremental stress harness")
struct IncrementalStressHarnessTests {
  @Test(
    "Representative fan-out runs record each root update and its affected branch",
    arguments: [100, 1_000, 10_000])
  func recordsRepresentativeFanOutRun(dependentCount: Int) throws {
    let result = try StressRunner.run(
      pattern: .incrementalFanOut,
      requestedCount: dependentCount)
    let metrics = try #require(result.incrementalMetrics)

    #expect(result.scene.orderedIDs.count == dependentCount + 1)
    #expect(metrics.dependentEntityCount == dependentCount)
    #expect(metrics.updateMilliseconds.count == 12)
    #expect(metrics.affectedCounts == Array(repeating: dependentCount + 1, count: 12))
    #expect(metrics.updateMilliseconds.allSatisfy { $0 >= 0 })
    #expect(metrics.p95UpdateMilliseconds == nearestRankP95(metrics.updateMilliseconds))
    #expect(metrics.frameBudgetMilliseconds == 16.7)

    print(
      "Incremental fan-out: dependents=\(dependentCount), "
        + "p95=\(metrics.p95UpdateMilliseconds) ms, "
        + "affected=\(metrics.typicalAffectedCount)")
  }

  private func nearestRankP95(_ measurements: [Double]) -> Double {
    let ordered = measurements.sorted()
    let index = max(0, Int(ceil(Double(ordered.count) * 0.95)) - 1)
    return ordered[index]
  }
}
