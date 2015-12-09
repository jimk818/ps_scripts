<#
.Synopsis
   This script is to be run as the first step of deployment pipeline.
   This will check dropzone for files, and if new drop exists, copy the package over to working directory.
   As for copy, robocopy will be used for its extra functions.
.DESCRIPTION
   Detailed information of each project will be obtained from the configuration file of the script.
.EXAMPLE
   .\Grab-ReleasePackage.ps1 -env Staging -dropzone '[dropzone location]'
.EXAMPLE
   .\Grab-ReleasePackage.ps1 -env Production -dropzone '[dropzone location]'
#>

[CmdletBinding()]
Param
(
    # The environment to deploy files to
    [Parameter(Mandatory=$true,
               Position=0)]
    [string]
    $env,

    # Location of dropzone
    [Parameter(Mandatory=$true,
               Position=1)]
    [string]
    $dropzone
)

$datetime=Get-Date -f yyyyMMdd_HHmmss

$scriptdir = "[designated script directory]"
$workingdir = "[designated working directory]"

$config = "$workingdir\_config\services_$env.txt"

$Apptobackup = ""
$AppsDeployed = ""

## Prepare working directory for deployment
$workingdir = "$workingdir\$env"
$emptydir = "$workingdir\_config\_emptydir"

## 1. Clear out temporary location to keep previously deployed files.
robocopy.exe $emptydir $workingdir\web_prev *.* /S /E /NC /NS /NP /r:2 /w:10 /MIR
## 2. Copy files from web to web_prev.
robocopy.exe $workingdir\web $workingdir\web_prev *.* /S /E /NC /NS /NP /r:2 /w:10 /MIR
## 3. Clear out web folder to receive new files.
robocopy.exe $emptydir $workingdir\web *.* /S /E /NC /NS /NP /r:2 /w:10 /MIR
## 4. Clear out database folder to receive new files.
robocopy.exe $emptydir $workingdir\database *.* /S /E /NC /NS /NP /r:2 /w:10 /MIR

$comps = Get-Content "$config"
foreach ($comp in $comps){
    if (!($comp.StartsWith("#")) -and !($comp -like '*(Database)*') -and ($comp -match '[A-Za-z]')) {
        $split = $comp.Split("{,}")

        $arg1 = $split[0]
        $arg2 = $split[1]
        $arg3 = $split[2]
        $arg4 = $split[3]

        $workingdir = "$workingdir\$env\web"

        $path = "$dropzone\$arg1"
        if (Test-Path $path) {
            $ascount = @(Get-ChildItem $path -filter "$arg1*").Count

            ## Copy files from dropzone to working dir if new drop is found.
            if ($ascount -gt 0) {
                ## Get the latest drop from each dropzone.
                $files = Get-ChildItem $path -Filter "$arg1*" | Sort-Object name | select -last 1

                ## Below will run only once per app for the latest drop.
                foreach ($file in $files){
                    $pkgpath = "$path\$file\$arg2"
                    if (Test-Path "$pkgpath"){
                        Write-Host "Found PKG: $pkgpath"
                        $AppsDeployed = $AppsDeployed + "`r`n" + "Deployed: $pkgpath"

                        ## Keep track of apps to be updated.
                        $Apptobackup = $Apptobackup + "`r`n" + $arg4 + "," + $arg3

                        if (!(Test-Path "$workingdir\$arg3")) {
                            mkdir "$workingdir\$arg3"
                        }
                        
                        robocopy.exe "$pkgpath" "$workingdir\$arg3" *.* /S /E /NC /NS /NP /r:2 /w:10
                        robocopy.exe "$path\Configurations\$env\$arg1" "$workingdir\$arg3" *.* /S /E /NC /NS /NP /r:2 /w:10
                    } ## end of if
                } ## end of foreach
            } ## end of if
        } ## end of if
    } ## end of if

    ## Prepare Database
    elseif (($comp -like '*(Database)*') -and ($comp -match '[A-Za-z]')) {
       $split = $comp.Split("{,}")

       $arg1 = $split[0]
       $arg2 = $split[1]

       $workingdir = "$workingdir\$env\database"
       $archivedir = "$workingdir\$env\database_archive"

       $path = "$dropzone\$arg1"
       if (Test-Path $path) {
            $dbcount = @(Get-ChildItem $path -filter "$arg1*").Count

            ## Copy files from dropzone to working dir if new drop is found.
            if ($dbcount -gt 0) {
                ## Get the latest drop from each dropzone.
                $files = Get-ChildItem $path -Filter "$arg1*" | Sort-Object name | select -last 1

                ## Below will run only once per app for the latest drop.
                foreach ($file in $files){
                    $pkgpath = "$path\$file"
                    if (Test-Path "$pkgpath"){
                        Write-Host "Found PKG: $pkgpath"
                        $AppsDeployed = $AppsDeployed + "`r`n" + "Deployed: $pkgpath"

                        if (!(Test-Path "$workingdir\$arg2\$arg1")) {
                            mkdir "$workingdir\$arg2\$arg1"
                        }
                        if (!(Test-Path "$archivedir\$datetime\$arg2\$arg1")) {
                            mkdir "$archivedir\$datetime\$arg2\$arg1"
                        }

                        robocopy.exe "$pkgpath" "$workingdir\$arg2\$arg1" *.* /S /E /NC /NS /NP /r:2 /w:10
                        robocopy.exe "$pkgpath" "$archivedir\$datetime\$arg2\$arg1" *.* /S /E /NC /NS /NP /r:2 /w:10
                        
                        ## Copy DB batch files to the same working directory from repository.
                        $DBbatchloc = "$workingdir\_config\DB_batch"
                        robocopy.exe "$DBbatchloc\$arg1" "$workingdir\$arg2\$arg1" "Deploy$env.bat" /S /E /NC /NS /NP /r:2 /w:10     
                        robocopy.exe "$DBbatchloc\$arg1" "$archivedir\$datetime\$arg2\$arg1" "Deploy$env.bat" /S /E /NC /NS /NP /r:2 /w:10   
                    } ## end of if
                } ## end of foreach
            } ## end of if
        } ## end of if
    } ## end of elseif
} ## end of foreach


Write-Verbose "# of Admin/Service pkgs found: $ascount"
Write-Verbose "# of DB pkgs found: $dbcount"

## Move all dropped files to archive.
$droparchive = "$workingdir\_fromTFS\_Archive\$env\$datetime"
mkdir $droparchive
foreach ($dir in Get-ChildItem $dropzone) {
    Move-Item $dropzone\$dir -Destination $droparchive -force
}

## Export list of apps updated to use for backup later.
$Apptobackup | Out-File "$workingdir\_config\updatelist_$env.txt"

## Record history of apps deployed.
$AppsDeployed | Out-File "$workingdir\$env\_history\DeployedAppList_$env_$datetime.txt"
