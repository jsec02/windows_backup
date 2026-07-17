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
        [string[]]$Paths
    )

    Write-Host "$Tag $Paths From Invoke-ResticBackup"
}

function Backup-Targets {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hostname,

        [string[]]$Targets
    )

    $Arguments = @('paths', $Hostname)

    if ($Targets) {
        $Arguments += $Targets
    }

    $Output = python "$HOME/parsers/inventory.py" $Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "Inventory lookup failed"
    }

    foreach ($Line in $Output) {
        $Parts = $Line -split ' '
        $Tag = $Parts[0]
        $Paths = $Parts[1..($Parts.Length -1)]
        Invoke-ResticBackup -Tag $Tag -Paths $Paths
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
            Backup-Targets -Hostname $Hostname -Targets $Arguments
        }
    }
}

Invoke-Main -Arguments $Args
