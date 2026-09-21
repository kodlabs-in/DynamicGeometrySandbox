import DynamicGeometry
import SwiftUI

nonisolated enum AdvancedMathLabError: Error, LocalizedError, Sendable {
  case scenarioFailed(String)

  var errorDescription: String? {
    switch self {
    case .scenarioFailed(let diagnostic): diagnostic
    }
  }
}

nonisolated enum AdvancedMathScenario: String, CaseIterable, Identifiable, Sendable {
  case polarRose
  case implicitContour
  case surface3D
  case symbolicDerivative
  case constraintIntersection

  var id: Self { self }

  var title: String {
    switch self {
    case .polarRose: "Polar"
    case .implicitContour: "Implicit"
    case .surface3D: "3D Surface"
    case .symbolicDerivative: "Symbolic"
    case .constraintIntersection: "Constraints"
    }
  }
}

nonisolated struct AdvancedLine2D: Equatable, Sendable {
  let start: Point2D
  let end: Point2D
}

nonisolated struct AdvancedMathRunResult: Sendable {
  let lines: [AdvancedLine2D]
  let points: [Point2D]
  let viewport: PlotViewport
  let summary: String
  let detail: String
  let diagnosticCount: Int
}

nonisolated enum AdvancedMathLabRunner {
  static func run(
    scenario: AdvancedMathScenario,
    resolution: Int,
    parameter: Double
  ) throws -> AdvancedMathRunResult {
    switch scenario {
    case .polarRose:
      return try polarRose(resolution: resolution, petalFactor: parameter)
    case .implicitContour:
      return try implicitCircle(resolution: resolution, radius: parameter)
    case .surface3D:
      return try projectedSaddle(resolution: resolution, curvature: parameter)
    case .symbolicDerivative:
      return try symbolicDerivative(resolution: resolution, probe: parameter)
    case .constraintIntersection:
      return try constraintIntersection(resolution: resolution, initialValue: parameter)
    }
  }

  private static func polarRose(
    resolution: Int,
    petalFactor: Double
  ) throws -> AdvancedMathRunResult {
    let thetaID = ScalarParameterID()
    let petalID = ScalarParameterID()
    let theta = ScalarExpression.parameter(.identified(thetaID))
    let petal = ScalarExpression.parameter(.identified(petalID))
    let radius = ScalarExpression.function(
      .cosine,
      argument: .arithmetic(
        left: petal,
        operation: .multiplication,
        right: theta))
    let function = try ScalarFunction1D(
      independentVariableID: thetaID,
      independentVariableName: "theta",
      expression: radius)
    let curve = try PolarCurveDefinition(
      radiusFunction: function,
      angleDomain: 0...(2 * Double.pi))
    let petalParameter = try ScalarParameter(
      id: petalID,
      name: "petalFactor",
      value: petalFactor)
    let sample = try curve.sample(
      sampleCount: max(16, resolution),
      parameters: [petalParameter])

    return AdvancedMathRunResult(
      lines: lines(from: sample.branches),
      points: [],
      viewport: PlotViewport(xRange: -1.15...1.15, yRange: -1.15...1.15),
      summary: "Polar rose · r = cos(\(petalFactor.formatted())θ)",
      detail: "A semantic PolarCurveDefinition sampled into independent safe branches.",
      diagnosticCount: sample.diagnostics.count)
  }

  private static func implicitCircle(
    resolution: Int,
    radius: Double
  ) throws -> AdvancedMathRunResult {
    let safeRadius = max(0.1, abs(radius))
    let xID = ScalarParameterID()
    let yID = ScalarParameterID()
    let radiusID = ScalarParameterID()
    let square: (ScalarExpression) -> ScalarExpression = {
      .arithmetic(left: $0, operation: .power, right: .constant(2))
    }
    let relation = try ScalarFunction2D(
      horizontalVariableID: xID,
      verticalVariableID: yID,
      expression: .arithmetic(
        left: .arithmetic(
          left: square(.parameter(.identified(xID))),
          operation: .addition,
          right: square(.parameter(.identified(yID)))),
        operation: .subtraction,
        right: square(.parameter(.identified(radiusID)))))
    let extent = safeRadius * 1.25
    let curve = try ImplicitCurveDefinition(
      relation: relation,
      horizontalDomain: -extent...extent,
      verticalDomain: -extent...extent)
    let radiusParameter = try ScalarParameter(
      id: radiusID,
      name: "radius",
      value: safeRadius)
    let contour = try curve.extractContours(
      columns: max(8, resolution),
      rows: max(8, resolution),
      parameters: [radiusParameter])

    return AdvancedMathRunResult(
      lines: contour.segments.map { AdvancedLine2D(start: $0.start, end: $0.end) },
      points: [],
      viewport: PlotViewport(xRange: -extent...extent, yRange: -extent...extent),
      summary: "Implicit contour · x² + y² = \(safeRadius * safeRadius)",
      detail: "Bounded marching-squares approximation; unresolved cells stay diagnosed.",
      diagnosticCount: contour.diagnostics.count)
  }

  static func lines(from branches: [CurveSampleBranch]) -> [AdvancedLine2D] {
    branches.flatMap { branch in
      zip(branch.points, branch.points.dropFirst()).map {
        AdvancedLine2D(start: $0, end: $1)
      }
    }
  }
}
