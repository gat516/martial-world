# Draws nameplate_band.png, the namecard band behind a player's name
# (assets/Nameplate.rbxmx, docs/systems/nameplates.md).
#
# Written in PowerShell + System.Drawing (GDI+) rather than draw_ui.py because it
# was drawn on a Windows machine with no Python; same method: drawn at 4x (SS)
# and downsampled. Run:  powershell -ExecutionPolicy Bypass -File art/ui/draw_nameplate.ps1
#
# The band, 704x128: a translucent dark-jade ink wash that thins out softly at both ends
# with a faint wobble, a gold hairline above and below it fading toward the ends,
# and a small gold lozenge closing each end at mid height. Shown with
# ScaleType Stretch at about its own aspect (the BillboardGui keeps width and
# height in one ratio), so nothing is 9-sliced. Lines are thick enough to stay
# ~1.5px when the band is shown 24-40px tall.

Add-Type -AssemblyName System.Drawing

$SS = 4
$W = 704 * $SS
$H = 128 * $SS
$out = Join-Path $PSScriptRoot "nameplate_band.png"

$GOLD = [System.Drawing.Color]::FromArgb(255, 214, 172, 92)
$GOLD_HI = [System.Drawing.Color]::FromArgb(255, 250, 222, 150)
$GOLD_LO = [System.Drawing.Color]::FromArgb(255, 120, 82, 34)
$INK = [System.Drawing.Color]::FromArgb(255, 14, 20, 24)

function Smooth([double]$t) {
	if ($t -lt 0) { $t = 0 } elseif ($t -gt 1) { $t = 1 }
	return $t * $t * (3 - 2 * $t)
}

$big = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppPArgb)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Horizontal alpha profile as a ColorBlend: smoothstep in over `fade` of the
# width from `u0`, out toward `u1`.
function Fill-Row($y, $h, [int[]]$rgb, [double]$alpha, [double]$u0, [double]$u1, [double]$fade) {
	$n = 24
	$colors = New-Object 'System.Drawing.Color[]' ($n + 1)
	$pos = New-Object 'single[]' ($n + 1)
	for ($i = 0; $i -le $n; $i++) {
		$u = $i / $n
		$a = (Smooth (($u - $u0) / $fade)) * (Smooth (($u1 - $u) / $fade))
		$colors[$i] = [System.Drawing.Color]::FromArgb([int](255 * $alpha * $a), $rgb[0], $rgb[1], $rgb[2])
		$pos[$i] = [single]$u
	}
	$rect = New-Object System.Drawing.RectangleF(-1, $y, ($W + 2), $h)
	$brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::Black, [System.Drawing.Color]::Black, 0.0)
	$blend = New-Object System.Drawing.Drawing2D.ColorBlend($n + 1)
	$blend.Colors = $colors
	$blend.Positions = $pos
	$brush.InterpolationColors = $blend
	$g.FillRectangle($brush, $rect)
	$brush.Dispose()
}

# Ink wash: dark jade, lighter at the top, soft at top, bottom and both ends.
$top = @(34, 56, 50); $bot = @(10, 18, 17)
$y0 = $H * 0.12; $y1 = $H * 0.88
for ($y = 0; $y -lt $H; $y += $SS) {
	$v = ($y - $y0) / ($y1 - $y0)
	if ($v -lt -0.06 -or $v -gt 1.06) { continue }
	$va = (Smooth (($v + 0.06) / 0.16)) * (Smooth ((1.06 - $v) / 0.16))
	$t = [Math]::Max(0.0, [Math]::Min(1.0, [double]$v))
	$c = @(0, 1, 2 | ForEach-Object { [int]($top[$_] + ($bot[$_] - $top[$_]) * $t) })
	$yy = $y / $H
	$jl = 0.006 * [Math]::Sin($yy * 9)
	$jr = 0.006 * [Math]::Sin($yy * 11 + 1)
	Fill-Row $y $SS $c (0.8 * $va) (0.04 - $jl) (0.96 + $jr) 0.26
}

# Gold hairlines with a dark line under each, fading toward the ends.
foreach ($ly in @([int]($H * 0.12), [int]($H * 0.88))) {
	Fill-Row ($ly + 2 * $SS) (3 * $SS) @(0, 0, 0) 0.45 0.06 0.94 0.2
	Fill-Row ($ly - 2.5 * $SS) (5 * $SS) @(214, 172, 92) 1.0 0.06 0.94 0.2
	Fill-Row ($ly - 2.5 * $SS) (2 * $SS) @(250, 222, 150) 1.0 0.06 0.94 0.2
}

function Diamond([double]$cx, [double]$cy, [double]$r) {
	$pts = New-Object 'System.Drawing.PointF[]' 4
	$pts[0] = New-Object System.Drawing.PointF($cx, ($cy - $r))
	$pts[1] = New-Object System.Drawing.PointF(($cx + $r), $cy)
	$pts[2] = New-Object System.Drawing.PointF($cx, ($cy + $r))
	$pts[3] = New-Object System.Drawing.PointF(($cx - $r), $cy)
	return , $pts
}

function Fill-Diamond($color, [double]$cx, [double]$cy, [double]$r) {
	$b = New-Object System.Drawing.SolidBrush($color)
	$g.FillPolygon($b, (Diamond $cx $cy $r))
	$b.Dispose()
}

# End lozenges (draw_ui.lozenge) with a short gold tick toward the centre.
$cy = $H / 2
$r = $H * 0.17
foreach ($end in @(@(($W * 0.07), 1), @(($W * 0.93), -1))) {
	$cx = $end[0]; $dir = $end[1]
	Fill-Diamond ([System.Drawing.Color]::FromArgb(110, 0, 0, 0)) ($cx + 2 * $SS) ($cy + 3 * $SS) ($r + 3 * $SS)
	$pen = New-Object System.Drawing.Pen($GOLD, (4 * $SS))
	$g.DrawLine($pen, [single]$cx, [single]$cy, [single]($cx + $dir * $W * 0.05), [single]$cy)
	$pen.Dispose()
	Fill-Diamond $GOLD_LO $cx $cy $r
	$r2 = $r - $r * 0.24
	Fill-Diamond $GOLD $cx $cy $r2
	$r3 = $r2 * 0.55
	Fill-Diamond $INK $cx $cy $r3
	$r4 = $r3 * 0.4
	$b = New-Object System.Drawing.SolidBrush($GOLD_HI)
	$g.FillEllipse($b, [single]($cx - $r4), [single]($cy - $r4), [single](2 * $r4), [single](2 * $r4))
	$b.Dispose()
}
$g.Dispose()

$small = New-Object System.Drawing.Bitmap(($W / $SS), ($H / $SS), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sg = [System.Drawing.Graphics]::FromImage($small)
$sg.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$sg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$attr = New-Object System.Drawing.Imaging.ImageAttributes
$attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)
$sg.DrawImage($big, (New-Object System.Drawing.Rectangle(0, 0, ($W / $SS), ($H / $SS))), 0, 0, $W, $H, [System.Drawing.GraphicsUnit]::Pixel, $attr)
$sg.Dispose()
$small.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$small.Dispose(); $big.Dispose()
"wrote $out"
