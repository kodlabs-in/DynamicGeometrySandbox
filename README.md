# DynamicGeometrySandbox

A small SwiftUI app for validating the adjacent `DynamicGeometry` Swift package on iPhone and
iPad.

The app builds a unit-circle construction entirely from package entities. Drag the orange point
around the circle or choose a preset angle. The radius, horizontal projection, vertical projection,
angle, cosine, and sine all resolve from the same dependency graph.

## Run

1. Keep `DynamicGeometry` and `DynamicGeometrySandbox` beside each other in the same directory.
2. Open `DynamicGeometrySandbox.xcodeproj` in Xcode.
3. Select an iPhone, iPad, or simulator.
4. Build and run the `DynamicGeometrySandbox` scheme.
5. Drag the orange point and confirm the projections and values update together.

The sandbox uses a relative local package reference so package changes can be tested immediately.

## Development checks

```bash
make format
make check
```
