function Copy-IsoContent {
    <#
    .SYNOPSIS
        Mount and copy ISO content to a destination folder.

    .DESCRIPTION
        Mount and copy ISO content to a destination folder.

        The function performs the following speps:
            * Check destination path exists, create if -force switch is used.
            * Mount ISO media.
            * Copy contents to destination, overwriting if -force is used.
            * Dismount media.

    .PARAMETER mediaPath
        The path of the source ISO.

    .PARAMETER destination
        The output directory to copy content to.

    .PARAMETER force
        Optional. Create destination directory. Overwrite any existing files.

   .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Copy-IsoContent -mediaPath D:\DML\sample.iso -destination D:\scrtachMedia -force -Verbose

        Mount and extract sample.iso to d:\scratchMedia, creating the directory or overwriting existing files.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$mediaPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$destination,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$force
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        ## Test destination path. Throw if force is not specified, create if it is.
        Write-Verbose ("Verifying destination " + $destination)

        if (!(Test-Path -Path $destination)) {

            ## Check force switch and create
            if ($force) {
                Write-Verbose ("Destination path was not found, it will be created.")

                ## Create destination path
                try {
                    New-Item -Path $destination -ItemType Directory -Force -ErrorAction Stop | Out-Null
                    Write-Verbose ("Destination directory " + $destination + " was created.")
                } # try
                catch {
                    throw ("Failed to create destination directory. " + $_.exception.message)
                } # catch

            } # if
            else {
                throw ("The destination path was not found. Use the -force switch to create it.")
            } # else

        } # if


        ## Mount the specified ISO media
        Write-Verbose ("Mounting specified media from " + $mediaPath)

        try {
            $isoMount = Mount-DiskImage -ImagePath $mediaPath -PassThru -ErrorAction Stop
            Write-Verbose ("Media was mounted successfully.")
        } # try
        catch {
            throw ("Failed to mount target media. " + $_.exception.message)
        } # catch


        ## Fetch drive letter
        Write-Verbose ("Finding drive letter.")

        try {
            $driveLetter = ($isoMount | Get-Volume -ErrorAction Stop).DriveLetter
            Write-Verbose ("Media is mounted to drive letter " + $driveLetter)
        } # try
        catch {
            throw ("Failed to find media drive letter. " + $_.exception.message)
        } # catch

        ## Perform copy operation
        Write-Verbose ("Copying ISO content.")

        try {
            ## Apply force as specified
            Copy-Item -Path ($driveLetter + ":\*") -Destination $destination -Recurse -Force:$force
            Write-Verbose ("Copy completed.")
        } # try
        catch {
            throw ("Failed to copy content. " + $_.exception.message)
        } # catch


        ## Dismount media
        Write-Verbose ("Dismounting media.")

        try {
            $isoMount | Dismount-DiskImage -ErrorAction Stop | Out-Null
            Write-Verbose ("Media dismounted.")
        } # try
        catch {
            throw ("Failed to dismount media. " + $_.exception.message)
        } # catch
    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function