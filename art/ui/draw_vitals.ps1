# Draws the bottom-centre vitals art in the style of the user's reference
# (user, 2026-10-23; docs/systems/ui.md, the bottom-centre stack):
#   vitals_mount.png  1600x200  Hud.Stack.Vitals.Mount: the gold-framed plate. A full-width
#                     body holds health (red gems on its ends, ten slanted segment
#                     dividers) and combat qi; a narrower tab under its middle holds the
#                     guard trough behind a red gem seal. Small gold lozenges sit on the
#                     frame's outer edges at both bar rows. Stretch at native aspect.
#   seat_mount.png    1600x200  Hud.Stack.SeatBars.Mount: the same plate with one
#                     cultivation track (breakthrough mark at BREAK, 80%) and the
#                     dantian in the tab.
#   name_plaque.png   1152x96   Hud.Stack.Vitals.NamePlaque: small lacquer plaque with a
#                     red gem on each pointed end and thin gold scrolls out to the sides.
#   realm_plaque.png  1536x112  Vitals.Crest and SeatBars.TitleCrest: the wider realm
#                     plaque, gold lozenges with dark centres and curl flourishes.
#   vitals_chip.png   128x128   Stack.Cooldowns.Dash/Strike: dark disc in a gold rim.
#   chip_shade.png    128x128   the chips' cooldown cover: a plain white disc (tinted dark).
# All Stretch at native aspect, nothing 9-sliced. The window boxes below are what the
# Studio layout copies, as scale. Written in PowerShell + System.Drawing (no Python on
# the machine it was drawn on); drawn at 4x (SS) and downsampled like draw_ui.py.
# Run:  powershell -ExecutionPolicy Bypass -File art/ui/draw_vitals.ps1
#
# Plate geometry (art px of the 1600x200 mounts):
#   body    44,10 - 1556,138      tab   400,138 - 1200,194   (chips sit in the left notch)
#   health  92,20 - 1508,80       qi    96,88 - 1504,128     guard 446,150 - 1154,180
#   track   92,22 - 1508,126 (seat; mark at x 1225)          dantian = guard
#   seal    800,165 r 24
# Plaque text areas: name x 300-852 y 20-76 of 1152x96; realm x 372-1164 y 22-90 of 1536x112.

Add-Type -AssemblyName System.Drawing

$SS = 4
$here = $PSScriptRoot

function C([int]$a, [int]$r, [int]$g, [int]$b) { [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }
$GOLD = C 255 214 172 92
$GOLD_HI = C 255 250 222 150
$GOLD_LO = C 255 110 74 30
$INK = C 255 14 12 10
$CLEAR = [System.Drawing.Color]::Transparent

function PF([double]$x, [double]$y) { New-Object System.Drawing.PointF([single]$x, [single]$y) }

function New-Canvas([int]$w, [int]$h) {
	$bmp = New-Object System.Drawing.Bitmap(($w * $SS), ($h * $SS), [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.Clear($CLEAR)
	$g.ScaleTransform($SS, $SS)
	return @{ bmp = $bmp; g = $g; w = $w; h = $h }
}

function Save-Canvas($cv, [string]$name) {
	$cv.g.Dispose()
	$w = $cv.w; $h = $cv.h
	$small = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$sg = [System.Drawing.Graphics]::FromImage($small)
	$sg.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$attr = New-Object System.Drawing.Imaging.ImageAttributes
	$attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
	$sg.DrawImage($cv.bmp, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), 0, 0, ($w * $SS), ($h * $SS), [System.Drawing.GraphicsUnit]::Pixel, $attr)
	$sg.Dispose()
	$out = Join-Path $here $name
	$small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
	$small.Dispose(); $cv.bmp.Dispose()
	"wrote $out"
}

function Pen($color, [double]$width) {
	$p = New-Object System.Drawing.Pen($color, [single]$width)
	$p.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter
	$p.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
	$p.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
	return $p
}

function Fill-Poly($g, $color, $pts) {
	$b = New-Object System.Drawing.SolidBrush($color)
	$g.FillPolygon($b, $pts)
	$b.Dispose()
}

function Diamond([double]$cx, [double]$cy, [double]$rx, [double]$ry) {
	$pts = New-Object 'System.Drawing.PointF[]' 4
	$pts[0] = PF $cx ($cy - $ry)
	$pts[1] = PF ($cx + $rx) $cy
	$pts[2] = PF $cx ($cy + $ry)
	$pts[3] = PF ($cx - $rx) $cy
	return , $pts
}

function Poly([double[]]$xy) {
	$n = $xy.Length / 2
	$pts = New-Object 'System.Drawing.PointF[]' $n
	for ($i = 0; $i -lt $n; $i++) { $pts[$i] = PF $xy[2 * $i] $xy[2 * $i + 1] }
	return , $pts
}

function VGrad($g, $pts, [double]$y0, [double]$y1, $top, $bot) {
	$rect = New-Object System.Drawing.RectangleF(0, [single]($y0 - 1), 10, [single]($y1 - $y0 + 2))
	$b = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bot, 90.0)
	$g.FillPolygon($b, $pts)
	$b.Dispose()
}

function Round-Rect([double]$x0, [double]$y0, [double]$x1, [double]$y1, [double]$r) {
	$p = New-Object System.Drawing.Drawing2D.GraphicsPath
	$d = 2 * $r
	$p.AddArc([single]$x0, [single]$y0, [single]$d, [single]$d, 180, 90)
	$p.AddArc([single]($x1 - $d), [single]$y0, [single]$d, [single]$d, 270, 90)
	$p.AddArc([single]($x1 - $d), [single]($y1 - $d), [single]$d, [single]$d, 0, 90)
	$p.AddArc([single]$x0, [single]($y1 - $d), [single]$d, [single]$d, 90, 90)
	$p.CloseFigure()
	return $p
}

# Punch a hole: everything inside goes fully transparent.
function Cut($g, [double]$x0, [double]$y0, [double]$x1, [double]$y1, [double]$r) {
	$path = Round-Rect $x0 $y0 $x1 $y1 $r
	$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
	$b = New-Object System.Drawing.SolidBrush($CLEAR)
	$g.FillPath($b, $path)
	$b.Dispose()
	$g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
	$path.Dispose()
}

# A gold rim around a window: dark lip, gold line, bright hairline on top.
function Window-Rim($g, [double]$x0, [double]$y0, [double]$x1, [double]$y1, [double]$r) {
	$p = Round-Rect ($x0 - 3) ($y0 - 3) ($x1 + 3) ($y1 + 3) ($r + 2)
	$pen = Pen $GOLD_LO 6; $g.DrawPath($pen, $p); $pen.Dispose()
	$pen = Pen $GOLD 3.5; $g.DrawPath($pen, $p); $pen.Dispose()
	$p.Dispose()
	$pen = Pen (C 150 255 236 180) 1.5
	$g.DrawLine($pen, [single]($x0 + $r), [single]($y0 - 4), [single]($x1 - $r), [single]($y0 - 4))
	$pen.Dispose()
}

# Spiral curl (a scroll end): from radius r0 inward over `turns`, starting at angle a0.
function Draw-Curl($g, $color, [double]$width, [double]$cx, [double]$cy, [double]$r0, [double]$turns, [double]$a0, [int]$dir) {
	$n = 40
	$pts = New-Object 'System.Drawing.PointF[]' ($n + 1)
	for ($i = 0; $i -le $n; $i++) {
		$t = $i / $n
		$r = $r0 * (1 - 0.78 * $t)
		$a = $a0 + $dir * $t * $turns * 2 * [Math]::PI
		$pts[$i] = PF ($cx + $r * [Math]::Cos($a)) ($cy + $r * [Math]::Sin($a))
	}
	$pen = Pen $color $width
	$g.DrawLines($pen, $pts)
	$pen.Dispose()
	return $pts[0]
}

# A faceted red gem in a gold diamond setting with a small white sparkle.
function Red-Gem($g, [double]$cx, [double]$cy, [double]$r) {
	Fill-Poly $g (C 130 0 0 0) (Diamond ($cx + 1.5) ($cy + 3) ($r + 3) ($r + 3))
	Fill-Poly $g $GOLD_LO (Diamond $cx $cy $r $r)
	Fill-Poly $g $GOLD (Diamond $cx $cy ($r * 0.86) ($r * 0.86))
	Fill-Poly $g $GOLD_HI (Poly @(($cx - $r * 0.86), $cy, $cx, ($cy - $r * 0.86), $cx, ($cy - $r * 0.7), ($cx - $r * 0.7), $cy))
	Fill-Poly $g $INK (Diamond $cx $cy ($r * 0.66) ($r * 0.66))
	$ri = $r * 0.56
	$rect = New-Object System.Drawing.RectangleF([single]($cx - $ri), [single]($cy - $ri), [single](2 * $ri), [single](2 * $ri))
	$b = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, (C 255 246 84 78), (C 255 120 8 20), 60.0)
	$g.FillPolygon($b, (Diamond $cx $cy $ri $ri))
	$b.Dispose()
	# facets: lit top-left, dark bottom-right
	Fill-Poly $g (C 90 255 200 190) (Poly @(($cx - $ri), $cy, $cx, ($cy - $ri), $cx, $cy))
	Fill-Poly $g (C 80 40 0 0) (Poly @(($cx + $ri), $cy, $cx, ($cy + $ri), $cx, $cy))
	# sparkle
	$s = $ri * 0.55; $k = $s * 0.22
	Fill-Poly $g (C 235 255 248 240) (Poly @($cx, ($cy - $s), ($cx + $k), ($cy - $k), ($cx + $s), $cy, ($cx + $k), ($cy + $k), $cx, ($cy + $s), ($cx - $k), ($cy + $k), ($cx - $s), $cy, ($cx - $k), ($cy - $k)))
}

# A gold lozenge with a dark centre and a gold pip.
function Gold-Lozenge($g, [double]$cx, [double]$cy, [double]$r) {
	Fill-Poly $g (C 120 0 0 0) (Diamond ($cx + 1) ($cy + 2.5) ($r + 2) ($r + 2))
	Fill-Poly $g $GOLD_LO (Diamond $cx $cy $r $r)
	Fill-Poly $g $GOLD (Diamond $cx $cy ($r * 0.84) ($r * 0.84))
	Fill-Poly $g $GOLD_HI (Poly @(($cx - $r * 0.84), $cy, $cx, ($cy - $r * 0.84), $cx, ($cy - $r * 0.6), ($cx - $r * 0.6), $cy))
	Fill-Poly $g $INK (Diamond $cx $cy ($r * 0.5) ($r * 0.5))
	Fill-Poly $g $GOLD_HI (Diamond $cx $cy ($r * 0.2) ($r * 0.2))
}

# A soft drop shadow under a polygon (stacked offset fills; GDI has no blur).
function Shadow($g, $pts, [int]$steps) {
	for ($i = $steps; $i -ge 1; $i--) {
		$m = New-Object System.Drawing.Drawing2D.Matrix
		$m.Translate(0, [single]($i * 1.2))
		$path = New-Object System.Drawing.Drawing2D.GraphicsPath
		$path.AddPolygon($pts)
		$path.Transform($m)
		$pen = Pen (C 34 0 0 0) ($i * 2.2)
		$g.DrawPath($pen, $path)
		$pen.Dispose()
		$b = New-Object System.Drawing.SolidBrush((C 34 0 0 0))
		$g.FillPath($b, $path)
		$b.Dispose(); $path.Dispose()
	}
}

# --- the plate shared by both mounts ---------------------------------------------
$BODY = @(44, 10, 1556, 138)
$TAB = @(400, 138, 1200, 194)
$HEALTH = @(92, 20, 1508, 80)
$QI = @(96, 88, 1504, 128)
$GUARD = @(446, 150, 1154, 180)
$TRACK = @(92, 22, 1508, 126)
$BREAK = 0.8

function Plate($g) {
	$c = 7 # chamfer at the outer corners
	$bx0, $by0, $bx1, $by1 = $BODY
	$tx0, $ty0, $tx1, $ty1 = $TAB
	$outline = Poly @(
		($bx0 + $c), $by0, ($bx1 - $c), $by0, $bx1, ($by0 + $c), $bx1, ($by1 - $c), ($bx1 - $c), $by1,
		$tx1, $by1, $tx1, ($ty1 - $c), ($tx1 - $c), $ty1, ($tx0 + $c), $ty1, $tx0, ($ty1 - $c), $tx0, $by1,
		($bx0 + $c), $by1, $bx0, ($by1 - $c), $bx0, ($by0 + $c))
	Shadow $g $outline 4
	VGrad $g $outline $by0 $ty1 (C 255 44 30 22) (C 255 13 10 9)
	# a faint warm wash along the top so it reads as lacquered wood, not flat black
	$wash = Poly @(($bx0 + 10), ($by0 + 4), ($bx1 - 10), ($by0 + 4), ($bx1 - 10), ($by0 + 26), ($bx0 + 10), ($by0 + 26))
	VGrad $g $wash ($by0 + 4) ($by0 + 26) (C 40 255 200 140) (C 0 255 200 140)
	$pen = Pen $GOLD_LO 8.5; $g.DrawPolygon($pen, $outline); $pen.Dispose()
	$pen = Pen $GOLD 5; $g.DrawPolygon($pen, $outline); $pen.Dispose()
	$pen = Pen (C 200 255 232 170) 1.6
	$g.DrawLine($pen, [single]($bx0 + $c), [single]($by0 - 1.2), [single]($bx1 - $c), [single]($by0 - 1.2))
	$pen.Dispose()
	# the inner hairline of the double frame
	$i = 8
	$inner = Poly @(
		($bx0 + $i), ($by0 + $i), ($bx1 - $i), ($by0 + $i), ($bx1 - $i), ($by1 - $i), ($tx1 - $i), ($by1 - $i),
		($tx1 - $i), ($ty1 - $i), ($tx0 + $i), ($ty1 - $i), ($tx0 + $i), ($by1 - $i), ($bx0 + $i), ($by1 - $i))
	$pen = Pen (C 150 214 172 92) 2.2; $g.DrawPolygon($pen, $inner); $pen.Dispose()
	# curls: a small scroll on each top corner and at the two steps down to the tab
	foreach ($side in @(-1, 1)) {
		$ex = if ($side -lt 0) { $bx0 } else { $bx1 }
		$dir = if ($side -lt 0) { 1 } else { -1 }
		$a0 = if ($side -lt 0) { [Math]::PI } else { 0 }
		[void](Draw-Curl $g $GOLD_LO 6 ($ex + $side * 2) ($by0 + 6) 13 1.15 $a0 $dir)
		[void](Draw-Curl $g $GOLD 3.6 ($ex + $side * 2) ($by0 + 6) 13 1.15 $a0 $dir)
		$sx = if ($side -lt 0) { $tx0 } else { $tx1 }
		[void](Draw-Curl $g $GOLD_LO 6 ($sx + $side * 2) ($by1 + 11) 10 1.15 ($a0 + [Math]::PI) (-$dir))
		[void](Draw-Curl $g $GOLD 3.6 ($sx + $side * 2) ($by1 + 11) 10 1.15 ($a0 + [Math]::PI) (-$dir))
	}
}

function Edge-Lozenges($g, [double[]]$rows) {
	foreach ($y in $rows) {
		Gold-Lozenge $g $BODY[0] $y 16
		Gold-Lozenge $g $BODY[2] $y 16
	}
}

# --- vitals_mount.png -------------------------------------------------------------
$cv = New-Canvas 1600 200; $g = $cv.g
Plate $g
Cut $g $HEALTH[0] $HEALTH[1] $HEALTH[2] $HEALTH[3] 7
Cut $g $QI[0] $QI[1] $QI[2] $QI[3] 7
Cut $g $GUARD[0] $GUARD[1] $GUARD[2] $GUARD[3] 6
# ten slanted segments over the health window
$hx0, $hy0, $hx1, $hy1 = $HEALTH
$g.SetClip((New-Object System.Drawing.RectangleF([single]$hx0, [single]$hy0, [single]($hx1 - $hx0), [single]($hy1 - $hy0))))
$seg = ($hx1 - $hx0) / 10
for ($k = 1; $k -lt 10; $k++) {
	$x = $hx0 + $seg * $k
	$pen = Pen (C 215 34 4 8) 5.5
	$g.DrawLine($pen, [single]($x - 11), [single]($hy1 + 2), [single]($x + 11), [single]($hy0 - 2)); $pen.Dispose()
	$pen = Pen (C 110 255 190 180) 2
	$g.DrawLine($pen, [single]($x - 11 + 4.5), [single]($hy1 + 2), [single]($x + 11 + 4.5), [single]($hy0 - 2)); $pen.Dispose()
}
$g.ResetClip()
Window-Rim $g $HEALTH[0] $HEALTH[1] $HEALTH[2] $HEALTH[3] 7
Window-Rim $g $QI[0] $QI[1] $QI[2] $QI[3] 7
Window-Rim $g $GUARD[0] $GUARD[1] $GUARD[2] $GUARD[3] 6
$hy = ($HEALTH[1] + $HEALTH[3]) / 2
$qy = ($QI[1] + $QI[3]) / 2
Edge-Lozenges $g @($hy, $qy)
Red-Gem $g $HEALTH[0] $hy 30
Red-Gem $g $HEALTH[2] $hy 30
Red-Gem $g 800 165 28
Save-Canvas $cv "vitals_mount.png"

# --- seat_mount.png ---------------------------------------------------------------
$cv = New-Canvas 1600 200; $g = $cv.g
Plate $g
Cut $g $TRACK[0] $TRACK[1] $TRACK[2] $TRACK[3] 8
Cut $g $GUARD[0] $GUARD[1] $GUARD[2] $GUARD[3] 6
Window-Rim $g $TRACK[0] $TRACK[1] $TRACK[2] $TRACK[3] 8
Window-Rim $g $GUARD[0] $GUARD[1] $GUARD[2] $GUARD[3] 6
$ty = ($TRACK[1] + $TRACK[3]) / 2
Edge-Lozenges $g @($ty)
Gold-Lozenge $g $TRACK[0] $ty 20
Gold-Lozenge $g $TRACK[2] $ty 20
# the breakthrough mark: a gilt divider with a red gem on the rim above it
$mx = $TRACK[0] + ($TRACK[2] - $TRACK[0]) * $BREAK
$pen = Pen $GOLD_LO 6; $g.DrawLine($pen, [single]$mx, [single]$TRACK[1], [single]$mx, [single]$TRACK[3]); $pen.Dispose()
$pen = Pen $GOLD 2.5; $g.DrawLine($pen, [single]$mx, [single]$TRACK[1], [single]$mx, [single]$TRACK[3]); $pen.Dispose()
Red-Gem $g $mx ($TRACK[1] - 2) 13
Save-Canvas $cv "seat_mount.png"

# --- plaques ------------------------------------------------------------------------
# A lacquer box with a gold double rim; `ends` = x of the pointed tips, box spans
# between them with its flat top and bottom from x0 to x1.
function Plaque-Box($g, [double]$tipL, [double]$x0, [double]$x1, [double]$tipR, [double]$y0, [double]$y1) {
	$cy = ($y0 + $y1) / 2
	$box = Poly @($tipL, $cy, $x0, $y0, $x1, $y0, $tipR, $cy, $x1, $y1, $x0, $y1)
	Shadow $g $box 3
	VGrad $g $box $y0 $y1 (C 255 58 30 18) (C 255 22 11 8)
	$pen = Pen $GOLD_LO 8; $g.DrawPolygon($pen, $box); $pen.Dispose()
	$pen = Pen $GOLD 4.6; $g.DrawPolygon($pen, $box); $pen.Dispose()
	$i = 8
	$inner = Poly @(($tipL + $i * 1.6), $cy, ($x0 + $i * 0.6), ($y0 + $i), ($x1 - $i * 0.6), ($y0 + $i), ($tipR - $i * 1.6), $cy, ($x1 - $i * 0.6), ($y1 - $i), ($x0 + $i * 0.6), ($y1 - $i))
	$pen = Pen (C 140 214 172 92) 2.2; $g.DrawPolygon($pen, $inner); $pen.Dispose()
	$pen = Pen (C 190 255 232 170) 1.5
	$g.DrawLine($pen, [single]($x0 + 2), [single]($y0 - 1), [single]($x1 - 2), [single]($y0 - 1)); $pen.Dispose()
}

# A thin gold scroll from the plaque's end out to `tip`: a curl near the end, then
# a fine line closing in a small spear lozenge.
function Flourish($g, [double]$from, [double]$tip, [double]$cy, [double]$curlR, [int]$side, [bool]$double) {
	foreach ($pass in @(@($GOLD_LO, 6.5), @($GOLD, 3.8))) {
		$pen = Pen $pass[0] ($pass[1] * 0.85)
		$g.DrawLine($pen, [single]$from, [single]$cy, [single]$tip, [single]$cy); $pen.Dispose()
		$ccx = $from + $side * ($curlR * 1.6)
		$dirUp = if ($side -lt 0) { 1 } else { -1 }
		[void](Draw-Curl $g $pass[0] $pass[1] $ccx ($cy - $curlR) $curlR 1.15 ([Math]::PI / 2) $dirUp)
		if ($double) {
			[void](Draw-Curl $g $pass[0] $pass[1] ($ccx + $side * $curlR * 1.1) ($cy + $curlR) $curlR 1.15 (-[Math]::PI / 2) (-$dirUp))
		}
	}
	Fill-Poly $g $GOLD_LO (Diamond $tip $cy 11 6)
	Fill-Poly $g $GOLD (Diamond $tip $cy 8 4)
}

# name_plaque.png 1152x96
$cv = New-Canvas 1152 96; $g = $cv.g
$cy = 48
Flourish $g 244 50 $cy 19 -1 $true
Flourish $g 908 1102 $cy 19 1 $true
Plaque-Box $g 262 292 860 890 14 82
Red-Gem $g 262 $cy 27
Red-Gem $g 890 $cy 27
Save-Canvas $cv "name_plaque.png"

# realm_plaque.png 1536x112
$cv = New-Canvas 1536 112; $g = $cv.g
$cy = 56
Flourish $g 306 96 $cy 23 -1 $true
Flourish $g 1230 1440 $cy 23 1 $true
Plaque-Box $g 326 350 1186 1210 14 98
Gold-Lozenge $g 340 $cy 33
Gold-Lozenge $g 1196 $cy 33
Save-Canvas $cv "realm_plaque.png"

# --- cooldown chips -----------------------------------------------------------------
$cv = New-Canvas 128 128; $g = $cv.g
$b = New-Object System.Drawing.SolidBrush((C 110 0 0 0)); $g.FillEllipse($b, 7, 9, 116, 116); $b.Dispose()
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddEllipse(8, 8, 112, 112)
$pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
$pgb.CenterColor = C 255 46 36 28
$pgb.CenterPoint = PF 56 48
$pgb.SurroundColors = [System.Drawing.Color[]]@((C 255 12 10 9))
$g.FillPath($pgb, $path); $pgb.Dispose(); $path.Dispose()
$pen = Pen $GOLD_LO 11; $g.DrawEllipse($pen, 9, 9, 110, 110); $pen.Dispose()
$pen = Pen $GOLD 6.5; $g.DrawEllipse($pen, 9, 9, 110, 110); $pen.Dispose()
$pen = Pen (C 200 255 236 180) 2; $g.DrawArc($pen, 10, 10, 108, 108, 200, 140); $pen.Dispose()
$pen = Pen (C 120 214 172 92) 2; $g.DrawEllipse($pen, 21, 21, 86, 86); $pen.Dispose()
Save-Canvas $cv "vitals_chip.png"

$cv = New-Canvas 128 128; $g = $cv.g
$b = New-Object System.Drawing.SolidBrush((C 255 255 255 255)); $g.FillEllipse($b, 12, 12, 104, 104); $b.Dispose()
Save-Canvas $cv "chip_shade.png"
