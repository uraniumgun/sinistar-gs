[string] $dest = "E:\"
Write-Host "Copying image\sinistargs.2mg to" $dest
copy -path "image\sinistargs.2mg" -destination $dest
