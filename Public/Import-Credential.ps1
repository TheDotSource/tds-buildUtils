function Import-Credential {
    <#
    .SYNOPSIS
        Import a credential created by Export-Credential

    .DESCRIPTION
        Import a credential created by Export-Credential.
        The same key file used to encrypt the exported credential must be specified at time of import.

    .PARAMETER inputFile
        The credential file to read.

    .PARAMETER aesKey
        A text file containing an AES encryption key used to encrypt the original export.

    .INPUTS
        None.

    .OUTPUTS
        System.Management.Automation.PSCredential

    .EXAMPLE
        Import-Credential -inputFile C:\credStore\credential1.json -aesKey C:\keys\key1.key

        Return a credential object from credential1.json using key file key1.key

    .LINK

    .NOTES
        01       27/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$inputFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$aesKey

    )


    begin {
        Write-Verbose ("Function start.")

    } # begin


    process {

        Write-Verbose ("Processing credential " + $inputFile)

        ## Import the specified key file
        try {
            $keyContent = Get-Content -Path $aesKey -ErrorAction Stop
            Write-Verbose ("Got key file content.")
        } # try
        catch {
            Write-Debug ("Failed to get key file content.")
            Throw ("Failed to get key file content.")
        } # catch


        ## Import target json file
        Write-Verbose ("Importing file.")

        try {
            $credObj = Get-Content -Path $inputFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose ("Imported file.")
        } # try
        catch {
            Write-Debug ("Failed to import.")
            throw ("Failed to import file. " + $_.exception.message)
        } # catch


        ## Create credential object
        Write-Verbose ("Creating credential object.")
        try {
            $creds = New-Object System.Management.Automation.PSCredential ($credObj.UserName,($credObj.password | ConvertTo-SecureString -Key $keyContent))
            Write-Verbose ("Credential created.")
        } # try
        catch {
            Write-Debug ("Failed to create credential.")
            throw ("Failed to create credential. " + $_.exception.message)
        } # catch

        Write-Verbose ("Completed credential.")

        ## Return completed credential
        return $creds

    } # process

    end {

        Write-Verbose ("Function complete.")
    } # end

} # function