function Get-placeHolder {
    <#
    .SYNOPSIS
        Get all placeholders from a json metadata file.

    .DESCRIPTION
        Get all placeholders from a json metadata file.

    .PARAMETER jsonFile
        The json template to process.

    .INPUTS
        System.IO.FileInfo. Target json placeholder file.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. A collection of objects representing placeholder data.

    .EXAMPLE
        Get-Item -Path 003$Connect-VIResource.json | Get-placeHolder

        Return all placeholder items in 003$Connect-VIResource.json

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>


    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [System.IO.FileInfo]$jsonFile

    )

    begin {
        Write-Verbose ("Function start.")

    } # begin


    process {

        Write-Verbose ("Processing metadata file at " + $jsonFile.FullName)


        ## Open this metadata file
        try {
            $json = Get-Content -Path $jsonFile.FullName -ErrorAction Stop
            Write-Verbose ("Opened file.")
        } # try
        catch {
            Write-Debug ("Filed to open file.")
            throw ("Failed to open file. " + $_.exception.message)
        } # catch


        ## Determine function name and sequence ID
        $functionName = $jsonFile.name.split("$")[1].split(".")[0]
        $sequenceID = $jsonFile.name.split("$")[0]


        ## Initialise array to store placeholder objects
        $placeHolders = @()


        ## Iterate through each row and replace placeholders with values
        foreach ($row in $json) {

            ## Set regex to catch value from tags
            $tagPattern =  '(?i)<@@[^>]*>(.*)</@@>'


            ## Apply regex to get value from tag on this row
            $result = [Regex]::Match($row, $tagPattern)


            ## If a tag was found on this line, find metadata value
            if ($result.Success) {

                ## Initialise object for this placeholder
                $placeHolder = [pscustomobject]@{
                                                "name" = $result.Groups[1].value
                                                "function" = $functionName
                                                "sequenceId" = $sequenceID
                                            } # placeHolder

                ## Add this to the collection
                $placeHolders += $placeHolder

                Write-Verbose ("Metadata placeholder " + $result.Groups[1].value + " found.")

            } # if

        } # foreach

        Write-Verbose ("Completed file.")

        return $placeHolders

    } # process


    end {
        Write-Verbose ("Function end.")

    } # end

} # function