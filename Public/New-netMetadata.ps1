function New-netMetadata {
    <#
    .SYNOPSIS
        Issue an IP, subnet mask or gateway sourced from a definition file.

    .DESCRIPTION
        Issue an IP, subnet mask or gateway sourced from a definition file.

    .PARAMETER definitionFile
        The json file containing the network schema.

    .PARAMETER action
        The type of IP to return from the requested network (new IP allocation, gateway IP etc).

    .PARAMETER netName
        The name of the network to allocate from.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-netMetadata -definitionFile C:\StackBuild\Builds\vsan-small-70\networks.json -action netId -netName pod-mgmt

        Fetch the network ID for network pod-mgmt from networks.json

    .EXAMPLE
        New-netMetadata -definitionFile C:\StackBuild\Builds\vsan-small-70\networks.json -action newIP -netName pod-mgmt

        Allocate the next available IP from pod-mgmt using networks.json. The allocated addresses in networks.json will be updated.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact="Low")]
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [String]$definitionFile,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [ValidateSet("newIP","gateway","netId","netMask")]
        [string]$action,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$netName

    )


    begin {

        Write-Verbose ("Function start.")
    } # begin


    process {

        ## Open networks defintion file
        try {
            $networks = Get-Content -Path $definitionFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            Write-Verbose ("Opened network definitions file at "+ $definitionFile)
        } # try
        catch {
            Write-Debug ("Failed to open network definition file.")
            throw ("Could not open network definitions file at "+ $definitionFile + ". The CMDlet returned: " + $_.exception.message)
        } # catch


        ## Get target network
        $targetNetwork = $networks | Where-Object {$_.networkName -eq $netname}

        ## Check this network name exists in our definition
        if (!$targetNetwork) {
            throw ("Network " + $netName + " was not found in the specified definition.")
        } # if


        switch ($action) {

            "newIP" {
                Write-Verbose ("Opened network definitions file at "+ $definitionFile)

                $ip1 = ([System.Net.IPAddress]$targetNetwork.rangestart).GetAddressBytes()
                [Array]::Reverse($ip1)
                $ip1 = ([System.Net.IPAddress]($ip1 -join '.')).Address


                $ip2 = ([System.Net.IPAddress]$targetNetwork.rangeEnd).GetAddressBytes()
                [Array]::Reverse($ip2)
                $ip2 = ([System.Net.IPAddress]($ip2 -join '.')).Address


                $availableAddresses = @()


                ## Calculate addresses in this range
                for ($x=$ip1; $x -le $ip2; $x++) {

                    $ip = ([System.Net.IPAddress]$x).GetAddressBytes()
                    [Array]::Reverse($ip)

                    $availableAddresses += $ip -join '.'

                } # for


                ## Sort and filter to get next address
                $nextAddress = $availableAddresses | Where-Object {$targetNetwork.addressAllocations -notcontains $_} | Select-Object -First 1

                Write-Verbose ("" + $nextAddress + " is the next available address.")


                ## Save this back to allocated addresses
                $targetNetwork.addressAllocations += $nextAddress


                ## Save allocations to originating JSON
                Write-Verbose ("Saving network state to originating JSON.")

                try {
                    $networks | ConvertTo-Json | Out-File -FilePath $definitionFile -Force -ErrorAction Stop
                    Write-Verbose ("State saved.")
                } # try
                catch {
                    Write-Debug ("Failed to save state.")
                    throw ("Failed to save network state to network configuration file. " + $_.exception.message)
                } # catch

                return $nextAddress

            } # newIP


            "gateway" {

                Write-Verbose ("Getting default gateway for specified network.")

                return $targetNetwork.gateway

            } # getGateway

            "netId" {

                Write-Verbose ("Getting network ID for specified network.")

                return $targetNetwork.netid

            } # netId

            "netMask" {

                Write-Verbose ("Getting subnet mask for specified network.")

                return $targetNetwork.netmask

            } # netMask

            default {
                throw ("Unknown action specified: " + $action)

            } # default

        } # switch


    } # process


    end {

        Write-Verbose ("Function complete.")
    } # end

} # function