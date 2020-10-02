### Azure Helpers ###

function Get-AzureCredentialFromUser()
{
    Write-Host "In order to fully deploy this solution, you'll need to be logged in with an account that is an admin `n" `
               "on an Azure subscription AND an admin on an Office 365 directory.  For more information, refer to the documentation.`n"

    Do
    {
        $UserCredential = Get-CredentialFromConsole

        # This handles the case where the user enters nothing or exits out of the Get-Credential prompt.
        if($UserCredential -eq $null)
        {
            Write-Host -ForegroundColor "ERROR: Cannot continue with blank credentials. Exiting the application."
            exit
        }

        $AuthResult = Login-AzureRmAccount -Credential $UserCredential -ErrorAction SilentlyContinue

        if($AuthResult -eq $null)
        {
            Write-Host -ForegroundColor Yellow "`nUnable to log in to Azure account."

            Do
            {
                Write-Host -ForegroundColor Yellow "Would you like to try again? (Y/N)"
                $tryAgain = Read-Host
                $tryAgain = $tryAgain.ToLower()

                if($tryAgain -ne "y" -and $tryAgain -ne "n")
                {
                    Write-Host -ForegroundColor Yellow "Invalid input.  Please enter Y or N.`n"
                }

                if($tryAgain -eq "n")
                {
                    Write-Host -ForegroundColor Red "Quitting the application.  You must be logged in to proceed with the deployment."
                    exit
                }
            }
            While($tryAgain -ne "y")
        }
        else
        {
            return $UserCredential
        }
     }
     While($AuthResult -eq $null -and $tryAgain -eq "y")
}

function Login-AzureAccount([PSCredential]$creds)
{
	$loggedIn = $true;
	
	Try
	{
		$context = Get-AzureRmContext -ErrorAction SilentlyContinue
		$subscription = Get-AzureRmSubscription -ErrorAction SilentlyContinue
		$loggedIn = (($context -ne $null) -and ($subscription -ne $null));
	}
	Catch
	{
		$loggedIn = $false
	}	

	if (-not $loggedIn)
	{
		$azAccount = Login-AzureRmAccount -Credentials $creds -ErrorAction Stop
	}

    Select-Subscription

    return $azAccount
}

function Select-Subscription()
{
    $associatedSubscriptions = Get-AzureRmSubscription | where { $_.State -eq "Enabled" }
    $choice = -1

    if($associatedSubscriptions.Length -gt 1)
    {
        Write-Host "Your account is associated with multiple Azure Subscriptions."

        while($choice -eq -1)
        {
            Write-Host "Please choose the subscription that you'd like to deploy to.`n"
            $count = 1

            foreach($subscription in $associatedSubscriptions)
            {
                Write-Host "[$count]: $($subscription.Name) - $($subscription.Id)"
                $count++
            }

            $input = Read-Host -Prompt "`nSubscription"

            if([int32]::TryParse($input, [ref]$choice))
            {
                if($choice -gt 0 -and $choice -le $associatedSubscriptions.length)
                {
                    $choice -= 1;
                }
                else
                {
                    Write-Warning "Invalid selection. Please select an option between 1 and $($associatedSubscriptions.length).`n"
                    $choice = -1;
                }
            }
            else
            {
                Write-Warning "Invalid selection.  Please select an option between 1 and $($associatedSubscriptions.length).`n"
                $choice = -1;
            }
        }

      }

    Write-Info "Using Subscription $($associatedSubscriptions[$choice].Name) - $($associatedSubscriptions[$choice].Id)."
	Select-AzureRmSubscription -SubscriptionId $associatedSubscriptions[$choice].Id
}

function Validate-UserIsAzureGlobalAdmin()
{
	$loginId = (Get-AzureRMContext).Account.Id
	$adminUserRoles = Get-AzureRMRoleAssignment -RoleDefinitionName "ServiceAdministrator" -IncludeClassicAdministrators | where { $_.SignInName -eq $loginId -and $_.RoleDefinitionName.Contains("ServiceAdministrator") }

	if ($adminUserRoles -eq $null)
	{
		Write-Error "This account is not the Global Admin of the Azure Subscription specified.  This script must be run as the Global Admin."
	}
}

function Select-SupportedResourceGroupLocations()
{
	$supportedLocations = "East US 2", "North Central US", "South Central US", "West Central US", "West US"
	$choice = -1

	if ($supportedLocations.length -gt 1)
	{
		while ($choice -eq -1)
		{
			Write-Host "Please choose which Azure region you'd like to deploy to.  You should try and use a region near you for optimal performance.`n"

			$count = 1;
			foreach ($location in $supportedLocations)
			{
				Write-Host "[$count]: $location"
				$count++;
			}

			$input = Read-Host -Prompt "`nResource Group Location"

			if ([int32]::TryParse($input, [ref]$choice))
			{
				if ($choice -gt 0 -and $choice -le $supportedLocations.length)
				{
					$selectedLocation = $supportedLocations[$choice-1]
					#Write-Success "Using Resource Group Location $selectedLocation."
					return $selectedLocation
				}

				else
				{
                    Write-Warning "Invalid selection.  Please select an option between 1 and $($supportedLocations.length).`n"
					$choice = -1;
				}
			}

			else
			{
                Write-Warning "Invalid selection.  Please select an option between 1 and $($supportedLocations.length).`n"
				$choice = -1;
			}
		}
	}
}

function Get-AzureResourceGroupName()
{
    Write-Host "`nEnter the resource group you'd like to deploy to. This can either be a new or existing resource group."

    return( Read-Host -Prompt "Resource Group Name" )
}

# All Azure cmdlets support resource group names in all lowercase with no whitespace.  Some Azure cmdlets
# support them in the format of "South Central US", but it's safer to format them all.
function Format-ResourceGroupLocation([string]$resourceGroupName)
{   
    $convertedName = $resourceGroupName -replace '\s', ''
    
    return $convertedName.ToLower()
}

function Get-AzureResourceGroupLocation([string]$resourceGroupName)
{
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue

    if(!$resourceGroup)
    {
        Write-Info "$resourceGroupName does not exist. We'll create it now.`n"
        $resourceGroupLocation = Format-ResourceGroupLocation( Select-SupportedResourceGroupLocations )
        $resourceGroup = New-AzureRmResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation

        Write-Info "Resource group $resourceGroupName has been created in location $resourceGroupLocation."
    }
    else
    {
        Write-Info "The resource group you entered, $resourceGroupName, already exists. All resources will be deployed here."
    }

    return $resourceGroup.Location.ToString()
}

function Get-AzureAnalysisServicesName()
{
    Write-Host "`nEnter the name for the Azure Analysis Services instance.  This will be part of the Azure AS connection string."

    $validName = $false
    $aasName = ""

    while(!$validName)
    {
        $aasName = Read-Host -Prompt "Azure Analysis Services Name"

        if(!($aasName -cmatch "^[a-z][a-zA-Z0-9]{2,62}$"))
        {
            Write-Warning "Invalid name.  The Analysis Services name must be lowercase alphanumeric, begin with a letter, and be between 3 and 63 characters with no spaces.`n"
        }
        else
        {
            if(Test-AzureRmAnalysisServicesServer -Name $aasName)
            {
                Write-Warning "That name is already being used.  Please enter a new, unique name.`n"
            }
            else
            {
                $validName = $true
            }
        }
    }

    return $aasName
}

function Get-AzureAnalysisServicesTier()
{
    $availableTiers = "D1", "B1", "B2", "S0", "S1", "S2", "S4"
    $choice = -1

	while ($choice -eq -1)
	{
		Write-Host "`nChoose the tier that you'd like to run Azure Analysis Services on.  For more information, visit https://azure.microsoft.com/en-us/pricing/details/analysis-services/.`n"

		$count = 1;
		foreach ($tier in $availableTiers)
		{
			Write-Host "[$count]: $tier"
			$count++;
		}
			
        $input = Read-Host -Prompt "`nAnalysis Services Tier"

		if ([int32]::TryParse($input, [ref]$choice))
		{
			if ($choice -gt 0 -and $choice -le $availableTiers.length)
			{
				$selectedTier = $availableTiers[$choice-1]
				Write-Info "Using tier $selectedTier for Azure Analysis Services."
				return $selectedTier
			}
				else
			{
                   Write-Warning "Invalid selection.  Please select an option between 1 and $($availableTiers.length).`n"
				$choice = -1;
			}
		}
	    else
		{
               Write-Warning "Invalid selection.  Please select an option between 1 and $($availableTiers.length).`n"
			$choice = -1;
		}
	}
}

### Azure Automation Account ###

function Create-AppCredentials([guid]$KeyId)
{
    $password = [guid]::NewGuid()
    $secpasswd = ConvertTo-SecureString $password -AsPlainText -Force
    $PSCredential = New-Object System.Management.Automation.PSCredential($keyId, $secpasswd)

    Import-Module AzureRM.Resources -DisableNameChecking -Force
    $PSADCredential = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADPasswordCredential
    $PSADCredential.Password = $password
    $PSADCredential.KeyId = $KeyId
    $PSADCredential.StartDate = (Get-Date)
    $PSADCredential.EndDate = (Get-Date).AddYears(5)

    return @{
        "PSCredential" = $PSCredential
        "PSADCredential" = $PSADCredential
    }
}

function Create-AzureADAppAndServicePrincipal([string]$resourceGroupName, [string]$automationAccountName)
{
    $servicePrincipalCredential = Create-AppCredentials ([guid]::NewGuid())
    $application = New-AzureRMADApplication -DisplayName $automationAccountName -IdentifierUris "https://$resourceGroupName-$automationAccountName"

    Sleep-WithMessage -message "Waiting for Active Directory to provision resources.." -secondsRemaining 60 -timerStopPoint 30
    
    $servicePrincipal = New-AzureRMADServicePrincipal -ApplicationId $application.ApplicationId -PasswordCredentials $servicePrincipalCredential.PSADCredential

    Sleep-WithMessage -message "Waiting for Active Directory to provision resources.." -secondsRemaining 30 -timerStopPoint 0

    Get-AzureRmADServicePrincipal -ObjectId $servicePrincipal.Id
    New-AzureRMRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $application.ApplicationId

    Sleep-WithMessage -message "Waiting for Active Directory permissions to propagate.." -secondsRemaining 30 -timerStopPoint 0

    New-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "AAS Service Principal" -Value $servicePrincipalCredential.PSCredential
}

function Create-RefreshRunbook([string]$resourceGroupName, [string]$resourceGroupLocation, [string]$automationAccountName, [string]$analysisServicesName)
{
    $refreshRunbook = Import-AzureRmAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$(($analysisServicesName).substring(0,6))-AnalysisServices-Refresh" `
                                                       -Type "PowerShell" -Path $PSScriptRoot\AnalysisServicesRefreshRunbook.ps1 
    
    Publish-AzureRmAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$(($analysisServicesName).substring(0,6))-AnalysisServices-Refresh"                    
    
    $weekdays = ([System.DayOfWeek]::Monday),([System.DayOfWeek]::Tuesday),([System.DayOfWeek]::Wednesday),([System.DayOfWeek]::Thursday),([System.DayOfWeek]::Friday)
    $refreshScheduleParameters = @{"serverName"=$analysisServicesName; "databaseName"="EdFi-Data-Analytics-Ods"; "resourceGroupLocation"=$resourceGroupLocation}

    $refreshSchedule = New-AzureRmAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Weekday Mornings Refresh" `
                                                     -WeekInterval 1 -DaysOfWeek $weekdays -StartTime (Get-Date "07:15:00").AddDays(1) -TimeZone ([System.TimeZone]::CurrentTimeZone.StandardName) `
                                                     -Description "Set for 7:15AM every weekday to refresh Analysis Services."

    Register-AzureRmAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -RunbookName $refreshRunbook.Name `
                                               -ScheduleName $refreshSchedule.Name -Parameters $refreshScheduleParameters
}

function Create-SchedulerRunbook([string]$resourceGroupName, [string]$automationAccountName, [string]$analysisServicesName)
{
    $schedulerRunbook = Import-AzureRmAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$(($analysisServicesName).substring(0,6))-AnalysisServices-Scheduler" `
                                                        -Type "PowerShell" -Path $PSScriptRoot\AnalysisServicesSchedulerRunbook.ps1

    Publish-AzureRmAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$(($analysisServicesName).substring(0,6))-AnalysisServices-Scheduler"

    $weekdays = ([System.DayOfWeek]::Monday),([System.DayOfWeek]::Tuesday),([System.DayOfWeek]::Wednesday),([System.DayOfWeek]::Thursday),([System.DayOfWeek]::Friday)

    $morningScheduleParameters = @{"action"="resume"; "resourceGroupName"=$resourceGroupName; "serverName"=$analysisServicesName}
    $eveningScheduleParameters = @{"action"="suspend"; "resourceGroupName"=$resourceGroupName; "serverName"=$analysisServicesName}

    $morningSchedule = New-AzureRmAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Weekday Mornings Start" `
                                                     -WeekInterval 1 -DaysOfWeek $weekdays -StartTime (Get-Date "07:00:00").AddDays(1) -TimeZone ([System.TimeZone]::CurrentTimeZone.StandardName) `
                                                     -Description "Set for 7:00AM every weekday to start Analysis Services."
    $eveningSchedule = New-AzureRmAutomationSchedule -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "Weekday Evenings Stop" `
                                                     -WeekInterval 1 -DaysOfWeek $weekdays -StartTime (Get-Date "19:00:00").AddDays(1) -TimeZone ([System.TimeZone]::CurrentTimeZone.StandardName) `
                                                     -Description "Set for 7:00PM every weekday to pause Analysis Services."

    Register-AzureRmAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -RunbookName $schedulerRunbook.Name `
                                               -ScheduleName $morningSchedule.Name -Parameters $morningScheduleParameters
    Register-AzureRmAutomationScheduledRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -RunbookName $schedulerRunbook.Name `
                                               -ScheduleName $eveningSchedule.Name -Parameters $eveningScheduleParameters
}

function Deploy-AzureAutomationAccount([string]$resourceGroupName, [string]$resourceGroupLocation, [string]$analysisServicesName)
{
    Try
    {
        $automationAccount = New-AzureRmAutomationAccount -ResourceGroupName $resourceGroupName -Location $resourceGroupLocation -Name "$(($analysisServicesName).substring(0,6))-AnalysisServices-Automation" -ErrorAction Stop
        Create-SchedulerRunbook $resourceGroupName $automationAccount.AutomationAccountName $analysisServicesName
        Create-RefreshRunbook $resourceGroupName $resourceGroupLocation $automationAccount.AutomationAccountName $analysisServicesName

        Create-AzureADAppAndServicePrincipal $resourceGroupName $automationAccount.AutomationAccountName

    }
    Catch
    {
        Write-Error "Failed to deploy the Azure Automation Account."
        Rollback-Deployment
    }
}

### SDS Sync Helpers ###

function Create-EWSGroups([PSCredential]$creds)
{
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $creds -Authentication Basic -AllowRedirection
    Import-PSSession $session -DisableNameChecking

    # Handle the case that Get-Credential doesn't return a proper username.  This will be passed along to the New-UnifiedGroup commands below.
    if($creds.UserName -eq $null)
    {
        Write-Host -ForegroundColor Yellow "WARNING: The username could not be validated."
        $username = Read-Host -Prompt "Enter the username for the Owner of each Office 365 Group"
    }
    else
    {
        $username = $creds.UserName
    }

    Try
    {
        $districtGroupExists = Get-UnifiedGroup -Identity "edfiewsdistrictadmins" -ErrorAction SilentlyContinue
        $schoolGroupExists = Get-UnifiedGroup -Identity "edfiewsschooladmins" -ErrorAction SilentlyContinue
        $teacherGroupExists = Get-UnifiedGroup -Identity "edfiewsteachers" -ErrorAction SilentlyContinue

        if($districtGroupExists -ne $null)
        {
            Write-Host "Ed-Fi EWS District Admins group already exists in this Office 365 tenancy."
        }
        else
        {
            New-UnifiedGroup -AccessType Public -Alias "edfiewsdistrictadmins" -DisplayName "Ed-Fi EWS District Admins" -HiddenGroupMembershipEnabled -Name "Ed-Fi EWS District Admins" `
                                -Owner $username
            Write-Host "Created the Ed-Fi EWS District Admins group."
        }
        
        if($schoolGroupExists -ne $null)
        {
            Write-Host "Ed-Fi EWS School Admins group already exists in this Office 365 tenancy."
        }
        else
        {
            New-UnifiedGroup -AccessType Public -Alias "edfiewsschooladmins" -DisplayName "Ed-Fi EWS School Admins" -HiddenGroupMembershipEnabled -Name "Ed-Fi EWS School Admins" `
                                -Owner $username
            Write-Host "Created the Ed-Fi EWS School Admins group."
        }

        if($teacherGroupExists -ne $null)
        {
            Write-Host "Ed-Fi EWS Teachers group already exists in this Office 365 tenancy."
        }
        else
        {
            New-UnifiedGroup -AccessType Public -Alias "edfiewsteachers" -DisplayName "Ed-Fi EWS Teachers" -HiddenGroupMembershipEnabled -Name "Ed-Fi EWS Teachers" `
                                -Owner $username
            Write-Host "Created the Ed-Fi EWS Teachers group."
        }
    }
    Catch
    {
        Write-Host -ForegroundColor Red "Failed to create the Office 365 Groups. Please visit your Office 365 Admin Portal to determine if the groups were established."
        return $false
    }
}

function Get-AzureADAdminConsent([string]$tenantId, [string]$clientId, [string]$redirectUri, [string]$resource)
{
    Write-Host "`nIn order to query the Principal information from School Data Sync, you must grant permission to read the directory information.`n" `
                "You may remove the 'Ed-Fi EWS SDS Sync' application from your Azure Active Directory at any time after the completion of this script.`n"`
                "A browser window will open asking for your Azure Active Directory credentials.  When successful, you will be directed to the Ed-Fi homepage.`n" `
                "Please press any key to load the browser."
    Read-Host

    Start "https://login.microsoftonline.com/$tenantId/oauth2/authorize?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&resource=$resource&prompt=admin_consent"

    Write-Host "To continue, press any key."
    Read-Host
    Sleep-WithMessage "Waiting for API permissions to propagate..." 60 0
}

function Get-AzureADAuthenticationToken([string]$tenantId, [string]$clientId, [string]$clientSecret, [string]$resource)
{
    $body = @{
                "grant_type" = "client_credentials"
                "client_id" = $clientId
                "client_secret" = $clientSecret
                "resource" = $resource
              }

    Try
    {
        $result = Invoke-WebRequest -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/token" -Body $body -ContentType "application/x-www-form-urlencoded" -UseBasicParsing
    }
    Catch
    {
        Write-Error "Failed to call the Microsoft Graph API."
        return
    }

    return ($result | ConvertFrom-Json | Select -Expand access_token)
}

function Get-SDSPrincipals([string]$tenantId, [string]$token)
{
    $result = Invoke-WebRequest -Method Get -Uri "https://graph.microsoft.com/beta/$tenantId/administrativeUnits" -Headers @{"Authorization" = "Bearer $token"} -UseBasicParsing

    return $result
}

function Parse-SDSPrincipals($schoolInfo)
{
    $parsedInfo = $schoolInfo | ConvertFrom-Json | Select -Expand value
    $principalList = @()

    foreach($school in $parsedInfo | where {$_.extension_fe2174665583431c953114ff7268b7b3_Education_ObjectType -eq "School"})
    {
        $schoolPrincipal = $school.extension_fe2174665583431c953114ff7268b7b3_Education_SchoolPrincipalEmail
        $principalList += $schoolPrincipal
    }

    return $principalList
}

function Add-EWSTeacherGroupMembers()
{
    $listOfSchools = Get-MsolAdministrativeUnit | where {$_.DisplayName -like "*School*"}

    Write-Host "`nFound $($listOfSchools.Count) schools in the directory:"
    
    foreach($school in $listOfSchools)
    {
        Write-Host "- $($school.DisplayName)"
    }

    $totalCount = 0

    foreach($school in $listOfSchools)
    {
        $listOfTeachers = Get-MsolAdministrativeUnitMember -AdministrativeUnitObjectId $school.ObjectId
        $counter = 0
        $count = $listOfTeachers.Count
        $totalCount += $count

        foreach($teacher in $listOfTeachers)
        {
            Write-Progress -Activity "Adding $($teacher.EmailAddress) from $($school.DisplayName) to the Ed-Fi EWS Teachers group..." -Status "Progress" -PercentComplete (($counter/$count)*100)

            $teacherExists = Get-AzureADUser -ObjectId $teacher.ObjectId

            if($teacherExists -ne $null)
            {
                Try
                {
                    Add-UnifiedGroupLinks -Identity "edfiewsteachers" -LinkType Members -Links $teacher.EmailAddress
                }
                Catch
                {
                    Write-Host -ForegroundColor Yellow "Failed to add $($teacher.EmailAddress) to the Ed-Fi EWS Teachers group. Skipping."
                }
            }
            else
            {
                Write-Warning "$($teacher.DisplayName) does not exist in the Office 365 directory.  Skipping."
            }

            $teacherExists = $null
            $counter++
        }
    }

    Write-Progress -Activity "Adding Teachers to Ed-Fi EWS Teachers Group." -Completed
    Write-Host -ForegroundColor Gray "Added $totalCount teachers to the Ed-Fi EWS Teachers group."
}

function Add-EWSPrincipalGroupMembers([string]$tenantId, [string]$appId, [string]$clientSecret)
{
    Get-AzureADAdminConsent $tenantId $appId "https://www.ed-fi.org" "https://graph.microsoft.com"
    $authToken = Get-AzureADAuthenticationToken $tenantId $appId $clientSecret "https://graph.microsoft.com"
    $schoolInfo = Get-SDSPrincipals $tenantId $authToken
    $principalList = Parse-SDSPrincipals $schoolInfo

    $counter = 0
    $count = $princpalList.Count

    foreach($principal in $principalList)
    {
        Write-Progress -Activity "Adding $($principal) to the Ed-Fi EWS School Admins group..." -Status "Progress"

        $principalExists = Get-AzureADUser -SearchString $principal

        if($principalExists -ne $null)
        {
            Try
            {
                Add-UnifiedGroupLinks -Identity "edfiewsschooladmins" -LinkType Members -Links $principal
            }
            Catch
            {
                Write-Host -ForegroundColor Yellow "Failed to add $principal to the Ed-Fi School Admins group. Skipping."
            }
        }
        else
        {
            Write-Warning "$principal does not exist in the Office 365 directory.  Skipping."
        }

        $counter++
    }
    
    Write-Progress -Activity "Adding Principals " -Completed
    Write-Host -ForegroundColor Gray "Added $count principals to the Ed-Fi EWS School Admins group."   
}

function Create-SDSSyncApp()
{
    $keyId = [guid]::NewGuid()
    $keyPassword = [guid]::NewGuid()
    Import-Module AzureRM.Resources -DisableNameChecking -Force
    $keyCredential = New-Object  Microsoft.Open.AzureAD.Model.PasswordCredential
    $keyCredential.StartDate = (Get-Date)
    $keyCredential.EndDate = (Get-Date).AddYears(5)
    $keyCredential.KeyId = $keyId
    $keyCredential.Value = $keyPassword

    $graphUserAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "06da0dbc-49e2-44d2-8312-53f166ab848a"
            Type = "Scope"
        }
    
    $graphDirectoryAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "0e263e50-5827-48a4-b97c-d940288653c7"
            Type = "Scope"
        }        

    $aadUserAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "311a71cc-e848-46a1-bdf8-97ff7156d8e6"
            Type = "Scope"
        }

    $aadDirectoryAccess = [Microsoft.Open.AzureAD.Model.ResourceAccess]@{
            Id = "5778995a-e1bf-45b8-affa-663a9f3f4d04"
            Type = "Role,Scope"
        }

    $graphAccessScope = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
        ResourceAppId = "00000003-0000-0000-c000-000000000000"
        ResourceAccess = @($graphUserAccess, $graphDirectoryAccess)
    }

    $aadAccessScope = [Microsoft.Open.AzureAD.Model.RequiredResourceAccess]@{
        ResourceAppId = "00000002-0000-0000-c000-000000000000"
        ResourceAccess = @($aadUserAccess, $aadDirectoryAccess)
    }


    $requiredScope = @($graphAccessScope, $aadAccessScope)

    $application = New-AzureADApplication -DisplayName "Ed-Fi EWS SDS Sync" -IdentifierUris "https://edfisdssync" -HomePage "https://www.ed-fi.org" -ReplyUrls "https://www.ed-fi.org" `
                                            -PasswordCredentials $keyCredential -RequiredResourceAccess $requiredScope
    
    # For some reason, $application.ApplicationId does not match the GUID in the Azure Portal, so we must query it separately.
    $applicationOBject = Get-AzureADApplication -SearchString "Ed-Fi EWS SDS Sync"

    Write-Host -ForegroundColor Gray "Created the Ed-Fi EWS SDS Sync application in Azure AD."

    Sleep-WithMessage "Waiting for Azure Active Directory permissions to propagate..." 60 0

    return @{
             "AppId" = $applicationObject.AppId
             "AppName" = $applicationObject.DisplayName
             "AppCredential" = $keyPassword
            }
}

function Populate-SDSTeachersAndPrincipalsInO365Groups([PSCredential]$creds, [string]$tenantId)
{
    while( ($sdsResponse -ne "n") -and ($sdsResponse -ne "y") )
    {
        $sdsResponse = Read-Host -Prompt "`nDid you load teachers and principals through the SDS (School Data Sync) tool? (Y/N)"
        $sdsResponse = $sdsResponse.ToLower()

        if( ($sdsResponse -ne "n") -and ($sdsResponse -ne "y") )
        {
            Write-Host -ForegroundColor Yellow "Invalid input. Please enter either Y or N."
        }
    }

    Try
    {
        Connect-MsolService -Credential $creds -ErrorAction Stop
    }
    Catch
    {
        Write-Host -ForegroundColor Yellow "WARNING: Unable to connect to Microsoft Online service.  Trying again.."
        
        Try
        {
            Connect-MsolService -Credential $creds -ErrorAction Stop
        }
        Catch
        {
            Write-Host -ForegroundColor Red "ERROR: Unable to connect to Microsoft Online service after multiple attempts. Make sure that you are an admin`n" `
                                            "on the Office 365 directory."
            Write-Host -ForegroundColor Red "Some Azure resources were deployed.  These can be removed in the Azure Portal."
            exit
        }
    }

    Create-EWSGroups $creds

    if($sdsResponse -eq "y")
    {
        $sdsApp = Create-SDSSyncApp
        Add-EWSPrincipalGroupMembers $tenantId $sdsApp.AppId $sdsApp.AppCredential
        Add-EWSTeacherGroupMembers
    }
    else
    {
        Write-Host -ForegroundColor Yellow "Ed-Fi EWS Groups were created, but will need to be manually populated with users in order for RLS to work.`n"
        return
    }

    Write-Success "`n`nSuccessfully added principals and teachers to the corresponding Office 365 Groups."
    Write-Info "District Admins must be added manually. Please refer to the documentation for instructions.`n"
}

### SQL Server Helpers ###

function Get-ODSConnectionInformation()
{
    $validConnectionString = $false

    Write-Host "`nNow, we're going to gather the information for your ODS.  This will connect the Analysis Services instance to your database."

    while(!$validConnectionString)
    {
       Write-Host "`nEnter the SQL Server address for your ODS."
       $odsServerName = Read-Host -Prompt "ODS Server Address"

       Write-Host "`nEnter the database name for your ODS."
       $odsDatabaseName = Read-Host -Prompt "ODS Database Name"

       Write-Host "`nEnter the credentials for your ODS database. This is the account that Analysis Services will use to connect and process data."
       $odsCredentials = Get-CredentialFromConsole
       
       # Build the Connection String based on the Server Address, Database Name, and Credentials
       $odsConnectionString = "Server=$odsServerName;Database=$odsDatabaseName;Persist Security Info=True;User ID=$($odsCredentials.UserName);Password=$(SecureString-ToPlainText($odsCredentials.Password))"

       $validConnectionString = Validate-SqlConnectionString $odsConnectionString

       if(!$validConnectionString)
       {
           $tryAgain = ""

            while(!($tryAgain.ToLower() -ne "y" -xor $tryAgain.ToLower() -ne "n"))
            {
                Write-Warning "Do you want to re-enter your connection string and credentials?"
                $tryAgain = Read-Host "Try Again? [Y/N]"

                if($tryAgain.ToLower() -eq "n")
                {
                    $validConnectionString = $true

                    Write-Warning "Proceeding without verifying the ODS SQL Server connection."
                    Write-Warning "         This may cause the Analysis Services server to fail when pulling in data from the ODS."
                }
                else
                {
                    if($tryAgain.ToLower() -eq "y")
                    {
                        #proceed
                    }
                    else
                    {
                        Write-Warning "Invalid input.  Please enter a Y or N.`n"
                    }
                }
            }
        }
     }

     return $odsConnectionString
}

function Validate-SqlConnectionString([string]$connString)
{
    Try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection 
        $sqlConnection.ConnectionString = $connString
        $sqlConnection.Open()
        $sqlConnection.Close()

        Write-Info "`nConnection to the SQL Server was successful."

        return $true
     }
     Catch
     {
        Write-Warning "`nUnable to connect to the SQL Server."

        return $false
     }
}

### XMLA Helpers ###

function Add-ConnectionStringAndRolesToXMLA([string]$xmlaFilePath, [string]$connString, [string]$domain)
{
    $xmlaContent = Get-Content $xmlaFilePath -Raw | ConvertFrom-Json
    $xmlaContent.createOrReplace.database.model.dataSources[0].connectionString = "Provider=SQLNCLI11;$connString"
    $xmlaContent.createOrReplace.database.model.roles[0].members[0].memberName = "edfiewsdistrictadmins@$domain"
    $xmlaContent.createOrReplace.database.model.roles[1].members[0].memberName = "edfiewsschooladmins@$domain"
    $xmlaContent.createOrReplace.database.model.roles[2].members[0].memberName = "edfiewsteachers@$domain"
    $xmlaContent | ConvertTo-Json -Depth 20 | Set-Content "$xmlaFilePath.deploy"
}

function Deploy-XmlaFileToAnalysisServices([PSCredential]$creds, [string]$xmlaFilePath, [string]$resourceGroupLocation, [string]$analysisServicesName)
{
    Try
    {
        $result = Invoke-ASCmd -Credential $creds -InputFile "$xmlaFilePath.deploy" -Server "asazure://$resourceGroupLocation.asazure.windows.net/$analysisServicesName" -ErrorAction SilentlyContinue
    }
    Catch
    {
        $ErrorMessage = $_.Exception.Message
        $FailedItem = $_.Exception.ItemName
    }

    if($result -ne $null)
    {
        #Remove-Item "$xmlaFilePath.deploy"
        return $true
    }
    else
    {
        return $false
    }

}

### Tooling Verification ### 

function Verify-PowershellCmdletsInstalled()
{
	$azurePowershellVersion = (Get-Module -ListAvailable -Name Azure -Refresh).Version
    $azureADPowershellVersion = (Get-Module -ListAvailable -Name AzureAD -Refresh).Version
    $msolPowershellVersion = (Get-Module -ListAvailable -Name MSOnline -Refresh).Version
    $failed = $false

	if ($azurePowershellVersion -eq $null)
	{
        Write-Error "You are missing the Azure PowerShell Modules. For more information,  refer to the Prerequisites section in the documentation."
	    $failed = $true
    }
    else
    {
        Write-Info "Verified that Azure PowerShell Modules are installed."
    }

    if($azureADPowershellVersion -eq $null)
    {
        Write-Error "You are missing the AzureAD PowerShell Module. For more information, refer to the Prerequisites section in the documentation."
        $failed = $true
    }
    else
    {
        Write-Info "Verified that the AzureAD PowerShell Module is installed."
    }

    if($msolPowershellVersion -eq $null)
    {
        Write-Error "You are missing the MSOnline PowerShell Module. For more information, refer to the Prerequisites section in the documentation."
        $failed = $true
    }
    else
    {
        Write-Info "Verified that the MSOnline PowerShell Module is installed."
    }

    if($failed)
    {
        exit
    }
}

function Verify-AzureResourceProviders()
{
    $resourceProviders = @("Microsoft.AnalysisServices", "Microsoft.Automation")

    foreach($resourceProvider in $resourceProviders)
    {
        if( (Get-AzureRmResourceProvider -ProviderNamespace $resourceProvider).RegistrationState -eq "Registered" )
        {
            Write-Host -ForegroundColor Gray "$resourceProvider is already registered on your Azure subscription."
        }
        else
        {
            Register-AzureRmResourceProvider -ProviderNamespace $resourceProvider
            Write-Host -ForegroundColor Green "$resourceProvider has been registered on your Azure subscription."
        }
    }
}

### Console Helpers ###

function Get-CredentialFromConsole($defaultUserName)
{
	if ($defaultUserName) {
		$username = Read-Host -Prompt "Username [$defaultUserName]"
		if (!$username) {
			$username = $defaultUserName
		}
	} else {
		do {
			$username = Read-Host -Prompt "Username"
		} while (!$username)		
	}

	$passwordMatch = $false
	do {
		$password = Read-Host -Prompt "Password" -AsSecureString
		$confirmPassword = Read-Host -Prompt "Confirm Password" -AsSecureString

		if (SecureString-Equals $password $confirmPassword) {
			$passwordMatch = $true
		} else {			
			Write-Host "Passwords don't match"
		}
	} while (-not $passwordMatch)
	

	$credential = New-Object System.Management.Automation.PSCredential($username, $password)	
	return $credential
}

function SecureString-ToPlainText([securestring] $value)
{
	$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
	$PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

	return $PlainPassword
}

function SecureString-Equals([securestring] $value1, [securestring] $value2)
{
	return ((SecureString-ToPlainText $value1) -eq (SecureString-ToPlainText $value2))
}

function Write-Info($message)
{
    Write-Host $message -ForegroundColor Gray
}

function Write-Warning($message)
{
	Write-Host "WARNING: $message" -ForegroundColor Yellow
}

function Write-Success($message)
{
	Write-Host $message -ForegroundColor Green
}

function Write-Error($message)
{
	Write-Host "`n`n***** ERROR *****" -ForegroundColor Red
	Write-Host $message -ForegroundColor Red
	Write-Host "*****************" -ForegroundColor Red
}

function Sleep-WithMessage([string]$message, [int]$secondsRemaining, [int]$timerStopPoint)
{
    if(!$timerStopPoint)
    {
        $timerStopPoint = 0;
    }

    for($i = $secondsRemaining; $i -gt $timerStopPoint; $i--)
    {
        Sleep(1)
        Write-Progress -Activity $message -SecondsRemaining $i
    }

    Write-Progress -Activity $message -Completed
}