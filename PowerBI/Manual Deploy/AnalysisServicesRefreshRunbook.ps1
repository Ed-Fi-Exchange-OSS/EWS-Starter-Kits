param(
    [Parameter(Mandatory = $true)]
    [string]
    $serverName,

    [Parameter(Mandatory = $true)]
    [string]
    $databaseName,

    [Parameter(Mandatory = $true)]
    [string]
    $resourceGroupLocation
)

$creds = Get-AutomationPSCredential -Name 'EdFiEWSAccount'

Invoke-ProcessASDatabase -Server "asazure://$resourceGroupLocation.asazure.windows.net/$serverName" -DatabaseName $databaseName -RefreshType Full -Credential $creds