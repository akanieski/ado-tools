param (
    # The URL of the Azure DevOps organization for which you want to fetch the list of projects.
    [Parameter(Mandatory=$true)]
    [string]$OrganizationUrl,

    # A Personal Access Token (PAT) to authenticate and authorize the script to access your Azure DevOps data.
    [Parameter(Mandatory=$true)]
    [string]$PAT,

    # The path where the CSV file containing the list of builds will be written.
    [Parameter(Mandatory=$false)]
    [string]$outputPath = "builds.csv",

    [Parameter(Mandatory=$false)]
    [switch]$append = $false
)

$apiVersion = "6.0"

# Base64 encode the PAT
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$PAT)))

# Create the header for the request
$headers = @{
    "Authorization" = "Basic $base64AuthInfo"
}

# Call the API
$response = Invoke-RestMethod -Uri "$OrganizationUrl/_apis/projects?api-version=$apiVersion" -Method Get -Headers $headers

# Get list of all tasks proactively
$taskList = (Invoke-RestMethod -Uri "$OrganizationUrl/_apis/distributedtask/tasks" -Method Get -Headers $headers) -replace '"":', '"$":' | ConvertFrom-Json
$taskList = $taskList.value

# Get list of all extensions proactively
$extMgmtSubdomain = $OrganizationUrl -replace 'dev.azure.com', 'extmgmt.dev.azure.com'
Write-Host "$extMgmtSubdomain/_apis/extensionmanagement/installedextensions"
$extensionsList = Invoke-RestMethod -Uri "$extMgmtSubdomain/_apis/extensionmanagement/installedextensions" -Method Get -Headers $headers
$extensionsList = $extensionsList.value


# Extract the project names from the response
$projects = $response.value

# Create an empty list to hold the pipelines
$pipelines = @()
$data = @()
# Iterate over each project
foreach ($project in $projects) {
    
    # Call the API to get the build runs in a given project
    $response = Invoke-RestMethod -Uri "$OrganizationUrl/$($project.id)/_apis/build/builds?api-version=$apiVersion" -Method Get -Headers $headers

    Write-Host "Processing $($response.count) builds in $($project.name)..."
    # Iterate over each build run
    foreach ($buildrun in $response.value) {
        # Go and get timeline
        $timeline = Invoke-RestMethod -Uri "$OrganizationUrl/$($project.id)/_apis/build/builds/$($buildrun.id)/timeline?api-version=$apiVersion" -Method Get -Headers $headers
        # Iterate over each record
        foreach ($record in $timeline.records) {
            # Check if the record is a task
            if ($record.type -eq "Task" -and $record.task -ne $null) {
                # Locate task in the task list
                $task = $taskList | Where-Object { $_.id -eq $record.task.id }
                if ($task.contributionIdentifier -eq $null) {
                    $extensionPublisher = "Microsoft"
                    $extensionName = "Built-in"
                    $extension = [PSCustomObject]@{
                        extensionId = "Built-in"
                        publisherId = "Microsoft"
                        version = ""
                    }
                } else {
                    $extensionPublisher = $task.contributionIdentifier.Split('.')[0]
                    $extensionName = $task.contributionIdentifier.Split('.')[1]
                    # Locate extension in the extension list
                    $extension = $extensionsList | Where-Object { $_.extensionId -eq $extensionName -and $_.publisherId -eq $extensionPublisher }
                }


                # Check if the task is already in the list
                $data += [PSCustomObject]@{
                    ProjectName = $project.name
                    BuildId = $buildrun.id
                    BuildNumber = $buildrun.buildNumber
                    ExtensionPublisher = $extensionPublisher
                    ExtensionName = $extensionName
                    ExtensionVersion = $extension.version
                    TaskId = $record.task.id
                    TaskName = $record.task.name
                    TaskVersion = $record.task.version
                    ExecutionTime = $record.finishTime
                    BuildRunUrl = $buildrun._links.web.href
                }
            }
        }
    }
}

Write-Host "Total Builds: $($data.Count)"


$csvContent = $data | ConvertTo-Csv  -NoTypeInformation
$lines = $csvContent -split "`n"

if ($append) {
    $lines | Select-Object -Skip 1 | Add-Content -Path $outputPath
} else {
    Set-Content -Path $outputPath -Value $csvContent
}