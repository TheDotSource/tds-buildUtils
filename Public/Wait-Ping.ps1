function Wait-Ping {
    <#
    .SYNOPSIS
        Basic function to wait for a ping response. Throw if none received within the specified timeout.

    .DESCRIPTION
        Basic function to wait for a ping response. Throw if none received within the specified timeout.

    .PARAMETER target
        The target address to wait for a ping response from.

    .PARAMETER timeout
        Tiemout in seconds.

    .INPUTS
        System.String. The target to test.

    .OUTPUTS
        None.

    .EXAMPLE
        Wait-Ping -target 10.10.1.100 -timeout 100

        Wait on 10.10.1.100 to respond to a ping requets for up to 100 seconds.

    .LINK

    .NOTES
        01           Alistair McNair          Initial version.

    #>

    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$target,
        [parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [int]$timeout
      )

    begin {

        Write-Verbose ("Function start.")

    } # begin

    process {

            Write-Verbose ("Processing target " + $target)

            ## Initialise a start time
            $startTime = Get-Date

            ## Begin connection test
            while (!(Test-Connection -TargetName $target -Quiet -Count 1)) {

                Write-Verbose ("Waiting for reply.")

                Start-Sleep 5

                ## Check if timeout has been exceeded
                if ($startTime -lt (Get-Date).AddSeconds(-$timeout)) {
                    throw ("Failed to get a response from " + $target + " within the specified timeout period - (" + $timeout + ") seconds.")
                } # if

            } # while

            Write-Verbose ("Received response from target after " + (New-TimeSpan -Start $startTime -End (Get-Date)).Seconds + " seconds.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function