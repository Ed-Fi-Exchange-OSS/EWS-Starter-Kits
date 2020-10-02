# Technical Details - Power BI Starter Kit

December 18, 2018

* [Solution Overview](readme.md)
* [Deployment](deployment.md)
* Technical Details
* [Early Warning Metrics](early-warning-metrics.md)

## <a name='TableofContents'></a>Table of Contents

<!-- vscode-markdown-toc -->
* [Considerations](#Considerations)
* [Required Tooling](#RequiredTooling)
* [Customization](#Customization)
    * [Modifying Indicator Labels](#ModifyingIndicatorLabels)
    * [Modifying Indicator Thresholds](#ModifyingIndicatorThresholds)
    * [Modifying Reports (incl. Mobile)](#ModifyingReportsincl.Mobile)
* [Manually Processing the Tabular Model](#ManuallyProcessingtheTabularModel)
* [Deploying a Modified Tabular Model](#DeployingaModifiedTabularModel)
    * [Deploy from Visual Studio](#DeployfromVisualStudio)
    * [Deploy with PowerShell](#DeploywithPowerShell)

<!-- vscode-markdown-toc-config
    numbering=false
    autoSave=true
    /vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->


## <a name='Considerations'></a>Considerations

* Denormalized Views - The denormalized views from the Ed-Fi Analytics
  Middle-Tier solution are utilized in this solution.  Documentation for the
  Ed-Fi Analytics Middle-Tier can be found on [Ed-Fi
  Exchange](https://exchange.ed-fi.org/).
* Tabular Model Level 1400 - Tabular Model Compatibility Level 1400 was used.
* DAX Variables - DAX Variables are used heavily in many of the custom
  calculations - this is to offload strain on the Formula Engine making numerous
  similar calls in a short timeframe, especially around student metrics.
* Azure Analysis Services Tier - Tabular Models are hosted entirely in-memory,
  so it is important to select a tier for Azure Analysis Services that is
  powerful enough to hold your Tabular Model as well as having enough overhead
  for user’s viewing reports and database processing.

## <a name='RequiredTooling'></a>Required Tooling

In order to make modifications to the Tabular Model, you will need:

* SQL Server Data Tools (version 17.1)
* Microsoft Visual Studio (>= 2017)
* SQL Server Management Studio

The Tabular Model Visual Studio Project is located in the Tabular Model Project
folder of the supplied artifacts.

## <a name='Customization'></a>Customization

### <a name='ModifyingIndicatorLabels'></a>Modifying Indicator Labels

If you would like to change the text that appears on the indicator labels (i.e.
On Track, Early Warning, At-Risk), you can do so by modifying the indicator
measures.

1. Open the Ed-Fi Data Analytics solution in Visual Studio.
    1. You’ll be prompted to log in. You must be an administrator on the
       Analysis Services server. You can modify the admins in the Azure Portal.
2. Open the Model.bim file. This is the Tabular Model file.
    1. If the Tabular Model Explorer window does not open automatically, you can
       manually open it in the View - Other Windows menu.
3. Select the Measures-EWS table. All of the indicators will be present here.
4. Select the measure that you would like to modify. There are various types of
   indicator measures.
    1. Indicator - This is an integer (2, 1, or 0) based on the indicator
       status.
    1. Status - This is the “user-friendly” label, based on the Flag value.
5. Modify the label, and save the project.

Note: Modifications to any measures or columns will require the Tabular Model to
be redeployed to the Analysis Services server.

### <a name='ModifyingIndicatorThresholds'></a>Modifying Indicator Thresholds

Attendance Rate, Grade, and Behavior thresholds are stored as DAX Variables on
each corresponding measure indicator.

1. Open up the Ed-Fi Data Analytics solution in Visual Studio.
    1. You’ll be prompted to log in. You must be an administrator on the
       Analysis Services server. You can modify the admins in the Azure Portal.
2. Open the Model.bim file. This is the Tabular Model file.
    1. If the Tabular Model Explorer window does not open automatically, you can
       manually open it in the View - Other Windows menu.
3. Select the Student or Measures-EWS table.
4. Select the measure that you would like to modify.
5. In the definition of the measure, you will see something similar to:
    ```none
    Math Indicator:=
    VAR AtRiskThreshold = 65
    VAR EarlyWarningThreshold = 72
    ```
6. Modify the values, and save the project.
    > Note: Modifications to any measures or columns will require the Tabular
    > Model to be redeployed to the Analysis Services server.

### <a name='ModifyingReportsincl.Mobile'></a>Modifying Reports (incl. Mobile)

1. Open the .PBIX file in Power BI Desktop.
2. You’ll be prompted to log in to Azure Analysis Services. You must be an
   administrator on the AAS server. You can modify admins in the Azure Portal.
3. Make changes to the report as necessary.
    1. To change mobile reports, go to the View - Phone Layout tab in the ribbon
       menu.
4. Save the .PBIX file.
5. Publish the Power BI reports to the appropriate workspace.

## <a name='ManuallyProcessingtheTabularModel'></a>Manually Processing the Tabular Model

In order to manually process the Tabular Model, you’ll need the latest version
of SQL Server Management Studio.

1. Open SQL Server Management Studio.
2. Connect - Analysis Services
3. Enter the connection string for your Azure Analysis Services server. You can
   find this in the Azure Portal.
4. You’ll be prompted to authenticate with Azure Active Directory. You must be
   an administrator on the AAS server in order to make changes and process the
   data. You can modify this list in the Azure Portal.
5. Right-click on the database that you want to process and select “Process”.
   For this project, the database name will be EdFi-Data-Analytics.
6. Choose which type of processing you’d like to do. For more information, view
   the [documentation on the Microsoft
   Docs](https://docs.microsoft.com/enus/sql/analysis-services/multidimensional-models/processing-options-and-settingsanalysis-services).

## <a name='DeployingaModifiedTabularModel'></a>Deploying a Modified Tabular Model

When changes are made to the Tabular Model project in Visual Studio, there are
two ways to deploy the updated model to the Analysis Services server.
* Deploy from Visual Studio (easiest)
* Deploy with PowerShell

### <a name='DeployfromVisualStudio'></a>Deploy from Visual Studio

1. Right-click on the project in Solution Explorer.
2. Select Deploy. This may prompt you for the Analysis Services connection
   string.
3. You’ll then be prompted for your data source (ODS database) connection
   information. This validates the data model against the data source schema.

### <a name='DeploywithPowerShell'></a>Deploy with PowerShell

1. Build the Tabular Model project in Visual Studio. This will create an
   .asdatabase output file.
2. Navigate to the ProjectRoot/bin folder. You should see a Model.asdatabase
   file.
3. In an admin-level command prompt, run the following command:
    ```powershell
    Microsoft.AnalysisServices.Deployment Model.asdatabase /o:”C:\Model.xmla” /d
    ```
    > Note: This requires Analysis Services to be installed on the local
    > machine. You can install this as part of the SQL Server 2016 installation
    > package.
4. This command will output the Model.xmla file to your C:\ directory.
5. Open the Model.xmla file in SQL Server Management Studio.
6. At the bottom, remove the last section in { } that contains the refresh
   information. This isn’t needed in Azure Analysis Services.
7. Save the file with the same name.
8. In an admin-level command prompt, run the following command to deploy the
   model:
    ```powershell
    Invoke-ASCmd -InputFile “C:\Model.xmla” -Server asazure://region.asazure.windows.net/aas-servername
    ```