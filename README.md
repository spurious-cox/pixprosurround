# PixProSurround 1.7.3

Draws a smooth full-circle glow — a bubble — around a Pixelmator Pro layer.
Pixelmator has no native outline glow of this kind; this builds one out of
many blurred copies of the layer, offset radially and stacked outward.

### [⬇︎ Download the latest release](https://github.com/spurious-cox/pixprosurround/releases/latest)

Notarized and stapled by Apple — open the DMG and drag PixProSurround to Applications,
or install it with Homebrew:

```
brew install --cask spurious-cox/tap/pixprosurround
```
Requires Pixelmator Pro. Both the 3.x build and the Creator Studio build work;
the app binds to whichever one is in front or has a document open.

## Using it

1. Select the one layer to surround. Text, shape and image layers all work.
2. Run PixProSurround.
3. Pick the two gradient colors. The picker opens twice: **start** (innermost)
   then **end** (outermost). The eyedropper samples anything on screen.
4. Enter `depth / blur`, for example `25 / 15`. Depth takes pixels (`25`),
   millimeters (`5mm`) or math (`72/25.4*5`); blur is the Gaussian radius that
   softens the whole glow.

The ray count is worked out from the depth, so there is nothing else to set.

## What you get

A group named after the source layer: a pixel copy, the merged surround, and
your original untouched at the bottom.

## How it works

The layer is converted to pixels once and blurred once, so every copy inherits
the same softness — fast, and perfectly even. Colored copies are then offset in
every direction of the circle and stacked outward, the ray count scaled to the
depth (`round(depth × π/2)`, clamped to 8–36), with the color walked from the
start color to the end color across the stack.

## Building

```
osacompile -o /tmp/PixProSurround.scpt PixProSurround.applescript
```

Signing uses a Developer ID certificate selected by SHA-1 hash and timestamped,
which is what keeps macOS's Automation grant alive across rebuilds.
`~/My_Applications/_signing/pixpro_release.sh all <App>` signs and notarizes;
`pixpro_publish.sh <App>` wraps it in the DMG and updates the cask.

## Problems or suggestions

Open an issue: https://github.com/spurious-cox/pixprosurround/issues

## License

MIT. See [LICENSE](LICENSE).
