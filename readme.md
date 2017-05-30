# Create Azure Active Directory Users with PowerShell

Create-AADUsers.PS1 is a PowerShell script used to create Azure Active Directiry users from Excel file

## Prerequisites
The script requires the following PowerShell libraries:
* Azure PowerShell
* Azure AD


## Excel spreadsheet

The Excel spreadsheet defines sttings of users to be created in Azure Active Directory.
If Group names are not set, only users are created.
If group names are specified, users will be added as member for all groups specified. Groups will be created if not existed

## Syntax

### To configure Alert Mail

```
    .\Create-AADUsers-Groups.ps1 -AADName <Azure-Admin-account> -AADPassword <AAD Admin account> -AADUserCSV c:\AADUsers.csv

```

