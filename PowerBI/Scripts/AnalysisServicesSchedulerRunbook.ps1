param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('suspend', 'resume')]
    [string]
    $action,

    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]
    $serverName
)

Add-AzureRmAccount -ServicePrincipal -Credential (Get-AutomationPSCredential -Name 'AAS Service Principal')

switch($action)
{
    'suspend' { Suspend-AzureRmAnalysisServicesServer -Name $serverName -ResourceGroupName $resourceGroupName }
    'resume'  { Resume-AzureRmAnalysisServicesServer -Name $serverName -ResourceGroupName $resourceGroupName }
}