import DynamicGeometry
import SwiftUI

struct AdvancedMathLabView: View {
  @State private var scenario = AdvancedMathScenario.polarRose
  @State private var resolution = 80.0
  @State private var parameter = 5.0
  @State private var result: AdvancedMathRunResult?
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          Text("Explore the package's bounded roadmap engines through reusable presets.")
            .foregroundStyle(.secondary)

          Picker("Engine", selection: $scenario) {
            ForEach(AdvancedMathScenario.allCases) { scenario in
              Text(scenario.title).tag(scenario)
            }
          }
          .pickerStyle(.segmented)

          controls
          output
        }
        .padding()
      }
      .navigationTitle("Advanced Math")
    }
    .task { run() }
    .onChange(of: scenario) { _, newScenario in
      parameter = newScenario.defaultParameter
      run()
    }
    .alert(
      "Advanced experiment failed",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }),
      actions: { Button("OK") { errorMessage = nil } },
      message: { Text(errorMessage ?? "Change the inputs and try again.") })
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Resolution: \(Int(resolution))")
          .frame(width: 130, alignment: .leading)
        Slider(value: $resolution, in: 16...160, step: 8)
      }
      HStack {
        let formattedParameter = parameter.formatted(
          .number.precision(.fractionLength(2)))
        Text("\(scenario.parameterTitle): \(formattedParameter)")
          .frame(width: 190, alignment: .leading)
        Slider(
          value: $parameter,
          in: scenario.parameterRange,
          step: scenario.parameterStep)
      }
      HStack {
        Button("Run Experiment", systemImage: "play.fill", action: run)
          .buttonStyle(.borderedProminent)
        Text(scenario.boundary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var output: some View {
    if let result {
      HStack(spacing: 24) {
        LabMetric(title: "Segments", value: result.lines.count.formatted())
        LabMetric(title: "Points", value: result.points.count.formatted())
        LabMetric(title: "Diagnostics", value: result.diagnosticCount.formatted())
      }
      AdvancedMathCanvas(result: result)
        .frame(height: 480)
      Text(result.summary)
        .font(.headline)
      Text(result.detail)
        .font(.footnote)
        .foregroundStyle(.secondary)
    } else {
      ContentUnavailableView(
        "No advanced experiment yet",
        systemImage: "cube.transparent",
        description: Text("Choose an engine and run its acceptance preset.")
      )
      .frame(height: 420)
    }
  }

  private func run() {
    do {
      result = try AdvancedMathLabRunner.run(
        scenario: scenario,
        resolution: Int(resolution),
        parameter: parameter)
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct AdvancedMathCanvas: View {
  let result: AdvancedMathRunResult

  var body: some View {
    Canvas { context, size in
      drawAxes(context: &context, size: size)
      var path = Path()
      for line in result.lines {
        path.move(to: result.viewport.viewPoint(line.start, size: size))
        path.addLine(to: result.viewport.viewPoint(line.end, size: size))
      }
      context.stroke(path, with: .color(.blue), lineWidth: 1.5)
      for point in result.points {
        let location = result.viewport.viewPoint(point, size: size)
        let bounds = CGRect(x: location.x - 6, y: location.y - 6, width: 12, height: 12)
        context.fill(Path(ellipseIn: bounds), with: .color(.orange))
      }
    }
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary) }
  }

  private func drawAxes(context: inout GraphicsContext, size: CGSize) {
    var axes = Path()
    if result.viewport.xRange.contains(0) {
      axes.move(
        to: result.viewport.viewPoint(
          Point2D(x: 0, y: result.viewport.yRange.lowerBound),
          size: size))
      axes.addLine(
        to: result.viewport.viewPoint(
          Point2D(x: 0, y: result.viewport.yRange.upperBound),
          size: size))
    }
    if result.viewport.yRange.contains(0) {
      axes.move(
        to: result.viewport.viewPoint(
          Point2D(x: result.viewport.xRange.lowerBound, y: 0),
          size: size))
      axes.addLine(
        to: result.viewport.viewPoint(
          Point2D(x: result.viewport.xRange.upperBound, y: 0),
          size: size))
    }
    context.stroke(axes, with: .color(.secondary), lineWidth: 1)
  }
}

private extension AdvancedMathScenario {
  var defaultParameter: Double {
    switch self {
    case .polarRose: 5
    case .implicitContour: 1
    case .surface3D: 0.7
    case .symbolicDerivative: 1
    case .constraintIntersection: 0.8
    }
  }

  var parameterTitle: String {
    switch self {
    case .polarRose: "Petal factor"
    case .implicitContour: "Radius"
    case .surface3D: "Curvature"
    case .symbolicDerivative: "Probe x"
    case .constraintIntersection: "Branch seed"
    }
  }

  var parameterRange: ClosedRange<Double> {
    switch self {
    case .polarRose: 1...9
    case .implicitContour: 0.25...2
    case .surface3D: 0.1...1
    case .symbolicDerivative: -2...2
    case .constraintIntersection: -1...1
    }
  }

  var parameterStep: Double {
    self == .polarRose ? 1 : 0.05
  }

  var boundary: String {
    switch self {
    case .polarRose: "Finite sampling preserves gaps."
    case .implicitContour: "Bounded contour approximation; inspect diagnostics."
    case .surface3D: "A renderer-independent mesh with a fixed 2D projection."
    case .symbolicDerivative: "Exact transformation for supported expression forms."
    case .constraintIntersection: "Local numerical solve; the seed chooses the branch."
    }
  }
}
