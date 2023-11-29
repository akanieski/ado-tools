param(
    # The $organizations parameter is a comma-separated list of organization names that the script will query for agents.
    # This parameter is mandatory and the script will prompt for it if it's not provided.
    [Parameter(Mandatory=$true)]
    [string]$organizations = (Read-Host -Prompt 'Input your organizations (comma separated list)'),

    # The $pat parameter is the Personal Access Token (PAT) used for authentication with the Azure DevOps REST API.
    # This parameter is mandatory and the script will prompt for it if it's not provided.
    [Parameter(Mandatory=$true)]
    [string]$pat = (Read-Host -Prompt 'Input your PAT'),

    # The $hostingBasePath parameter is the base URL for the Azure DevOps instance.
    # This parameter is optional and defaults to "https://dev.azure.com" if not provided.
    [Parameter(Mandatory=$false)]
    [string]$hostingBasePath = "https://dev.azure.com",

    # The $outputPath parameter is the file path where the script will output the CSV file with the agent details.
    # This parameter is optional and defaults to "agents.csv" if not provided.
    [Parameter(Mandatory=$false)]
    [string]$outputPath = "agents.csv",

    # The $capabilities parameter is a comma-separated list of capabilities that the script will query for each agent.
    # This parameter is optional and the script will prompt for it if it's not provided.
    [Parameter(Mandatory=$false)]
    [string]$capabilities = (Read-Host -Prompt 'Input your capabilities (comma separated list)')
)

# 1. First we prompt the user for the organizations they want to query, the PAT, and the capabilities they want to query.
# 2. Then we go through each organization the user input and query the agent pools.
# 3. For each agent pool, we query the agents.
# 4. Then we query the agent details for each agent.
# 5. Finally, we output the agents to a CSV file.

# Ensure $hostingBasePath does not end with a "/"
$hostingBasePath = $hostingBasePath.TrimEnd('/')
$orgList = $organizations.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)

foreach ($orgName in $orgList) {
    # Define the Azure DevOps organization URL, PAT, and API version
    $organizationUrl = "$hostingBasePath/$orgName"
    Write-Host "> Organization URL: $organizationUrl"
    # Create a header for the API request
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$pat)))
    $headers = @{Authorization=("Basic {0}" -f $base64AuthInfo)}


    # Send a GET request to the Azure DevOps REST API to get all agent pools
    $agentPoolsUrl = "$organizationUrl/_apis/distributedtask/pools"
    $agentPoolsResponse = Invoke-RestMethod -Uri $agentPoolsUrl -Method Get -ContentType "application/json" -Headers $headers

    $agents = @()
    # For each agent pool, send another GET request to get all agents in that pool
    foreach($pool in $agentPoolsResponse.value) {
        if ($pool.isHosted) {
            continue;
        }
        $agentsUrl = "$organizationUrl/_apis/distributedtask/pools/$($pool.id)/agents"
        $agentsResponse = Invoke-RestMethod -Uri $agentsUrl -Method Get -ContentType "application/json" -Headers $headers

        Write-Host "....... Pool: $($pool.name) - Agents: $($agentsResponse.count)"
        # Output the agent details
        foreach ($agent in $agentsResponse.value) {
            $agentDetails = Invoke-RestMethod -Uri "$($agent._links.self.href)?includeCapabilities=true&includeLastCompletedRequest=true" -Method Get -ContentType "application/json" -Headers $headers
            
            $agentObject = [PSCustomObject]@{
                'OrgName' = $orgName
                'AgentName' = $agentDetails.name
                'AgentPool' = $pool.name
                'AgentStatus' = $agentDetails.status
                'AgentVersion' = $agentDetails.version
                "LastActivity" = if ($agentDetails.lastCompletedRequest) { $agentDetails.lastCompletedRequest.finishTime } else { $null }
            }
            if ($capabilities) {
                $capabilitiesList = $capabilities.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)
            } else {
                $keys = $agentDetails.systemCapabilities | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
                $capabilitiesList = $keys
            }
            foreach ($capability in $capabilitiesList) {
                $capabilityValue = if ($agentDetails.systemCapabilities."$capability") { $agentDetails.systemCapabilities."$capability" } else { $null }
                $agentObject | Add-Member -NotePropertyName $capability -NotePropertyValue $capabilityValue
            }
            $agents += $agentObject
        }
    }
}

Write-Host "Total Agents: $($agents.Count)"
$agents | ConvertTo-Csv  -NoTypeInformation | Out-File -FilePath $outputPath