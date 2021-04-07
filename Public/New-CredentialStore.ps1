function New-CredentialStore {
    <#
    .SYNOPSIS
        Generate a new credential store for a Podium workflow.

    .DESCRIPTION
        Generate a new credential store for a Podium workflow.
        All data of type credential will be pulled from the workflow values table.
        The function will prompt for each credential.

        An AES key is generated then credential items written to the specified credential folder.
        The AES key should then be stored elsewhere in a secure location.

    .PARAMETER buildPath
        The Podium build workflow to process

    .PARAMETER outputPath
        The path to generate the new credential store. If it doesn't exist, it will be created.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-CredentialStore -buildPath C:\Podium\builds\vsan-large\ -outputPath C:\credentialStore\

        Get all credential items from the vsan-large workflow and prompt the user for usernames and passwords.
        AES key and json credential files are saved to c:\credentialStore

    .LINK

    .NOTES
        01       11/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$buildPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$outputPath
    )

    begin {
        Write-Verbose ("Function start.")
    } # begin

    process {

        Write-Verbose ("Processing credentials for " + $buildPath)

        ## Strip trailing \ from build path, if specified
        $buildPath = $buildPath.Trim("\")
        $outputPath = $outputPath.Trim("\")

        ## Validate specified build folder exists
        if (!(Test-Path $buildPath)) {
            Write-Verbose ("Build path not found.")
            throw ("Build path " + $buildPath + " was not found.")
        } # if

        ## Check if output folder exists, if not, create it
        if (!(Test-Path $outputPath)) {
            Write-Verbose ("Output directory does not exist, it will be created.")

            try {
                New-Item -Path $outputPath -ItemType Directory -ErrorAction Stop | Out-Null
                Write-Verbose ("Directory created.")
            } # try
            catch {
                Write-Debug ("Failed to create output directory. " + $_.exception.message)
                throw ("Failed to create output directory. " + $_.exception.message)
            } # catch

        } # if


        ## Import all credential items from build values
        Write-Verbose ("Fetching credential data items from build workflow.")

        try {
            $credItems = (Get-ChildItem -Path  ($buildPath + "\values") -ErrorAction Stop).FullName |  Import-Csv -ErrorAction Stop | Where-Object {$_.datatype -eq "Credential"}
            Write-Verbose ("Got items.")
        } # try
        catch {
            Write-Debug ("Failed to import values from " + $buildPath + ". " + $_.exception.message)
            throw ("Failed to import values from " + $buildPath + ". " + $_.exception.message)
        } # catch

        ## Check we have some items to process
        if ($credItems.count -eq 0) {
            throw ("No data items of type credential were found in this workflow.")
        } # if

        Write-Verbose ("Found " + $credItems.count + " credential items in this workflow.")

        ## Generate 256 bit key / byte array to encrypt credentials
        Write-Verbose ("Generating 256 bit key")

        $key = New-Object Byte[] 32
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)

        Write-Verbose ("Key was generated.")

        ## Output this key file to target directory
        Write-Verbose ("Saving key file.")

        try {
            $key | Out-File -FilePath ($outputPath + "\aesKey.key") -Force -ErrorAction Stop
            Write-Verbose ("Key saved.")
        } # try
        catch {
            Write-Debug ("Failed to save key. " + $_.exception.message)
            throw ("Failed to save key. " + $_.exception.message)
        } # catch

        ## Prompt for each credential
        foreach ($credItem in $credItems) {

            Write-Verbose ("Processing credential " + $credItem.Key)

            ## Capture this credential
            $cred = Get-Credential -Message $credItem.description

            ## Use Export-Credential to write out the .json file
            Write-Verbose ("Saving credential json.")
            try {
                Export-Credential -Credential $cred -outputFile ($outputPath + "\" + $credItem.value) -aesKey ($outputPath + "\aesKey.key") -ErrorAction Stop
                Write-Verbose ("Credential saved.")
            } # try
            catch {
                Write-Debug ("Failed to save credential. " + $_.exception.message)
                throw ("Failed to save credential. " + $_.exception.message)
            } # catch

            Write-Verbose ("Completed credential.")

        } # foreach

    } # process

    end {
        Write-Verbose ("Function complete.")

    } # end

} # function