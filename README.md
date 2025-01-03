# nim
An animation library for Love2D.
Nim can handle animations made up of individual keyframes, as well as keyframes being able to run custom functions. It also has the ability to make creating entire sets of easings very easily (ie. ease in, ease out, ease in-out, ease out-in).

## Interpolation Functions

Interpolation functions are the things that make keyframes (and therefore animations) work; an interpolation function takes in a starting value, an ending value, a time value from 0 to 1 and an optional table of parameters (used in the built-in exponential easing to decide what power to raise x by, for example). They can return any number value.

## Keyframes

Keyframes are fragments of an animation. A keyframe has 4 fields:
- an interpolation function which can be any function that returns a number,
- a starting value which decides what value the animation should start at,
- an ending value
- a length which decides how long the animation should be.

For example, this would be a keyframe that goes from 1 to 0 in 2 seconds:

```lua
nim.KeyFrame:new(
    nim.Easings.sine.out, -- lerp function
    2, -- length
    1, -- starting value
    0 -- ending value
)
```