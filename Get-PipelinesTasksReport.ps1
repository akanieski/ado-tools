param (
    # The URL of the Azure DevOps organization for which you want to fetch the list of projects.
    [Parameter(Mandatory=$true)]
    [string]$OrganizationUrl,

    # A Personal Access Token (PAT) to authenticate and authorize the script to access your Azure DevOps data.
    [Parameter(Mandatory=$true)]
    [string]$PAT,

    # The path where the CSV file containing the list of pipelines will be written.
    [Parameter(Mandatory=$false)]
    [string]$outputPath = "pipelines2.csv"
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


# Extract the project names from the response
$projects = $response.value

# Create an empty list to hold the pipelines
$pipelines = @()
$usedTasks = @()
# Iterate over each project
foreach ($project in $projects) {
    # Call the API to get the pipelines for the project
    $pipelineResponse = Invoke-RestMethod -Uri "$OrganizationUrl/$($project.name)/_apis/pipelines?api-version=$apiVersion" -Method Get -Headers $headers

    # Iterate over each pipeline
    foreach ($pipeline in $pipelineResponse.value) {
        # Call the API to get the pipeline definition details
        $pipelineDefinition = Invoke-RestMethod -Uri "$OrganizationUrl/$($project.name)/_apis/pipelines/$($pipeline.id)?api-version=$apiVersion" -Method Get -Headers $headers
        
        # Check the configuration type and change it if necessary
        $configurationType = $pipelineDefinition.configuration.type
        if ($configurationType -eq "designerJson") {
            $configurationType = "Classic"
        } elseif ($configurationType -eq "yaml") {
            $configurationType = "Yaml"
        }

        # Extract the process details
        $processDetails = $pipelineDefinition.configuration.designerJson.process

        $pipelineObject = [PSCustomObject]@{
            Id = $pipelineDefinition.id
            Name = $pipelineDefinition.name
            Revision = $pipelineDefinition.revision
            Folder = $pipelineDefinition.folder
            ProjectName = $project.name
            #RawJson = $pipelineDefinition | ConvertTo-Json -Depth 100
            ConfigurationType = $configurationType
            Tasks = @()
        }
        
        # Iterate over each phase
        foreach ($phase in $processDetails.phases) {
            # Iterate over each step in the phase
            foreach ($step in $phase.steps) {
                $pipelineObject.Tasks += $step.task.id.Trim()
                $usedTasks += $step.task.id.Trim()
            }
        }

        # Add the pipeline definition to the list
        $pipelines += $pipelineObject
    }
}


# Iterate over each pipeline
foreach ($pipeline in $pipelines) {
    # Iterate over each task in the usedTasks list
    foreach ($usedTask in $usedTasks) {
        # Find the usedTask in the taskList
        $task = $taskList | Where-Object { $_.id -ceq $usedTask } | Select-Object -First 1
        
        # Add a property for the task
        if ($pipeline.Tasks -contains $usedTask) {
            $pipeline | Add-Member -Type NoteProperty -Name $task.name -Value "Y"
        } else {
            $pipeline | Add-Member -Type NoteProperty -Name $task.name -Value "N"
        }
    }
    $pipeline.PSObject.Properties.Remove('Tasks')
}

# Write the pipelines to the CSV file
$pipelines | Export-Csv -Path $outputPath -NoTypeInformation

