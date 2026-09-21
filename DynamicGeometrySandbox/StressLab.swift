import DynamicGeometry
import Foundation
import SwiftUI

struct StressLabView: View {
  @State private var pattern: StressPattern = .waveGraph
  @State private var count = 1_000.0
  @State private var result: StressRunResult?
  @State private var isRunning = false
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Text("Generate large scenes, resolve every entity, and encode a full round trip.")
          .foregroundStyle(.secondary)

        Picker("Pattern", selection: $pattern) {
          ForEach(StressPattern.allCases) { pattern in
            Text(pattern.title).tag(pattern)
          }
        }
        .pickerStyle(.segmented)

        Text(pattern.explanation)
          .font(.footnote)
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          Text("Requested: \(Int(count))")
            .frame(width: 130, alignment: .leading)
          Slider(
            value: $count,
            in: pattern == .incrementalFanOut ? 100...10_000 : 10...1_000,
            step: pattern == .incrementalFanOut ? 100 : 10)
          Button("Run", systemImage: "gauge.open.with.lines.needle.33percent", action: run)
            .buttonStyle(.borderedProminent)
            .disabled(isRunning)
        }

        if pattern == .incrementalFanOut {
          HStack {
            Text("Fan-out presets")
              .font(.caption)
              .foregroundStyle(.secondary)
            ForEach([100, 1_000, 10_000], id: \.self) { preset in
              Button(preset.formatted()) {
                count = Double(preset)
              }
              .buttonStyle(.bordered)
            }
          }
        }

        if isRunning {
          ProgressView("Building and validating scene…")
        }

        if let result {
          metrics(result)
          if let incrementalMetrics = result.incrementalMetrics {
            incrementalMetricsView(incrementalMetrics)
          } else {
            GeometrySceneCanvas(
              scene: result.scene,
              viewport: result.viewport,
              showsPoints: false
            )
            .frame(height: 420)
          }
          Text(result.summary)
            .font(.footnote.monospaced())
            .textSelection(.enabled)
        } else {
          ContentUnavailableView(
            "No stress run yet",
            systemImage: "gauge.with.dots.needle.67percent",
            description: Text("Choose a pattern and entity count."))
        }
        Spacer(minLength: 0)
      }
      .padding()
      .navigationTitle("Stress Lab")
    }
    .onChange(of: pattern) { _, newPattern in
      let range: ClosedRange<Double> = newPattern == .incrementalFanOut ? 100...10_000 : 10...1_000
      count = min(max(count, range.lowerBound), range.upperBound)
    }
    .alert(
      "Stress run failed",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }),
      actions: { Button("OK") { errorMessage = nil } },
      message: { Text(errorMessage ?? "Please try a smaller scene.") })
  }

  private func metrics(_ result: StressRunResult) -> some View {
    HStack(spacing: 22) {
      LabMetric(title: "Entities", value: result.scene.orderedIDs.count.formatted())
      LabMetric(title: "Build", value: result.buildMilliseconds.formattedTime)
      LabMetric(title: "Resolve", value: result.resolveMilliseconds.formattedTime)
      LabMetric(title: "Codable", value: result.codableMilliseconds.formattedTime)
    }
  }

  private func incrementalMetricsView(_ metrics: IncrementalStressMetrics) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 22) {
        LabMetric(title: "P95 update", value: metrics.p95UpdateMilliseconds.formattedTime)
        LabMetric(title: "Affected/update", value: metrics.typicalAffectedCount.formatted())
        LabMetric(title: "60 Hz budget", value: metrics.frameBudgetMilliseconds.formattedTime)
      }
      Text(
        "Measured p95 is "
          + (metrics.p95UpdateMilliseconds <= metrics.frameBudgetMilliseconds ? "within" : "above")
          + " the 16.7 ms 60 Hz frame budget (informational, not pass/fail)."
      )
      .font(.footnote.monospaced())
      .foregroundStyle(.secondary)
    }
  }

  private func run() {
    let requestedPattern = pattern
    let requestedCount = Int(count)
    isRunning = true
    Task {
      do {
        let runResult = try await Task.detached(priority: .userInitiated) {
          try StressRunner.run(pattern: requestedPattern, requestedCount: requestedCount)
        }.value
        result = runResult
      } catch {
        errorMessage = error.localizedDescription
      }
      isRunning = false
    }
  }
}

nonisolated enum StressPattern: String, CaseIterable, Identifiable, Sendable {
  case waveGraph
  case overlapping
  case dependencyChain
  case incrementalFanOut
  case invalidInput

  var id: Self { self }

  var title: String {
    switch self {
    case .waveGraph: "Graph"
    case .overlapping: "Overlap"
    case .dependencyChain: "Chain"
    case .incrementalFanOut: "Incremental"
    case .invalidInput: "Invalid"
    }
  }

  var explanation: String {
    switch self {
    case .waveGraph: "Creates sampled sine-wave points and connected segments."
    case .overlapping: "Creates many distinct circles with exactly the same centre and radius."
    case .dependencyChain: "Creates a deep chain of projections to exercise resolution."
    case .incrementalFanOut: "Moves one root and records every incremental fan-out update."
    case .invalidInput: "Submits NaN points and verifies every failed insertion rolls back."
    }
  }
}

nonisolated struct IncrementalStressMetrics: Sendable {
  let dependentEntityCount: Int
  let updateMilliseconds: [Double]
  let affectedCounts: [Int]
  let frameBudgetMilliseconds = 16.7

  var p95UpdateMilliseconds: Double {
    guard !updateMilliseconds.isEmpty else { return 0 }
    let ordered = updateMilliseconds.sorted()
    let index = max(0, Int(ceil(Double(ordered.count) * 0.95)) - 1)
    return ordered[index]
  }

  var typicalAffectedCount: Int { affectedCounts.first ?? 0 }
}

nonisolated struct StressRunResult: Sendable {
  let scene: GeometryScene
  let viewport: PlotViewport
  let buildMilliseconds: Double
  let resolveMilliseconds: Double
  let codableMilliseconds: Double
  let encodedByteCount: Int
  let incrementalMetrics: IncrementalStressMetrics?
  let summary: String
}

nonisolated enum StressRunner {
  static func run(pattern: StressPattern, requestedCount: Int) throws -> StressRunResult {
    let count = pattern == .dependencyChain ? min(requestedCount, 400) : requestedCount
    let clock = ContinuousClock()

    let buildStart = clock.now
    var scene = try buildScene(pattern: pattern, count: count)
    let buildMilliseconds = buildStart.duration(to: clock.now).milliseconds

    let incrementalMetrics = try measureIncrementalUpdates(
      in: &scene,
      pattern: pattern,
      dependentCount: count,
      clock: clock)

    let resolveStart = clock.now
    try resolveEveryEntity(in: scene)
    let resolveMilliseconds = resolveStart.duration(to: clock.now).milliseconds

    let codableStart = clock.now
    let data = try JSONEncoder().encode(scene)
    let decoded = try JSONDecoder().decode(GeometryScene.self, from: data)
    try decoded.validate()
    let codableMilliseconds = codableStart.duration(to: clock.now).milliseconds

    return StressRunResult(
      scene: scene,
      viewport: viewport(for: pattern, count: count),
      buildMilliseconds: buildMilliseconds,
      resolveMilliseconds: resolveMilliseconds,
      codableMilliseconds: codableMilliseconds,
      encodedByteCount: data.count,
      incrementalMetrics: incrementalMetrics,
      summary: summary(
        pattern: pattern,
        requestedCount: requestedCount,
        actualCount: count,
        scene: scene,
        incrementalMetrics: incrementalMetrics))
  }

  private static func buildScene(pattern: StressPattern, count: Int) throws -> GeometryScene {
    switch pattern {
    case .waveGraph:
      try buildWaveGraph(count: count)
    case .overlapping:
      try buildOverlappingCircles(count: count)
    case .dependencyChain:
      try buildDependencyChain(count: count)
    case .incrementalFanOut:
      try buildIncrementalFanOut(count: count)
    case .invalidInput:
      try buildInvalidInputRun(count: count)
    }
  }

  private static func buildWaveGraph(count: Int) throws -> GeometryScene {
    var scene = GeometryScene()
    var previousID: GeometryID?
    for index in 0..<count {
      let x = Double(index) / Double(max(1, count - 1)) * 20 - 10
      let id = try scene.addPoint(.free(Point2D(x: x, y: sin(x))))
      if let previousID {
        _ = try scene.addSegment(start: previousID, end: id)
      }
      previousID = id
    }
    return scene
  }

  private static func buildOverlappingCircles(count: Int) throws -> GeometryScene {
    var scene = GeometryScene()
    let centre = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    for _ in 0..<count {
      _ = try scene.addCircle(center: centre, radius: 5)
    }
    return scene
  }

  private static func buildDependencyChain(count: Int) throws -> GeometryScene {
    var scene = GeometryScene()
    var previous = try scene.addPoint(.free(Point2D(x: 1, y: 1)))
    for index in 1..<count {
      if index.isMultiple(of: 2) {
        previous = try scene.addPoint(
          .horizontalProjection(of: previous, ontoY: Double(index) / 10))
      } else {
        previous = try scene.addPoint(
          .verticalProjection(of: previous, ontoX: Double(index) / 10))
      }
    }
    return scene
  }

  private static func buildIncrementalFanOut(count: Int) throws -> GeometryScene {
    var scene = GeometryScene()
    let root = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    for index in 0..<count {
      _ = try scene.addPoint(
        .horizontalProjection(of: root, ontoY: Double(index) / 100))
    }
    return scene
  }

  private static func measureIncrementalUpdates(
    in scene: inout GeometryScene,
    pattern: StressPattern,
    dependentCount: Int,
    clock: ContinuousClock
  ) throws -> IncrementalStressMetrics? {
    guard pattern == .incrementalFanOut,
      let root = scene.orderedIDs.first
    else {
      return nil
    }
    var durations: [Double] = []
    var affectedCounts: [Int] = []
    for step in 1...12 {
      let target = Point2D(x: Double(step), y: Double((step % 3) - 1))
      let start = clock.now
      let change = try scene.movePointReportingChanges(root, to: target)
      durations.append(start.duration(to: clock.now).milliseconds)
      affectedCounts.append(change.affectedEntityIDs.count)
    }
    return IncrementalStressMetrics(
      dependentEntityCount: dependentCount,
      updateMilliseconds: durations,
      affectedCounts: affectedCounts)
  }

  private static func buildInvalidInputRun(count: Int) throws -> GeometryScene {
    var scene = GeometryScene()
    for _ in 0..<count {
      do {
        _ = try scene.addPoint(.free(Point2D(x: .nan, y: .infinity)))
      } catch GeometryError.nonFiniteValue {
        continue
      }
    }
    try scene.validate()
    return scene
  }

  private static func resolveEveryEntity(in scene: GeometryScene) throws {
    for id in scene.orderedIDs {
      guard let entity = scene.entity(id) else { throw GeometryError.missingEntity(id) }
      switch entity {
      case .point: _ = try scene.point(id)
      case .circle: _ = try scene.circle(id)
      case .ellipse: _ = try scene.ellipse(id)
      case .segment: _ = try scene.segment(id)
      case .line: _ = try scene.line(id)
      case .ray: _ = try scene.ray(id)
      }
    }
  }

  private static func viewport(for pattern: StressPattern, count: Int) -> PlotViewport {
    switch pattern {
    case .waveGraph:
      return PlotViewport(xRange: -10...10, yRange: -2...2)
    case .overlapping, .invalidInput, .incrementalFanOut:
      return PlotViewport(xRange: -6...6, yRange: -6...6)
    case .dependencyChain:
      let extent = max(2, Double(count) / 10)
      return PlotViewport(xRange: -1...extent, yRange: -1...extent)
    }
  }

  private static func summary(
    pattern: StressPattern,
    requestedCount: Int,
    actualCount: Int,
    scene: GeometryScene,
    incrementalMetrics: IncrementalStressMetrics?
  ) -> String {
    if pattern == .invalidInput {
      return "Rejected \(requestedCount) invalid insertions; scene remained empty and valid."
    }
    if requestedCount != actualCount {
      return "Capped recursive chain at \(actualCount) to keep the prototype responsive."
    }
    if let incrementalMetrics {
      return "Updated \(incrementalMetrics.dependentEntityCount) dependents 12 times; p95 "
        + "\(incrementalMetrics.p95UpdateMilliseconds.formattedTime), "
        + "\(incrementalMetrics.typicalAffectedCount) affected entities per update."
    }
    return "Built, resolved, encoded, decoded, and revalidated \(scene.orderedIDs.count) entities."
  }
}

private extension Double {
  var formattedTime: String {
    if self < 1 { return String(format: "%.3f ms", self) }
    return String(format: "%.2f ms", self)
  }
}
