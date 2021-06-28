function Initialize-PodNetworks {
    <#
    .SYNOPSIS
        Prepare host networking for a Podium deployment.

    .DESCRIPTION
        The function will perform the following prerequisite checks and configurations:
            * Podium switches.
            * Podium portgorups
            * Validate MAC learning capabilty on portgroups (credit to https://williamlam.com/2018/04/native-mac-learning-in-vsphere-6-7-removes-the-need-for-promiscuous-mode-for-nested-esxi.html)
            * Apply switches to target host.

    .PARAMETER vmHost
        The target host to apply networking to.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Initialize-PodNetworks -vmHost podesx.lab.local

        Apply necessary Podium switches to podesx.lab.local

    .LINK

    .NOTES
        01       24/06/21     Initial version.           A McNair
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$vmHost
    )

    begin {
        Write-Verbose ("Function start.")

    } # begin

    process {

        Write-Verbose ("Processing host " + $vmHost)

        ## Get VM host object
        Write-Verbose ("Getting VM host object.")

        try {
            $vmHost = Get-VMHost -Name $vmhost -ErrorAction Stop
            Write-Verbose ("Got VM host object.")
        } # try
        catch {
            throw ("Failed to get host object. " + $_.exception.message)
        } # catch


        ## Fetch datacenter for this host
        Write-Verbose ("Querying parent datacenter for this host.")

        try {
            $datacenter = Get-Datacenter -VMHost $vmHost -ErrorAction Stop
            Write-Verbose ("Datacenter is " + $datacenter.Name)
        } # try
        catch {
            throw ("Failed to get host object. " + $_.exception.message)
        } # catch

        ## Use null coalescing to ensure presence of the Pod switch
        Write-Verbose ("Configuring Pod switches POD-DVS01 and POD-DVS02.")

        try {
            $vds01 = (Get-VDSwitch -Name POD-DVS01 -ErrorAction SilentlyContinue) ?? (New-VDSwitch -Name POD-DVS01 -Location $datacenter.Name -ErrorAction Stop)
            $vds02 = (Get-VDSwitch -Name POD-DVS02 -ErrorAction SilentlyContinue) ?? (New-VDSwitch -Name POD-DVS02 -Location $datacenter.Name -ErrorAction Stop)

            Write-Verbose ("Pod switches are configured for datacenter " + $datacenter.name)
        } # try
        catch {
            throw ("DVS configuration failed. " + $_.exception.message)
        } # catch


        ## Set 9000 MTU on POD-DVS02
        Write-Verbose ("Configuring POD-DVS02 with MTU 9000.")
        try {
            $vds02 = $vds02 | Set-VDSwitch -Mtu 9000

            Write-Verbose ("MTU 9000 set.")
        } # try
        catch {
            throw ("DVS MTU configuration failed. " + $_.exception.message)
        } # catch


        ## Use null coalescing to ensure presence of the Podium portgroups
        Write-Verbose ("Configuring Pod portgroups.")

        try {
            $pg01 = (Get-VDPortGroup -Name MTU1500 -ErrorAction SilentlyContinue) ?? ($vds01 | New-VDPortgroup -Name MTU1500 -ErrorAction Stop)
            $pg02 = (Get-VDPortGroup -Name MTU9000 -ErrorAction SilentlyContinue) ?? ($vds02 | New-VDPortgroup -Name MTU9000 -ErrorAction Stop)

            Write-Verbose ("Podium portgroups configured.")
        } # try
        catch {
            throw ("Portgroup configuration failed. " + $_.exception.message)
        } # catch


        ## Ensure MAC learning, forge transmit and mac changes are enabled on each portgroup
        ## https://williamlam.com/2018/04/native-mac-learning-in-vsphere-6-7-removes-the-need-for-promiscuous-mode-for-nested-esxi.html
        Write-Verbose ("Configuring MAC learning on Podium portgroups.")

        $spec = New-Object VMware.Vim.DVPortgroupConfigSpec
        $dvPortSetting = New-Object VMware.Vim.VMwareDVSPortSetting
        $macMmgtSetting = New-Object VMware.Vim.DVSMacManagementPolicy
        $macLearnSetting = New-Object VMware.Vim.DVSMacLearningPolicy
        $macMmgtSetting.MacLearningPolicy = $macLearnSetting
        $dvPortSetting.MacManagementPolicy = $macMmgtSetting
        $spec.DefaultPortConfig = $dvPortSetting

        foreach ($pg in @($pg01,$pg02)) {

            Write-Verbose ("Configuring portgroup " + $pg.name)

            $spec.ConfigVersion = $pg.ExtensionData.Config.ConfigVersion

            $macMmgtSetting.AllowPromiscuous = $false
            $macMmgtSetting.ForgedTransmits = $true
            $macMmgtSetting.MacChanges = $true
            $macLearnSetting.Enabled = $true
            $macLearnSetting.AllowUnicastFlooding = $true
            $macLearnSetting.LimitPolicy = "DROP"
            $macLearnsetting.Limit = "4096"

            $task = $pg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
            $task1 = Get-Task -Id ("Task-$($task.value)")
            $task1 | Wait-Task | Out-Null

            Write-Verbose ("Completed configuring portgroup.")
        } # foreach

        Write-Verbose ("Completed host.")


        ## Check if this switch has already been applied to this host.

        foreach ($vds in @($vds01,$vds02)) {

            if (!($vds | Get-VMHost -Name $vmHost -ErrorAction SilentlyContinue)) {
                Write-Verbose ($vds.name + " is not applied to host, it will be applied.")

                try {
                    Add-VDSwitchVMHost -VDSwitch $vds -VMHost $vmHost -ErrorAction Stop | Out-Null

                    Write-Verbose ("Switch has been applied to host.")
                } # try
                catch {
                    throw ("Failed to apply switch. " + $_.exception.message)
                } # catch
            } # if

        } # foreach

        Write-Verbose ("Host complete.")

    } # process

    end {
        Write-Verbose ("Function complete.")
    } # end

} # function