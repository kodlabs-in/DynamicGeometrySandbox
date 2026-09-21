import CoreGraphics
import DynamicGeometry
import Foundation
import Testing

@testable import DynamicGeometrySandbox

@Suite("Plot viewport")
struct PlotViewportTests {
  @Test("Geometry coordinates round-trip through a non-square canvas")
  func roundTripsCoordinates() {
    let viewport = PlotViewport(xRange: -10...10, yRange: -5...5)
    let geometryPoint = Point2D(x: 3.25, y: -1.5)
    let canvasSize = CGSize(width: 1_024, height: 420)

    let viewPoint = viewport.viewPoint(geometryPoint, size: canvasSize)
    let restoredPoint = viewport.geometryPoint(viewPoint, size: canvasSize)

    #expect(isClose(restoredPoint.x, geometryPoint.x))
    #expect(isClose(restoredPoint.y, geometryPoint.y))
  }
}

@Suite("Formula parser")
struct FormulaParserTests {
  @Test("Functions, constants, precedence, and right-associative powers evaluate correctly")
  func evaluatesSupportedSyntax() throws {
    var parser = try MathExpressionParser("sin(pi / 2) + 2 * x^2^2")
    let expression = try parser.parse()

    #expect(isClose(expression.evaluate(x: 2), 33))
  }

  @Test("An unsupported function produces an actionable error")
  func rejectsUnknownFunctions() {
    #expect(throws: MathExpressionError.self) {
      var parser = try MathExpressionParser("sinh(x)")
      _ = try parser.parse()
    }
  }
}

@Suite("Function experiments")
struct FunctionExperimentTests {
  @Test("A sampled graph becomes package points and segments")
  func buildsFiniteGeometryScene() throws {
    let result = try FunctionLabRunner.run(request(formula: "sin(x)", sampleCount: 32))

    #expect(result.scene.orderedIDs.count == 63)
    #expect(result.encodedByteCount > 0)
    try result.scene.validate()
  }

  @Test("The trapezoidal integral approximates the area under sine")
  func approximatesIntegral() throws {
    let result = try FunctionLabRunner.run(
      request(
        formula: "sin(x)",
        mode: .integral,
        sampleCount: 512,
        integralLower: 0,
        integralUpper: .pi))
    let integral = try #require(result.integral)

    #expect(isClose(integral, 2, tolerance: 0.0001))
    #expect(result.integralFill.count == 512)
  }

  @Test("A removable discontinuity approaches the expected two-sided limit")
  func estimatesFiniteLimit() throws {
    let result = try FunctionLabRunner.run(
      request(formula: "sin(x) / x", mode: .limit, limitTarget: 0))
    let estimateText = try #require(result.limitEstimate)
    let estimate = try #require(Double(estimateText))

    #expect(isClose(estimate, 1, tolerance: 0.0001))
    #expect(result.limitSamples.count == 10)
  }

  @Test("Opposite one-sided behaviour is not reported as a limit")
  func rejectsDisagreeingLimit() throws {
    let result = try FunctionLabRunner.run(
      request(formula: "1 / x", mode: .limit, limitTarget: 0))

    #expect(result.limitEstimate == "does not agree")
  }

  private func request(
    formula: String,
    mode: FunctionRunMode = .graph,
    sampleCount: Int = 64,
    integralLower: Double = -1,
    integralUpper: Double = 1,
    limitTarget: Double = 0
  ) -> FunctionRunRequest {
    FunctionRunRequest(
      formula: formula,
      mode: mode,
      xMinimum: -4,
      xMaximum: 4,
      yMinimum: -4,
      yMaximum: 4,
      sampleCount: sampleCount,
      integralLower: integralLower,
      integralUpper: integralUpper,
      limitTarget: limitTarget)
  }
}

@Suite("Stress experiments")
struct StressExperimentTests {
  @Test("Invalid geometry is rejected without leaving partial scene state")
  func invalidInputRollsBack() throws {
    let result = try StressRunner.run(pattern: .invalidInput, requestedCount: 100)

    #expect(result.scene.orderedIDs.isEmpty)
    #expect(result.summary.contains("remained empty and valid"))
  }

  @Test("Identical overlapping circles keep distinct identities")
  func overlappingShapesRemainDistinct() throws {
    let result = try StressRunner.run(pattern: .overlapping, requestedCount: 100)

    #expect(result.scene.orderedIDs.count == 101)
    try result.scene.validate()
  }
}

private func isClose(_ left: Double, _ right: Double, tolerance: Double = 0.000_001) -> Bool {
  abs(left - right) <= tolerance
}
