# ================================================================================
# =                                    BACKUP                                    =
# ================================================================================

function Get-BackupIntegrity {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Repositories
    )

    foreach ($Repository in $Repositories) {
        restic --repo $Repository check --read-data-subset=5%
    }
}

function Get-BackupStats {
    param (
        [Parameter(Mandatory=$true)]
        [array]$Repositories
    )

    foreach ($Repository in $Repositories) {
        restic --repo $Repository stats --mode=raw-data
    }
}

function Invoke-ResticBackup {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tag,

        [Parameter(Mandatory=$true)]
        [string[]]$Paths,

        [Parameter(Mandatory=$true)]
        [string]$Hostname,

        [Parameter(Mandatory=$true)]
        [string[]]$Repositories
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
        restic --repo $Repository forget--host $Hostname --tag $Tag --keep-last 7 --group-by hosts,tags --prune
    }
}

function Backup-Targets {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hostname,

        [string[]]$Targets,

        [Parameter(Mandatory=$true)]
        [string[]]$Repositories
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
        $Parts = $Line -split ' '
        $Tag = $Parts[0]
        $Paths = $Parts[1..($Parts.Length -1)]
        Invoke-ResticBackup -Tag $Tag -Paths $Paths -Hostname $Hostname -Repositories $Repositories
    }
}

function Invoke-Main {
    param(
        [string[]]$Arguments
    )

    $Repositories = @($Env:R1, $Env:R2)
    
    $Hostname = $Env:COMPUTERNAME.ToLowerInvariant()

    if ($Arguments) {
        $Arguments = $Arguments.ToLowerInvariant()
    }

    switch ($Arguments[0]) {
        "integrity" {
            Get-BackupIntegrity -Repositories $Repositories
        }
        "stats" {
            Get-BackupStats -Repositories $Repositories
        }
        default {
            Backup-Targets -Hostname $Hostname -Targets $Arguments -Repositories $Repositories
        }
    }
}

Invoke-Main -Arguments $Args
