function Write-BuildLog {
    <#
    .SYNOPSIS
        Send information, verbose, warning and error data to a log.

    .DESCRIPTION
        This function can be added to the end of a pipeline. It will filter off output streams of type Verbose, Error and Warning.
        These outputs are sent to the specified log file.

        If an object is piped into this funtion, the type is logged, and the object returned.

    .PARAMETER logItem
        Input from pipeline to filter streams from.

    .PARAMETER logPath
        The path to the log file to write entries to.

    .PARAMETER functionName
        The name of the function that should be recorded against the log entry.

    .INPUTS
        System.Object. Any pipeline input from the preceding function.

    .OUTPUTS
        System.Object. The function returns any object that is not Verbose, Error or Warning.

    .EXAMPLE
        Connect-ViServer -Server pod.lab.local -Credental $creds -Verbose | Write-Log -logPath c:\log\build.log -functionName Connect-ViServer

        Log output from the Connect-ViServer to build.log CMDlet and return the connection object.

    .LINK

    .NOTES
        01       27/05/20     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [System.Object]$logItem,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$logPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false)]
        [string]$functionName
    )

    begin {

    } # begin

    process {

            switch ($logItem) {

                {$_.Gettype().fullname -eq "System.Management.Automation.VerboseRecord"} {
                    $streamMessage =  ("[" + (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + "][" + $functionName + "][VERBOSE]" + $_.message)
                } # verbose stream

                {$_.Gettype().fullname -eq "System.Management.Automation.ErrorRecord"} {
                    $streamMessage =  ("[" + (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + "][" + $functionName + "][ERROR]" + $_.exception.Message)
                } # error stream

                {$_.Gettype().fullname -eq "System.Management.Automation.WarningRecord"} {
                    $streamMessage =  ("[" + (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + "][" + $functionName + "][WARNING]" + $_.message)
                } # warning stream

                default {

                    ## If actual object then log and return this
                    ("[" + (Get-Date -Format "yyyy-MM-ddTHH:mm:ss") + "][" + $functionName + "][STDOUT]Function returned standard output of type " + $_.gettype().fullname) | Out-File -FilePath $logPath -Append -Force
                    return $_

                } # default

            } # switch


            $streamMessage | Out-File -FilePath $logPath -Append -Force

    } # process


    end {

    } # end

} # function