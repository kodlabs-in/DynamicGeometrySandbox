import SwiftUI

struct LabGuideView: View {
  var body: some View {
    NavigationStack {
      List {
        Section("Construction") {
          GuideRow(
            title: "Build base geometry",
            detail:
              "Choose Point, Segment, Line, Ray, Circle, or Ellipse and follow the tap prompt.")
          GuideRow(
            title: "Build any finite shape",
            detail: "Choose Polyline, tap each vertex, then finish an open path or close the shape."
          )
          GuideRow(
            title: "Remove geometry",
            detail:
              "Use Delete to remove one entity and its dependents, Undo or Redo for history, "
              + "or Clear to reset the scene."
          )
          GuideRow(
            title: "Test dependencies",
            detail: "Drag orange point handles and watch every dependent entity resolve again.")
        }

        Section("Functions, integrals, and limits") {
          GuideRow(
            title: "Enter a formula",
            detail:
              "Use x, pi, e, explicit multiplication, parentheses, powers, "
              + "and supported functions."
          )
          GuideRow(
            title: "Graph representation",
            detail:
              "The package produces separate finite branches and never connects across an "
              + "undefined discontinuity."
          )
          GuideRow(
            title: "Integral",
            detail:
              "Choose package-defined left, right, or midpoint Riemann rectangles. "
              + "Heights and sums are signed and numerical."
          )
          GuideRow(
            title: "Limit",
            detail:
              "The lab approaches the target from both sides and exposes divergence or infinity.")
        }

        Section("Formula syntax") {
          Text("Operators: +  −  *  /  ^")
          Text("Functions: sin cos tan abs sqrt log ln exp")
          Text("Examples: sin(x)/x, 1/x, exp(-x^2), x^3-3*x")
          Text("Write 2*x, not 2x. Function calls require parentheses.")
        }
        .font(.system(.body, design: .monospaced))

        Section("Find package limits") {
          GuideRow(
            title: "Graph",
            detail: "Raises point and segment counts together and measures construction cost.")
          GuideRow(
            title: "Overlap",
            detail: "Creates many distinct circles at identical coordinates.")
          GuideRow(
            title: "Chain",
            detail:
              "Creates deeply nested derived-point dependencies and measures "
              + "recursive resolution.")
          GuideRow(
            title: "Incremental",
            detail:
              "Moves one root twelve times at 100, 1,000, or 10,000 dependents and records "
              + "p95 update time plus the affected count."
          )
          GuideRow(
            title: "Invalid",
            detail:
              "Submits NaN and infinity repeatedly and confirms rollback leaves "
              + "a valid empty scene."
          )
        }

        Section("Important boundary") {
          Text(
            "DynamicGeometry provides numerical explicit curves and semantic Riemann sums. "
              + "It does not claim symbolic algebra, exact integration, formal proofs, or a "
              + "general constraint solver.")
        }
      }
      .navigationTitle("Using the Lab")
    }
  }
}

private struct GuideRow: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.headline)
      Text(detail)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 3)
  }
}
