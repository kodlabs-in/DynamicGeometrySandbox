import DynamicGeometry
import Foundation

nonisolated extension AdvancedMathLabRunner {
  static func projectedSaddle(
    resolution: Int,
    curvature: Double
  ) throws -> AdvancedMathRunResult {
    let horizontalID = ScalarParameterID()
    let verticalID = ScalarParameterID()
    let curvatureID = ScalarParameterID()
    let horizontal = ScalarExpression.parameter(.identified(horizontalID))
    let vertical = ScalarExpression.parameter(.identified(verticalID))
    let surface = try ParametricSurfaceDefinition(
      uVariableID: horizontalID,
      vVariableID: verticalID,
      xExpression: horizontal,
      yExpression: vertical,
      zExpression: saddleHeight(
        horizontal: horizontal,
        vertical: vertical,
        curvatureID: curvatureID),
      uDomain: -1.5...1.5,
      vDomain: -1.5...1.5)
    let curvatureParameter = try ScalarParameter(
      id: curvatureID,
      name: "curvature",
      value: curvature)
    let sampleCount = max(3, min(40, resolution))
    let mesh = try surface.sample(
      uSampleCount: sampleCount,
      vSampleCount: sampleCount,
      parameters: [curvatureParameter])

    return AdvancedMathRunResult(
      lines: projectedMeshLines(mesh),
      points: [],
      viewport: PlotViewport(xRange: -3...3, yRange: -3...3),
      summary: "3D saddle · z = \(curvature.formatted())(u² − v²)",
      detail: "A package-generated indexed 3D mesh shown with a fixed isometric projection.",
      diagnosticCount: mesh.diagnostics.count)
  }

  static func symbolicDerivative(
    resolution: Int,
    probe: Double
  ) throws -> AdvancedMathRunResult {
    let xID = ScalarParameterID()
    let xExpression = ScalarExpression.parameter(.identified(xID))
    let squared = ScalarExpression.arithmetic(
      left: xExpression,
      operation: .power,
      right: .constant(2))
    let expression = ScalarExpression.function(.sine, argument: squared)
    guard
      case .exact(let derivativeExpression) = expression.differentiated(
        withRespectTo: xID)
    else {
      throw MathExpressionError.unsupportedPackageFunction("symbolic derivative")
    }
    let originalFunction = try ScalarFunction1D(
      independentVariableID: xID,
      expression: expression)
    let derivativeFunction = try ScalarFunction1D(
      independentVariableID: xID,
      expression: derivativeExpression)
    let originalCurve = try ExplicitCurveDefinition(function: originalFunction, domain: -2...2)
    let derivativeCurve = try ExplicitCurveDefinition(function: derivativeFunction, domain: -2...2)
    let sampleCount = max(16, resolution)
    let originalSample = try originalCurve.sample(sampleCount: sampleCount)
    let derivativeSample = try derivativeCurve.sample(sampleCount: sampleCount)
    let safeProbe = min(2, max(-2, probe))

    return AdvancedMathRunResult(
      lines: lines(from: originalSample.branches) + lines(from: derivativeSample.branches),
      points: probePoints(
        at: safeProbe,
        originalFunction: originalFunction,
        derivativeFunction: derivativeFunction),
      viewport: PlotViewport(xRange: -2.2...2.2, yRange: -4.5...4.5),
      summary: "Symbolic derivative · f(x) = sin(x²)",
      detail: "The package derives an exact expression, then both expressions are sampled.",
      diagnosticCount: originalSample.diagnostics.count + derivativeSample.diagnostics.count)
  }

  static func constraintIntersection(
    resolution: Int,
    initialValue: Double
  ) throws -> AdvancedMathRunResult {
    let xID = ScalarParameterID()
    let yID = ScalarParameterID()
    let xExpression = ScalarExpression.parameter(.identified(xID))
    let yExpression = ScalarExpression.parameter(.identified(yID))
    let branchSeed = initialValue < 0 ? min(-0.2, initialValue) : max(0.2, initialValue)
    let system = try makeIntersectionSystem(
      xID: xID,
      yID: yID,
      xExpression: xExpression,
      yExpression: yExpression,
      branchSeed: branchSeed)
    guard case .converged(let solution) = system.solve() else {
      throw AdvancedMathLabError.scenarioFailed(
        "The local numerical constraint solve did not converge.")
    }
    guard
      let solvedX = solution.value(for: xID),
      let solvedY = solution.value(for: yID)
    else {
      throw AdvancedMathLabError.scenarioFailed("The solver omitted a requested variable.")
    }
    let circleSample = try unitCircleSample(resolution: resolution)

    return AdvancedMathRunResult(
      lines: lines(from: circleSample.branches),
      points: [Point2D(x: solvedX, y: solvedY)],
      viewport: PlotViewport(xRange: -1.25...1.25, yRange: -1.25...1.25),
      summary: "Constraint intersection · circle ∩ x = y",
      detail: "The initial seed selects a local branch; this is a bounded numerical result.",
      diagnosticCount: circleSample.diagnostics.count)
  }
}

private nonisolated extension AdvancedMathLabRunner {
  static func saddleHeight(
    horizontal: ScalarExpression,
    vertical: ScalarExpression,
    curvatureID: ScalarParameterID
  ) -> ScalarExpression {
    let square: (ScalarExpression) -> ScalarExpression = {
      .arithmetic(left: $0, operation: .power, right: .constant(2))
    }
    return .arithmetic(
      left: .parameter(.identified(curvatureID)),
      operation: .multiplication,
      right: .arithmetic(
        left: square(horizontal),
        operation: .subtraction,
        right: square(vertical)))
  }

  static func projectedMeshLines(_ mesh: ParametricSurfaceMesh) -> [AdvancedLine2D] {
    let projectedPoints = mesh.vertices.map { project($0.point) }
    return mesh.triangles.flatMap { triangle in
      let indices = [
        triangle.firstVertexIndex,
        triangle.secondVertexIndex,
        triangle.thirdVertexIndex,
      ]
      return [
        AdvancedLine2D(start: projectedPoints[indices[0]], end: projectedPoints[indices[1]]),
        AdvancedLine2D(start: projectedPoints[indices[1]], end: projectedPoints[indices[2]]),
        AdvancedLine2D(start: projectedPoints[indices[2]], end: projectedPoints[indices[0]]),
      ]
    }
  }

  static func project(_ point: Point3D) -> Point2D {
    Point2D(
      x: point.x - 0.65 * point.z,
      y: point.y + 0.35 * point.z)
  }

  static func probePoints(
    at value: Double,
    originalFunction: ScalarFunction1D,
    derivativeFunction: ScalarFunction1D
  ) -> [Point2D] {
    [
      originalFunction.evaluate(at: value).value.map { Point2D(x: value, y: $0) },
      derivativeFunction.evaluate(at: value).value.map { Point2D(x: value, y: $0) },
    ].compactMap { $0 }
  }

  static func makeIntersectionSystem(
    xID: ScalarParameterID,
    yID: ScalarParameterID,
    xExpression: ScalarExpression,
    yExpression: ScalarExpression,
    branchSeed: Double
  ) throws -> ScalarConstraintSystem {
    let square: (ScalarExpression) -> ScalarExpression = {
      .arithmetic(left: $0, operation: .power, right: .constant(2))
    }
    return try ScalarConstraintSystem(
      variables: [
        ScalarParameter(id: xID, name: "x", value: branchSeed),
        ScalarParameter(id: yID, name: "y", value: branchSeed),
      ],
      constraints: [
        ScalarEqualityConstraint(
          left: .arithmetic(
            left: square(xExpression),
            operation: .addition,
            right: square(yExpression)),
          right: .constant(1)),
        ScalarEqualityConstraint(left: xExpression, right: yExpression),
      ])
  }

  static func unitCircleSample(resolution: Int) throws -> CurveSampleResult {
    let angleID = ScalarParameterID()
    let circle = try PolarCurveDefinition(
      radiusFunction: ScalarFunction1D(
        independentVariableID: angleID,
        independentVariableName: "theta",
        expression: .constant(1)),
      angleDomain: 0...(2 * Double.pi))
    return try circle.sample(sampleCount: max(16, resolution))
  }
}
