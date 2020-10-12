function Test-metaData {
    <#
    .SYNOPSIS
        Test a piece of data against a known type.

    .DESCRIPTION
        Test a piece of data against a known type.
        For example:
            * test a supplied value is an IP address.
            * test a supplied value is a valid size for a vROPs appliance

    .PARAMETER metaData
        The data item to test.

    .PARAMETER dataType
        The type of data that the data item should be tested against.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        $buildValues | Test-metaData

        Validate all metadata items in the $buildValues table.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>


    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [String]$value,
        [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
        [ValidateSet("FQDN","string","ipv4","ipv4MaskLength","nsxtTransportType","CIDR","vcsaAppSize","folderPath")]
        [string]$dataType

    )


    begin {

        Write-Verbose ("Function start.")
    } # begin


    process {

        ## Run appropriate test on specified metadata item
        switch ($dataType) {

            "FQDN" {

                ## Test this string is formatted as an FQDN
                if (!($value -match "(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{1,63}(?<!-)\.)+[a-zA-Z]{2,63}$)")) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # FQDN


            "string" {

                ## Check the string is not null or just white space
                if ([string]::IsNullOrWhiteSpace($value)) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # notNullString



            "ipv4" {

                ## Check data item is a valid IPv4 address
                if (!($value -match "^(((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?))$")) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # ipv4


            "ipv4MaskLength" {

                ## Check that the data item is a valid IPv4 subnet mask length
                if (!($value -notin 0..32)) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # ipv4MaskLength


            "nsxtTransportType" {

                ## Check that the data item is a valid value for NSX-T transport zone types.
                $validTypes = @("OVERLAY","VLAN")

                if (!($validTypes.contains($value))) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # nsxtTransportType


            "CIDR" {

                ## Check that the data item is a valid value for CIDR notation
                if ($value -notmatch "(^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[0-9]))$)") {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # CIDR


            "vcsaAppSize" {

                ## Check data item is a valid deployment size for a vSphere VCSA appliance
                $vcsaSizes = @("tiny","small","medium","large")

                if ($vcsaSizes -notcontains $value) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # vcsaAppSize


            "folderPath" {

                ## Check that the data item is a valid IPv4 subnet mask length
                if (!(Test-Path $value)) {
                    Write-Warning ("Data item " + $value + " did not pass validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $false}
                } # if
                else {
                    Write-Verbose ("Data item " + $value + " passed validation for type " + $dataType)
                    return [pscustomobject]@{"dataItem" = $value; "dataType" = $dataType; "isValid" = $true}
                } # else

            } # folderPath


            default {
                throw ("No test defined for data type " + $dataType)
            } # default

        } # switch

    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end

} # function