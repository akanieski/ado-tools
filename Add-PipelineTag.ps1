param(
    # The $organizations parameter is a comma-separated list of organization names that the script will query for agents.
    # This parameter is mandatory and the script will prompt for it if it's not provided.
    [Parameter(Mandatory=$true)]
    [string]$organization = (Read-Host -Prompt 'Input your organization'),

    # The $pat parameter is the Personal Access Token (PAT) used for authentication with the Azure DevOps REST API.
    # This parameter is mandatory and the script will prompt for it if it's not provided.
    [Parameter(Mandatory=$true)]
    [string]$pat = (Read-Host -Prompt 'Input your PAT'),

    [Parameter(Mandatory=$true)]
    [string]$projectName = (Read-Host -Prompt 'Input your project name'),

    # The $hostingBasePath parameter is the base URL for the Azure DevOps instance.
    # This parameter is optional and defaults to "https://dev.azure.com" if not provided.
    [Parameter(Mandatory=$false)]
    [string]$hostingBasePath = "https://dev.azure.com",

    [Parameter(Mandatory=$false)]
    [string]$pipelinePath = (Read-Host -Prompt 'Input your pipeline path'),

    [Parameter(Mandatory=$false)]
    [string]$pipelineName,

    [Parameter(Mandatory=$true)]
    [string]$tagValue = (Read-Host -Prompt 'Input your desired tag value'),

    [Parameter(Mandatory=$false)]
    [switch]$force,
    
    [Parameter(Mandatory=$true)]
    [string]$tagName = (Read-Host -Prompt 'Input your desired tag name')
)

# Ensure $hostingBasePath does not end with a "/"
$hostingBasePath = $hostingBasePath.TrimEnd('/')
$orgList = $organizations.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)

if ($hostingBasePath -like 'dev.azure.com') {
    $analyticsBasePath = "https://analytics.dev.azure.com"
} else {
    $analyticsBasePath = $hostingBasePath
}

# Define the Azure DevOps organization URL, PAT, and API version
$organizationUrl = "$hostingBasePath/$orgName"

Write-Host "> Organization URL: $organizationUrl"
# Create a header for the API request
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$pat)))
$headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}


# Send a GET request to the Azure DevOps REST API to get all agent pools
$pipelinesUrl = "$organizationUrl/$projectName/_apis/build/definitions?path=$pipelinePath&name=$pipelineName"

$pipelinesResponse = Invoke-RestMethod -Uri $pipelinesUrl -Method Get -ContentType "application/json" -Headers $headers

if ($false -eq $force) {
    $confirm = Read-Host -Prompt "Are you sure you want to tag $($pipelinesResponse.count) pipelines with tag [$($tagName): $tagValue]? (y/n)"
    if ($confirm -ne "y") {
        exit
    }
}

foreach ($pipeline in $pipelinesResponse.value) {
    
    # Get Pipeline Runs in the given date range
    $updateUrl = "$($pipeline._links.self.href.Split('?')[0])/tags?api-version=7.1-preview.3"
    $body = "[`"$($tagName): $tagValue`"]"
    $result = Invoke-RestMethod -Uri $updateUrl -Method POST -ContentType "application/json" -Headers $headers -Body $body
    Write-Host "Pipeline $pipelineName updated with tag $($tagName): $tagValue"
}
