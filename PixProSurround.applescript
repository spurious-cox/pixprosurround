-- ============================================================
-- PixProSurround.applescript
-- Version 1.4.0  (2026-06-25)
--
-- New in 1.4.0: targets whichever Pixelmator build is actually in use,
--   resolved at run time by bundle id (see pixTarget). Since the Creator
--   Studio rebrand `tell application "Pixelmator Pro"` bound to a fixed path
--   at compile time, so a document open in the other build read as no
--   document at all.
--
-- Copyright (c) 2026 Tim McCoy. All rights reserved.
-- Developed with assistance from Claude (Anthropic).
--
-- New in 1.3.1: added bundle version + copyright to the app
--   Info.plist (shown in Finder Get Info) and re-signed; no
--   functional change to the script.
--
-- New in 1.3.0: results (.pixel + surround) and the source layer are grouped
--   under the source layer name (matches PixProShadow 7.2.0).
--
-- Creates a smooth full-360° glow/bubble surround effect around
-- a selected layer in Pixelmator Pro. Works with text layers,
-- shape layers, and image layers.
--
-- METHOD
-- A Gaussian blur is applied to the pixel source layer before
-- duplication. The blurred, colour-filled copies are then offset
-- radially in every direction (full circle) and stacked by depth,
-- producing smooth overlapping edges that merge into a bubble shape.
--
-- INPUTS
--   • Start / end colours   — picked via macOS color picker (eyedropper)
--   • Depth                 — radial extent in pixels, mm, or math
--   • Blur radius           — Gaussian blur in pixels (e.g. 15)
--
-- Steps (ray count) are auto-calculated from depth:
--   steps = round(depth × π/2), clamped 8–36
--   depth=10 → 16 steps   depth=20 → 31 steps   depth=30+ → 36
--
-- Rings: 3 rings per direction. Blur is applied once to the pixel
--   source and inherited by all copies — not reapplied per copy.
--   Total layers = 3 × steps.  depth=20 → 93 layers.  depth=30 → 108.
--
-- LAYER HANDLING
--   ALL TYPES     Original is duplicated and converted to pixels.
--                 The real original stays in the document, unchanged.
--   After processing (top to bottom):
--     <name>.pixel    — pixel copy of original, on top
--     <name> surround — merged glow layer below it
--     <name>          — real original, untouched, below surround
--
-- DEPTH FIELD accepts plain numbers, millimetres, or math:
--   25   •   5mm   •   72/25.4*5   •   5mm+10
--
-- COLOUR INPUT accepts R,G,B decimal or hex (with or without #):
--   246,38,8   •   F6260E   •   #F6260E
--
-- Defaults saved to ~/.textsurround_defaults.plist
-- ============================================================

property debugMode : false

-- ============================================================
-- WHICH PIXELMATOR?  (added 2026-08-10)
-- Since the Creator Studio rebrand there are two installs:
--   com.apple.pixelmator             Pixelmator Pro Creator Studio (4.x)
--   com.pixelmatorteam.pixelmator.x  Pixelmator Pro (3.x)
-- `tell application "Pixelmator Pro"` binds to a fixed path at COMPILE time,
-- so a document open in the other build looks like no document at all.
-- pixTarget() picks at run time: frontmost build first, then any running
-- build that has a document open.
-- ============================================================
property kPixIDs : {"com.apple.pixelmator", "com.pixelmatorteam.pixelmator.x"}

property scriptVersion : "1.7.3"

-- ============================================================
-- UPDATE CHECK (reports only, never downloads)
-- ============================================================
-- Asks GitHub for the newest published tag and adds a line to the prompt when
-- this build is behind. It never downloads or replaces anything: a running
-- bundle cannot safely overwrite its own files, and getting that wrong costs
-- the app.
--
-- Checked once a day at most and capped at three seconds, so a slow or absent
-- network barely shows. The tag and the day it was fetched are kept in the
-- same defaults file as the settings.
--
-- The JSON is picked apart with grep and cut rather than a parser: a stranger's
-- Mac is not guaranteed to have python3, and the tag is the only field wanted.
property kSlug : "pixprosurround"
property kDefaults : "$HOME/.textsurround_defaults"

on versionParts(v)
	set out to {}
	set AppleScript's text item delimiters to "."
	set pieces to text items of v
	set AppleScript's text item delimiters to ""
	repeat with piece in pieces
		set digits to ""
		repeat with c in (characters of (piece as text))
			if c is in "0123456789" then set digits to digits & c
		end repeat
		if digits is "" then set digits to "0"
		set end of out to digits as integer
	end repeat
	return out
end versionParts

on isNewer(tag, mine)
	-- Compared as integers, so 3.10.0 comes out above 3.9.0 rather than below.
	set a to my versionParts(tag)
	set b to my versionParts(mine)
	repeat with i from 1 to 3
		set x to 0
		set y to 0
		if i ≤ (count a) then set x to item i of a
		if i ≤ (count b) then set y to item i of b
		if x > y then return true
		if x < y then return false
	end repeat
	return false
end isNewer

on latestTag()
	set today to do shell script "/bin/date +%Y-%m-%d"
	set lastDay to ""
	try
		set lastDay to do shell script "defaults read " & kDefaults & " updateCheckedOn 2>/dev/null"
	end try
	if lastDay is today then
		try
			return do shell script "defaults read " & kDefaults & " updateLatestTag 2>/dev/null"
		end try
		return ""
	end if
	try
		set tag to do shell script "/usr/bin/curl -sL --max-time 3 -H \"Accept: application/vnd.github+json\" https://api.github.com/repos/spurious-cox/" & kSlug & "/releases/latest | /usr/bin/grep -o '\"tag_name\": *\"[^\"]*\"' | /usr/bin/head -1 | /usr/bin/cut -d'\"' -f4"
		do shell script "defaults write " & kDefaults & " updateLatestTag " & quoted form of tag
		do shell script "defaults write " & kDefaults & " updateCheckedOn " & quoted form of today
		return tag
	on error
		return ""
	end try
end latestTag

on updateNotice(mine)
	set tag to my latestTag()
	if tag is "" then return ""
	if not (my isNewer(tag, mine)) then return ""
	set t to tag
	if t starts with "v" then set t to text 2 thru -1 of t
	return return & return & "Update available: " & t & "  —  brew upgrade --cask " & kSlug
end updateNotice


property pixApp : ""

-- ============================================================
-- READ ME
-- The README is copied into this applet's OWN Contents/Resources at build
-- time and found with `path to resource`, so it travels inside the bundle.
-- Nothing here depends on ~/My_Applications, or on any other external path:
-- move or copy the app anywhere and the Read Me button still works.
-- ============================================================
on showReadMe()
	try
		set rmRef to (path to resource "PixProSurround-README.txt")
		do shell script "open -e " & quoted form of (POSIX path of rmRef)
	on error
		tell me to activate
		display dialog "The Read Me is missing from the app bundle." buttons {"OK"} default button "OK"
	end try
end showReadMe


on pixTarget()
	set rawPaths to {}
	try
		set psOut to do shell script "/bin/ps -Axo args= | /usr/bin/grep '/Contents/MacOS/Pixelmator' | /usr/bin/grep -v grep | /usr/bin/sed 's|/Contents/MacOS/.*||' | /usr/bin/sort -u"
		-- `do shell script` separates lines with RETURN, not linefeed. Split on
		-- the wrong one and every path arrives glued into a single string.
		set AppleScript's text item delimiters to return
		set rawPaths to text items of psOut
		set AppleScript's text item delimiters to ""
	end try

	-- Keep only genuine Pixelmator Pro builds, identified by the bundle id in
	-- each app's OWN Info.plist. Nothing here depends on what the app is
	-- called or where it lives, so this works on any Mac: renamed bundles,
	-- App Store or Setapp copies, apps in ~/Applications, all fine. It also
	-- excludes the classic Pixelmator (com.pixelmatorteam.pixelmator), whose
	-- dictionary is different and which would fail halfway through.
	set candidates to {}
	repeat with rp in rawPaths
		set p to rp as text
		if p is not "" then
			try
				set theID to do shell script "/usr/bin/defaults read " & quoted form of (p & "/Contents/Info") & " CFBundleIdentifier"
				if theID is in kPixIDs then set end of candidates to p
			end try
		end if
	end repeat
	if candidates is {} then return ""

	-- Which of them, if any, is frontmost. The frontmost process's pid maps
	-- back to its bundle path through ps.
	set frontPath to ""
	try
		-- Bounded: asking System Events which app is frontmost needs Automation
		-- permission, and on a first run that call sits there waiting for a
		-- consent prompt. If the prompt does not appear — and for a freshly
		-- built applet it may not — the app hangs with no window and nothing
		-- to click. Five seconds, then carry on: the frontmost check only
		-- orders the candidates, it does not find them.
		with timeout of 5 seconds
			tell application "System Events"
				set fpid to unix id of (first application process whose frontmost is true)
			end tell
		end timeout
		set frontPath to do shell script "/bin/ps -p " & fpid & " -o args= | /usr/bin/sed 's|/Contents/MacOS/.*||'"
	end try

	set ordered to {}
	repeat with c in candidates
		set cc to c as text
		if cc is equal to frontPath then set end of ordered to cc
	end repeat
	repeat with c in candidates
		set cc to c as text
		if cc is not equal to frontPath then set end of ordered to cc
	end repeat

	repeat with c in ordered
		set cc to c as text
		try
			using terms from application "Pixelmator Pro"
				tell application cc
					if (count of documents) > 0 then return cc
				end tell
			end using terms from
		end try
	end repeat
	return item 1 of ordered
end pixTarget


if debugMode then
	do shell script "echo '' > ~/Desktop/ts_debug.txt"
	set startTime to do shell script "date '+%Y-%m-%d %H:%M:%S'"
	my tsLog("=== PixProSurround started at " & startTime & " ===")
end if

-- ============================================================
-- LOAD SAVED DEFAULTS
-- ============================================================
set defaultDepth to "20"
set defaultBlur to "15"
set defaultStartRGB to "0,0,80"
set defaultEndRGB to "80,0,0"

try
	set defaultDepth to do shell script "defaults read $HOME/.textsurround_defaults depth 2>/dev/null"
end try
try
	set defaultBlur to do shell script "defaults read $HOME/.textsurround_defaults blur 2>/dev/null"
end try
try
	set defaultStartRGB to do shell script "defaults read $HOME/.textsurround_defaults startRGB 2>/dev/null"
end try
try
	set defaultEndRGB to do shell script "defaults read $HOME/.textsurround_defaults endRGB 2>/dev/null"
end try

-- ============================================================
-- PICK THE PIXELMATOR BUILD (see pixTarget above)
-- ============================================================
set pixApp to pixTarget()
if pixApp is "" then
	tell me to activate
	display dialog "Pixelmator Pro is not running. Open Pixelmator Pro and a document, select a layer, and try again." buttons {"OK"} default button "OK" with title "PixProSurround"
	error number -128
end if


using terms from application "Pixelmator Pro"
tell application pixApp
	activate
	tell front document
		
		if not (count selected layers) = 1 then
			display alert "Make sure a single layer is selected."
		else
			
			-- ── Record original layer info ─────────────────────────────────
			set originalLayerName to name of current layer
			set originalLayerIndex to index of current layer
			set {coordX, coordY} to position of current layer
			set layerKind to (class of current layer) as text
			set isTextLayer to layerKind = "text layer"
			set isShapeLayer to layerKind = "shape layer"
			set pixelLayerIndex to originalLayerIndex
			set preservedOriginalIndex to -1
			my tsLog("Layer: " & originalLayerName & " index=" & originalLayerIndex & " kind=" & layerKind)
			my tsLog("Position: " & (coordX as text) & "," & (coordY as text))
			
			-- ── Get document DPI ──────────────────────────────────────────
			set docDPI to 72
			try
				set docDPI to resolution of front document
			end try
			my tsLog("DPI: " & (docDPI as text))
			
			-- ════════════════════════════════════════════════════════════
			-- PIXEL COPY: Duplicate original and convert to pixels.
			-- Works for all layer types (text, shape, image). The duplicate
			-- lands AT originalLayerIndex; the real original shifts to +1.
			-- Converting to pixels gives the true rendered bounding box
			-- top-left as the layer position. The real original is NEVER
			-- modified or deleted — it stays in the document below the result.
			-- ════════════════════════════════════════════════════════════
			my tsLog("Pixel copy: duplicating original at index " & originalLayerIndex)
			duplicate layer originalLayerIndex
			set pixelLayerIndex to originalLayerIndex
			tell layer pixelLayerIndex to convert into pixels
			set isTextLayer to false
			set isShapeLayer to false
			set {coordX, coordY} to position of layer pixelLayerIndex
			my tsLog("Pixel copy at " & pixelLayerIndex & ", original preserved at " & (originalLayerIndex + 1))
			my tsLog("Pixel copy position: " & (coordX as text) & "," & (coordY as text))
			
			set pixelX to coordX
			set pixelY to coordY
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 2: Prompt for colours.
			-- ════════════════════════════════════════════════════════════
			-- Color picker opens twice: START colour first, then END colour.
			repeat
				set rmChoice to button returned of (display dialog "Pick TWO colours for the surround gradient:" & return & ¬
					"  1 → START colour  (innermost)" & return & ¬
					"  2 → END colour    (outermost)" & return & return & ¬
					"The color picker opens twice." & return & ¬
					¬
						"Use the eyedropper to sample any colour on screen." & my updateNotice(scriptVersion) buttons {"Read Me", "Open Color Picker"} default button "Open Color Picker")
				if rmChoice is not "Read Me" then exit repeat
				my showReadMe()
			end repeat
			set startColorDefault to my parseRGB(defaultStartRGB)
			set shadowColor1 to choose color default color startColorDefault
			set endColorDefault to my parseRGB(defaultEndRGB)
			set shadowColor2 to choose color default color endColorDefault
			set saveStartRGB to my colorToRGBString(shadowColor1)
			set saveEndRGB to my colorToRGBString(shadowColor2)
			my tsLog("Colours picked: start=" & saveStartRGB & " end=" & saveEndRGB)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 3: Prompt for depth and blur radius.
			-- Format: depth / blur
			-- Uses LAST slash as separator so depth can contain "/" (math).
			-- ════════════════════════════════════════════════════════════
			set depthBlurDefault to defaultDepth & " / " & defaultBlur
			set depthBlurInput to text returned of ¬
				(display dialog "Enter depth and blur radius:" & return & ¬
					"Format: depth / blur" & return & ¬
					"Depth: pixels, mm (e.g. 5mm), or math (e.g. 72/25.4*5)" & return & ¬
					¬
						"Blur:  Gaussian blur radius in pixels (e.g. 15)" default answer depthBlurDefault)
			
			-- Strip spaces
			set AppleScript's text item delimiters to " "
			set depthBlurInput to text items of depthBlurInput
			set AppleScript's text item delimiters to ""
			set depthBlurInput to depthBlurInput as text
			
			-- Find last slash — depth before it, blur after it
			set lastSlash to 0
			repeat with i from 1 to (count characters of depthBlurInput)
				if character i of depthBlurInput is "/" then
					set lastSlash to i
				end if
			end repeat
			
			if lastSlash = 0 then
				display alert "Invalid input — expected: depth / blur"
				return
			end if
			
			set rawDepth to text 1 thru (lastSlash - 1) of depthBlurInput
			set rawBlur to text (lastSlash + 1) thru -1 of depthBlurInput
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 4: Evaluate depth expression via Python 3.
			-- ════════════════════════════════════════════════════════════
			set stripeThickness to defaultDepth as number
			try
				set depthScript to "import re; dpi=" & (docDPI as text) & "; expr='" & rawDepth & "'; expr=re.sub(r'([0-9.]+)mm', lambda m: str(float(m.group(1))*dpi/25.4), expr); print(int(round(eval(expr))))"
				set stripeThickness to (do shell script "python3 -c " & quoted form of depthScript) as number
			on error errMsg
				my tsLog("Depth eval failed (" & errMsg & "), using default")
			end try
			if stripeThickness < 1 then set stripeThickness to 1
			
			-- Parse blur radius (plain integer)
			set blurRadius to 15
			try
				set blurRadius to rawBlur as number
			on error
				my tsLog("Blur parse failed, using default 15")
			end try
			if blurRadius < 1 then set blurRadius to 1
			my tsLog("Depth=" & stripeThickness & " Blur=" & blurRadius)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 5: Create a blurred working copy for ring duplication.
			-- The original pixel source is NOT touched — it appears on top
			-- at the end with its original appearance (no blur, no fill).
			-- The blur copy is used as the base for all ring duplicates;
			-- it is deleted after the merge.
			-- ════════════════════════════════════════════════════════════
			duplicate layer pixelLayerIndex
			-- Blur copy lands at pixelLayerIndex; original shifts to +1
			set blurSourceIndex to pixelLayerIndex
			tell layer blurSourceIndex
				make new gaussian effect at the beginning of effects with properties {radius:blurRadius as real}
			end tell
			set pixelLayerIndex to pixelLayerIndex + 1
			if preservedOriginalIndex > -1 then set preservedOriginalIndex to preservedOriginalIndex + 1
			my tsLog("Step 5: blur copy at " & blurSourceIndex & ", original at " & pixelLayerIndex)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 6: Save defaults.
			-- ════════════════════════════════════════════════════════════
			do shell script "defaults write $HOME/.textsurround_defaults depth " & stripeThickness
			do shell script "defaults write $HOME/.textsurround_defaults blur " & blurRadius
			do shell script "defaults write $HOME/.textsurround_defaults startRGB " & quoted form of saveStartRGB
			do shell script "defaults write $HOME/.textsurround_defaults endRGB " & quoted form of saveEndRGB
			my tsLog("Defaults saved")
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 7: Build colour list and compute auto steps.
			-- ringLevels rings per ray; blur copy fills gaps between rings.
			-- 3 rings. Total shadow layers = ringLevels × steps.
			-- Steps auto-calculated: round(depth × π/2), clamped 8–36.
			-- ════════════════════════════════════════════════════════════
			set ringLevels to 3
			-- Colours for ring copies only: beginRGB (innermost) → endRGB (outermost).
			-- The pixel source is NOT recoloured — it keeps its original appearance.
			set shadowColorList to my interpolateColors(shadowColor1, shadowColor2, ringLevels)
			
			set chosenNumSteps to round (stripeThickness * 3.14159265 / 2)
			if chosenNumSteps < 8 then set chosenNumSteps to 8
			if chosenNumSteps > 36 then set chosenNumSteps to 36
			set totalShadowLayers to chosenNumSteps * ringLevels
			my tsLog("Steps=" & chosenNumSteps & " rings=" & ringLevels & " total shadow layers=" & totalShadowLayers)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 8: Build the surround stack.
			-- All ring copies are duplicated from blurSourceIndex (the blur
			-- working copy). pixelLayerIndex tracks the original (unblurred)
			-- pixel source one position below the blur copy throughout.
			-- Full 360°: angle_j = (j-1)/steps × 360, endpoint not repeated.
			-- Inner loop: ringLevels rings per ray, offsets evenly spaced
			-- from depth/ringLevels to depth.
			-- ════════════════════════════════════════════════════════════
			my tsLog("Step 8: building surround stack")
			set shadowStackBase to blurSourceIndex
			set currentOriginalIndex to blurSourceIndex
			
			repeat with j from 1 to chosenNumSteps
				set angle_j to ((j - 1) / chosenNumSteps) * 360
				set angleRad_j to angle_j * (3.14159265 / 180)
				set dirX_j to (my cosine(angleRad_j)) * -1
				set dirY_j to my sine(angleRad_j)
				
				repeat with i from 1 to ringLevels
					set scaledOffset to (i / ringLevels) * stripeThickness
					duplicate layer currentOriginalIndex
					-- item i: beginRGB (innermost) → endRGB (outermost)
					set fill color of styles of layer currentOriginalIndex to item i of shadowColorList
					set position of layer currentOriginalIndex to ¬
						{coordX + (dirX_j * scaledOffset), coordY + (dirY_j * scaledOffset)}
					set currentOriginalIndex to currentOriginalIndex + 1
					set pixelLayerIndex to pixelLayerIndex + 1
					if preservedOriginalIndex > -1 then
						set preservedOriginalIndex to preservedOriginalIndex + 1
					end if
				end repeat
				if j mod 5 = 0 then my tsLog("Step 8: ray " & j & " of " & chosenNumSteps & " done")
			end repeat
			my tsLog("Step 8 done: pixelLayerIndex=" & pixelLayerIndex)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 9: Merge the surround stack, then delete blur copy.
			-- Ring copies: shadowStackBase .. shadowStackBase+total-1.
			-- Blur copy: shadowStackBase+totalShadowLayers  (excluded from merge).
			-- Original pixel source: shadowStackBase+totalShadowLayers+1.
			-- After merging (total-1) layers removed:
			--   blur copy → shadowStackBase+1, original → shadowStackBase+2.
			-- After deleting blur copy: original → shadowStackBase+1.
			-- Merged layer position is kept as-is (Pixelmator's bounding box is correct).
			-- ════════════════════════════════════════════════════════════
			set stackTop to shadowStackBase
			set stackBottom to shadowStackBase + totalShadowLayers - 1
			
			my tsLog("Step 9: merging layers " & stackTop & " to " & stackBottom)
			set layersToMerge to {}
			repeat with k from stackTop to stackBottom
				set end of layersToMerge to layer k
			end repeat
			my tsLog("Merging " & (count layersToMerge) & " layers")
			
			set mergedLayer to merge layers layersToMerge
			set {px, py} to position of mergedLayer
			my tsLog("Merge done, raw pos=" & (px as text) & "," & (py as text))
			
			-- Merged layer position kept as-is; Pixelmator's bounding box is correct.
			set name of mergedLayer to originalLayerName & " surround"
			my tsLog("Surround position kept at raw merge pos: " & (px as text) & "," & (py as text))
			
			-- totalShadowLayers merged to 1 → (totalShadowLayers-1) removed
			set pixelLayerIndex to pixelLayerIndex - (totalShadowLayers - 1)
			if preservedOriginalIndex > -1 then
				set preservedOriginalIndex to preservedOriginalIndex - (totalShadowLayers - 1)
			end if
			my tsLog("Post-merge pixelLayerIndex=" & pixelLayerIndex)
			
			-- Delete the blur working copy (now at shadowStackBase+1).
			-- Original pixel source shifts to shadowStackBase+1 after delete.
			delete layer (shadowStackBase + 1)
			set pixelLayerIndex to pixelLayerIndex - 1
			if preservedOriginalIndex > -1 then set preservedOriginalIndex to preservedOriginalIndex - 1
			my tsLog("Blur copy deleted, original at " & pixelLayerIndex)
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 10: Rename pixel source and place it just above surround.
			-- We move to before mergedLayer (not layer 1) so we only affect
			-- the two layers we created and leave all others in place.
			-- Only these two layers get their visibility set; everything else
			-- stays exactly as the user left it.
			-- ════════════════════════════════════════════════════════════
			set pixelSourceRef to layer pixelLayerIndex
			set name of pixelSourceRef to originalLayerName & ".pixel"
			move pixelSourceRef to before mergedLayer
			set visible of pixelSourceRef to true
			set visible of mergedLayer to true
			my tsLog("Pixel source placed just above surround; both set visible")
			
			-- ════════════════════════════════════════════════════════════
			-- STEP 11: Group the result + source layers under the source name.
			-- ════════════════════════════════════════════════════════════
			set theGroup to make group from {pixelSourceRef, mergedLayer, layer originalLayerName}
			set name of theGroup to originalLayerName
			my tsLog("Step 11 done: grouped as " & originalLayerName)
			
		end if
	end tell
end tell
end using terms from
if debugMode then
	set endTime to do shell script "date '+%Y-%m-%d %H:%M:%S'"
	my tsLog("=== PixProSurround complete at " & endTime & " ===")
end if

-- ============================================================
-- HELPER HANDLERS
-- ============================================================

-- tsLog: appends a line to ~/Desktop/ts_debug.txt
on tsLog(msg)
	if debugMode then do shell script "echo " & quoted form of msg & " >> ~/Desktop/ts_debug.txt"
end tsLog

-- colorToRGBString: converts {0-65535} colour list to "R,G,B" string (0-255).
on colorToRGBString(c)
	set r to round ((item 1 of c) / 257)
	set g to round ((item 2 of c) / 257)
	set b to round ((item 3 of c) / 257)
	return (r as text) & "," & (g as text) & "," & (b as text)
end colorToRGBString

-- parseRGB: converts colour string to Pixelmator {0-65535} list.
-- Accepts R,G,B decimal (246,38,8) or hex with or without # (F6260E).
-- Returns {0,0,0} on parse error.
on parseRGB(colorString)
	set s to colorString
	if length of s > 0 and character 1 of s is "#" then
		set s to text 2 thru -1 of s
	end if
	set hasComma to false
	repeat with i from 1 to (count characters of s)
		if character i of s is "," then
			set hasComma to true
			exit repeat
		end if
	end repeat
	if hasComma then
		try
			set oldDelimiters to AppleScript's text item delimiters
			set AppleScript's text item delimiters to ","
			set parts to text items of s
			set AppleScript's text item delimiters to oldDelimiters
			set r to ((item 1 of parts) as number) * 257
			set g to ((item 2 of parts) as number) * 257
			set b to ((item 3 of parts) as number) * 257
			return {r, g, b}
		on error
			my tsLog("parseRGB: failed decimal '" & colorString & "' — black")
			return {0, 0, 0}
		end try
	else
		try
			set hexResult to do shell script "python3 -c 'h=\"" & s & "\"; print(int(h[0:2],16), int(h[2:4],16), int(h[4:6],16))'"
			set oldDelimiters to AppleScript's text item delimiters
			set AppleScript's text item delimiters to " "
			set hexParts to text items of hexResult
			set AppleScript's text item delimiters to oldDelimiters
			set r to ((item 1 of hexParts) as number) * 257
			set g to ((item 2 of hexParts) as number) * 257
			set b to ((item 3 of hexParts) as number) * 257
			return {r, g, b}
		on error
			my tsLog("parseRGB: failed hex '" & colorString & "' — black")
			return {0, 0, 0}
		end try
	end if
end parseRGB

-- interpolateColors: returns n colours interpolated between c1 and c2.
-- item 1 = c1 (innermost), item n = c2 (outermost).
on interpolateColors(c1, c2, n)
	set colorList to {}
	repeat with i from 1 to n
		if n > 1 then
			set t to (i - 1) / (n - 1)
		else
			set t to 0
		end if
		set r to round ((item 1 of c1) + t * ((item 1 of c2) - (item 1 of c1)))
		set g to round ((item 2 of c1) + t * ((item 2 of c2) - (item 2 of c1)))
		set b to round ((item 3 of c1) + t * ((item 3 of c2) - (item 3 of c1)))
		set colorList to colorList & {{r, g, b}}
	end repeat
	return colorList
end interpolateColors

-- cosine: Taylor series (AppleScript has no built-in trig).
on cosine(x)
	set pi to 3.14159265359
	set twoPi to 2 * pi
	set x to x - (twoPi * (round (x / twoPi)))
	set x2 to x * x
	return 1 - (x2 / 2) + (x2 * x2 / 24) - (x2 * x2 * x2 / 720)
end cosine

-- sine: Taylor series (AppleScript has no built-in trig).
on sine(x)
	set pi to 3.14159265359
	set twoPi to 2 * pi
	set x to x - (twoPi * (round (x / twoPi)))
	set x3 to x * x * x
	return x - (x3 / 6) + (x3 * x * x / 120) - (x3 * x * x * x * x / 5040)
end sine