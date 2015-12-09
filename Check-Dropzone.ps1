<#
.Synopsis
   This script will check for new ZIP package in dropzone.
   This can be added as the first step of deployment pipeline.
   If no package is found, it will result in error as it should stop the deployment.
.DESCRIPTION
   The script will check in the dropzone for the newest package and move any older packages to archive if there is any.
   The archive directory is the parent of the dropzone.
.EXAMPLE
   .\Check-Dropzone.ps1 "[dropzone location]"
#>
[CmdletBinding()]
Param
(
    # Location of package
    [Parameter(Mandatory=$true,
               ValueFromPipelineByPropertyName=$true,
               Position=0)]
    [string]
    $Pkgpath
)

if (!(Test-Path $Pkgpath -PathType Container)){
    throw "The dropzone path does not exist!"
}

if (!(Test-Path $Pkgpath\*.zip -PathType Leaf)){
    throw "There is no new package in dropzone."
}

$pkgcount = (Get-ChildItem $Pkgpath -filter "*.zip").Count

if ($pkgcount -ge 2){
   Write-Verbose "More than one packages are found. Moving older items to archive..."

   $files = gci $Pkgpath | sort LastWriteTime | select -first ($pkgcount-1)

   foreach ($file in $files)
   {
        $destinationFolder = Split-Path -Parent $file.Directory.FullName

        Write-Debug $file.FullName
        Write-Debug $destinationFolder

        Move-Item $file.FullName $destinationFolder
   }
}

Write-Verbose "Dropzone check finished."
