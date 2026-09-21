import DynamicGeometry
import SwiftUI

struct ContentView: View {
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

        if let snapshot = construction?.snapshot {
          valueSummary(snapshot)
          UnitCircleCanvas(snapshot: snapshot, onDrag: movePoint)
        } else {
          ContentUnavailableView(
            "Construction unavailable",
            systemImage: "exclamationmark.triangle",
            description: Text(errorMessage ?? "The geometry could not be resolved."))
        }
      }
      .padding()
      .navigationTitle("Dynamic Geometry")
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
        ForEach([0, 45, 90, 135, 180, 270, 360], id: \.self) { degrees in
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
      value(label: "Angle", value: String(format: "%.1f°", snapshot.angleDegrees))
      value(label: "cos θ", value: String(format: "%.3f", snapshot.cosine))
      value(label: "sin θ", value: String(format: "%.3f", snapshot.sine))
    }
    .monospacedDigit()
  }

  private func value(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
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
  let snapshot: UnitCircleSnapshot
  let onDrag: (Point2D) -> Void

  var body: some View {
    GeometryReader { proxy in
      let transform = DiagramTransform(size: proxy.size)
      let center = transform.viewPoint(snapshot.center)
      let movingPoint = transform.viewPoint(snapshot.movingPoint)
      let horizontal = transform.viewPoint(snapshot.horizontalProjection)
      let vertical = transform.viewPoint(snapshot.verticalProjection)

      ZStack {
        Canvas { context, _ in
          drawAxes(context: &context, transform: transform)
          drawCircle(context: &context, transform: transform)
          drawSegment(context: &context, from: center, to: movingPoint, color: .orange)
          drawProjection(context: &context, from: movingPoint, to: horizontal)
          drawProjection(context: &context, from: movingPoint, to: vertical)
          drawPoint(context: &context, at: horizontal, color: .green, diameter: 12)
          drawPoint(context: &context, at: vertical, color: .green, diameter: 12)
        }

        Circle()
          .fill(.orange)
          .frame(width: 24, height: 24)
          .position(movingPoint)
          .contentShape(Circle().inset(by: -14))
          .gesture(
            DragGesture(coordinateSpace: .named("unit-circle"))
              .onChanged { value in
                onDrag(transform.geometryPoint(value.location))
              }
          )
          .accessibilityLabel("Point on circle")
          .accessibilityHint("Drag to change the angle")
      }
      .coordinateSpace(name: "unit-circle")
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 620, maxHeight: 620)
    .frame(maxWidth: .infinity)
  }

  private func drawAxes(context: inout GraphicsContext, transform: DiagramTransform) {
    var horizontal = Path()
    horizontal.move(to: transform.viewPoint(Point2D(x: -1.25, y: 0)))
    horizontal.addLine(to: transform.viewPoint(Point2D(x: 1.25, y: 0)))
    var vertical = Path()
    vertical.move(to: transform.viewPoint(Point2D(x: 0, y: -1.25)))
    vertical.addLine(to: transform.viewPoint(Point2D(x: 0, y: 1.25)))
    context.stroke(horizontal, with: .color(.secondary), lineWidth: 1.5)
    context.stroke(vertical, with: .color(.secondary), lineWidth: 1.5)
  }

  private func drawCircle(context: inout GraphicsContext, transform: DiagramTransform) {
    let center = transform.viewPoint(snapshot.center)
    let radius = transform.radius
    let bounds = CGRect(
      x: center.x - radius,
      y: center.y - radius,
      width: radius * 2,
      height: radius * 2)
    context.stroke(Path(ellipseIn: bounds), with: .color(.blue), lineWidth: 4)
  }

  private func drawSegment(
    context: inout GraphicsContext,
    from start: CGPoint,
    to end: CGPoint,
    color: Color
  ) {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    context.stroke(path, with: .color(color), lineWidth: 3)
  }

  private func drawProjection(
    context: inout GraphicsContext,
    from start: CGPoint,
    to end: CGPoint
  ) {
    var path = Path()
    path.move(to: start)
    path.addLine(to: end)
    context.stroke(
      path,
      with: .color(.green),
      style: StrokeStyle(lineWidth: 2, dash: [7, 6]))
  }

  private func drawPoint(
    context: inout GraphicsContext,
    at point: CGPoint,
    color: Color,
    diameter: CGFloat
  ) {
    let bounds = CGRect(
      x: point.x - diameter / 2,
      y: point.y - diameter / 2,
      width: diameter,
      height: diameter)
    context.fill(Path(ellipseIn: bounds), with: .color(color))
  }
}

private struct DiagramTransform {
  let size: CGSize

  var radius: CGFloat {
    min(size.width, size.height) * 0.36
  }

  private var center: CGPoint {
    CGPoint(x: size.width / 2, y: size.height / 2)
  }

  func viewPoint(_ point: Point2D) -> CGPoint {
    CGPoint(
      x: center.x + point.x * radius,
      y: center.y + point.y * radius)
  }

  func geometryPoint(_ point: CGPoint) -> Point2D {
    Point2D(
      x: (point.x - center.x) / radius,
      y: (point.y - center.y) / radius)
  }
}

private struct UnitCircleConstruction {
  private(set) var scene: GeometryScene
  let circleID: GeometryID
  let movingPointID: GeometryID
  let horizontalProjectionID: GeometryID
  let verticalProjectionID: GeometryID

  init() throws {
    var scene = GeometryScene(coordinateSystem: .screenYDown)
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
