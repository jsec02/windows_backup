# ================================================================================
# =                                    BACKUP                                    =
# ================================================================================

[CmdletBinding(DefaultParameterSetName = 'Backup')]
param(
    [Parameter(ParameterSetName = 'Backup')]
    [string[]]$Targets,

    [Parameter(ParameterSetName = 'Integrity')]
    [switch]$Integrity,

    [Parameter(ParameterSetName = 'Stats')]
    [switch]$Stats
)

Set-StrictMode -Version Latest

function Get-BackupIntegrity {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [array]$Repositories
    )

    foreach ($Repository in $Repositories) {
        restic --repo $Repository check --read-data-subset=5%
    }
}

function Get-BackupStats {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [array]$Repositories
    )

    foreach ($Repository in $Repositories) {
        restic --repo $Repository stats --mode=raw-data
    }
}

function Invoke-ResticBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hostname,

        [Parameter(Mandatory=$true)]
        [string[]]$Repositories,

        [Parameter(Mandatory=$true)]
        [string]$Tag,

        [Parameter(Mandatory=$true)]
        [string[]]$Paths
    )

    $ValidatedPaths = @()

    foreach ($Path in $Paths) {
        # If path exists on system, append to paths array
        if (Test-Path -Path $Path) {
            $ValidatedPaths += $Path
        }
    }

    # If paths array is empty, return early
    if ($ValidatedPaths.Count -eq 0) {
        return
    }

    foreach ($Repository in $Repositories) {
        restic --repo $Repository backup $ValidatedPaths --tag $Tag
        # Group by hosts and tags to prevent path changes from creating orphaned snapshots
        restic --repo $Repository forget --host $Hostname --tag $Tag --keep-last 7 --group-by hosts,tags --prune
    }
}

function Invoke-Backup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hostname,

        [Parameter(Mandatory=$true)]
        [string[]]$Repositories,

        [string[]]$Targets
    )

    $Arguments = @('paths', $Hostname)

    if ($Targets) {
        $Arguments += $Targets
    }

    $Output = python "$HOME\parsers\inventory.py" $Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Inventory lookup failed"
    }

    foreach ($Line in $Output) {
        # Ignore $Parts[0], the sudo flag is not needed on windows
        $Parts = $Line -split ' '
        $Tag = $Parts[1]
        $Paths = $Parts[2..($Parts.Length - 1)]
        Invoke-ResticBackup -Hostname $Hostname -Repositories $Repositories -Tag $Tag -Paths $Paths
    }
}

function Invoke-Main {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Mode,

        [string[]]$Targets
    )

    $Repositories = @($Env:R1, $Env:R2)

    $Hostname = $Env:COMPUTERNAME.ToLowerInvariant()

    if ($Targets) {
        $Targets = $Targets.ToLowerInvariant()
    }

    switch ($Mode) {
        'Integrity' {
            Get-BackupIntegrity -Repositories $Repositories
        }
        'Stats' {
            Get-BackupStats -Repositories $Repositories
        }
        'Backup' {
            Invoke-Backup -Hostname $Hostname -Repositories $Repositories -Targets $Targets
        }
    }
}

Invoke-Main -Mode $PSCmdlet.ParameterSetName -Targets $Targets
