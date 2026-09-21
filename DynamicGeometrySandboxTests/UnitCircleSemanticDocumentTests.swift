import DynamicGeometry
import Foundation
import Testing

@testable import DynamicGeometrySandbox

@Suite("Unit-circle semantic document")
struct UnitCircleSemanticDocumentTests {
  @Test("A dragged construction can reopen and continue dragging with its relationships intact")
  func dragReopenAndContinue() throws {
    var session = try UnitCircleLabSession()
    try session.movePoint(
      to: Point2D(x: 0, y: 4),
      coalescingID: "first-drag")
    let encoded = try session.encodedDocument()

    var reopened = try UnitCircleLabSession(encodedDocument: encoded)
    #expect(isClose(reopened.snapshot?.angleRadians, .pi / 2))
    #expect(
      reopened.document.scene.parameter(reopened.document.construction.angleParameterID)?.value
        != nil)

    try reopened.movePoint(
      to: Point2D(x: -4, y: 0),
      coalescingID: "second-drag")

    let snapshot = try #require(reopened.snapshot)
    #expect(isClose(snapshot.angleRadians, .pi))
    #expect(isClose(snapshot.movingPoint.x, -1))
    #expect(isClose(snapshot.movingPoint.y, 0))
    #expect(isClose(snapshot.horizontalProjection.x, -1))
    #expect(isClose(snapshot.horizontalProjection.y, 0))
    #expect(isClose(snapshot.verticalProjection.x, 0))
    #expect(isClose(snapshot.verticalProjection.y, 0))
  }

  @Test("Every update from one drag is undone in one step")
  func dragCoalescesIntoOneUndoStep() throws {
    var session = try UnitCircleLabSession()
    let initial = try #require(session.snapshot)

    try session.movePoint(to: Point2D(x: 3, y: 4), coalescingID: "one-drag")
    try session.movePoint(to: Point2D(x: -4, y: 2), coalescingID: "one-drag")

    #expect(session.canUndo)
    let didUndo = session.undo()
    #expect(didUndo)
    #expect(session.snapshot == initial)
    #expect(!session.canUndo)
  }

  @Test("Animation frames share one history action")
  func animationCoalescesIntoOneUndoStep() throws {
    var session = try UnitCircleLabSession()
    let initialAngle = try #require(session.snapshot?.angleRadians)

    try session.advanceAngle(by: 0.1, coalescingID: "one-animation")
    try session.advanceAngle(by: 0.1, coalescingID: "one-animation")
    #expect(isClose(session.snapshot?.angleRadians, initialAngle + 0.2))

    let didUndo = session.undo()
    #expect(didUndo)
    #expect(isClose(session.snapshot?.angleRadians, initialAngle))
    #expect(!session.canUndo)
  }
}

private func isClose(
  _ first: Double?,
  _ second: Double,
  tolerance: Double = 0.000_000_1
) -> Bool {
  guard let first else { return false }
  return abs(first - second) <= tolerance
}
