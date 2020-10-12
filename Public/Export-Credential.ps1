function Export-Credential {
    <#
    .SYNOPSIS
        Export a PS credential object to a JSON file using a key.

    .DESCRIPTION
        Export a PS credential object to a JSON file using a key.
        The password portion of the credential is encrypted using the specified key file.
        Username and password are then saved to the specfied JSON file and can be imported at a later date using the same key file.

    .PARAMETER Credential
        The credential item to be encrpyted with the specified key and saved.

    .PARAMETER aesKey
        A text file containing an AES encryption key.

    .PARAMETER outputFile
        The file to output the credential json.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Export-Credential -Credential $rootCreds -aesKey C:\keys\key1.key -outputFile c:\credentials\rootCreds.json

        Take the $rootCreds credential object and save to rootCreds.json, encrypting the password string with key1.key

    .LINK

    .NOTES
        01       27/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$aesKey,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$outputFile
    )


    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing credential " + $Credential.username)

        ## Import the specified key file
        try {
            $keyContent = Get-Content -Path $aesKey -ErrorAction Stop
            Write-Verbose ("Got key file content.")
        } # try
        catch {
            Write-Debug ("Failed to get key file content.")
            Throw ("Failed to get key file content.")
        } # catch


        ## Create a custom object for this credential
        Write-Verbose ("Encrypting password for export.")
        try {
            $exportObj = [pscustomobject]@{"userName" = $Credential.UserName; "password" = ($Credential.password | ConvertFrom-SecureString -Key $keyContent)}
            Write-Verbose ("Password encrypted.")
        } # try
        catch {
            Write-Debug ("Failed to encrypt string.")
            throw ("Failed to encrypt string. " + $_.exception.message)
        } # catch

        ## Export json to specified file
        Write-Verbose ("Exporting JSON credential object to " + $outputFile)

        try {
            $exportObj | ConvertTo-Json -ErrorAction Stop | Out-File -FilePath $outputFile -ErrorAction Stop
            Write-Verbose ("Export complete.")
        } # try
        catch {
            Write-Debug ("Failed to export.")
            throw ("Failed to export file. " + $_.exception.message)
        } # catch


        Write-Verbose ("Completed credential.")

    } # process


    end {

        Write-Verbose ("Function end.")
    } # end

} # function