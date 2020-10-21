function Get-buildValues {
    <#
    .SYNOPSIS
        Analyse a build workflow, perform necessary validation and return values.

    .DESCRIPTION
        Analyse a build workflow, perform necessary validation and return values.

        Performs the following actions:
            * Resolves DML paths and verifies media SHA256.
            * Resolves credential paths and verifies supplied encryption key.
            * Tests all other metadata items using their respective type using Test-metaData

        Returns a completed values table if all tests pass.

    .PARAMETER buildPath
        Full path to the specified build to process.

    .PARAMETER dmlCSV
        Full path to the DML CSV to use.

    .PARAMETER dmlCSV
        Full path to the DML CSV to use.

    .PARAMETER credentialStore
        Full path to credential store to use with the specified build.

    .PARAMETER credentialKeyFile
        The AES encryption key file to use with the credential store.

    .PARAMETER skipMediaValidation
        Skip media validation (not receommended). Optional.

    .INPUTS
        System.String. The build path to process.

    .OUTPUTS
        System.Management.Automation.PSCustomObject. Completed build values.

    .EXAMPLE
        Get-buildValues -buildPath C:\StackBuild\Builds\vsan-large-67\ -dmlCSV C:\DML\dmlContents.csv -credentialStore C:\StackBuild\Credentials\ -credentialKeyFile C:\StackBuild\aesKey.key

        Verify the build vsan-large-67 and return values.

    .EXAMPLE
        Get-buildValues -buildPath C:\StackBuild\Builds\vsan-large-67\ -dmlCSV C:\DML\dmlContents.csv -credentialStore C:\StackBuild\Credentials\ -credentialKeyFile C:\StackBuild\aesKey.key -skipMediaValidation

        Verify the build vsan-large-67 and return values. Skip media validation.

    .LINK

    .NOTES
        01       27/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [String]$buildPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$dmlCSV,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$credentialStore,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$credentialKeyFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$logPath,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [String]$overrides,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$skipMediaValidation
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Processing build at " + $buildPath)

        ## Strip trailing \ from build path, if specified
        $buildPath = $buildPath.Trim("\")

        ## Strip trailing \ from credential store path, if specified
        $credentialStore = $credentialStore.Trim("\")

        ## Import values table from CSVs
        Write-Verbose ("Opening workflow value files.")

        try {
            $buildValues = (Get-ChildItem -Path  ($buildPath + "\values") -ErrorAction Stop).FullName |  Import-Csv -ErrorAction Stop
            Write-Verbose ("Opened files.")
        } # try
        catch {
            Write-Debug ("The specified values file could not be imported.")
            throw ("Failed to import values from " + $buildPath + ". " + $_.exception.message)
        } # catch


        ## Check there is at least 1 row in the file
        if (($buildValues | Measure-Object).Count -lt 1) {
            throw("No content found within values.csv.")
        } # if

        ## Add any supplied overrides
        if ($overrides) {
            Write-Verbose ("Override values have been specified.")

            try {
                $overrideValues = Import-Csv -Path $overrides -ErrorAction Stop
                Write-Verbose ("Opened override CSV at " + $overrides)
            } # try
            catch {
                Write-Debug ("Failed to import overrides.")
                throw ("Failed to import overrides from " + $overrides + ". " + $_.exception.message)
            } # catch   

            ## Merge and overwrite these with main values table
            $buildValues = ($buildValues | Where-Object {$_.key -notin $overrideValues.key}) + $overrideValues
        } # if
  
        ## Import DML from CSV
        Write-Verbose ("Importing DML index CSV.")

        try {
            $dmlIndex = Import-Csv -Path $dmlCSV -ErrorAction Stop
            Write-Verbose ("Opened DML index file.")
        } # try
        catch {
            Write-Debug ("DML import failed.")
            throw ("The specified DML index file could not be imported. The CMDlet returned: " + $_.exception.message)
        } # catch


        ## Resolve out paths to DML items
        Write-Verbose ("Resolving paths to DML items in values table.")

        foreach ($buildValue in $buildValues | Where-Object {$_.dataType -eq "DML"}) {

            $dmlItem = $dmlIndex | Where-Object {$_.itemNumber -eq $buildValue.value}

            ## Check there was a DML item found
            if (!$dmlItem) {
                throw ("Failed to find entry for DML " + $buildValue.value + " in DML index " + $dmlCSV)
            } # if

            Write-Verbose ("Found DML entry for item number " + $buildValue.value)

            ## Escape out \ characters for JSON
            $buildValue.value = ((Split-Path -Path $dmlCSV -parent) +"\" + $dmlItem.path)#.replace("\","\\")
            $buildValue.dataType = "folderPath"

            ## Skip media validation if specified
            if (!$skipMediaValidation) {

                Write-Verbose ("Validating SHA256 for " + $buildValue.value)

                ## Validate SHA256 of item
                try {
                    $fileSHA = Get-FileHash -Path $buildValue.value -Algorithm SHA256 -ErrorAction Stop
                    Write-Verbose ("Got SHA256 value.")
                } # try
                catch {
                    throw ("Failed to get SHA256 value. " + $_.exception.message)
                } # catch


                if ($dmlItem.sha256 -ne $fileSHA.Hash) {
                    throw ("DML item + "+ $buildValue.value + " failed SHA256 validation.")
                } # if

                Write-Verbose ($buildValue.value + " passed validation.")

            } # if

        } # foreach

        Write-Verbose ("Completed processing DML items.")

        ## Test credential items. This proves the file can be imported and the AES key works.
        Write-Verbose ("Testing credential items.")

        foreach ($buildValue in $buildValues | Where-Object {$_.dataType -eq "Credential"}) {

                $buildValue.Value = ($credentialStore + "\" + $buildValue.value)

                Write-Verbose ("Credential item at " + $buildValue.Value + " added.")

                ## Skip credential validation if specified
                if (!$skipMediaValidation) {

                    try {
                        Import-Credential -inputFile $buildValue.Value -aesKey $credentialKeyFile -ErrorAction Stop | Out-Null
                        Write-Verbose ("Credential imported successfully.")
                    } # try
                    catch {
                        throw ("Failed to import credential. " + $_.exception.message)
                    } # catch

                } # if

        } # foreach

        Write-Verbose ("Credential tests complete.")


        ## Allocate network addressing
        Write-Verbose ("Allocating dynamic network values.")

        ## Copy networks.json to log directory
        Copy-Item -Path ($buildPath + "\networks.json") -Destination ($masterLogPath + "\networks.json")

        foreach ($buildValue in $buildValues | Where-Object {$_.dataType -like "NETALLOCATION#*"}) {

            ## The network we want to allocate to
            $netName = $buildValue.DataType.split("#")[1]

            ## The network action we want to do, e.g. new IP, get gateway
            $action = $buildValue.DataType.Split("#")[2]

            try {
                $buildValue.Value = New-netMetadata -definitionFile ($logPath + "\networks.json") -action $action -netName $netName -ErrorAction Stop
            } # try
            catch {
                Write-Debug ("Network allocation failed.")
                Throw ("Failed to allocate dynamic network value. " + $_.exception.message)
            } # catch


            $buildValue.dataType = "ipv4"

        } # foreach


        ## Test metadata in values table
        Write-Verbose ("Start metadata testing.")

        ## Start metadata validation on values.csv
        try {
            $results = $buildValues | Where-Object {$_.dataType -ne "Credential"} | Test-metaData -ErrorAction Stop
            Write-Verbose ("Completed metadata testing.")
        } # try
        catch {
            Write-Debug ("Failed to test metadata.")
            Throw ("Failed to test metadata. " + $_.exception.message)
        } # catch


        ## Report on what has failed validation, if anything
        if ($results | Where-Object {!$_.isValid}) {
            throw ("Some metadata items did not pass validation.")
        } # if

        return $buildValues

    } # process

    end {
        Write-Verbose ("Function complete.")

    } # end

} # function