import DynamicGeometry
import Foundation
import Testing

@testable import DynamicGeometrySandbox

@Suite("Advanced mathematics lab")
struct AdvancedMathLabTests {
  @Test("A polar rose preset is sampled through the package curve API")
  func buildsPolarRose() throws {
    let result = try AdvancedMathLabRunner.run(
      scenario: .polarRose,
      resolution: 96,
      parameter: 5)

    #expect(!result.lines.isEmpty)
    #expect(result.diagnosticCount == 0)
    #expect(result.summary.localizedCaseInsensitiveContains("polar"))
  }

  @Test("An implicit circle preset is extracted through the bounded contour API")
  func buildsImplicitCircle() throws {
    let result = try AdvancedMathLabRunner.run(
      scenario: .implicitContour,
      resolution: 40,
      parameter: 1)

    #expect(!result.lines.isEmpty)
    #expect(result.diagnosticCount <= 8)
    let contourPoints = result.lines.flatMap { [$0.start, $0.end] }
    let allPointsFollowCircle = contourPoints.allSatisfy { point in
      let residual = point.x * point.x + point.y * point.y - 1
      return abs(residual) < 0.01
    }
    #expect(allPointsFollowCircle)
  }

  @Test("A three-dimensional surface preset produces a projected mesh")
  func buildsProjectedSurface() throws {
    let result = try AdvancedMathLabRunner.run(
      scenario: .surface3D,
      resolution: 12,
      parameter: 0.7)

    #expect(!result.lines.isEmpty)
    #expect(result.diagnosticCount == 0)
    #expect(result.summary.localizedCaseInsensitiveContains("3D"))
  }

  @Test("A symbolic preset differentiates and samples both exact expressions")
  func buildsSymbolicDerivative() throws {
    let result = try AdvancedMathLabRunner.run(
      scenario: .symbolicDerivative,
      resolution: 80,
      parameter: 1)

    #expect(result.lines.count > 100)
    #expect(result.points.count == 2)
    #expect(result.diagnosticCount == 0)
    #expect(result.summary.localizedCaseInsensitiveContains("symbolic"))
  }

  @Test("A simultaneous constraint preset follows the chosen local branch")
  func buildsConstraintIntersection() throws {
    let result = try AdvancedMathLabRunner.run(
      scenario: .constraintIntersection,
      resolution: 96,
      parameter: -0.8)

    let point = try #require(result.points.first)
    #expect(abs(point.x + sqrt(0.5)) < 0.000_001)
    #expect(abs(point.y + sqrt(0.5)) < 0.000_001)
    #expect(result.summary.localizedCaseInsensitiveContains("constraint"))
  }
}
