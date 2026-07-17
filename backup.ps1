# ================================================================================
# =                                    BACKUP                                    =
# ================================================================================

param (
    [string]$Action
)

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

function Main {
    $Repositories = @($Env:R1, $Env:R2)

    switch ($Action.ToLower()) {
        "integrity" {
            Get-BackupIntegrity $Repositories
        }
        "stats" {
            Get-BackupStats $Repositories
        }
        default {
            Write-Host "Did not chose anything"
        }
    }
}

Main

# python "$HOME/parsers/inventory.py" paths windows
