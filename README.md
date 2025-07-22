# FIDO2Passkey PowerShell Script

## Overview

This PowerShell script identifies Azure AD users who **do not** have FIDO2 security keys registered. It connects to Microsoft Graph, checks each user’s authentication methods, and generates a report. Optionally, you can export the results to a CSV file.

---

## Features

- Connects to Microsoft Graph API
- Filters users by domain (optional)
- Checks for FIDO2 authentication methods
- Outputs results to the console
- Optionally exports results to a timestamped CSV file

---

## Prerequisites

- PowerShell 7.x or later
- [Microsoft.Graph PowerShell module](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation)
- Azure AD permissions: `User.Read.All`, `UserAuthenticationMethod.Read.All`

---

## Usage

```powershell
# Basic usage (console output only)
.\fido2passkey.ps1

# Export results to CSV
.\fido2passkey.ps1 -ExportToCsv

# Filter users by domain and export to CSV
.\fido2passkey.ps1 -DomainFilter "contoso.com" -ExportToCsv

# Specify a custom output path for CSV
.\fido2passkey.ps1 -ExportToCsv -OutputPath "C:\Reports\FIDO2"
```

---

## Parameters

| Parameter      | Description                                                                 |
| -------------- | --------------------------------------------------------------------------- |
| `-ExportToCsv` | (Switch) Export results to a CSV file.                                      |
| `-OutputPath`  | (String) Directory path for the CSV file. Default: `C:\Tools\FIDO2`         |
| `-DomainFilter`| (String) Only include users with UPNs ending in this domain (e.g. contoso.com) |

---

## Output

- Console table of users without FIDO2 keys
- CSV file (if `-ExportToCsv` is used), named: `Users_Without_FIDO2_YYYY-MM-DD_HHmm.csv`

---

## Author

Robert Milner  
_Last Modified: 2025-07-22_

---
