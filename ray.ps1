if ($args -ne $null) {
    Start-Process -FilePath "./tools/bin/Debug/net5.0/Tools.exe" -NoNewWindow -Wait -ArgumentList $args
} else {
    Start-Process -FilePath "./tools/bin/Debug/net5.0/Tools.exe" -NoNewWindow -Wait
}