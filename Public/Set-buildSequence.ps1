function Set-buildSequence {
    <#
    .SYNOPSIS
        Renumber a set of metadata files to insert a gap at the specified point.

    .DESCRIPTION
        Renumber a set of metadata files to insert a gap at the specified point.
        Useful in the event that additional metadata files need to be added mid-sequence.

    .PARAMETER buildPath
        The path to the specified build to process.

    .PARAMETER addAtStep
        The step number at which to start renumbering from.

    .PARAMETER stepsToAdd
        The number of steps to inject at this point.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Set-buildSequence -buildPath C:\StackBuild\Builds\test -addAtStep 10 -stepsToAdd 4

        Add a space of 4 in the sequence starting at step 10.
    .LINK

    .NOTES
        01       27/05/20     Initial version.           A McNair
    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    param(
        [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$True)]
        [string]$buildPath,
        [Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$True)]
        [int]$addAtStep,
        [Parameter(Mandatory=$false,Position=0,ValueFromPipeline=$True)]
        [int]$stepsToAdd
    )


    Begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        ## Strip trailing \ from build path, if specified
        $buildPath = ($buildPath.Trim("\") + "\metadata")

        ## Get the available stage JSON files from the metadata folder
        try {
            $JSONFiles = (Get-ChildItem -Path $BuildPath -Filter *.json -ErrorAction Stop | Sort-Object name).name
            Write-Verbose ("Fetched JSON content from " + $buildPath)
        } # try
        catch {
            throw("Failed to retreive content from folder. The CMDlet returned " + $_.exception.message)
        } # catch


        ## Check that there is at least 1 stage file
        if ($JSONFiles.Count -eq 0) {
            throw("No stage files in the specified directory.")
        } # if

        Write-Verbose ("Found " + $JSONFiles.Count + " files to process.")


        ## Build hash table of new sequence
        $newSequence = @{}


        ## Set initial counter
        $i = 1

        ## Iterate through JSON files and populate hash table
        foreach ($item in $JSONFiles) {

            ## Get filename without leading number
            $filename = $item.split("$")[1]

            ## Format with leading zeros
            $leadingZero = "{0:000}" -f $i

            ## Add to hash table
            $newSequence.add($leadingZero,$filename)


            ## Add a gap if specified
            if ($addAtStep) {

                if ($i -eq $addAtStep) {

                    $i = $i + $stepsToAdd

                } # if

            } # if

            ## Increment counter
            $i++
        } # foreach


        ## Rename file to new sequence
        $x = 0

        foreach ($item in ($newSequence.GetEnumerator() | Sort-Object name)) {

            if ($PSCmdlet.ShouldProcess($item.name)) {
                Rename-Item -Path ($BuildPath + "\" + $JSONFiles[$x]) -NewName ($item.name + "$" + $item.Value)
            } # if

            Write-Verbose ($JSONFiles[$x] + " renamed to " + ($item.name + "$" + $item.Value))
            $x++

        } # foreach

    } # process

    end {
        Write-Verbose ("End of function.")

    } # end

} # function