import DynamicGeometry
import Foundation

enum FunctionRunMode: String, CaseIterable, Identifiable, Sendable {
  case graph
  case integral
  case limit

  var id: Self { self }
  var title: String { rawValue.capitalized }
}

struct FunctionRunRequest: Sendable {
  let formula: String
  let mode: FunctionRunMode
  let xMinimum: Double
  let xMaximum: Double
  let yMinimum: Double
  let yMaximum: Double
  let sampleCount: Int
  let integralLower: Double
  let integralUpper: Double
  let limitTarget: Double
  let riemannRule: RiemannSamplingRule

  init(
    formula: String,
    mode: FunctionRunMode,
    xMinimum: Double,
    xMaximum: Double,
    yMinimum: Double,
    yMaximum: Double,
    sampleCount: Int,
    integralLower: Double,
    integralUpper: Double,
    limitTarget: Double,
    riemannRule: RiemannSamplingRule = .midpoint
  ) {
    self.formula = formula
    self.mode = mode
    self.xMinimum = xMinimum
    self.xMaximum = xMaximum
    self.yMinimum = yMinimum
    self.yMaximum = yMaximum
    self.sampleCount = sampleCount
    self.integralLower = integralLower
    self.integralUpper = integralUpper
    self.limitTarget = limitTarget
    self.riemannRule = riemannRule
  }
}

struct FunctionLimitSample: Identifiable, Sendable {
  let distance: Double
  let leftValue: Double
  let rightValue: Double

  var id: Double { distance }
}

struct FunctionRunResult: Sendable {
  let scene: GeometryScene
  let curveDefinition: ExplicitCurveDefinition
  let curveResult: CurveSampleResult
  let riemannDefinition: RiemannSumDefinition?
  let riemannResult: RiemannSumResult?
  let buildMilliseconds: Double
  let encodedByteCount: Int
  let integral: Double?
  let integralFill: [Point2D]
  let limitSamples: [FunctionLimitSample]
  let limitEstimate: String?

  var encodedSize: String {
    ByteCountFormatter.string(fromByteCount: Int64(encodedByteCount), countStyle: .file)
  }

  static func format(_ value: Double) -> String {
    if value.isNaN { return "undefined" }
    if value == .infinity { return "+∞" }
    if value == -.infinity { return "−∞" }
    return String(format: "%.6g", value)
  }

  static func format(_ outcome: ScalarEvaluationOutcome) -> String {
    if let value = outcome.value {
      return format(value)
    }
    switch outcome {
    case .undefined: return "undefined"
    case .unsupported: return "unsupported"
    case .nonconvergent: return "nonconvergent"
    case .pending: return "pending"
    case .exact, .approximate: return "unavailable"
    }
  }
}

enum FunctionLabError: Error, LocalizedError {
  case invalidRange(String)

  var errorDescription: String? {
    switch self {
    case .invalidRange(let name):
      "\(name) minimum must be smaller than its maximum."
    }
  }
}

enum FunctionLabRunner {
  static func run(_ request: FunctionRunRequest) throws -> FunctionRunResult {
    guard request.xMinimum < request.xMaximum else {
      throw FunctionLabError.invalidRange("x")
    }
    guard request.yMinimum < request.yMaximum else {
      throw FunctionLabError.invalidRange("y")
    }
    guard request.integralLower < request.integralUpper || request.mode != .integral else {
      throw FunctionLabError.invalidRange("Integral")
    }

    let xRange = request.xMinimum...request.xMaximum
    var parser = try MathExpressionParser(request.formula)
    let parsedExpression = try parser.parse()
    let variableID = ScalarParameterID()
    let function = try ScalarFunction1D(
      independentVariableID: variableID,
      expression: parsedExpression.scalarExpression(variableID: variableID))
    let curveDefinition = try ExplicitCurveDefinition(function: function, domain: xRange)
    let clock = ContinuousClock()
    let start = clock.now
    let curveResult = try curveDefinition.sample(sampleCount: request.sampleCount)
    let scene = try buildScene(curveResult)
    let elapsed = start.duration(to: clock.now).milliseconds
    let encodedByteCount = try JSONEncoder().encode(scene).count
    let riemannDefinition = try makeRiemannDefinition(request: request, function: function)
    let riemannResult = riemannDefinition?.evaluate()
    let limitResult = limitResult(
      mode: request.mode,
      function: function,
      target: request.limitTarget,
      domainWidth: xRange.upperBound - xRange.lowerBound)

    return FunctionRunResult(
      scene: scene,
      curveDefinition: curveDefinition,
      curveResult: curveResult,
      riemannDefinition: riemannDefinition,
      riemannResult: riemannResult,
      buildMilliseconds: elapsed,
      encodedByteCount: encodedByteCount,
      integral: riemannResult?.signedSum.value,
      integralFill: riemannResult?.rectangles.map {
        Point2D(x: $0.sampleInput, y: $0.height)
      } ?? [],
      limitSamples: limitResult.samples,
      limitEstimate: limitResult.estimate)
  }

  private static func buildScene(_ result: CurveSampleResult) throws -> GeometryScene {
    var scene = GeometryScene(coordinateSystem: .cartesian)

    for branch in result.branches {
      var previousID: GeometryID?
      for point in branch.points {
        let id = try scene.addPoint(.free(point))
        if let previousID {
          _ = try scene.addSegment(start: previousID, end: id)
        }
        previousID = id
      }
    }
    return scene
  }

  private static func makeRiemannDefinition(
    request: FunctionRunRequest,
    function: ScalarFunction1D
  ) throws -> RiemannSumDefinition? {
    guard request.mode == .integral else { return nil }
    return try RiemannSumDefinition(
      function: function,
      interval: request.integralLower...request.integralUpper,
      rectangleCount: request.sampleCount,
      samplingRule: request.riemannRule)
  }

  private static func limitResult(
    mode: FunctionRunMode,
    function: ScalarFunction1D,
    target: Double,
    domainWidth: Double
  ) -> (samples: [FunctionLimitSample], estimate: String?) {
    guard mode == .limit else { return ([], nil) }
    let initialDistance = max(domainWidth / 8, 0.01)
    let samples = (1...10).map { step in
      let distance = initialDistance / Foundation.pow(2, Double(step))
      return FunctionLimitSample(
        distance: distance,
        leftValue: function.evaluate(at: target - distance).value ?? .nan,
        rightValue: function.evaluate(at: target + distance).value ?? .nan)
    }
    guard let last = samples.last else { return (samples, "unknown") }
    return (samples, estimateLimit(left: last.leftValue, right: last.rightValue))
  }

  private static func estimateLimit(left: Double, right: Double) -> String {
    if left == .infinity, right == .infinity { return "+∞" }
    if left == -.infinity, right == -.infinity { return "−∞" }
    guard left.isFinite, right.isFinite else { return "does not agree" }
    let scale = max(1, max(abs(left), abs(right)))
    guard abs(left - right) <= scale * 0.01 else { return "does not agree" }
    return FunctionRunResult.format((left + right) / 2)
  }
}
