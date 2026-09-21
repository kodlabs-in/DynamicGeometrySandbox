import DynamicGeometry
import SwiftUI

struct FunctionLabView: View {
  @State private var preset: FunctionPreset = .sine
  @State private var formula = FunctionPreset.sine.formula
  @State private var mode: FunctionRunMode = .graph
  @State private var xMinimum = -10.0
  @State private var xMaximum = 10.0
  @State private var yMinimum = -5.0
  @State private var yMaximum = 5.0
  @State private var sampleCount = 160.0
  @State private var integralLower = 0.0
  @State private var integralUpper = Double.pi
  @State private var riemannRule: FunctionRiemannRule = .midpoint
  @State private var limitTarget = 0.0
  @State private var result: FunctionRunResult?
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          formulaControls
          rangeControls
          runControls
          output
        }
        .padding()
      }
      .navigationTitle("Function Lab")
    }
    .task {
      if result == nil {
        run()
      }
    }
    .alert(
      "Function error",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }),
      actions: { Button("OK") { errorMessage = nil } },
      message: { Text(errorMessage ?? "Check the formula and ranges.") })
  }

  private var formulaControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Picker("Preset", selection: $preset) {
          ForEach(FunctionPreset.allCases) { preset in
            Text(preset.title).tag(preset)
          }
        }
        .onChange(of: preset) { _, newValue in
          formula = newValue.formula
        }

        Picker("Experiment", selection: $mode) {
          ForEach(FunctionRunMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .pickerStyle(.segmented)
      }

      TextField("Formula", text: $formula)
        .font(.system(.body, design: .monospaced))
        .textFieldStyle(.roundedBorder)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()

      Text("Use x, pi, e, + − * / ^, parentheses, sin, cos, tan, abs, sqrt, log, and exp.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var rangeControls: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Viewport")
        .font(.headline)
      HStack {
        NumberField(title: "x min", value: $xMinimum)
        NumberField(title: "x max", value: $xMaximum)
        NumberField(title: "y min", value: $yMinimum)
        NumberField(title: "y max", value: $yMaximum)
      }

      HStack {
        Text("\(mode == .integral ? "Rectangles" : "Samples"): \(Int(sampleCount))")
          .font(.caption)
          .frame(width: 130, alignment: .leading)
        Slider(value: $sampleCount, in: 16...512, step: 16)
      }

      switch mode {
      case .graph:
        EmptyView()
      case .integral:
        HStack {
          NumberField(title: "Integral from", value: $integralLower)
          NumberField(title: "Integral to", value: $integralUpper)
        }
        Picker("Rectangle sample", selection: $riemannRule) {
          ForEach(FunctionRiemannRule.allCases) { rule in
            Text(rule.title).tag(rule)
          }
        }
        .pickerStyle(.segmented)
      case .limit:
        NumberField(title: "x approaches", value: $limitTarget)
          .frame(maxWidth: 220)
      }
    }
  }

  private var runControls: some View {
    HStack {
      Button("Build Geometry", systemImage: "play.fill", action: run)
        .buttonStyle(.borderedProminent)
      Text("The graph and calculus results are evaluated by DynamicGeometry.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private var output: some View {
    if let result {
      HStack(spacing: 24) {
        LabMetric(title: "Entities", value: result.scene.orderedIDs.count.formatted())
        LabMetric(title: "Build", value: String(format: "%.2f ms", result.buildMilliseconds))
        LabMetric(title: "Encoded", value: result.encodedSize)
        if let signedSum = result.riemannResult?.signedSum {
          LabMetric(title: "Signed sum", value: FunctionRunResult.format(signedSum))
        }
        if let limit = result.limitEstimate {
          LabMetric(title: "Limit", value: limit)
        }
      }

      GeometrySceneCanvas(
        scene: result.scene,
        viewport: safeViewport,
        showsPoints: false,
        riemannRectangles: result.riemannResult?.rectangles ?? []
      )
      .frame(height: 460)

      if !result.limitSamples.isEmpty {
        limitTable(result.limitSamples)
      }
    } else {
      ContentUnavailableView(
        "No experiment yet",
        systemImage: "function",
        description: Text("Enter a formula and build its geometry.")
      )
      .frame(height: 420)
    }
  }

  private var safeViewport: PlotViewport {
    PlotViewport(
      xRange: safeRange(xMinimum, xMaximum),
      yRange: safeRange(yMinimum, yMaximum))
  }

  private func limitTable(_ samples: [FunctionLimitSample]) -> some View {
    Grid(alignment: .leading, horizontalSpacing: 22, verticalSpacing: 6) {
      GridRow {
        Text("Distance").bold()
        Text("From left").bold()
        Text("From right").bold()
      }
      ForEach(samples) { sample in
        GridRow {
          Text(FunctionRunResult.format(sample.distance))
          Text(FunctionRunResult.format(sample.leftValue))
          Text(FunctionRunResult.format(sample.rightValue))
        }
        .monospacedDigit()
      }
    }
    .font(.caption)
  }

  private func run() {
    do {
      result = try FunctionLabRunner.run(
        FunctionRunRequest(
          formula: formula,
          mode: mode,
          xMinimum: xMinimum,
          xMaximum: xMaximum,
          yMinimum: yMinimum,
          yMaximum: yMaximum,
          sampleCount: Int(sampleCount),
          integralLower: integralLower,
          integralUpper: integralUpper,
          limitTarget: limitTarget,
          riemannRule: riemannRule.packageRule))
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func safeRange(_ first: Double, _ second: Double) -> ClosedRange<Double> {
    if first == second { return (first - 1)...(second + 1) }
    return min(first, second)...max(first, second)
  }
}

private enum FunctionRiemannRule: String, CaseIterable, Identifiable {
  case left
  case right
  case midpoint

  var id: Self { self }
  var title: String { rawValue.capitalized }

  var packageRule: RiemannSamplingRule {
    switch self {
    case .left: .left
    case .right: .right
    case .midpoint: .midpoint
    }
  }
}

private struct NumberField: View {
  let title: String
  @Binding var value: Double

  var body: some View {
    TextField(title, value: $value, format: .number)
      .textFieldStyle(.roundedBorder)
      .keyboardType(.numbersAndPunctuation)
  }
}

private enum FunctionPreset: String, CaseIterable, Identifiable {
  case sine
  case cosine
  case quadratic
  case cubic
  case reciprocal
  case sinc
  case gaussian
  case tangent
  case custom

  var id: Self { self }

  var title: String {
    switch self {
    case .sine: "Sine"
    case .cosine: "Cosine"
    case .quadratic: "Quadratic"
    case .cubic: "Cubic"
    case .reciprocal: "Reciprocal"
    case .sinc: "Sinc limit"
    case .gaussian: "Gaussian"
    case .tangent: "Tangent"
    case .custom: "Custom"
    }
  }

  var formula: String {
    switch self {
    case .sine: "sin(x)"
    case .cosine: "cos(x)"
    case .quadratic: "x^2"
    case .cubic: "x^3 - 3*x"
    case .reciprocal: "1/x"
    case .sinc: "sin(x)/x"
    case .gaussian: "exp(-x^2)"
    case .tangent: "tan(x)"
    case .custom: ""
    }
  }
}
