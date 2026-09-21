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
              "Use Undo to remove the latest construction change, or Clear to reset the scene."
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
              "Each finite sample becomes a package point; adjacent samples become "
              + "package segments."
          )
          GuideRow(
            title: "Integral",
            detail:
              "The lab uses the trapezoid rule and shades the sampled area. "
              + "It is numerical, not symbolic."
          )
          GuideRow(
            title: "Limit",
            detail:
              "The lab approaches the target from both sides and exposes divergence or infinity.")
        }

        Section("Formula syntax") {
          Text("Operators: +  −  *  /  ^")
          Text("Functions: sin cos tan asin acos atan abs sqrt log ln exp floor ceil")
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
            title: "Invalid",
            detail:
              "Submits NaN and infinity repeatedly and confirms rollback leaves "
              + "a valid empty scene."
          )
        }

        Section("Important boundary") {
          Text(
            "DynamicGeometry currently models finite geometric entities and relationships. "
              + "The sandbox samples calculus expressions into those entities. It does not "
              + "claim the package is a symbolic algebra or calculus engine.")
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
