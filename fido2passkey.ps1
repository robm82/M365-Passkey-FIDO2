<#
.SYNOPSIS
    Identifies Azure AD users without FIDO2 security keys configured.
.DESCRIPTION
    This script connects to Microsoft Graph and generates a report of users 
    who haven't registered FIDO2 security keys for authentication.
.PARAMETER OutputPath
    The path where the CSV report will be saved. Default: C:\Tools\FIDO2
.PARAMETER ExportToCsv
    Switch to export results to CSV.
.PARAMETER DomainFilter
    Only include users with UPNs ending in this domain (e.g. contoso.com).
.EXAMPLE
    .\fido2passkey.ps1 -ExportToCsv
.EXAMPLE
    .\fido2passkey.ps1 -DomainFilter "contoso.com" -ExportToCsv
.EXAMPLE
    .\fido2passkey.ps1 -DomainFilter "contoso.com" -ExportToCsv -OutputPath "C:\Reports\FIDO2"
.NOTES
    Version: 1.1
    Author: Robert Milner
    Last Modified: 2025-07-25
#>



[CmdletBinding()]
param(
    [Parameter(HelpMessage="Directory for CSV export.")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = "C:\Tools\FIDO2",

    [Parameter(HelpMessage="Export results to CSV.")]
    [switch]$ExportToCsv,

    [Parameter(HelpMessage="Filter users by domain (e.g. contoso.com)")]
    [string]$DomainFilter
)


# Ensure Microsoft.Graph module is installed and imported
$requiredVersion = "2.0.0"
try {
    $module = Get-Module -Name Microsoft.Graph -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module -or $module.Version -lt [version]$requiredVersion) {
        Write-Host "Installing/Updating Microsoft.Graph module..."
        Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -MinimumVersion $requiredVersion -ErrorAction Stop
    }
    Import-Module Microsoft.Graph -MinimumVersion $requiredVersion -ErrorAction Stop
} catch {
    Write-Error "Failed to install or import Microsoft.Graph module: $($_.Exception.Message)"
    exit 1
}


# Authenticate with Microsoft Graph
try {
    Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All" -NoWelcome -ErrorAction Stop
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    exit 1
}

# Get users based on domain filter if specified
try {
    if ($DomainFilter) {
        $filterDomain = if ($DomainFilter.StartsWith("@")) { $DomainFilter } else { "@$DomainFilter" }
        $allUsers = Get-MgUser -All -Filter "endsWith(userPrincipalName,'$filterDomain')" -ConsistencyLevel eventual -ErrorAction Stop
    } else {
        $allUsers = Get-MgUser -All -ErrorAction Stop
    }
} catch {
    Write-Error "Failed to retrieve users from Microsoft Graph: $($_.Exception.Message)"
    Disconnect-MgGraph | Out-Null
    exit 1
}


# Create an array to store users without FIDO2
$usersWithoutFido2 = @()

# Loop through each user
$i = 0
foreach ($user in $allUsers) {
    $i++
    Write-Progress "Checking FIDO2 Status" -Status $user.UserPrincipalName -PercentComplete (($i / $allUsers.Count) * 100)
    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $user.Id -ErrorAction Stop
        $hasFido2 = $methods | Where-Object {
            $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.fido2AuthenticationMethod'
        }
        if (-not $hasFido2) {
            $usersWithoutFido2 += [PSCustomObject]@{
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                ID                = $user.Id
            }
        }
    } catch {
        Write-Warning "Could not retrieve methods for $($user.UserPrincipalName): $($_.Exception.Message)"
        continue
    }
}


# Output results
if ($usersWithoutFido2.Count -eq 0) {
    Write-Host "All users have at least one FIDO2 security key registered." -ForegroundColor Green
} else {
    $usersWithoutFido2 | Sort-Object DisplayName | Format-Table -AutoSize
}

# Export to CSV if parameter is present
if ($ExportToCsv) {
    try {
        if (-not (Test-Path $OutputPath)) {
            New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
        }
        $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
        $outputFile = Join-Path -Path $OutputPath -ChildPath "Users_Without_FIDO2_$timestamp.csv"
        $usersWithoutFido2 | Export-Csv -Path $outputFile -NoTypeInformation
        Write-Host "Results exported to: $outputFile" -ForegroundColor Cyan
    } catch {
        Write-Error "Failed to export results to CSV: $($_.Exception.Message)"
    }
} else {
    Write-Host "CSV export skipped. Use -ExportToCsv parameter to export results."
}


# Always disconnect from Microsoft Graph
try {
    # Disconnect-MgGraph | Out-Null
    Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Yellow
} catch {
    Write-Warning "Could not disconnect from Microsoft Graph: $($_.Exception.Message)"
}
