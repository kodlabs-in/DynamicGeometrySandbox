# DynamicGeometrySandbox

A small SwiftUI app for validating the
[DynamicGeometry](https://github.com/kodlabs-in/DynamicGeometry) Swift package on iPhone and iPad.

The app provides a Geometry Lab for:

- Building points, segments, lines, rays, circles, ellipses, polylines, and closed custom shapes
- Removing one construction entity with dependency-aware cascade deletion, or undoing the edit
- Graphing free-form expressions with package-owned explicit-curve definitions and safe branches
- Exploring package-owned left, right, and midpoint Riemann sums plus two-sided limits
- Inspecting polar and implicit curves, projected 3D meshes, symbolic derivatives, and local
  simultaneous constraint solves in the Advanced Math lab
- Stressing overlaps, deep chains, Codable round trips, invalid rollback, and incremental fan-out
- Revisiting a draggable, animated unit circle with undo, redo, save, and reopen controls

See [GEOMETRY_LAB.md](GEOMETRY_LAB.md) for formula syntax, workflows, and extension instructions.

## Run

1. Keep `DynamicGeometry` and `DynamicGeometrySandbox` beside each other in the same directory.
2. Open `DynamicGeometrySandbox.xcodeproj` in Xcode.
3. Select an iPhone, iPad, or simulator.
4. Build and run the `DynamicGeometrySandbox` scheme.
5. Use Construction and Function labs for experiments, then use Incremental in Stress to record
   p95 update time and affected-entity counts at 100, 1,000, and 10,000 dependents.
6. Use Advanced to vary resolution and one meaningful parameter across every roadmap engine.

The sandbox uses a relative local package reference so package changes can be tested immediately.

## Xcode previews

Open `DynamicGeometrySandbox/PreviewGallery.swift` and resume the Canvas. It provides previews for:

- A package-scenario gallery covering circle-with-axes, dependency, overlap, affine-transform,
  and sampled-integral constructions
- The complete Sandbox navigation
- Construction tools
- The draggable, persisted unit circle
- Package-backed function graph, Riemann-sum, and limit experiments
- Advanced polar, implicit, 3D, symbolic, and constraint experiments
- Package stress experiments

The scenario gallery creates real `DynamicGeometry` scenes. Its scenarios are also validated,
encoded, and decoded by the unit-test target, so the preview fixtures cannot silently drift away
from the package API.

## Development checks

```bash
make format
make check
```

The test target also runs the representative 100/1,000/10,000 incremental fan-out cases. These are
measurement tests: they verify correctness and print device-specific p95 timings without imposing
a hardware-dependent performance threshold.
