import Combine
import DynamicGeometry
import Foundation
import SwiftUI

struct UnitCircleLabView: View {
  @State private var session: UnitCircleLabSession?
  @State private var savedDocument: Data?
  @State private var isPlaying = false
  @State private var animationCoalescingID: String?
  @State private var errorMessage: String?

  private let animationTimer = Timer.publish(every: 1.0 / 30, on: .main, in: .common)
    .autoconnect()

  init() {
    do {
      _session = State(initialValue: try UnitCircleLabSession())
      _errorMessage = State(initialValue: nil)
    } catch {
      _session = State(initialValue: nil)
      _errorMessage = State(initialValue: error.localizedDescription)
    }
  }

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 18) {
        Text("Drag the orange point, choose an angle, or animate the shared θ parameter.")
          .foregroundStyle(.secondary)
        angleButtons
        documentControls

        if let session, let snapshot = session.snapshot {
          valueSummary(snapshot)
          UnitCircleCanvas(
            scene: session.document.scene,
            movingPointID: session.document.construction.movingPointID,
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
    .onReceive(animationTimer) { _ in
      guard isPlaying, let animationCoalescingID else { return }
      updateSession { session in
        try session.advanceAngle(by: .pi / 90, coalescingID: animationCoalescingID)
      }
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
            stopAnimation()
            updateSession { session in
              try session.setAngle(Double(degrees) * .pi / 180)
            }
          }
          .buttonStyle(.bordered)
        }
      }
    }
  }

  private var documentControls: some View {
    HStack {
      Button("Undo", systemImage: "arrow.uturn.backward") {
        stopAnimation()
        mutateSession { $0.undo() }
      }
      .disabled(session?.canUndo != true)

      Button("Redo", systemImage: "arrow.uturn.forward") {
        stopAnimation()
        mutateSession { $0.redo() }
      }
      .disabled(session?.canRedo != true)

      Button("Save", systemImage: "square.and.arrow.down") {
        guard let session else { return }
        do {
          savedDocument = try session.encodedDocument()
        } catch {
          errorMessage = error.localizedDescription
        }
      }

      Button("Reopen", systemImage: "doc.badge.arrow.up") {
        reopenSavedDocument()
      }
      .disabled(savedDocument == nil)

      Button(
        isPlaying ? "Pause" : "Play",
        systemImage: isPlaying ? "pause.fill" : "play.fill",
        action: toggleAnimation
      )
      .buttonStyle(.borderedProminent)
    }
  }

  private func valueSummary(_ snapshot: UnitCircleSnapshot) -> some View {
    HStack(spacing: 24) {
      LabMetric(title: "Angle", value: String(format: "%.1f°", snapshot.angleDegrees))
      LabMetric(title: "cos θ", value: String(format: "%.3f", snapshot.cosine))
      LabMetric(title: "sin θ", value: String(format: "%.3f", snapshot.sine))
    }
  }

  private func movePoint(to point: Point2D, coalescingID: String) {
    stopAnimation()
    updateSession { session in
      try session.movePoint(to: point, coalescingID: coalescingID)
    }
  }

  private func toggleAnimation() {
    if isPlaying {
      stopAnimation()
    } else {
      animationCoalescingID = "animation:\(UUID().uuidString)"
      isPlaying = true
    }
  }

  private func stopAnimation() {
    isPlaying = false
    animationCoalescingID = nil
  }

  private func reopenSavedDocument() {
    guard let savedDocument else { return }
    stopAnimation()
    do {
      session = try UnitCircleLabSession(encodedDocument: savedDocument)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func updateSession(_ update: (inout UnitCircleLabSession) throws -> Void) {
    guard var session else { return }
    do {
      try update(&session)
      self.session = session
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func mutateSession(_ mutation: (inout UnitCircleLabSession) -> Bool) {
    guard var session else { return }
    _ = mutation(&session)
    self.session = session
  }
}

private struct UnitCircleCanvas: View {
  let scene: GeometryScene
  let movingPointID: GeometryID
  let onDrag: (Point2D, String) -> Void

  @State private var dragCoalescingID: String?

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
                  let identifier = dragCoalescingID ?? "drag:\(UUID().uuidString)"
                  dragCoalescingID = identifier
                  onDrag(viewport.geometryPoint(value.location, size: proxy.size), identifier)
                }
                .onEnded { _ in dragCoalescingID = nil }
            )
            .accessibilityLabel("Point on circle")
            .accessibilityHint("Drag to change the shared angle")
        }
      }
      .coordinateSpace(name: "unit-circle")
    }
    .aspectRatio(1, contentMode: .fit)
    .frame(maxWidth: 620, maxHeight: 620)
    .frame(maxWidth: .infinity)
  }
}

enum UnitCircleDocumentError: Error, LocalizedError {
  case inconsistentDocument

  var errorDescription: String? {
    "The saved unit-circle document does not contain its required relationships."
  }
}

struct UnitCircleDocument: Codable, Equatable, Sendable {
  var scene: GeometryScene
  let construction: UnitCircleConstruction

  init() throws {
    var scene = GeometryScene(coordinateSystem: .cartesian)
    let construction = try UnitCircleConstruction.insert(into: &scene)
    self.scene = scene
    self.construction = construction
  }

  var snapshot: UnitCircleSnapshot? {
    try? construction.snapshot(in: scene)
  }

  func validate() throws {
    do {
      _ = try construction.snapshot(in: scene)
    } catch {
      throw UnitCircleDocumentError.inconsistentDocument
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    scene = try container.decode(GeometryScene.self, forKey: .scene)
    construction = try container.decode(UnitCircleConstruction.self, forKey: .construction)
    try validate()
  }

  func encode(to encoder: Encoder) throws {
    try validate()
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(scene, forKey: .scene)
    try container.encode(construction, forKey: .construction)
  }

  private enum CodingKeys: CodingKey {
    case scene
    case construction
  }
}

struct UnitCircleLabSession: Sendable {
  private(set) var document: UnitCircleDocument
  private var history: GeometryHistory

  init() throws {
    self.init(document: try UnitCircleDocument())
  }

  init(document: UnitCircleDocument) {
    self.document = document
    history = GeometryHistory(scene: document.scene)
  }

  init(encodedDocument: Data) throws {
    self.init(document: try JSONDecoder().decode(UnitCircleDocument.self, from: encodedDocument))
  }

  var snapshot: UnitCircleSnapshot? { document.snapshot }
  var canUndo: Bool { history.canUndo }
  var canRedo: Bool { history.canRedo }

  func encodedDocument() throws -> Data {
    try JSONEncoder().encode(document)
  }

  mutating func setAngle(
    _ angleRadians: Double,
    coalescingID: String? = nil
  ) throws {
    try apply(
      .setParameter(id: document.construction.angleParameterID, value: angleRadians),
      coalescingID: coalescingID)
  }

  mutating func advanceAngle(by delta: Double, coalescingID: String) throws {
    guard let angle = snapshot?.angleRadians else {
      throw UnitCircleDocumentError.inconsistentDocument
    }
    try setAngle(angle + delta, coalescingID: coalescingID)
  }

  mutating func movePoint(to point: Point2D, coalescingID: String) throws {
    try apply(
      .movePoint(id: document.construction.movingPointID, target: point),
      coalescingID: coalescingID)
  }

  @discardableResult
  mutating func undo() -> Bool {
    let changed = history.undo()
    synchronizeDocument()
    return changed
  }

  @discardableResult
  mutating func redo() -> Bool {
    let changed = history.redo()
    synchronizeDocument()
    return changed
  }

  private mutating func apply(
    _ command: GeometryCommand,
    coalescingID: String?
  ) throws {
    _ = try history.apply(
      GeometryTransaction(commands: [command]),
      coalescingID: coalescingID)
    synchronizeDocument()
  }

  private mutating func synchronizeDocument() {
    document.scene = history.scene
  }
}
