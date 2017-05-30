## -------------------------------------------------------------------------------------------------------------
##
##
##      Description: AAD management
##
## DISCLAIMER
## The sample scripts are not supported under any HPE standard support program or service.
## The sample scripts are provided AS IS without warranty of any kind. 
## HP further disclaims all implied warranties including, without limitation, any implied 
## warranties of merchantability or of fitness for a particular purpose. 
##
##    
## Scenario
##     	Create users and groups in Azure Active Directory
##		
##
## Input parameters:
##	   AADname                            = Admin name of the AAD Domain
##         AADPassword                        = Administrator's password
##         UsersCSV                           = path to the CSV file containing users/group definition
##
## https://docs.microsoft.com/en-us/azure/active-directory/active-directory-accessmanagement-groups-settings-v2-cmdlets         
##
## History: 
##       April 2017   :  -First Release
##
## Version : 1.00
##
##
## -------------------------------------------------------------------------------------------------------------

[CmdletBinding()]

Param ( [string]$AaDUserCSV       = "AAd-Users.csv",  
        [string]$AADName          = "MASServiceAdmin@HPEAcademyCom.onmicrosoft.com", 
        [string]$AADPassword      = "P@ssword1",
        [string]$MASEnvironment   = "AzureStack",
        [string]$AzureEnvironment = "AzureCloud",
        [string]$MASToolsFolder   = "C:\Kits\AzureStack-Tools-master"
        
      )   



    $SepChar = '|'

    ## *****************************
    ## 
    ##      Main Entry
    ##

        ## Install Azure module
    if ( -not (get-module -listavailable | where name -match 'Azure'))
    {
        install-module AzureAD -scope CuurentUser -force -confirm:$false
        import-module AzureAD -verbose:$false  
    }
    
        ## Install Azure AD
    if ( -not (get-module -listavailable | where name -match 'AzureAD'))
    {
        install-module AzureAD -force -confirm:$false
        import-module AzureAD -verbose:$false
       
    }

    ## Process CSV file
    if ( -not (Test-path $AaDUserCSV ))
    {
        write-host -foreground CYAN "No file specified or file $AaDUserCSV does not exist."
        return
    }
   
    # Read the CSV Users file
    write-host -foreground CYAN "Importing the CSV file...."
    $tempFile = [IO.Path]::GetTempFileName()
    type $AaDUserCSV | where { ($_ -notlike ",,,,,,,*") -and ( $_ -notlike "#*") -and ($_ -notlike ",,,#*") } > $tempfile   # Skip blank line

    $ListofGroups    = @()

    $ListofUSers     = import-csv $tempfile | Sort Username
    write-host -foreground CYAN "Checking Azure Environment $AzureEnvironment...."
    if ( ( Get-AzureEnvironment | where Name -match $AzureEnvironment ) -eq $NULL)
    {
            write-host -foreground CYAN "The Azure Environment $AzureEnvironment does not exist. Pls specify an existing Azure environment"
            return
    }
    ## Login to Azure AD

    write-host -foreground CYAN "Login to Azure AD ...."
    $secpasswd      = ConvertTo-SecureString   $AADPassword -AsPlainText -Force
    $AADcreds       = New-Object System.Management.Automation.PSCredential ($AADName, $secpasswd)

    $ThisAdmin      = Connect-AzureAD -AzureEnvironment $AzureEnvironment -credential $AADCreds

    $ThisDomain     = Get-AzureADDomain                   # Assume there is only ONE domain

    $ThisDomainName = $ThisDomain.Name   

    $UPNTag         = "#EXT#@" + $ThisDomainName                 # Used for UserPrincipal Name format is: #EXT#@HPEAcademyCom.onmicrosoft.com

    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

    foreach ($U in $ListofUsers)
    {
        $User    = $U.Username.Trim()
        if ($User)
        {
            write-host  ""
            write-host -foreground CYAN "---------------------------------"
            write-host -foreground CYAN "  Working on user $User.....     " 
            write-host -foreground CYAN "---------------------------------"

            # User Principal Name
            if ( $User.Split('@')[1] -match $ThisDomainName)
            {
                $UPN = $User             # Username in the same domain as AAD
            }
            else
            {                           # Username in different domain for example: User1@outlook.com
                $UPN = $User -replace '@' , '_'
                $UPN = $UPN + $UPNTag
            }
            $ThisUser = Get-AzureADUser | where UserPrincipalName -match $UPN
            if ( -not $ThisUser )
            {
                # DisplayName
                $DisplayName = $U.DisplayName 

                # Enable account?
                $AccountEnabled = $U.AccountEnabled -eq 'Yes'

                # PasswordProfile
                $PasswordProfile.Password = $U.Password

                # User Type
                $UserType        = if ($U.UserType) {$U.UserType} else {'Guest'}

                $mailnickname    = 'NotSet'

                write-host -foreground CYAN  "Creating User $User "
                $ThisUser = New-AzureADUser -AccountEnabled $AccountEnabled -DisplayName $DisplayName -PasswordProfile $PasswordProfile `
                            -UserType $UserType -mailnickname $mailNickName  -UserPrincipalName $UPN
            }
            else
            {
                write-host -foreground YELLOW "User $User already exists. Skip it..."
            }

            $UserID   = $ThisUser.ObjectID

            # Collect group information
            $GroupName = $GDescription = $GMailEnabled = $GSecEnabled = @()
            
            if ($U.GroupName)
            {
                $GroupName     = $U.GroupName.Split($SepChar)
                $GDescription  = $U.G_Description.Split($SepChar)
                $GMailEnabled  = $U.G_MailEnabled.Split($SepChar) | % { $_ -eq 'Yes'} 
                $GSecEnabled   = $U.G_SecurityEnabled.Split($SepChar) | % { $_ -eq 'Yes'} 
                $mailNickName  = "NotSet" 

                for ($i=0;$i -lt $GroupName.Length; $i++)
                {
                    $ThisGroup = Get-AzureADGroup -SearchString $GroupName[$i]
                    if (-not $ThisGroup)
                    {
                        write-host -foreground CYAN  "Creating group $($Groupname[$i]) "
                        $ThisGroup = new-azureadgroup -displayname  $GroupName[$i] -description $Gdescription[$i] -MailEnabled $GMailEnabled[$i]  -SecurityEnabled $GSecEnabled[$i] -mailnickname $mailNickName
                    }

                    $GroupId = $ThisGroup.ObjectID
                    $ListofMembers = Get-AzureAdGroupMember -ObjectID $GroupID | where  ObjectID -match $UserID 
                    if (-not $ListofMembers)
                    {
                        write-host -foreground CYAN  "Adding user $User to $($ThisGroup.DisplayName) "
                        Add-AzureAdGroupMember -ObjectID $GroupID -RefObjectId $UserID
                    }
                    else
                    {
                        write-host -foreground YELLOW  "User $User is already member of group $($ThisGroup.DisplayName)"
                    }
                }

            }
        }
    }

## New-AzureADUser -AccountEnabled $True -DisplayName "dOUG" -PasswordProfile $PasswordProfile -mailnickname 'NotSet'  -UserPrincipalName "Test2_outlook.comm#EXT#@HPEAcademyCom.onmicrosoft.com
