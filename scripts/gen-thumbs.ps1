# Regenerate archive thumbnails from full-resolution brochure scans.
# Run from project root:  pwsh scripts\gen-thumbs.ps1
# Output: images\thumbs\pl-NN.jpg  (600px wide, JPEG q78)
# When adding new plates: append to the $plates array below.

$ErrorActionPreference = 'Stop'

# Ensure we're at project root (where index.html lives)
if (-not (Test-Path 'index.html')) {
    Write-Error 'Run from project root (index.html not found in current directory).'
    exit 1
}

New-Item -ItemType Directory -Force -Path 'images\thumbs' | Out-Null
Add-Type -AssemblyName System.Drawing

# Plate manifest: src (in images/) -> out (in images/thumbs/)
$plates = @(
    @{ src = 'signal-2026-05-26-195451.jpeg';     out = 'pl-01.jpg' }
    @{ src = 'signal-2026-05-26-195408_003.jpeg'; out = 'pl-02.jpg' }
    @{ src = 'signal-2026-05-26-195226.png';      out = 'pl-03.jpg' }
    @{ src = 'signal-2026-05-26-195408.jpeg';     out = 'pl-04.jpg' }
    @{ src = 'signal-2026-05-26-195408_002.jpeg'; out = 'pl-05.jpg' }
    @{ src = 'signal-2026-05-26-195408_004.jpeg'; out = 'pl-06.jpg' }
    @{ src = 'signal-2026-05-26-195408_005.jpeg'; out = 'pl-07.jpg' }
    @{ src = 'signal-2026-05-26-195408_006.jpeg'; out = 'pl-08.jpg' }
    @{ src = 'signal-2026-05-26-195408_007.jpeg'; out = 'pl-09.jpg' }
    @{ src = 'signal-2026-05-26-195408_008.jpeg'; out = 'pl-10.jpg' }
)

$targetWidth = 600
$quality = 78L

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter `
    ([System.Drawing.Imaging.Encoder]::Quality), $quality

$totalIn = 0; $totalOut = 0
foreach ($p in $plates) {
    $srcPath = Join-Path (Get-Location) "images\$($p.src)"
    $dstPath = Join-Path (Get-Location) "images\thumbs\$($p.out)"
    if (-not (Test-Path $srcPath)) {
        Write-Warning "missing source: $($p.src) — skipping"
        continue
    }
    $img = [System.Drawing.Image]::FromFile($srcPath)
    try {
        $ratio = $targetWidth / $img.Width
        $newH = [int]($img.Height * $ratio)
        $bmp = New-Object System.Drawing.Bitmap $targetWidth, $newH
        $bmp.SetResolution(72, 72)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.DrawImage($img, 0, 0, $targetWidth, $newH)
        $g.Dispose()
        $bmp.Save($dstPath, $jpegCodec, $encParams)
        $bmp.Dispose()
    } finally {
        $img.Dispose()
    }
    $inSize  = (Get-Item $srcPath).Length
    $outSize = (Get-Item $dstPath).Length
    $totalIn  += $inSize
    $totalOut += $outSize
    '{0}  {1,9:N0} -> {2,7:N0}  ({3}x{4})' -f $p.out, $inSize, $outSize, $targetWidth, $newH
}

''
'TOTAL: {0:N0} bytes -> {1:N0} bytes  ({2:N1}x reduction)' -f `
    $totalIn, $totalOut, ($totalIn / [Math]::Max($totalOut, 1))
