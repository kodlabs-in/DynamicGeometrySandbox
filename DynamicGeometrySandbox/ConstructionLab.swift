import DynamicGeometry
import Foundation
import SwiftUI

struct ConstructionLabView: View {
  @State private var scene = GeometryScene(coordinateSystem: .cartesian)
  @State private var tool: ConstructionTool = .point
  @State private var draftPoints: [Point2D] = []
  @State private var polylinePointIDs: [GeometryID] = []
  @State private var history: [GeometryScene] = []
  @State private var extent = 10.0
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 14) {
        controls
        status
        constructionCanvas
        Text(tool.instructions)
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding()
      .navigationTitle("Construction Lab")
      .toolbar {
        ToolbarItemGroup(placement: .primaryAction) {
          Button("Undo", systemImage: "arrow.uturn.backward") {
            undo()
          }
          .disabled(history.isEmpty)

          Button("Clear", systemImage: "trash", role: .destructive) {
            clear()
          }
          .disabled(scene.orderedIDs.isEmpty)
        }
      }
    }
    .alert(
      "Construction error",
      isPresented: Binding(
        get: { errorMessage != nil },
        set: { if !$0 { errorMessage = nil } }),
      actions: { Button("OK") { errorMessage = nil } },
      message: { Text(errorMessage ?? "Please try again.") })
  }

  private var controls: some View {
    VStack(alignment: .leading, spacing: 10) {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack {
          ForEach(ConstructionTool.allCases) { candidate in
            if candidate == tool {
              toolButton(candidate)
                .buttonStyle(.borderedProminent)
            } else {
              toolButton(candidate)
                .buttonStyle(.bordered)
            }
          }
        }
      }

      HStack {
        Text("Viewport ±\(extent, format: .number.precision(.fractionLength(0)))")
          .font(.caption)
          .frame(width: 90, alignment: .leading)
        Slider(value: $extent, in: 2...50, step: 1)

        if tool == .polyline, !polylinePointIDs.isEmpty {
          Button("Finish") {
            finishPolyline(closed: false)
          }
          Button("Close Shape") {
            finishPolyline(closed: true)
          }
          .buttonStyle(.borderedProminent)
        }
      }
    }
  }

  private var status: some View {
    HStack(spacing: 24) {
      LabMetric(title: "Entities", value: scene.orderedIDs.count.formatted())
      LabMetric(title: "Draft taps", value: draftPoints.count.formatted())
      LabMetric(title: "Encoded", value: encodedSize)
    }
  }

  private var constructionCanvas: some View {
    GeometryReader { proxy in
      let viewport = PlotViewport(xRange: -extent...extent, yRange: -extent...extent)
      ZStack {
        GeometrySceneCanvas(scene: scene, viewport: viewport)
          .contentShape(Rectangle())
          .gesture(
            SpatialTapGesture()
              .onEnded { event in
                addTap(viewport.geometryPoint(event.location, size: proxy.size))
              })

        ForEach(draftPoints.indices, id: \.self) { index in
          Circle()
            .fill(.red.opacity(0.75))
            .frame(width: 12, height: 12)
            .position(viewport.viewPoint(draftPoints[index], size: proxy.size))
        }

        ForEach(movablePointIDs, id: \.self) { id in
          if let point = try? scene.point(id) {
            Circle()
              .fill(.orange)
              .frame(width: 18, height: 18)
              .position(viewport.viewPoint(point, size: proxy.size))
              .contentShape(Circle().inset(by: -12))
              .gesture(
                DragGesture(coordinateSpace: .named("construction-canvas"))
                  .onChanged { event in
                    movePoint(
                      id,
                      to: viewport.geometryPoint(event.location, size: proxy.size))
                  }
              )
              .accessibilityLabel("Movable geometry point")
          }
        }
      }
      .coordinateSpace(name: "construction-canvas")
    }
    .frame(minHeight: 420)
  }

  private var movablePointIDs: [GeometryID] {
    scene.orderedIDs.filter { id in
      guard case .point(let definition) = scene.entity(id) else { return false }
      switch definition {
      case .free, .onCircle:
        return true
      case .horizontalProjection, .verticalProjection:
        return false
      }
    }
  }

  private var encodedSize: String {
    guard let data = try? JSONEncoder().encode(scene) else { return "Invalid" }
    return ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
  }

  private func toolButton(_ candidate: ConstructionTool) -> some View {
    Button(candidate.title, systemImage: candidate.systemImage) {
      tool = candidate
      draftPoints = []
      polylinePointIDs = []
    }
  }

  private func addTap(_ point: Point2D) {
    if tool == .point {
      mutateScene { scene in
        _ = try scene.addPoint(.free(point))
      }
      return
    }
    if tool == .polyline {
      appendPolylinePoint(point)
      return
    }

    draftPoints.append(point)
    guard draftPoints.count == tool.requiredTaps else { return }
    buildDraft()
  }

  private func buildDraft() {
    let points = draftPoints
    draftPoints = []
    mutateScene { scene in
      switch tool {
      case .point, .polyline:
        return
      case .segment:
        let ids = try addFreePoints(points, to: &scene)
        _ = try scene.addSegment(start: ids[0], end: ids[1])
      case .line:
        let ids = try addFreePoints(points, to: &scene)
        _ = try scene.addLine(first: ids[0], second: ids[1])
      case .ray:
        let ids = try addFreePoints(points, to: &scene)
        _ = try scene.addRay(origin: ids[0], through: ids[1])
      case .circle:
        let centre = try scene.addPoint(.free(points[0]))
        _ = try scene.addCircle(center: centre, radius: points[0].distance(to: points[1]))
      case .ellipse:
        let centre = try scene.addPoint(.free(points[0]))
        _ = try scene.addEllipse(
          center: centre,
          radiusX: abs(points[1].x - points[0].x),
          radiusY: abs(points[2].y - points[0].y))
      }
    }
  }

  private func appendPolylinePoint(_ point: Point2D) {
    var addedID: GeometryID?
    mutateScene { scene in
      let newID = try scene.addPoint(.free(point))
      if let previousID = polylinePointIDs.last {
        _ = try scene.addSegment(start: previousID, end: newID)
      }
      addedID = newID
    }
    if let addedID {
      polylinePointIDs.append(addedID)
    }
  }

  private func finishPolyline(closed: Bool) {
    if closed, polylinePointIDs.count > 2 {
      mutateScene { scene in
        guard let first = polylinePointIDs.first, let last = polylinePointIDs.last else { return }
        _ = try scene.addSegment(start: last, end: first)
      }
    }
    polylinePointIDs = []
  }

  private func movePoint(_ id: GeometryID, to point: Point2D) {
    mutateScene(recordsHistory: false) { scene in
      try scene.movePoint(id, to: point)
    }
  }

  private func mutateScene(
    recordsHistory: Bool = true,
    _ mutation: (inout GeometryScene) throws -> Void
  ) {
    var updated = scene
    do {
      try mutation(&updated)
      if recordsHistory {
        history.append(scene)
      }
      scene = updated
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func addFreePoints(
    _ points: [Point2D],
    to scene: inout GeometryScene
  ) throws -> [GeometryID] {
    try points.map { point in
      try scene.addPoint(.free(point))
    }
  }

  private func clear() {
    guard !scene.orderedIDs.isEmpty else { return }
    history.append(scene)
    scene = GeometryScene(coordinateSystem: .cartesian)
    draftPoints = []
    polylinePointIDs = []
  }

  private func undo() {
    guard let previous = history.popLast() else { return }
    scene = previous
    draftPoints = []
    polylinePointIDs = []
  }
}

private enum ConstructionTool: String, CaseIterable, Identifiable {
  case point
  case segment
  case line
  case ray
  case circle
  case ellipse
  case polyline

  var id: Self { self }

  var title: String {
    rawValue.capitalized
  }

  var systemImage: String {
    switch self {
    case .point: "smallcircle.filled.circle"
    case .segment: "line.diagonal"
    case .line: "arrow.left.and.right"
    case .ray: "arrow.up.right"
    case .circle: "circle"
    case .ellipse: "oval"
    case .polyline: "point.3.connected.trianglepath.dotted"
    }
  }

  var requiredTaps: Int {
    switch self {
    case .point, .polyline:
      1
    case .segment, .line, .ray, .circle:
      2
    case .ellipse:
      3
    }
  }

  var instructions: String {
    switch self {
    case .point:
      "Tap anywhere to add a free point. Drag orange handles to move free points."
    case .segment:
      "Tap two endpoints to create a finite segment."
    case .line:
      "Tap two distinct points to create an infinite line."
    case .ray:
      "Tap an origin and a second point to create a ray."
    case .circle:
      "Tap the centre, then a radius point. The circle keeps one structural radius."
    case .ellipse:
      "Tap the centre, a horizontal-radius point, then a vertical-radius point."
    case .polyline:
      "Tap repeatedly to connect segments. Finish an open path or close a custom shape."
    }
  }
}
