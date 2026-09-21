import DynamicGeometry
import Foundation
import Testing

@testable import DynamicGeometrySandbox

@Suite("Package-backed Function Lab")
struct PackageBackedFunctionLabTests {
  @Test("A free-form quadratic produces a persistable package curve and sampled geometry")
  func buildsSemanticQuadratic() throws {
    let result = try FunctionLabRunner.run(request(formula: "x^2", sampleCount: 5))

    #expect(
      result.curveResult.branches.map(\.points) == [
        [
          Point2D(x: -2, y: 4),
          Point2D(x: -1, y: 1),
          Point2D(x: 0, y: 0),
          Point2D(x: 1, y: 1),
          Point2D(x: 2, y: 4),
        ]
      ])
    #expect(result.scene.orderedIDs.count == 9)

    let stored = try JSONEncoder().encode(result.curveDefinition)
    let reopened = try JSONDecoder().decode(ExplicitCurveDefinition.self, from: stored)
    #expect(try reopened.sample(sampleCount: 5) == result.curveResult)
  }

  @Test("A reciprocal graph keeps its two branches disconnected")
  func preservesReciprocalGap() throws {
    let result = try FunctionLabRunner.run(request(formula: "1/x", sampleCount: 4))

    #expect(result.curveResult.branches.count == 2)
    let segments = try result.scene.orderedIDs.compactMap { id -> Segment2D? in
      guard case .segment = result.scene.entity(id) else { return nil }
      return try result.scene.segment(id)
    }
    #expect(
      segments.allSatisfy { segment in
        !(segment.start.x < 0 && segment.end.x > 0)
      })
  }

  @Test("Integral mode exposes persistable package rectangles and signed sum")
  func buildsSemanticRiemannSum() throws {
    let result = try FunctionLabRunner.run(
      request(
        formula: "x^2",
        mode: .integral,
        sampleCount: 4,
        integralLower: 0,
        integralUpper: 2,
        riemannRule: .left))
    let definition = try #require(result.riemannDefinition)
    let riemannResult = try #require(result.riemannResult)

    #expect(riemannResult.rectangles.map(\.sampleInput) == [0, 0.5, 1, 1.5])
    #expect(riemannResult.signedSum.value == 1.75)
    #expect(result.integral == 1.75)

    let stored = try JSONEncoder().encode(definition)
    let reopened = try JSONDecoder().decode(RiemannSumDefinition.self, from: stored)
    #expect(reopened.evaluate() == riemannResult)
  }

  @Test("A parsed function outside the package capability returns a clear error")
  func reportsUnsupportedFunction() {
    #expect(throws: MathExpressionError.unsupportedPackageFunction("floor")) {
      _ = try FunctionLabRunner.run(request(formula: "floor(x)"))
    }
  }

  private func request(
    formula: String,
    mode: FunctionRunMode = .graph,
    sampleCount: Int = 64,
    integralLower: Double = -1,
    integralUpper: Double = 1,
    riemannRule: RiemannSamplingRule = .midpoint
  ) -> FunctionRunRequest {
    FunctionRunRequest(
      formula: formula,
      mode: mode,
      xMinimum: -2,
      xMaximum: 2,
      yMinimum: -4,
      yMaximum: 4,
      sampleCount: sampleCount,
      integralLower: integralLower,
      integralUpper: integralUpper,
      limitTarget: 0,
      riemannRule: riemannRule)
  }
}
