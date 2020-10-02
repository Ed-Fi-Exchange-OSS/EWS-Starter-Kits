# Deployment - Power BI Starter Kit

December 18, 2018

* [Solution Overview](readme.md)
* Deployment
* [Technical Details](technical-details.md)
* [Early Warning Metrics](early-warning-metrics.md)

## <a name='TableofContents'></a>Table of Contents


<!-- vscode-markdown-toc -->
* [Azure Deployment](#AzureDeployment)
    * [Analysis Services](#AnalysisServices)
    * [Automation](#Automation)
        * [Automation Account](#AutomationAccount)
        * [Credentials](#Credentials)
        * [Modules](#Modules)
        * [Runbooks](#Runbooks)
        * [Schedule](#Schedule)
        * [Office 365 Group Creation](#Office365GroupCreation)
    * [Analytics Middle Tier Deployment](#AnalyticsMiddleTierDeployment)
    * [Tabular Model Deployment](#TabularModelDeployment)
    * [Power BI Deployment](#PowerBIDeployment)
* [Post Deployment Actions](#PostDeploymentActions)

<!-- vscode-markdown-toc-config
    numbering=false
    autoSave=true
    /vscode-markdown-toc-config -->
<!-- /vscode-markdown-toc -->

## <a name='AzureDeployment'></a>Azure Deployment

There are two main components in Azure - Analysis Services and Automation.
Analysis Services is required for this solution, while Automation provides some
useful cost-saving features and is completely optional.

* Analysis Services is the platform-as-a-service offering of SQL Server Analysis
  Services.  This holds the definition of the data model and metric measurements
  and calculates the results for the Power BI report visualizations.
* Optional: Automation is a scripting framework to automate processes in
  Microsoft Azure.  This is used to enable, disable, and process the Analysis
  Services model on a schedule.

### <a name='AnalysisServices'></a>Analysis Services

1. Log in to the [Microsoft Azure Portal](https://portal.azure.com).
2. Select the “+ New” button at the top of the left-navigation menu.
3. Search for “Analysis Services”.  The first result will be published by
   Microsoft.
4. Select the “Analysis Services” option and click Create.
5. Enter the name for the Analysis Services (AS) server.  This will be the
   unique identifier for your server and will be used in the connection string.
6. Select the subscription that the server will be deployed to.
7. Choose an existing or new resource group to deploy the server to.  A resource
   group is a collection of Azure services.
8. Select the location where the Analysis Services server will be hosted.
9. Select the tier for which the server will run on.  For more information
   regarding which tier to choose, read the section of this documentation
   entitled ‘Pricing Tiers’.
10. Select an Administrator from the Azure Active Directory - this can be an
    individual or group.  This can be changed at any time, and for the purposes
    of successful deployment, leave it to the default value (your username).
11. Optional: You have the option to back up the server to an Azure Storage
    Account.  By default, this is not enabled, and can be enabled anytime in the
    future.
12. Click “Create” to initiate the deployment of the Analysis Services server.
13. Once the deployment has finished, you can view the server in the list of
    resources in the Azure Portal.

### <a name='Automation'></a>Automation

#### <a name='AutomationAccount'></a>Automation Account

1. Log in to the [Microsoft Azure Portal](https://portal.azure.com).
2. Select the “+ New” button at the top of the left-navigation menu.
3. Search for “Automation”.  The first result will be published by Microsoft.
4. Select the “Automation” option and click Create.
5. Enter the name for the Automation account.  The name should represent a
   collection of like-minded tasks, such as “ed-fi-analytics-automation”.
6. Select the subscription where the account will be deployed.
7. Choose an existing or new resource group.  A resource group is a collection
   of Azure services.
8. Select the location where the Automation account will be hosted.
9. Click “Create” to initiate the creation of the Automation account.
10. Leave the default value of “Yes” for “Create Azure Run As account.”
11. Proceed to the Credentials section below.

#### <a name='Credentials'></a>Credentials

A set of credentials must be stored within the Azure Automation account in order
to authenticate against both Azure and the Analysis Services server.

1. From the “All Resources” blade, navigate to the Azure Automation account you
   created.
2. Select “Credentials” under the “Shared Resources” category on the
   left-navigation menu within the resource panel.
3. Select “+ Add a credential” at the top of the panel.
4. Enter the following name for the credential: EdFiEWSAccount
    1. You can use a different name if you wish, but you’ll need to adjust the
       runbook scripts accordingly.
5. Enter a username and password for an account within the Azure Active
   Directory.
    > (!) Note:  This account must be an administrator on the Azure Analysis
    > Services server and have access to the Azure Portal resource.  For the
    > ease of deployment, use the same account for all steps. For more
    > information on Analysis Services  administrator accounts, see [Tutorial:
    > Configure server administrator and user
    > roles](https://docs.microsoft.com/en-us/azure/analysis-services/tutorials/analysis-services-tutorial-roles).
6. Click “Create” to add the credential to the Automation account.
7. Proceed to the Modules section.

#### <a name='Modules'></a>Modules

Azure Automation is backed by PowerShell, and this solution requires certain
PowerShell modules to be configured on the Automation account.

1. Navigate to the Azure Automation account you created.
2. Select “Modules” under the “Shared Resources” category on the left-navigation
   menu within the resource panel.
3. Select “Update Azure Modules” at the top of the panel, then click “Yes” to
   verify the action. This will ensure that we have the latest AzureRM modules
   installed in our Automation account.  Click “Refresh” to check on the status
   of the updates.  Once all the modules are updated, proceed with the next
   steps.
4. Select “Browse Gallery” at the top of the panel.
5. Search for “AzureRM.AnalysisServices”.  Select the result created by
   “azure-sdk”.
6. Select “Import” at the top of the panel, and then click “Ok”.
7. Select “Browse Gallery” again, and search for the “SqlServer” module.  Select
   the result created by “matteot_msft”.
8. Select “Import” at the top of the panel, and then click “Ok”.
9. Proceed to the Runbooks section below.

#### <a name='Runbooks'></a>Runbooks

A runbook is a script that is executed on-demand or based on a schedule. One or
more runbooks associated with each Automation account.

1. Navigate to the Azure Automation account you created.
2. Select “Runbooks” under the “Process Automation” category on the
   left-navigation menu within the resource panel.
3. Select “+ Add a runbook” at the top of the panel.
4. Choose “Import an existing runbook”.
5. Select the runbook file.  There are two runbooks that should be imported:
    | Runbook Name | Description |
    | ------------ | ----------- |
    | AnalysisServicesSchedulerRunbook.ps1 | Used to pause and resume the Analysis Services server on a schedule. |
    | AnalysisServicesRefreshRunbook.ps1 | Used to re-process the Analysis Services Tabular Model on a schedule.  This will pull in the latest information from the ODS. |
6. Select “PowerShell” for the “Runbook type”.
7. Click “Create” to import the PowerShell script.
8. Repeat steps 3 through 7 for each .ps1 file.
9. Once all Runbooks have been imported, we need to publish and create a
   schedule for each one.
10. Open the `AnalysisServicesSchedulerRunbook` runbook.
11. Click “Edit” on the top of the panel.  This will bring you into an editor
    for the PowerShell script.
12. Click “Publish” on the top of the panel, then “Yes” to verify the action.
    This will save and publish the runbook, and allow you to set a schedule for
    it.
13. Repeat steps 10 through 12 for each runbook.
14. Once both runbooks are published, proceed to the Schedule section below.

#### <a name='Schedule'></a>Schedule

A schedule is a time-based trigger to run an associated runbook.  Additionally,
you have the option to pass schedule-specific parameters to the runbook.

1. Navigate to the Azure Automation account you created.
2. Select “Runbooks” under the “Process Automation” category on the
   left-navigation menu within the resource panel.
3. Select the AnalysisServicesRefreshRunbook.
4. Select “Schedules” under the “Resources” category on the left-navigation
   menu.
5. Select “+ Add a schedule” at the top of the panel.
    > Note: If the “+ Add a schedule” button is greyed out, the runbook is not
    > published.  Follow steps 10 through 12 in the Runbooks section.
6. Select the “Schedule Link a schedule to your runbook” option, and then “+
    Create a new schedule”. For the purposes of this solution, three schedules
    are recommended: 
    | Schedule Name | Description | Time | Associated Runbook |
    | ------------- | ----------- | ---- | ------------------ |
    | RefreshAnalysisServices | Refreshes the Analysis Services Tabular Model | 7:15am | AnalysisServicesRefreshRunbook |
    | ResumeAnalysisServices | Resumes the Analysis Services server | 7:00am | AnalysisServicesSchedulerRunbook |
    | SuspendAnalysisServices | Pauses the Analysis Services server | 7:00pm | AnalysisServicesSchedulerRunbook |
7. Set the schedule for the associated action.  Make sure to enable “Recurrence”
   and set the interval at which this action will run (e.g. daily).
8. Click “Create” to save the schedule.
9. Select the “Parameters and run settings” option.  Each runbook will have a
    specific set of parameters.
    | Runbook Name | Parameters |
    | ------------ | ---------- |
    | AnalysisServicesRefreshRunbook | <ul><li>`servername` - This is the name for the Azure Analysis Services server.</li><li>`databasename` - This is the name of the Tabular Model.  By default, it is “Ed-Fi-Data-Analytics”.</li><li>`resourcegrouplocation` - This is the resource group location for the Analysis Services server. It must be formatted in all lowercase with no spaces (e.g. South Central US becomes southcentralus).</li></ul> | 
    | AnalysisServicesSchedulerRunbook | <ul><li>`action` - This is either “resume” or “suspend”, depending on the associated time. This will pause or resume the Analysis Service server.</li><li>`resourcegroupname` - This is the name of the Azure Resource Group where the Analysis Services server is located.</li><li>`servername` - This is the name of the Azure Analysis Services server.</li></ul> |
10. Click “Ok” twice to create and associate the schedule with the runbook.
11. Repeat this process for each schedule.
12. This completes the Azure Automation deployment. You can monitor the success
    or failure of each runbook in the Azure Portal.

#### <a name='Office365GroupCreation'></a>Office 365 Group Creation

1. Log in to the [Office 365 Admin
   Portal](https://portal.office.com/adminportal/).
2. Select the “Groups” tab in the left-navigation menu and select Groups.
3. Repeat steps 4 through 11 for the two groups below: | Group Name | Group Id /
    Group email address |
    | ---------- | ------------------------------ |
    | Ed-Fi EWS Read All | edfiewsreadall | | Ed-Fi EWS Student Auth |
    edfiewsstudentauth |
4. Click “+ Add a Group” at the top of the page.  A new panel will appear.
5. Make sure the “Type” chosen is “Office 365 group”.
6. Enter the Name of the group.
7. Enter the Id/email address of the group.  This will be the alias of the
   group.
8. Make sure “Privacy” is set to Public.  This is required for Analysis Services
   row-level security.
9. Select an owner for the group.  Select your username - this can be changed at
   a later date, and you will need access to the group in subsequent steps.
10. Disable the toggle for “Send copies of group conversations and events to
    group members’ inboxes”.
11. Click “Add” to create the group.  It may take a minute or two to populate in
    the Office 365 Portal.

### <a name='AnalyticsMiddleTierDeployment'></a>Analytics Middle Tier Deployment

The Analytics Middle Tier is a collection of views that simplify the process of
retrieving data from the ODS for use in ad hoc or packaged analytics solutions.
A basic installation might target the production ODS. For better overall
performance, consider creating a replicated copy of the ODS and installing the
Analytics Middle Tier into that copy. See Patterns and Practices for more
information on this approach.

1. On a computer that can access the ODS database, download the latest release
   of the [Analytics Middle
   Tier](https://github.com/Ed-Fi-Alliance-OSS/Ed-Fi-Analytics-Middle-Tier/releases)
   (must be signed-in on Github.com before clicking the link). The larger zip
   file, EdFi.AnalyticsMiddleTier-win10.x64.zip, contains all dependencies
   needed to run the application. The smaller file,
   EdFi.AnalyticsMiddleTier.zip, requires the .NET Core 2.1 runtime to be
   separately installed.
    1. If using a local computer, make sure that computer’s IP address is
       allowed to access the SQL Server instance behind its firewall.
    2. Another option is to use Remote Desktop to connect to the database server
       (if on a Virtual Machine) and download and execute the program there.
2. Unzip the release.
3. Open a command prompt and CD to the directory containing the unzipped
   contents.
4. Assuming use of self-sufficient win10.x64 zip file, run the following
   command, substituting in a correct connection string for your ODS database:
   `.\EdFi.AnalyticsMiddleTier.Console.exe --connectionString
   "Server=.;Database=EdFi_Glendale;Trusted_connection=true"`

### <a name='TabularModelDeployment'></a>Tabular Model Deployment

1. Open SQL Server Management Studio.
2. Navigate to File - Open and select the Model.xmla file in the Ed-Fi Early
   Warning System directory.
3. You will be prompted to connect to an Analysis Services server.  Enter the
   connection string for your Analysis Services instance.  You can find this on
   the resource panel in the Azure Portal, and should be formatted like:
   `asazure://resourcegrouplocation.asazure.windows.net/servername`
4. Click “Connect”.  You’ll be prompted to log in with your Azure AD account.
5. Now, we’ll need to modify the connection to the ODS data source in the script
   before executing.
    1. Search the document for `address`.  Replace `{Azure SQL Server name}` and
       `{Azure SQL database name}` with the name of your Azure SQL server
       running your Ed-Fi ODS database and the name of that database.
    1. Search the document for `credential`.  Again replace `{Azure SQL Server
       name}` and `{Azure SQL database name}` with the name of your Azure SQL
       server running your Ed-Fi ODS database and the name of that database.
       Also replace `{SQL username}` and `{SQL password}` with the username and
       password for the SQL admin credentials on the Ed-Fi ODS database:
6. Search the document for `@domain.com`.  There will be two matches toward the
   bottom of the document: one for `edfiewsreadall` and one for
   `edfiewsstudentauth`.
7. Replace each of these instances with the correct domain for your Office 365
   account.  Each of these will correlate to an Office 365 Group that was
   created earlier.
8. Select “! Execute” at the top of SSMS or press F5 to execute the script.  The
   tabular model will be deployed to the Azure Analysis Services server.
    > Note: The Analysis Services model will not be populated with data until
    > you complete the processing step in the Post Deployment Actions section.

### <a name='PowerBIDeployment'></a>Power BI Deployment

1. Open the Power BI folder in the supplied artifacts.
2. Open one of the .PBIX files in Power BI Desktop.
3. You will be prompted to log in to your Azure account.
4. You will receive an error message stating that your account does not have
   access to the server. This is correct - it is trying to authenticate your
   account to an invalid server (the one used for initial development of this
   model).
5. Select ‘Edit’ on the warning message and enter your Analysis Services
   connection string. Leave the Database Name alone - this is hardcoded in the
   Tabular Model.
    1. If you did not write this down after deploying the Azure components, you
       can view it in the Azure Portal. It will look something like as
       `azure://{region}.asazure.windows.net/{ssas-name}`
    1. In the future you can return to the connection settings from the Home
       ribbon, under Edit Queries > Data Source Settings
6. When prompted, select “Model”. This is selecting the Tabular Model within the
   Analysis Services server.
7. Once connected, select “Publish” in the top ribbon menu. You may be prompted
   to log in to your Power BI account.
8. Select the workspace that you’d like to publish these reports to. This should
   match the context for each report.
    1. District and School PBIX should be published to the District Admins and
       School Admins workspaces.
    1. Teacher PBIX should be published to the Teachers workspace.
9. The reports should now be visible on the Power BI Web Service.
10. Before the reports can be completely used, you must complete the
    Post-Deployment Actions below.
    > Note: In order to view the reports on PowerBI.com, you must change the
    > workspace from ‘My Workspace’ to one of the security groups.

## <a name='PostDeploymentActions'></a>Post Deployment Actions

Once all the Azure and Power BI components are fully deployed, the Tabular Model
will need to be processed.  This step is required; it will pull information into
the Azure Analysis Services server from the ODS and allow the individuals to
view the Power BI reports.

1. Process the Tabular Model database manually.
    1. Load SSMS and navigate to Connect - Analysis Services.
    1. Enter the Azure Analysis Services connection string. You’ll be prompted
       to log in with your Azure AD account.
    1. Right-click the database and select “Process”. For the first time, you’ll
       want to use Process Full. This can take some time depending on your
       Analysis Services tier.
        1. If you find that you have a credential problem when connecting to the
           SQL Server, in SSMS, expand Ed-Fi > Connections. Double-click on
           Enterprise ODS. In the next dialog box, click in the Credentials
           property to edit the credentials.
2. Verify that your Power BI Workspaces are set to read-only.  This ensures that
   your end users cannot modify the reports for other individuals.
    1. Log in to the Power BI Web Service.
    1. Open up the Workspace selection menu.
    1. Click on the three-dot menu next to each workspace.  Select “Edit
       workspace”.
    1. Change the drop-down menu under the Privacy subsection to “Members can
       only view Power BI content”.
    1. Click Save to apply the new settings.
3. Add users to the appropriate Office 365 Groups.  This can be done in the
   Office 365 Portal.
    1. Users added to `Ed-Fi EWS Student Auth` can only view the data for
       schools and sections associated with their user account in the
       `StudentDataAuthorization` table.
    1. Users added to `Ed-Fi EWS Read All` can view all data. Recommended only
       for use in testing, not production.