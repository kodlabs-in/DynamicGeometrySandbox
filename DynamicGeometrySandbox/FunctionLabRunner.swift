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
}

struct FunctionLimitSample: Identifiable, Sendable {
  let distance: Double
  let leftValue: Double
  let rightValue: Double

  var id: Double { distance }
}

struct FunctionRunResult: Sendable {
  let scene: GeometryScene
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
}

enum FunctionLabError: Error, LocalizedError {
  case invalidRange(String)
  case nonFiniteIntegral(Double)

  var errorDescription: String? {
    switch self {
    case .invalidRange(let name):
      "\(name) minimum must be smaller than its maximum."
    case .nonFiniteIntegral(let x):
      "The integral crosses a non-finite value near x = \(FunctionRunResult.format(x))."
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
    let yRange = request.yMinimum...request.yMaximum
    var parser = try MathExpressionParser(request.formula)
    let expression = try parser.parse()
    let clock = ContinuousClock()
    let start = clock.now
    let scene = try buildScene(
      expression: expression,
      xRange: xRange,
      yRange: yRange,
      sampleCount: request.sampleCount)
    let elapsed = start.duration(to: clock.now).milliseconds
    let encodedByteCount = try JSONEncoder().encode(scene).count
    let integralResult = try integralResult(request: request, expression: expression)
    let limitResult = limitResult(
      mode: request.mode,
      expression: expression,
      target: request.limitTarget,
      domainWidth: xRange.upperBound - xRange.lowerBound)

    return FunctionRunResult(
      scene: scene,
      buildMilliseconds: elapsed,
      encodedByteCount: encodedByteCount,
      integral: integralResult?.value,
      integralFill: integralResult?.points ?? [],
      limitSamples: limitResult.samples,
      limitEstimate: limitResult.estimate)
  }

  private static func buildScene(
    expression: MathExpression,
    xRange: ClosedRange<Double>,
    yRange: ClosedRange<Double>,
    sampleCount: Int
  ) throws -> GeometryScene {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    var previous: (id: GeometryID, point: Point2D)?
    let discontinuityThreshold = (yRange.upperBound - yRange.lowerBound) * 4
    let step = (xRange.upperBound - xRange.lowerBound) / Double(sampleCount - 1)

    for index in 0..<sampleCount {
      let x = xRange.lowerBound + Double(index) * step
      let y = expression.evaluate(x: x)
      guard y.isFinite else {
        previous = nil
        continue
      }
      let point = Point2D(x: x, y: y)
      let id = try scene.addPoint(.free(point))
      if let previous, abs(previous.point.y - point.y) <= discontinuityThreshold {
        _ = try scene.addSegment(start: previous.id, end: id)
      }
      previous = (id, point)
    }
    return scene
  }

  private static func integralResult(
    request: FunctionRunRequest,
    expression: MathExpression
  ) throws -> (value: Double, points: [Point2D])? {
    guard request.mode == .integral else { return nil }
    let step =
      (request.integralUpper - request.integralLower)
      / Double(request.sampleCount - 1)
    var points: [Point2D] = []
    var total = 0.0
    var previousValue: Double?

    for index in 0..<request.sampleCount {
      let x = request.integralLower + Double(index) * step
      let value = expression.evaluate(x: x)
      guard value.isFinite else {
        throw FunctionLabError.nonFiniteIntegral(x)
      }
      points.append(Point2D(x: x, y: value))
      if let previousValue {
        total += (previousValue + value) * 0.5 * step
      }
      previousValue = value
    }
    return (total, points)
  }

  private static func limitResult(
    mode: FunctionRunMode,
    expression: MathExpression,
    target: Double,
    domainWidth: Double
  ) -> (samples: [FunctionLimitSample], estimate: String?) {
    guard mode == .limit else { return ([], nil) }
    let initialDistance = max(domainWidth / 8, 0.01)
    let samples = (1...10).map { step in
      let distance = initialDistance / Foundation.pow(2, Double(step))
      return FunctionLimitSample(
        distance: distance,
        leftValue: expression.evaluate(x: target - distance),
        rightValue: expression.evaluate(x: target + distance))
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
