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

    [Parameter(Mandatory=$true)]
    [string]$tagValue = (Read-Host -Prompt 'Input your desired tag value'),

    [Parameter(Mandatory=$false)]
    [switch]$force,
    
    [Parameter(Mandatory=$true)]
    [string]$tagName = (Read-Host -Prompt 'Input your desired tag name')
)

# Ensure $hostingBasePath does not end with a "/"
$hostingBasePath = $hostingBasePath.TrimEnd('/')

# Define the Azure DevOps organization URL, PAT, and API version
$organizationUrl = "$hostingBasePath/$orgName"

Write-Host "> Organization URL: $organizationUrl"
# Create a header for the API request
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$pat)))
$headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}


# Send a GET request to the Azure DevOps REST API to get all agent pools
$projectsUrl = "$organizationUrl/_apis/projects"

$projectsResponse = Invoke-RestMethod -Uri $projectsUrl -Method Get -ContentType "application/json" -Headers $headers

$project = $projectsResponse.value | Where-Object { $_.name -eq $projectName }

if ($null -eq $project) {
    Write-Host "Project $projectName not found"
    exit
} else {
    $confirm = Read-Host -Prompt "Are you sure you want to tag project [$projectName] with tag [$($tagName): $tagValue]? (y/n)"
    if ($confirm -ne "y") {
        exit
    }
}

$body = "[$(@{
      "op" = "add"
      "path" = "/$tagName"
      "value" = $tagValue
    } | ConvertTo-Json -Depth 10)]"

Invoke-RestMethod -Uri "$($project.url)/properties?api-version=7.2-preview.1" `
    -Method Patch `
    -ContentType "application/json-patch+json" `
    -Headers $headers `
    -Body $body
