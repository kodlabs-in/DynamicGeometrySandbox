import DynamicGeometry
import SwiftUI

struct UnitCircleLabView: View {
  @State private var construction: UnitCircleConstruction?
  @State private var errorMessage: String?

  init() {
    do {
      _construction = State(initialValue: try UnitCircleConstruction())
      _errorMessage = State(initialValue: nil)
    } catch {
      _construction = State(initialValue: nil)
      _errorMessage = State(initialValue: error.localizedDescription)
    }
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Text("Drag the orange point or choose an exact angle.")
          .foregroundStyle(.secondary)
        angleButtons

        if let construction, let snapshot = construction.snapshot {
          valueSummary(snapshot)
          UnitCircleCanvas(
            scene: construction.scene,
            movingPointID: construction.movingPointID,
            onDrag: movePoint)
        } else {
          ContentUnavailableView(
            "Construction unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage ?? "The geometry could not be resolved."))
        }
      }
      .padding()
      .navigationTitle("Unit Circle")
    }
    .alert(
      "Geometry error",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }),
      actions: { Button("OK") { errorMessage = nil } },
      message: { Text(errorMessage ?? "Please try again.") })
  }

  private var angleButtons: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack {
        ForEach([0, 30, 45, 60, 90, 135, 180, 270, 360], id: \.self) { degrees in
          Button("\(degrees)°") {
            setAngle(degrees)
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private func valueSummary(_ snapshot: UnitCircleSnapshot) -> some View {
    HStack(spacing: 24) {
      LabMetric(title: "Angle", value: String(format: "%.1f°", snapshot.angleDegrees))
      LabMetric(title: "cos θ", value: String(format: "%.3f", snapshot.cosine))
      LabMetric(title: "sin θ", value: String(format: "%.3f", snapshot.sine))
    }
  }

  private func setAngle(_ degrees: Int) {
    guard var construction else { return }
    do {
      try construction.setAngle(Double(degrees) * .pi / 180)
      self.construction = construction
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func movePoint(to point: Point2D) {
    guard var construction else { return }
    do {
      try construction.movePoint(to: point)
      self.construction = construction
    } catch GeometryError.undefinedDirection {
      return
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct UnitCircleCanvas: View {
  let scene: GeometryScene
  let movingPointID: GeometryID
  let onDrag: (Point2D) -> Void

  private let viewport = PlotViewport(xRange: -1.3...1.3, yRange: -1.3...1.3)

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        GeometrySceneCanvas(scene: scene, viewport: viewport, showsPoints: true)

        if let point = try? scene.point(movingPointID) {
          Circle()
            .fill(.orange)
            .frame(width: 24, height: 24)
            .position(viewport.viewPoint(point, size: proxy.size))
            .contentShape(Circle().inset(by: -14))
            .gesture(
              DragGesture(coordinateSpace: .named("unit-circle"))
                .onChanged { value in
                  onDrag(viewport.geometryPoint(value.location, size: proxy.size))
                }
            )
            .accessibilityLabel("Point on circle")
            .accessibilityHint("Drag to change the angle")
        }
      }
      .coordinateSpace(name: "unit-circle")
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 620, maxHeight: 620)
    .frame(maxWidth: .infinity)
  }
}

private struct UnitCircleConstruction {
  private(set) var scene: GeometryScene
  let circleID: GeometryID
  let movingPointID: GeometryID
  let horizontalProjectionID: GeometryID
  let verticalProjectionID: GeometryID

  init() throws {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    let centerID = try scene.addPoint(.free(Point2D(x: 0, y: 0)))
    let circleID = try scene.addCircle(center: centerID, radius: 1)
    let movingPointID = try scene.addPoint(
      .onCircle(circle: circleID, angleRadians: .pi / 4))
    let horizontalProjectionID = try scene.addPoint(
      .horizontalProjection(of: movingPointID, ontoY: 0))
    let verticalProjectionID = try scene.addPoint(
      .verticalProjection(of: movingPointID, ontoX: 0))
    _ = try scene.addSegment(start: centerID, end: movingPointID)
    _ = try scene.addSegment(start: movingPointID, end: horizontalProjectionID)
    _ = try scene.addSegment(start: movingPointID, end: verticalProjectionID)

    self.scene = scene
    self.circleID = circleID
    self.movingPointID = movingPointID
    self.horizontalProjectionID = horizontalProjectionID
    self.verticalProjectionID = verticalProjectionID
  }

  var snapshot: UnitCircleSnapshot? {
    do {
      guard case .point(.onCircle(_, let angle)) = scene.entity(movingPointID) else {
        return nil
      }
      return UnitCircleSnapshot(
        center: try scene.circle(circleID).center,
        movingPoint: try scene.point(movingPointID),
        horizontalProjection: try scene.point(horizontalProjectionID),
        verticalProjection: try scene.point(verticalProjectionID),
        angleRadians: angle)
    } catch {
      return nil
    }
  }

  mutating func setAngle(_ angleRadians: Double) throws {
    try scene.replace(
      movingPointID,
      with: .point(.onCircle(circle: circleID, angleRadians: angleRadians)))
  }

  mutating func movePoint(to point: Point2D) throws {
    try scene.movePoint(movingPointID, to: point)
  }
}

private struct UnitCircleSnapshot {
  let center: Point2D
  let movingPoint: Point2D
  let horizontalProjection: Point2D
  let verticalProjection: Point2D
  let angleRadians: Double

  var angleDegrees: Double {
    angleRadians * 180 / .pi
  }

  var cosine: Double {
    cos(angleRadians)
  }

  var sine: Double {
    sin(angleRadians)
  }
}
