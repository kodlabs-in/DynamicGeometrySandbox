import DynamicGeometry
import SwiftUI

struct GeometryPreviewSnapshot {
  let scene: GeometryScene
  let viewport: PlotViewport
  let detail: String
  var fillPoints: [Point2D] = []
}

enum GeometryPreviewScenario: String, CaseIterable, Identifiable, Sendable {
  case circleWithAxes
  case dependentUnitCircle
  case overlappingShapes
  case transformedPolygon
  case sineIntegral

  var id: Self { self }

  var title: String {
    switch self {
    case .circleWithAxes: "Circle + Axes"
    case .dependentUnitCircle: "Dependencies"
    case .overlappingShapes: "Overlaps"
    case .transformedPolygon: "Transforms"
    case .sineIntegral: "Integral"
    }
  }

  func makeSnapshot() throws -> GeometryPreviewSnapshot {
    switch self {
    case .circleWithAxes:
      try circleWithAxesSnapshot()
    case .dependentUnitCircle:
      try dependentUnitCircleSnapshot()
    case .overlappingShapes:
      try overlappingShapesSnapshot()
    case .transformedPolygon:
      try transformedPolygonSnapshot()
    case .sineIntegral:
      try sineIntegralSnapshot()
    }
  }

  private func circleWithAxesSnapshot() throws -> GeometryPreviewSnapshot {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    let center = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    let left = try scene.addPoint(.free(Point2D(x: -5, y: 0)))
    let right = try scene.addPoint(.free(Point2D(x: 5, y: 0)))
    let bottom = try scene.addPoint(.free(Point2D(x: 0, y: -5)))
    let top = try scene.addPoint(.free(Point2D(x: 0, y: 5)))
    _ = try scene.addCircle(center: center, radius: 3.5)
    _ = try scene.addLine(first: left, second: right)
    _ = try scene.addLine(first: bottom, second: top)
    return GeometryPreviewSnapshot(
      scene: scene,
      viewport: PlotViewport(xRange: -6...6, yRange: -6...6),
      detail: "A real circle crossed by independent horizontal and vertical lines.")
  }

  private func dependentUnitCircleSnapshot() throws -> GeometryPreviewSnapshot {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    let center = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    let circle = try scene.addCircle(center: center, radius: 1)
    let movingPoint = try scene.addPoint(
      .onCircle(circle: circle, angleRadians: .pi / 3))
    let horizontalProjection = try scene.addPoint(
      .horizontalProjection(of: movingPoint, ontoY: 0))
    let verticalProjection = try scene.addPoint(
      .verticalProjection(of: movingPoint, ontoX: 0))
    _ = try scene.addSegment(start: center, end: movingPoint)
    _ = try scene.addSegment(start: movingPoint, end: horizontalProjection)
    _ = try scene.addSegment(start: movingPoint, end: verticalProjection)
    return GeometryPreviewSnapshot(
      scene: scene,
      viewport: PlotViewport(xRange: -1.35...1.35, yRange: -1.35...1.35),
      detail: "A constrained point drives two projections and three dependent segments.")
  }

  private func overlappingShapesSnapshot() throws -> GeometryPreviewSnapshot {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    let center = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    let left = try scene.addPoint(.free(Point2D(x: -4, y: 0)))
    let right = try scene.addPoint(.free(Point2D(x: 4, y: 0)))
    let top = try scene.addPoint(.free(Point2D(x: 0, y: 4)))
    _ = try scene.addCircle(center: center, radius: 3)
    _ = try scene.addCircle(center: center, radius: 2)
    _ = try scene.addEllipse(center: center, radiusX: 3, radiusY: 1.5)
    _ = try scene.addSegment(start: left, end: right)
    _ = try scene.addRay(origin: center, through: top)
    return GeometryPreviewSnapshot(
      scene: scene,
      viewport: PlotViewport(xRange: -5...5, yRange: -5...5),
      detail: "Distinct circles, an ellipse, a segment, and a ray share coordinates safely.")
  }

  private func transformedPolygonSnapshot() throws -> GeometryPreviewSnapshot {
    let sourcePoints = [
      Point2D(x: -2, y: -2),
      Point2D(x: 2, y: -2),
      Point2D(x: 2, y: 2),
      Point2D(x: -2, y: 2),
    ]
    let transform = try CoordinateTransform2D.rotation(radians: .pi / 6)
      .followed(by: .translation(x: 1.5, y: 0.75))
    let transformedPoints = try sourcePoints.map(transform.transform)
    var scene = GeometryScene(coordinateSystem: .cartesian)
    try addClosedPolyline(sourcePoints, to: &scene)
    try addClosedPolyline(transformedPoints, to: &scene)
    return GeometryPreviewSnapshot(
      scene: scene,
      viewport: PlotViewport(xRange: -5...5, yRange: -5...5),
      detail: "The same closed geometry before and after an affine rotation and translation.")
  }

  private func sineIntegralSnapshot() throws -> GeometryPreviewSnapshot {
    let result = try FunctionLabRunner.run(
      FunctionRunRequest(
        formula: "sin(x)",
        mode: .integral,
        xMinimum: -.pi,
        xMaximum: .pi,
        yMinimum: -1.5,
        yMaximum: 1.5,
        sampleCount: 96,
        integralLower: 0,
        integralUpper: .pi,
        limitTarget: 0))
    return GeometryPreviewSnapshot(
      scene: result.scene,
      viewport: PlotViewport(xRange: -.pi...Double.pi, yRange: -1.5...1.5),
      detail: "A sampled sine graph plus the numerical integral from zero to π.",
      fillPoints: result.integralFill)
  }

  private func addClosedPolyline(
    _ points: [Point2D],
    to scene: inout GeometryScene
  ) throws {
    let pointIDs = try points.map { try scene.addPoint(.free($0)) }
    for index in pointIDs.indices {
      _ = try scene.addSegment(
        start: pointIDs[index],
        end: pointIDs[(index + 1) % pointIDs.count])
    }
  }
}

struct GeometryPreviewGalleryView: View {
  @State private var selection = GeometryPreviewScenario.circleWithAxes

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 16) {
        Picker("Scenario", selection: $selection) {
          ForEach(GeometryPreviewScenario.allCases) { scenario in
            Text(scenario.title).tag(scenario)
          }
        }
        .pickerStyle(.segmented)

        switch Result(catching: selection.makeSnapshot) {
        case .success(let snapshot):
          Text(snapshot.detail)
            .foregroundStyle(.secondary)
          GeometrySceneCanvas(
            scene: snapshot.scene,
            viewport: snapshot.viewport,
            fillPoints: snapshot.fillPoints)
          Text("\(snapshot.scene.orderedIDs.count) package entities")
            .font(.caption.monospacedDigit())
        case .failure(let error):
          ContentUnavailableView(
            "Preview failed",
            systemImage: "exclamationmark.triangle",
            description: Text(error.localizedDescription))
        }
      }
      .padding()
      .navigationTitle("Package Scenarios")
    }
  }
}

#if DEBUG
  #Preview("Package Scenario • Circle + Axes") {
    GeometryPreviewGalleryView()
      .frame(width: 1_080, height: 760)
  }

  #Preview("Complete Sandbox") {
    ContentView()
      .frame(width: 1_180, height: 820)
  }

  #Preview("Construction • Draw Shapes") {
    ConstructionLabView()
      .frame(width: 1_080, height: 760)
  }

  #Preview("Unit Circle • Drag Point") {
    UnitCircleLabView()
      .frame(width: 1_080, height: 760)
  }

  #Preview("Functions • Graph, Integral, Limit") {
    FunctionLabView()
      .frame(width: 1_080, height: 760)
  }

  #Preview("Stress • Package Limits") {
    StressLabView()
      .frame(width: 1_080, height: 760)
  }
#endif
