import DynamicGeometry
import SwiftUI

nonisolated struct PlotViewport: Equatable, Sendable {
  let xRange: ClosedRange<Double>
  let yRange: ClosedRange<Double>

  init(
    xRange: ClosedRange<Double> = -10...10,
    yRange: ClosedRange<Double> = -10...10
  ) {
    self.xRange = xRange
    self.yRange = yRange
  }

  func viewPoint(_ point: Point2D, size: CGSize) -> CGPoint {
    let horizontal = (point.x - xRange.lowerBound) / width
    let vertical = (point.y - yRange.lowerBound) / height
    return CGPoint(
      x: horizontal * size.width,
      y: (1 - vertical) * size.height)
  }

  func geometryPoint(_ point: CGPoint, size: CGSize) -> Point2D {
    Point2D(
      x: xRange.lowerBound + Double(point.x / size.width) * width,
      y: yRange.upperBound - Double(point.y / size.height) * height)
  }

  private var width: Double {
    xRange.upperBound - xRange.lowerBound
  }

  private var height: Double {
    yRange.upperBound - yRange.lowerBound
  }
}

struct GeometrySceneCanvas: View {
  let scene: GeometryScene
  let viewport: PlotViewport
  var showsPoints = true
  var fillPoints: [Point2D] = []
  var riemannRectangles: [RiemannRectangle2D] = []

  var body: some View {
    Canvas { context, size in
      drawGrid(context: &context, size: size)
      drawIntegralFill(context: &context, size: size)
      drawRiemannRectangles(context: &context, size: size)
      for id in scene.orderedIDs {
        drawEntity(id, context: &context, size: size)
      }
    }
    .background(Color(uiColor: .secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(.quaternary)
    }
  }

  private func drawGrid(context: inout GraphicsContext, size: CGSize) {
    var grid = Path()
    let xStart = Int(floor(viewport.xRange.lowerBound))
    let xEnd = Int(ceil(viewport.xRange.upperBound))
    let yStart = Int(floor(viewport.yRange.lowerBound))
    let yEnd = Int(ceil(viewport.yRange.upperBound))

    for value in xStart...xEnd {
      let start = viewport.viewPoint(
        Point2D(x: Double(value), y: viewport.yRange.lowerBound), size: size)
      let end = viewport.viewPoint(
        Point2D(x: Double(value), y: viewport.yRange.upperBound), size: size)
      grid.move(to: start)
      grid.addLine(to: end)
    }
    for value in yStart...yEnd {
      let start = viewport.viewPoint(
        Point2D(x: viewport.xRange.lowerBound, y: Double(value)), size: size)
      let end = viewport.viewPoint(
        Point2D(x: viewport.xRange.upperBound, y: Double(value)), size: size)
      grid.move(to: start)
      grid.addLine(to: end)
    }
    context.stroke(grid, with: .color(.gray.opacity(0.14)), lineWidth: 1)

    var axes = Path()
    if viewport.xRange.contains(0) {
      axes.move(to: viewport.viewPoint(Point2D(x: 0, y: viewport.yRange.lowerBound), size: size))
      axes.addLine(
        to: viewport.viewPoint(Point2D(x: 0, y: viewport.yRange.upperBound), size: size))
    }
    if viewport.yRange.contains(0) {
      axes.move(to: viewport.viewPoint(Point2D(x: viewport.xRange.lowerBound, y: 0), size: size))
      axes.addLine(
        to: viewport.viewPoint(Point2D(x: viewport.xRange.upperBound, y: 0), size: size))
    }
    context.stroke(axes, with: .color(.secondary), lineWidth: 1.5)
  }

  private func drawIntegralFill(context: inout GraphicsContext, size: CGSize) {
    guard let first = fillPoints.first, let last = fillPoints.last else { return }
    var path = Path()
    path.move(to: viewport.viewPoint(Point2D(x: first.x, y: 0), size: size))
    for point in fillPoints {
      path.addLine(to: viewport.viewPoint(point, size: size))
    }
    path.addLine(to: viewport.viewPoint(Point2D(x: last.x, y: 0), size: size))
    path.closeSubpath()
    context.fill(path, with: .color(.blue.opacity(0.16)))
  }

  private func drawRiemannRectangles(context: inout GraphicsContext, size: CGSize) {
    for rectangle in riemannRectangles {
      let first = viewport.viewPoint(
        Point2D(x: rectangle.interval.lowerBound, y: 0),
        size: size)
      let opposite = viewport.viewPoint(
        Point2D(x: rectangle.interval.upperBound, y: rectangle.height),
        size: size)
      let bounds = CGRect(
        x: min(first.x, opposite.x),
        y: min(first.y, opposite.y),
        width: abs(opposite.x - first.x),
        height: abs(opposite.y - first.y))
      let path = Path(bounds)
      let color: Color = rectangle.height >= 0 ? .blue : .orange
      context.fill(path, with: .color(color.opacity(0.18)))
      context.stroke(path, with: .color(color.opacity(0.65)), lineWidth: 1)
    }
  }

  private func drawEntity(
    _ id: GeometryID,
    context: inout GraphicsContext,
    size: CGSize
  ) {
    guard let entity = scene.entity(id) else { return }
    do {
      switch entity {
      case .point:
        if showsPoints {
          drawPoint(try scene.point(id), context: &context, size: size)
        }
      case .circle:
        drawCircle(try scene.circle(id), context: &context, size: size)
      case .ellipse:
        drawEllipse(try scene.ellipse(id), context: &context, size: size)
      case .segment:
        let segment = try scene.segment(id)
        drawLine(from: segment.start, to: segment.end, context: &context, size: size)
      case .line:
        drawInfiniteLine(try scene.line(id), context: &context, size: size)
      case .ray:
        drawRay(try scene.ray(id), context: &context, size: size)
      }
    } catch {
      return
    }
  }

  private func drawPoint(_ point: Point2D, context: inout GraphicsContext, size: CGSize) {
    let location = viewport.viewPoint(point, size: size)
    let bounds = CGRect(x: location.x - 4, y: location.y - 4, width: 8, height: 8)
    context.fill(Path(ellipseIn: bounds), with: .color(.orange))
  }

  private func drawCircle(_ circle: Circle2D, context: inout GraphicsContext, size: CGSize) {
    let centre = viewport.viewPoint(circle.center, size: size)
    let horizontalEdge = viewport.viewPoint(
      Point2D(x: circle.center.x + circle.radius, y: circle.center.y), size: size)
    let verticalEdge = viewport.viewPoint(
      Point2D(x: circle.center.x, y: circle.center.y + circle.radius), size: size)
    let horizontalRadius = abs(horizontalEdge.x - centre.x)
    let verticalRadius = abs(verticalEdge.y - centre.y)
    let bounds = CGRect(
      x: centre.x - horizontalRadius,
      y: centre.y - verticalRadius,
      width: horizontalRadius * 2,
      height: verticalRadius * 2)
    context.stroke(Path(ellipseIn: bounds), with: .color(.blue), lineWidth: 2.5)
  }

  private func drawEllipse(
    _ ellipse: Ellipse2D,
    context: inout GraphicsContext,
    size: CGSize
  ) {
    let centre = viewport.viewPoint(ellipse.center, size: size)
    let horizontalEdge = viewport.viewPoint(
      Point2D(x: ellipse.center.x + ellipse.radiusX, y: ellipse.center.y), size: size)
    let verticalEdge = viewport.viewPoint(
      Point2D(x: ellipse.center.x, y: ellipse.center.y + ellipse.radiusY), size: size)
    let horizontalRadius = abs(horizontalEdge.x - centre.x)
    let verticalRadius = abs(verticalEdge.y - centre.y)
    let bounds = CGRect(
      x: centre.x - horizontalRadius,
      y: centre.y - verticalRadius,
      width: horizontalRadius * 2,
      height: verticalRadius * 2)
    context.stroke(Path(ellipseIn: bounds), with: .color(.purple), lineWidth: 2.5)
  }

  private func drawLine(
    from start: Point2D,
    to end: Point2D,
    context: inout GraphicsContext,
    size: CGSize
  ) {
    var path = Path()
    path.move(to: viewport.viewPoint(start, size: size))
    path.addLine(to: viewport.viewPoint(end, size: size))
    context.stroke(path, with: .color(.green), lineWidth: 2)
  }

  private func drawInfiniteLine(
    _ line: Line2D,
    context: inout GraphicsContext,
    size: CGSize
  ) {
    let multiplier = 10_000.0
    let start = Point2D(
      x: line.first.x - line.direction.x * multiplier,
      y: line.first.y - line.direction.y * multiplier)
    let end = Point2D(
      x: line.first.x + line.direction.x * multiplier,
      y: line.first.y + line.direction.y * multiplier)
    drawLine(from: start, to: end, context: &context, size: size)
  }

  private func drawRay(_ ray: Ray2D, context: inout GraphicsContext, size: CGSize) {
    let multiplier = 10_000.0
    let end = Point2D(
      x: ray.origin.x + ray.direction.x * multiplier,
      y: ray.origin.y + ray.direction.y * multiplier)
    drawLine(from: ray.origin, to: end, context: &context, size: size)
  }
}

struct LabMetric: View {
  let title: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.headline)
        .monospacedDigit()
    }
  }
}

extension Duration {
  nonisolated var milliseconds: Double {
    let parts = components
    return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
  }
}
