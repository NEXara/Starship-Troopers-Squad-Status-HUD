Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$bitmap = New-Object System.Drawing.Bitmap 256,256
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.SmoothingMode = 'AntiAlias'
$g.Clear([System.Drawing.Color]::Transparent)
$blue = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(28,97,192))
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$light = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(137,205,255))
$g.FillRectangle($blue,8,8,240,240)
foreach ($y in @(48,108,168)) {
  $g.FillEllipse($white,36,$y,28,28)
  $g.FillRectangle($white,82,($y+2),132,9)
  $g.FillRectangle($light,82,($y+18),104,10)
}
$bitmap.Save((Join-Path $root 'Squad.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$memory = New-Object System.IO.MemoryStream
$bitmap.Save($memory,[System.Drawing.Imaging.ImageFormat]::Png)
$bytes = $memory.ToArray()
$file = [System.IO.File]::Create((Join-Path $root 'Squad.ico'))
$writer = New-Object System.IO.BinaryWriter $file
$writer.Write([uint16]0); $writer.Write([uint16]1); $writer.Write([uint16]1)
$writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0); $writer.Write([byte]0)
$writer.Write([uint16]1); $writer.Write([uint16]32)
$writer.Write([uint32]$bytes.Length); $writer.Write([uint32]22); $writer.Write($bytes)
$writer.Dispose(); $memory.Dispose(); $g.Dispose(); $bitmap.Dispose()
$blue.Dispose(); $white.Dispose(); $light.Dispose()
