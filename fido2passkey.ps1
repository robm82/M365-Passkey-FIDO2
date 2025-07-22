<#
.SYNOPSIS
    Identifies Azure AD users without FIDO2 security keys configured.
.DESCRIPTION
    This script connects to Microsoft Graph and generates a report of users 
    who haven't registered FIDO2 security keys for authentication.
.PARAMETER OutputPath
    The path where the CSV report will be saved.
.NOTES
    Version: 1.0
    Author: Robert Milner
    Last Modified: 2025-07-22
#>


[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = "C:\Tools\FIDO2",
    
    [Parameter()]
    [switch]$ExportToCsv,
    
    [Parameter()]
    [string]$DomainFilter
)

# Check for Microsoft.Graph module
$requiredVersion = "2.0.0" # Specify your minimum required version
$module = Get-Module -Name Microsoft.Graph -ListAvailable
if (-not $module -or $module.Version -lt [version]$requiredVersion) {
    Write-Host "Installing/Updating Microsoft.Graph module..."
    Install-Module Microsoft.Graph -Scope CurrentUser -Force -AllowClobber -MinimumVersion $requiredVersion
}

# Authenticate with Microsoft Graph
Connect-MgGraph -Scopes "User.Read.All", "UserAuthenticationMethod.Read.All" -NoWelcome

# Get users based on domain filter if specified
if ($DomainFilter) {
    $allUsers = Get-MgUser -ConsistencyLevel eventual -Top 999 -Filter "endsWith(userPrincipalName,'$DomainFilter')"
} else {
    $allUsers = Get-MgUser -All
}

# Create an array to store users without FIDO2
$usersWithoutFido2 = @()

# Loop through each user
$i = 0
foreach ($user in $allUsers) {
    $i++
    Write-Progress "Checking FIDO2 Status" -Status $user.UserPrincipalName -PercentComplete (($i / $allUsers.Count) * 100)
    try {
        $methods = Get-MgUserAuthenticationMethod -UserId $user.Id

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
        Write-Warning "Could not retrieve methods for $($user.UserPrincipalName): $_"
    }
}

# Output results
$usersWithoutFido2 | Sort-Object DisplayName | Format-Table -AutoSize

# Export to CSV if parameter is present
if ($ExportToCsv) {
    # Check CSV path exists
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force
    }
    # Export results to CSV
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmm"
    $outputFile = Join-Path -Path $OutputPath -ChildPath "Users_Without_FIDO2_$timestamp.csv"
    $usersWithoutFido2 | Export-Csv -Path $outputFile -NoTypeInformation
    Write-Host "Results exported to: $outputFile"
} else {
    Write-Host "CSV export skipped. Use -ExportToCsv parameter to export results."
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null
Write-Host "Disconnected from Microsoft Graph."
