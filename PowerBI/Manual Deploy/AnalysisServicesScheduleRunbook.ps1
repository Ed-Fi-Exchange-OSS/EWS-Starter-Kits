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

Get-AutomationPSCredential -Name 'EdFiEWSAccount'
Add-AzureRmAccount -Credential $creds

switch($action)
{
    'suspend' { Suspend-AzureRmAnalysisServicesServer -Name $serverName -ResourceGroupName $resourceGroupName }
    'resume'  { Resume-AzureRmAnalysisServicesServer -Name $serverName -ResourceGroupName $resourceGroupName }
}