import SwiftUI

struct ContentView: View {
  @State private var selection: GeometryLab = .construction

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(GeometryLab.allCases) { lab in
          Button {
            selection = lab
          } label: {
            Label(lab.title, systemImage: lab.systemImage)
              .foregroundStyle(selection == lab ? Color.accentColor : Color.primary)
          }
        }
      }
      .navigationTitle("Geometry Lab")
    } detail: {
      selectedLab
        .safeAreaInset(edge: .bottom) {
          PrototypeLabSwitcher(selection: $selection)
        }
    }
  }

  @ViewBuilder
  private var selectedLab: some View {
    switch selection {
    case .construction:
      ConstructionLabView()
    case .functions:
      FunctionLabView()
    case .unitCircle:
      UnitCircleLabView()
    case .stress:
      StressLabView()
    case .guide:
      LabGuideView()
    }
  }
}

private enum GeometryLab: String, CaseIterable, Identifiable {
  case construction
  case functions
  case unitCircle
  case stress
  case guide

  var id: Self { self }

  var title: String {
    switch self {
    case .construction: "Construction"
    case .functions: "Functions"
    case .unitCircle: "Unit Circle"
    case .stress: "Stress"
    case .guide: "Guide"
    }
  }

  var systemImage: String {
    switch self {
    case .construction: "point.3.connected.trianglepath.dotted"
    case .functions: "function"
    case .unitCircle: "circle.dotted"
    case .stress: "gauge.with.dots.needle.67percent"
    case .guide: "book.pages"
    }
  }
}

private struct PrototypeLabSwitcher: View {
  @Binding var selection: GeometryLab

  var body: some View {
    HStack(spacing: 12) {
      Button("Previous", systemImage: "chevron.left") {
        move(by: -1)
      }
      .labelStyle(.iconOnly)

      Text("Prototype · \(selection.title)")
        .font(.caption.weight(.semibold))
        .frame(minWidth: 150)

      Button("Next", systemImage: "chevron.right") {
        move(by: 1)
      }
      .labelStyle(.iconOnly)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 9)
    .background(.regularMaterial, in: Capsule())
    .shadow(radius: 8, y: 3)
    .padding(.bottom, 8)
  }

  private func move(by offset: Int) {
    let labs = GeometryLab.allCases
    guard let index = labs.firstIndex(of: selection) else { return }
    selection = labs[(index + offset + labs.count) % labs.count]
  }
}
