function Invoke-buildWorkflow {
    <#
    .SYNOPSIS
        Start a TDS build workflow for the given path.

    .DESCRIPTION
        Start a TDS build workflow for a given path.

    .PARAMETER buildPath
        The path to the build workflow.

    .PARAMETER dmlCSV
        The path to the Definitive Media Library index file.

    .PARAMETER credentialStore
        Path to the credential store.

    .PARAMETER credentialKeyFile
        The AES key used to decrypt credential objects in the credential store.

    .PARAMETER logpath
        Path to save build logs to.

    .PARAMETER overrides
        Optional values CSV. These values will override the mandatory values in the value table.

    .PARAMETER skipValidation
        Skip metadata and media validation (not recommended)

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Invoke-buildWorkflow -buildPath C:\StackBuild\Builds\baseVsphere67\ -dmlCSV C:\DML\dmlContents.csv -credentialStore C:\StackBuild\Credentials\ -credentialKeyFile C:\StackBuild\aesKey.key

        Start the build baseVsphere67 using the specified dmlCsv, credential store and aes key.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

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
        [String[]]$overrides,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [switch]$skipMediaValidation
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Processing workflow at " + $buildPath)

        ## Strip trailing \ from build path, if specified
        $buildPath = $buildPath.Trim("\")

        ## Strip trailing \ from credential store path, if specified
        $credentialStore = $credentialStore.Trim("\")

        ## Strip trailing \ from log path, if specified
        $logPath = $logPath.Trim("\")

        ## Derive build name from path
        $buildName = Split-Path -Path $buildPath -Leaf

        ## Validate specified build folder exists
        if (!(Test-Path $buildPath)) {
            Write-Verbose ("Build path not found.")
            throw ("Build path " + $buildPath + " was not found.")
        } # if

        Write-Verbose ("Build path found.")

        ## Initiate logs and scratch directory
        $masterLogPath = ($logPath + "\" + (Get-Date -Format "yyyy-MM-dd-HH-mm-ss") + "-" + $buildName + "-log")
        $scratchPath = ($logPath + "\" + (Get-Date -Format "yyyy-MM-dd-HH-mm-ss") + "-" + $buildName + "-scratch")


        try {
            New-Item -ItemType Directory -Path $masterLogPath -Force | Out-Null
            Write-Verbose ("Log directory created at " + $masterLogPath)
        } # try
        catch {
            Write-Debug ("Failed to created log directory.")
            throw ("Failed to create logs path. " + $_.exception.message)
        } # catch


        ## Generate build values table
        Write-Verbose ("Generating build values table.")
        try {
            $buildValues = Get-buildValues -buildPath $buildPath -dmlCSV $dmlCSV -credentialStore $credentialStore -credentialKeyFile $credentialKeyFile `
            -skipMediaValidation:$skipMediaValidation -logPath $masterLogPath -overrides $overrides -ErrorAction Stop
            Write-Verbose ("Build values generated.")
        } # try
        catch {
            Write-Debug ("Failed to generate build values.")
            throw ("Failed to generate build values. Get-buildValues returned: " + $_.exception.message)
        } # catch


        ## Add log and scratch directories to values table to make it available to other functions.
        $buildValues += [pscustomobject]@{"Key" = "logDirectory"; "Value" = $masterLogPath; "DataType" = "String"; "Description" = "Environment log directory"}
        $buildValues += [pscustomobject]@{"Key" = "scratchDirectory"; "Value" = $scratchPath; "DataType" = "String"; "Description" = "Environment scratch directory"}

        ## Add AES key to values table to make it available to other functions.
        $buildValues += [pscustomobject]@{"Key" = "credentialKeyFile"; "Value" = $credentialKeyFile; "DataType" = "String"; "Description" = "AES key for credentail objects"}


        ## Save a copy of this values table to the logs directory for reference
        Write-Verbose ("Exporting values table to " + $masterLogPath + "\translatedValues.csv")
        try {
            $buildValues | Export-Csv -Path ($masterLogPath + "\translatedValues.csv") -NoClobber -NoTypeInformation -ErrorAction Stop
            Write-Verbose ("Saved traslated values table to log directory.")
        } # try
        catch {
            Write-Debug ("Failed to save CSV.")
            throw ("Failed to save translated values CSV to "+ $masterLogPath + "\translatedValues.csv " + $_.exception.message)
        } # catch


        ## Get the available stage JSON files from the metadata folder
        try {
            $jsonFiles = Get-ChildItem -Path ($buildPath + "\metadata") -Filter *.json -ErrorAction Stop | Sort-Object
            Write-Verbose ("Got list of json metadata files.")
        } # try
        catch {
            Write-Debug ("Failed to retreive content from the metadata folder.")
            throw("Failed to retreive content from the metadata folder.")
        } # catch


        ## Check that there is at least 1 stage file
        if ($jsonFiles.Count -eq 0) {
            throw("No stage files in the specified directory.")
        } # if


        ## Inject values into json templates
        try {
            $jsonMaster = $jsonFiles | Set-placeholderValue -buildValues $buildValues -ErrorAction Stop
            Write-Verbose ("Completed injecting values to json templates.")
        } # try
        catch {
            Write-Debug ("Failed to inject values.")
            throw ("Failed to inject values to json templates. " + $_.exception.message)
        } # catch


        ## Save copy of build object to log directory for reference
        try {
            $jsonMaster | ConvertTo-Json -Depth 5 | Out-File -FilePath ($masterLogPath + "\buildJSON.json") -ErrorAction Stop
            Write-Verbose ("Saved build JSON to log directory.")
        } # try
        catch {
            Write-Debug ("Failed to save build JSON.")
            throw ("Failed to save build JSON to log directory. " + $_.exception.message)
        } # catch


        ## Initialise main build log file
        $buildLog = ($masterLogPath + "\buildRunTime.log")

        ## Initialise workflow attributes hash table
        $workflowAttribs = @{}

        Write-Verbose ("Starting build.")

        ## Iterate through master JSON and run functions in sequence
        foreach ($stage in $jsonMaster) {

            ## Build collection of hashtables so we can splat parameters
            $paramHashTables = @()

            ## Initialise attribute name flag
            $attribNames = @()

            foreach ($obj in $stage.Objects) {

                ## Initilaise empty hashtable
                $paramHashTable = @{}

                ## Define foreach process block
                $feProcess = {

                    ## Process parameters
                    switch ($_) {

                        ## Generate workflow attribute. This is not a parameter, but an instruction to capture the output of this function to the specified attribute name.
                        {$_.name -eq "workflowAttrib"} {

                            Write-Verbose ("Workflow attribute detected. Output from this function will be captured to workflow attribute " + $_.value)
                            $attribNames += $_.value
                            break
                        } # Generate attribute

                        ## Workflow attribute, use a value from the attributes table
                        {$_.value -like "@@*"} {

                            Write-Verbose ("Value for parameter " + $_.name + " will be taken from workflow attribute with key " + $_.value.trim("@@"))
                            $paramHashTable[$_.Name] = $workFlowAttribs.($_.value.trim("@@"))
                            break
                        } # Use attribute

                        ## All other standard values taken from values table
                        default {

                            $paramHashTable[$_.Name] = $_.value
                        } # default

                    } # switch

                } # scriptblock

                ## Convert this object to a hashtable
                $obj.psobject.properties | ForEach-Object -Process $feProcess

                ## Add this hash table to the collection
                $paramHashTables += $paramHashTable

            } # foreach


            ## Iterate counter
            $i++

            ## Write progress to the screen
            Write-Progress -Activity ("[" + $buildName + "] Executing stage " + $stage.Function + " [" + $i + " of " + ($jsonMaster | Measure-Object).count + "]") -PercentComplete (($i / ($jsonMaster | Measure-Object).count) * 100)

            ## Generate dynamic scriptblock
            $scriptBlock = [scriptblock]::Create("`$paramHashTables | ForEach-Object {$($stage.Function) @_ -Verbose -ErrorAction Stop *>&1} | Write-BuildLog -logPath `$buildLog -functionName $($stage.Function)")

            Write-Verbose ("Executing script block " + $i + " of " + ($jsonMaster | Measure-Object).count + ": " + $scriptBlock)

            try {
                ## Execute script block
                $cmdReturns = Invoke-Command -ScriptBlock $scriptBlock -ErrorAction Stop
            } # try
            catch {
                Write-Debug ("Command failure.")
                $_ | Write-BuildLog -logPath $buildLog -functionName $stage.function

                ## Build failed, clean up scratch directory before throwing
                Write-Verbose ("Removing scratch directory " + $scratchPath)

                try {
                    Remove-Item -Path $scratchPath -Confirm:$false -Recurse -Force
                    Write-Verbose ("Removed.")
                } # try
                catch {
                    Write-Warning ("Failed to remove scratch directory. " + $_.exception.message)
                } # catch

                throw ("A build failure was detected. Examine " + $buildLog + " for more details.")
            } # catch

            ## If we have a workflowAttrib parameter set, save the output of this function to the specified workflow attribute
            if ($attribNames) {

                ## Check there was actual output
                if ($cmdReturns) {

                    ## Set counter, we use this to match an attribute name to a cmd return as they are in different arrays
                    $x = 0

                    foreach ($cmdReturn in $cmdReturns) {

                        ## Fetch the attribName for this cmdreturn
                        $attribName = $attribNames[$x]

                        ## Check if this attribute already exists, if so update it
                        if ($workflowAttribs.$attribName) {
                            Write-Verbose ("Workflow attribute already exists, it will be updated.")
                            $workflowAttribs.$attribName = $cmdReturn
                        } # if
                        else {
                            Write-Verbose ("Saving function output to workflow attribute " + $attribName)
                            $workFlowAttribs.add($attribName,$cmdReturn)
                        } # else

                        ## Increment counter
                        $x++
                    }

                } # if
                else {
                    Write-Warning ("The workflowAttrib parameter was specified for this function, but it returned no ouput. This may affect other functions with a dependency on this attribute.")
                } # else

            } # if

            ## Wait 2 seconds between functions
            Start-Sleep 2

        } # foreach


        ## Remove scratch path
        Write-Verbose ("Removing scratch directory " + $scratchPath)
        try {
            Remove-Item -Path $scratchPath -Confirm:$false -Recurse -Force
            Write-Verbose ("Removed.")
        } # try
        catch {
            Write-Warning ("Failed to remove scratch directory. " + $_.exception.message)
        } # catch


        Write-Verbose ("Build complete.")

    } # process

    end {

        Write-Verbose ("All builds complete.")

    } # end

} # function