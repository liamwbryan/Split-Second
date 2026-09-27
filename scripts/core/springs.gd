class_name Springs
extends RefCounted
## Damped springs for camera/weapon juice, stable at any frame rate.
## A spring integrated once per render frame blows up when the frame time gets
## long (a hitch, or a throttled background window): the "goes crazy" bug.
## Substepping at <= 1/240 s keeps it stable and frame-rate independent.

const MAX_STEP := 1.0 / 240.0


## Advances a spring toward 0. Returns Vector2(position, velocity).
static func step(x: float, v: float, stiffness: float, damping: float, delta: float) -> Vector2:
	delta = minf(delta, 0.25)  # never try to simulate a multi-second stall
	var steps := maxi(1, ceili(delta / MAX_STEP))
	var h := delta / steps
	for i in steps:
		v += (-stiffness * x - damping * v) * h
		x += v * h
	return Vector2(x, v)
