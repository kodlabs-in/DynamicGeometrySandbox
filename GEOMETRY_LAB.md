# Geometry Lab Guide

The sandbox is a prototype for discovering what `DynamicGeometry` can express and where its current
model stops being sufficient. Most lab state is temporary; the Unit Circle lab can encode and
reopen its package scene and construction identifiers in memory to verify persistence behavior.

## Construction Lab

Choose a tool and tap the canvas:

- **Point:** one tap creates a free point.
- **Segment, Line, or Ray:** two taps create the defining points and entity.
- **Circle:** tap its centre and one radius point.
- **Ellipse:** tap its centre, a horizontal-radius point, and a vertical-radius point.
- **Polyline:** keep tapping vertices, then choose **Finish** or **Close Shape**.

Use **Delete** to choose one entity and cascade through geometry that depends on it. Use **Undo** or
**Redo** to navigate construction edits. Use **Clear** to reset the whole scene; Clear itself can be
undone.

Orange handles are package point entities. Drag them to call `GeometryScene.movePoint`, then observe
the dependent geometry resolve again. A closed polyline is the generic way to approximate any
finite custom outline with the package's existing point and segment primitives.

## Function Lab

Enter an expression using:

```text
x  pi  e
+  -  *  /  ^  (  )
sin cos tan abs sqrt log ln exp
```

Multiplication must be explicit: use `2*x`, not `2x`.

Examples:

```text
sin(x)
sin(x)/x
1/x
exp(-x^2)
x^3 - 3*x
```

Choose an experiment:

- **Graph** asks the package to sample a semantic explicit curve into separate finite branches.
- **Integral** asks the package for signed left, right, or midpoint Riemann rectangles and their sum.
- **Limit** evaluates points approaching the target from the left and right.

The package intentionally separates branches around undefined or detected discontinuities, so the
renderer never draws a segment across a gap such as `1/x` at zero. Curve and Riemann definitions
are Codable semantic data; sampled points and rectangles are derived on demand and are not stored
in a scene document.

The integral and limit results are numerical experiments. Symbolic differentiation is available
for supported `ScalarExpression` forms, but exact integration and formal limit proofs are not. The
sandbox parser recognizes a few additional names; unsupported package functions are reported
clearly instead of being silently approximated as supported engine behavior.

## Advanced Math Lab

Choose one package-backed acceptance preset:

- **Polar:** samples `r = cos(kθ)` into safe curve branches.
- **Implicit:** extracts a circle contour from a bounded grid and reports unresolved cells.
- **3D Surface:** samples a saddle into an indexed mesh and applies a fixed 2D projection for this
  UI. The package itself remains renderer-independent.
- **Symbolic:** differentiates `sin(x²)` structurally, then samples the original and exact
  derivative expressions.
- **Constraints:** solves a circle and line equality together. Positive and negative seeds select
  different local intersections.

Resolution controls sampling density. The second slider changes a scenario-specific mathematical
parameter. Diagnostics remain visible because zero diagnostics are not a valid assumption for an
approximate implicit contour.

These boundaries are intentional: implicit extraction is bounded and approximate, surface meshes
use fixed rectangular sampling, symbolic algebra covers documented forms rather than acting as a
general CAS, and the simultaneous solver is local and numerical rather than globally complete.

## Unit Circle Lab

The Unit Circle lab is built by `UnitCircleConstruction`, not a Sandbox-only geometry recipe. Drag
the orange point, choose a preset angle, or press **Play** to change the shared angle parameter.
Continuous drag and animation updates are coalesced into sensible history steps.

Use **Save** and **Reopen** to encode and decode the package scene together with the construction's
stable identifiers. The reopened point remains draggable and the cosine, sine, projections, angle,
and radius continue to resolve from the same semantic parameters.

## Stress Lab

Select a pattern and requested size:

- **Graph:** points plus connecting segments.
- **Overlap:** distinct circles with identical geometry.
- **Chain:** deeply nested derived projections. This is capped at 400 to keep the prototype usable.
- **Incremental:** one free root with 100, 1,000, or 10,000 dependents, moved twelve times. It
  reports p95 update time and the exact affected-entity count without rendering every dependent.
- **Invalid:** repeated NaN and infinity insertions; the final scene must remain empty and valid.

Each run measures scene construction, complete resolution, JSON encoding, JSON decoding, and final
validation. Incremental runs additionally measure the package's targeted invalidation path. Record
the device, pattern, count, and timings before optimizing; the 16.7 ms marker is informational, not
a portable pass/fail threshold.

## Add another formula preset

Add a case to `FunctionPreset` in `DynamicGeometrySandbox/FunctionLab.swift`, give it a title, and
return its expression string from `formula`. The free-form formula field requires no code change.

## Add another stress scenario

Add a `StressPattern` case in `DynamicGeometrySandbox/StressLab.swift`, implement its scene builder,
and add an appropriate viewport. Keep the scenario expressed through public `DynamicGeometry` APIs
so it continues to measure the package boundary.

## Add another advanced scenario

Add a case to `AdvancedMathScenario`, implement a runner using public `DynamicGeometry` APIs, and
give it a parameter range and boundary statement in `AdvancedMathLabView.swift`. Add an acceptance
test to `AdvancedMathLabTests.swift` before the implementation. Keep projection and drawing in the
Sandbox; keep semantic curves, surfaces, expressions, and solver behavior in the package.

## Interpreting a missing capability

Do not add a one-off drawing workaround and call it package support. If an experiment needs a
native curve, polygon, intersection, transformation, or new constraint, record that as a package
capability. The sandbox may approximate it to explore the interaction, but the distinction should
remain visible.
