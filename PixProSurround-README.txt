=============================================================================
 PixProSurround — Full-360° Glow / Bubble Surround for Pixelmator Pro
=============================================================================

PixProSurround is a macOS AppleScript applet that creates a smooth,
full-circle glow ("bubble") surround around a selected layer in Pixelmator
Pro. It works with text layers, shape layers, and image layers. Pixelmator
Pro has no native outline-glow effect of this kind; the applet builds one
out of many precisely offset, blurred copies of the source layer.

Applet:   /Applications/PixProSurround.app
Source:   ~/My_Applications/PixProSurround/PixProSurround.applescript
Defaults: ~/.textsurround_defaults.plist


-----------------------------------------------------------------------------
 HOW TO USE IT
-----------------------------------------------------------------------------

    1. In Pixelmator Pro, select the one layer to surround. Text, shape
       and image layers all work.

    2. Run PixProSurround (/Applications/PixProSurround.app).

    3. Pick the two gradient colors. The color picker opens twice: first
       the START color, innermost, then the END color, outermost. The
       eyedropper samples any color on screen.

    4. Enter depth / blur, for example 25 / 15.
           Depth   pixels (25), millimeters (5mm) or math (72/25.4*5)
           Blur    Gaussian radius in pixels; softens the whole glow
       The ray count is worked out from the depth, so there is nothing
       else to set.

    5. Click OK and let it build.

You get one group named after the source layer. Your original is the bottom
layer of that group, untouched — delete the group and run again with other
settings to start over.


-----------------------------------------------------------------------------
 HOW THE EFFECT IS BUILT (techniques)
-----------------------------------------------------------------------------

PIXEL SOURCE
    The original layer is duplicated and the duplicate converted into
    pixels. The real original is never modified. Converting first is what
    lets one identical method serve text, shapes, and images alike.

PRE-BLUR, INHERITED BY ALL COPIES
    A Gaussian blur (user-chosen radius) is applied ONCE to the pixel
    source before duplication. Every subsequent copy inherits the blur —
    it is not re-applied per copy, which keeps the effect fast and the
    softness perfectly uniform.

RADIAL RAY STACKING
    Colour-filled copies of the blurred source are offset radially in
    every direction of the full circle and stacked outward by depth:
    - The ray count ("steps") is auto-calculated from the chosen depth:
      steps = round(depth x pi/2), clamped to 8-36. Deeper surrounds
      automatically get more rays so the ring stays smooth.
      (depth 10 -> 16 rays, depth 20 -> 31, depth 30+ -> 36)
    - Three rings of copies are laid down per direction, so the total
      stack is 3 x steps layers (depth 20 -> 93 layers).
    - The overlapping blurred edges merge into a single smooth bubble.
    The stack is then merged into one layer, "<name> surround".

COLOUR GRADIENT
    Start and end colours are picked with the macOS colour picker (the
    eyedropper can sample anything on screen) and interpolated across the
    rings. Direct entry also works: R,G,B decimals (246,38,8) or hex with
    or without # (F6260E / #F6260E).

DEPTH INPUT
    The depth field accepts plain pixels (25), millimetres (5mm), or math
    expressions (72/25.4*5, 5mm+10, 25*2).

RESULT GROUPING
    The output is a group named after the source layer, containing
    (top to bottom):
        <name>.pixel    — pixel copy of the original
        <name> surround — the merged glow layer
        <name>          — the real original, untouched
    All settings are saved as defaults for the next run.


-----------------------------------------------------------------------------
 IF THE RESULT IS NOT WHAT YOU EXPECTED
-----------------------------------------------------------------------------

Multiple layers are created in this process. They are collected into one
group named after the source layer.

The BOTTOM layer of that group is your ORIGINAL, untouched. To start over:
drag that bottom layer out of the group to the top level of the Layers list
and make it visible, then delete the group and run PixProSurround again with
adjusted settings.

Nothing is lost by retrying — the original is never modified.


-----------------------------------------------------------------------------
 VERSION HISTORY (documented milestones)
-----------------------------------------------------------------------------

v1.0.9
    Positioning fix. An earlier "snap" formula repositioned the merged
    bubble after the merge (pixelX - (depth + blur)); it underestimated
    the Gaussian blur's true pixel extent and shifted the bubble ~12 px
    right/down on shape layers. The snap was removed — Pixelmator's raw
    merge position is correct and is now used as-is.

v1.3.0  (2026-06)
    Grouped output. The .pixel copy, the merged surround, and the real
    original are wrapped in a group named after the source layer
    (matching PixProShadow 7.2.0 behaviour). The script only ever
    touches its own layers' visibility.

v1.3.1  (2026-06-25)
    No functional change. Added CFBundleShortVersionString /
    CFBundleVersion / copyright to the app's Info.plist so Finder's
    Get Info shows the version, and re-signed the app. Source encoding
    converted from UTF-16 LE to UTF-8 (lossless, bytecode verified
    identical).

(Earlier 1.x iterations existed during initial development; their
individual changes were not separately recorded.)



v1.4.0  (2026-08-10)
    Targets whichever Pixelmator build is actually in use. Since the Creator
    Studio rebrand there are two installs — com.apple.pixelmator (Creator
    Studio 4.x) and com.pixelmatorteam.pixelmator.x (Pixelmator Pro 3.x) —
    and `tell application "Pixelmator Pro"` bound to a fixed app path at
    compile time. A document open in the other build therefore read as no
    document at all. The build is now resolved at run time by bundle id
    (pixTarget): frontmost first, then any running build with a document.


v1.5.0  (2026-08-10)
    Read Me button. This README is now copied into the app bundle's own
    Contents/Resources at build time and opened via `path to resource`, so it
    travels inside the app — nothing depends on ~/My_Applications or any other
    external path. The button sits on the colour-picker entry prompt and returns you
    to the prompt after the Read Me opens.

v1.6.0  (2026-08-15)
    Targets the running Pixelmator by BUNDLE PATH instead of by bundle id.
    Several COPIES of one build can be installed and copies share an
    identifier, so `tell application id` could not tell them apart: it
    addressed whichever copy macOS preferred, launched that copy if it was not
    already running, and then failed on the empty one. The path and pid of
    every running Pixelmator process are read from `ps`, which is the one
    thing that distinguishes identical copies, and everything is keyed to
    that.


v1.6.1  (2026-08-19)
    Signing release; no change to the effect. Signed with the Developer ID
    certificate under the hardened runtime and notarized, plus the two things
    osacompile does not put in an applet:

        com.apple.security.automation.apple-events. The hardened runtime
        stops an app from ASKING for Automation, so without this entitlement
        the applet keeps working on a Mac that already granted access and
        fails on a fresh one with "Not authorized to send Apple events"
        (-1743) — with no way for the user to switch it on by hand, because
        it never appears in the Automation list.

        A real CFBundleIdentifier (com.timmccoy.pixprosurround). osacompile writes
        none and drops it again on every rebuild, so codesign had been sealing
        the bundle NAME instead: nothing could address the app with
        `tell application id`, and it could hold no defaults domain.


v1.6.2  (2026-09-13)
    Documentation release; no change to the effect. Adds a HOW TO USE IT
    section — numbered steps from selecting the layer, through every dialog
    field and its units, to what the result group contains — and fills in a
    version history that had stopped one release short of the shipping build.
    The copy inside the bundle was refreshed with it, so the Read Me button
    shows the same text.


v1.7.0  (2026-09-13)  — current
    Checks for a newer release. The app asks GitHub for the newest published
    tag and says so in the color prompt when this build is behind; nothing
    is shown when it is current. It only ever REPORTS — it never downloads or
    replaces itself, because a running bundle cannot safely overwrite its own
    files.

    The check runs once a day at most and is capped at three seconds, so a slow
    or absent network barely shows. The tag and the day it was fetched are kept
    in the defaults file. The version is compared as integers, so 3.10.0 counts
    as newer than 3.9.0 rather than older.


-----------------------------------------------------------------------------
 Copyright (c) 2026 Tim McCoy. All rights reserved.

 Developed with the support of Claude (Anthropic) — design, code, and
 testing assistance.
=============================================================================
