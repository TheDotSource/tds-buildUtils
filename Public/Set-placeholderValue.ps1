function Set-placeholderValue {
    <#
    .SYNOPSIS
        Inject values from a table into tagged placeholders in json files.

    .DESCRIPTION
        Inject values from a table into tagged placeholders in json files.

    .PARAMETER jsonFile
        The json template to process.

    .PARAMETER buildValues
        Values table from which to populate json files.

    .INPUTS
        System.IO.FileInfo. Target json placeholder file.

    .OUTPUTS
        None.

    .EXAMPLE
        $jsonFiles | Set-placeholderValue -buildValues $buildValues

        Inject values from $buildValues table into placeholders in $jsonFiles.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo]$jsonFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Object]$buildValues

    )


    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing JSON file " + $jsonFile.fullname)


        ## Determine function name and sequence ID
        $functionName = $jsonFile.name.split("$")[1].split(".")[0]
        $sequenceID = $jsonFile.name.split("$")[0]


        Write-Verbose ("Function name is " + $functionName)
        Write-Verbose ("Stage ID is " + $sequenceID)


        ## Configure return object
        $jsonStage = [pscustomobject]@{"Function" = $functionName; "SequenceID" = $sequenceID; "Objects" = @()}


        ## Insert placeholder values to this object
        $json = Get-Content -Path $jsonFile.FullName

        $newJSON = @()

        ## Iterate through each row and replace placeholders with values
        $i = 1

        foreach ($row in $json) {

            Write-Verbose ("Processing row number " + $i)

            ## Set regex to catch value from tags
            $tagPattern =  '(?i)<@@[^>]*>(.*)</@@>'


            ## Apply regex to get value from tag on this row
            $result = [Regex]::Match($row, $tagPattern)


            ## If a tag was found on this line, find metadata value
            if ($result.Success) {

                Write-Verbose ("Placeholder tag detected at row " + $i)

                ## Tag has been found, retreive a value
                $metaValue = ($buildValues | Where-Object {$_.key -eq $result.Groups[1].value}).value

                Write-Verbose ("Value " + $metaValue + " will be injected.")

                if ($metaValue) {
                    Write-Verbose ("Metadata placeholder " + $result.Groups[1].value + " has been populated with value " + $metaValue)
                } # if
                else {
                    throw ("Placeholder " + $result.Groups[1].value + " from JSON file " + $jsonFile.FullName + " could not be found in values table.")
                } # else

                ## Insert this value into the string
                $row = $row -replace $result.Groups[0].value,$metaValue

            } # if
            else {
                Write-Verbose ("No placeholder tag found at this row.")

            } # else

            ## Append row to new JSON
            $newJSON += $row

            ## Increment counter
            $i++

        } # foreach


        try {
            ## Apply JSON escape character to \
            $newJSON = $newJSON.Replace("\","\\")
            $jsonStage.Objects += $newJSON | ConvertFrom-Json -ErrorAction Stop
        } # try
        catch {
            Write-Debug ("Failed to add stage object.")
            throw ("Failed to add stage object. The CMDlet returned: " + $_.exception.message)
        } # catch

        Write-Verbose ("Finished processing JSON file.")

        return $jsonStage

    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end


} # function