# Geometry Lab Guide

The sandbox is an in-memory prototype for discovering what `DynamicGeometry` can express and where
its current model stops being sufficient. It does not save experiments.

## Construction Lab

Choose a tool and tap the canvas:

- **Point:** one tap creates a free point.
- **Segment, Line, or Ray:** two taps create the defining points and entity.
- **Circle:** tap its centre and one radius point.
- **Ellipse:** tap its centre, a horizontal-radius point, and a vertical-radius point.
- **Polyline:** keep tapping vertices, then choose **Finish** or **Close Shape**.

Use **Undo** to remove the most recent construction change. Use **Clear** to reset the whole scene;
Clear itself can be undone.

Orange handles are package point entities. Drag them to call `GeometryScene.movePoint`, then observe
the dependent geometry resolve again. A closed polyline is the generic way to approximate any
finite custom outline with the package's existing point and segment primitives.

## Function Lab

Enter an expression using:

```text
x  pi  e
+  -  *  /  ^  (  )
sin cos tan asin acos atan abs sqrt log ln exp floor ceil
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

- **Graph** samples the expression across the x-domain.
- **Integral** uses the trapezoid rule and shades the sampled area.
- **Limit** evaluates points approaching the target from the left and right.

Every finite graph sample is inserted into a real `GeometryScene` as a free point. Adjacent samples
are connected using segment entities. The reported entity count, construction time, and JSON size
therefore measure the package rather than only SwiftUI drawing.

The integral and limit results are numerical experiments. `DynamicGeometry` does not currently do
symbolic algebra, exact integration, or formal limit proofs.

## Stress Lab

Select a pattern and requested size:

- **Graph:** points plus connecting segments.
- **Overlap:** distinct circles with identical geometry.
- **Chain:** deeply nested derived projections. This is capped at 400 to keep the prototype usable.
- **Invalid:** repeated NaN and infinity insertions; the final scene must remain empty and valid.

Each run measures scene construction, complete resolution, JSON encoding, JSON decoding, and final
validation. Increase the requested count until the interaction cost is no longer acceptable, then
record the device, pattern, count, and timings before optimizing the package.

## Add another formula preset

Add a case to `FunctionPreset` in `DynamicGeometrySandbox/FunctionLab.swift`, give it a title, and
return its expression string from `formula`. The free-form formula field requires no code change.

## Add another stress scenario

Add a `StressPattern` case in `DynamicGeometrySandbox/StressLab.swift`, implement its scene builder,
and add an appropriate viewport. Keep the scenario expressed through public `DynamicGeometry` APIs
so it continues to measure the package boundary.

## Interpreting a missing capability

Do not add a one-off drawing workaround and call it package support. If an experiment needs a
native curve, polygon, intersection, transformation, or new constraint, record that as a package
capability. The sandbox may approximate it to explore the interaction, but the distinction should
remain visible.
