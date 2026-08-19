Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile('c:\website\flutter-project\assets\logo.png')
$ratio = $img.Width / $img.Height
$newHeight = [int]108
$newWidth = [int][math]::Round($ratio * $newHeight)
$bmp = New-Object System.Drawing.Bitmap($newWidth, $newHeight)
$graph = [System.Drawing.Graphics]::FromImage($bmp)
$graph.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graph.DrawImage($img, 0, 0, $newWidth, $newHeight)
$bmp.Save('c:\website\flutter-project\assets\logo_small.png', [System.Drawing.Imaging.ImageFormat]::Png)
$img.Dispose()
$bmp.Dispose()
$graph.Dispose()
