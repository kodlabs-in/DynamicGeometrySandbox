# DynamicGeometrySandbox

A small SwiftUI app for validating the
[DynamicGeometry](https://github.com/kodlabs-in/DynamicGeometry) Swift package on iPhone and iPad.

The app provides an in-memory Geometry Lab for:

- Building points, segments, lines, rays, circles, ellipses, polylines, and closed custom shapes
- Graphing free-form expressions as real `DynamicGeometry` point and segment entities
- Exploring numerical integrals and two-sided limits
- Stressing overlaps, deep dependency chains, Codable round trips, and invalid-number rollback
- Revisiting the draggable unit-circle construction

See [GEOMETRY_LAB.md](GEOMETRY_LAB.md) for formula syntax, workflows, and extension instructions.

## Run

1. Keep `DynamicGeometry` and `DynamicGeometrySandbox` beside each other in the same directory.
2. Open `DynamicGeometrySandbox.xcodeproj` in Xcode.
3. Select an iPhone, iPad, or simulator.
4. Build and run the `DynamicGeometrySandbox` scheme.
5. Use Construction and Function labs for experiments, then use Stress to measure package limits.

The sandbox uses a relative local package reference so package changes can be tested immediately.

## Xcode previews

Open `DynamicGeometrySandbox/PreviewGallery.swift` and resume the Canvas. It provides previews for:

- A package-scenario gallery covering circle-with-axes, dependency, overlap, affine-transform,
  and sampled-integral constructions
- The complete Sandbox navigation
- Construction tools
- The draggable unit circle
- Function graph, integral, and limit experiments
- Package stress experiments

The scenario gallery creates real `DynamicGeometry` scenes. Its scenarios are also validated,
encoded, and decoded by the unit-test target, so the preview fixtures cannot silently drift away
from the package API.

## Development checks

```bash
make format
make check
```
