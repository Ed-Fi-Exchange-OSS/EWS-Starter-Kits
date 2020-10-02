$AzureArmTemplateFile = "$PSScriptRoot\EdFiDataAnalyticsARMTemplate.json"
$AzureArmTemplateParametersFile = "$PSScriptRoot\EdFiDataAnalyticsARMTemplateParameters.json"
$TabularModelDeploymentFile = "$PSScriptRoot\Model.xmla"

Import-Module $PSScriptRoot\EdFiDataAnalyticsHelperCmdlets.psm1 -Force -DisableNameChecking

Verify-PowershellCmdletsInstalled

$userCreds = Get-AzureCredentialFromUser
$azureAccount = Login-AzureAccount $userCreds
$azureADAccount = Connect-AzureAD -Credential $userCreds

Verify-AzureResourceProviders

$azureResourceGroupName = Get-AzureResourceGroupName
$azureResourceGroupLocation = Get-AzureResourceGroupLocation($azureResourceGroupName)

$azureAnalysisServicesName = Get-AzureAnalysisServicesName
$azureAnalysisServicesTier = Get-AzureAnalysisServicesTier

function Rollback-Deployment()
{
    Write-Host -ForegroundColor Red "`n***** Rolling Back Deployment *****"

    Try
    {
        if(Test-AzureRmAnalysisServicesServer -Name $azureAnalysisServicesName -ResourceGroupName $azureResourceGroupName)
        {
            Remove-AzureRmAnalysisServicesServer -Name $azureAnalysisServicesName -ResourceGroupName $azureResourceGroupName
            Write-Host "Removed Analysis Services: $azureAnalysisServicesName" -ForegroundColor Red
        }

        if((Get-AzureRmAutomationAccount -ResourceGroupName $azureResourceGroupName -Name "$(($azureAnalysisServicesName).substring(0,6))-AnalysisServices-Automation" -ErrorAction SilentlyContinue) -ne $null)
        {
            Remove-AzureRmAutomationAccount -Name "$(($azureAnalysisServicesName).substring(0,6))-AnalysisServices-Automation" -ResourceGroupName $azureResourceGroupName
            Write-Host "Removed Automation Account: $(($azureAnalysisServicesName).substring(0,6))-AnalysisServices-Automation" -ForegroundColor Red
        }

        $azureADAccount = Connect-AzureAD -Credential $userCreds
        $azureADApp = Get-AzureADApplication -Filter "DisplayName eq '$(($azureAnalysisServicesName).substring(0,6))-AnalysisServices-Automation'"

        if($azureADApp -ne $null)
        {
            Remove-AzureADApplication $azureADApp.ObjectId
            Write-Host "Removed Active Directory App: $(($azureAnalysisServicesName).substring(0,6))-AnalysisServices-Automation" -ForegroundColor Red
        }
    }
    Catch
    {
        Write-Error "Failed to rollback the deployment.  You will need to manually remove the deployed components from the Azure Portal."
        exit
    }

        Write-Host "Rollback Complete.  If your deployment created a new Resource Group, you will need to manually remove this in the Azure Portal." -ForegroundColor Yellow
        exit
}

function Deploy-AzureServices()
{
    Write-Host "`n***** Deploying Azure Components *****"

    $deployParameters = New-Object -TypeName Hashtable
    $deployParameters.Add("analysisServicesName", $azureAnalysisServicesName)
    $deployParameters.Add("serverLocation", $azureResourceGroupLocation)
    $deployParameters.Add("serverTier", $azureAnalysisServicesTier)
    $deployParameters.Add("admin", $azureAccount.Account.Id)
    $deployParameters.Add("managedMode", "1")

    Try
    {
        $deploymentResult = New-AzureRmResourceGroupDeployment -Name ("edfianalytics-" + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                                                -ResourceGroupName $azureResourceGroupName `
                                                                -TemplateFile $AzureArmTemplateFile `
                                                                -TemplateParameterFile $AzureArmTemplateParametersFile `
                                                                @deployParameters `
                                                                -Force -Verbose -ErrorAction Stop

        Deploy-AzureAutomationAccount $azureResourceGroupName $azureResourceGroupLocation $azureAnalysisServicesName
    }
    Catch
    {
        Write-Error "Failed to deploy Azure components."
        Rollback-Deployment
    }

    Populate-SDSTeachersAndPrincipalsInO365Groups $userCreds $azureAccount.Tenant.Id

    if($deploymentResult.ProvisioningState -eq "Succeeded")
    {
        Write-Success "***** Successfully Deployed Azure Components *****"
        return $true
    }
}

function Deploy-TabularModel($filepath)
{
    $connString = Get-ODSConnectionInformation
    #$domainName = (($azureAccount.Context.Account.Id) -split "@")[1]
	$domainName = $azureADAccount.TenantDomain
	
    Write-Host "`n***** Deploying Tabular Model *****"

    Try
    {
        Add-ConnectionStringAndRolesToXMLA $filepath $connString $domainName
        $xmlaDeployResult = Deploy-XmlaFileToAnalysisServices $userCreds $filepath $azureResourceGroupLocation $azureAnalysisServicesName
    }
    Catch
    {
        Write-Error "Failed to deploy the Tabular Model."
        Rollback-Deployment
        return $false
    }

    if($xmlaDeployResult -ne $null)
    {
        Write-Success "***** Successfully Deployed Tabular Model *****"
        return $true
    }
}

$azureDeployResult = Deploy-AzureServices
$tabularDeploymentResult = Deploy-TabularModel $TabularModelDeploymentFile

if($azureDeployResult -eq $true -and $tabularDeploymentResult -eq $true)
{
    Write-Success "`nDeployment Complete!"

    $resourceCostNotificationMessage = "All newly deployed resources will now incur costs until they are manually removed from the Azure portal.`n`n"
    $resourceCostNotificationMessage += "Your Analysis Services server connection info is: asazure://$azureResourceGroupLocation.asazure.windows.net/$azureAnalysisServicesName`n"
    $resourceCostNotificationMessage += "Please see the documentation for help on deploying the Power BI Reports and finishing the deployment."

    Write-Success "*** NOTE ***"
    Write-Success $resourceCostNotificationMessage
    Write-Success "***"

    [System.Windows.Forms.MessageBox]::Show($resourceCostNotificationMessage, "Deployment Complete")
}

