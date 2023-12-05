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
    # This parameter is optional and defaults to "agent-pool-usage.csv" if not provided.
    [Parameter(Mandatory=$false)]
    [string]$outputDirectory = "./",
    
    # The start date for fetching the agent pool usage. If not provided, the script will prompt for it.
    [Parameter(Mandatory=$false)]
    [string]$startDate = (Read-Host -Prompt 'Input your start date (yyyy-MM-dd)'),
    
    # If this switch is provided, the script will append the results to the existing output file instead of overwriting it.
    [Parameter(Mandatory=$false)]
    [switch]$append = $false,
    
    # The name of the tag for which the agent pool usage will be fetched.
    [Parameter(Mandatory=$true)]
    [string]$tagName
)

# Ensure $hostingBasePath does not end with a "/"
$hostingBasePath = $hostingBasePath.TrimEnd('/')
$orgList = $organizations.Split(',', [System.StringSplitOptions]::RemoveEmptyEntries)

$results = @()
$summary = [PSCustomObject]@{ }

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

    # For each agent pool, send another GET request to get all agents in that pool
    foreach($pool in $agentPoolsResponse.value) {
        $requestsUrl = "$organizationUrl/_apis/distributedtask/pools/$($pool.id)/jobrequests"
        $requestsResponse = Invoke-RestMethod -Uri $requestsUrl -Method Get -ContentType "application/json" -Headers $headers

        $requests = @($requestsResponse.value | Where-Object { $_.finishTime -gt $startDate })

        Write-Host "Pool `"$($pool.name)`" (Id: $($pool.id)) has [$($requests.count)] requests since [$startDate]"
        if ($null -eq $requests.count) {
            $requests | ConvertTo-Json -Depth 10
            Read-Host -Prompt "Press any key to continue"
        }

        foreach ($request in $requests) {
            $receivedTime = Get-Date $request.receiveTime
            $finishedTime = Get-Date $request.finishTime

            $definitionDetails = Invoke-RestMethod -Uri $request.definition._links.self.href -Method Get -ContentType "application/json" -Headers $headers

            $definitionDetails.tags = $definitionDetails.tags | Where-Object { $_ -match "^$($tagName): .+" } | ForEach-Object { $_.Replace("$($tagName): ", "") }

            if ($definitionDetails.tags.count -gt 1) {
                Write-Host "Warning: Multiple $tagName tags found on pipeline $($definitionDetails.name)"
            }

            if ($null -eq $definitionDetails.tags -or $definitionDetails.tags.Count -eq 0) {
                # No tracking tags have been found on the pipeline.. lets check above on the project for tags
                Write-Host "    Checking project for tags on pipeline $($definitionDetails.name)"
                $projectDetails = Invoke-RestMethod -Uri "$($definitionDetails.project.url)/properties" -Method Get -ContentType "application/json" -Headers $headers
                $projectTags = $projectDetails.value | Where-Object { $_.name -eq $tagName } | ForEach-Object { $_.value }
                if ($projectTags.count -gt 0) {
                    if ($definitionDetails.tags.count -gt 1) {
                        Write-Host "Warning: Multiple $tagName tags found on project $($projectDetails.name)"
                    }
                    $definitionDetails.tags = $projectTags
                    if ($null -eq $definitionDetails.tags -or $definitionDetails.tags.Count -eq 0) {
                        $definitionDetails.tags = @("No Tags")
                    }
                } else {
                    $definitionDetails.tags = @("No Tags")
                }
            }
            
            $results += [PSCustomObject] @{
                Organization = $orgName
                Project = $definitionDetails.project.name
                PoolName = $pool.name
                AgentName = $request.agentName
                PoolId = $pool.id
                DefinitionId = $request.definition.id
                PipelineName = $definitionDetails.name
                FinishTime = $request.finishTime
                DurationInSeconds = ($finishedTime - $receivedTime).TotalSeconds
                Result = $request.result
                Tags = $definitionDetails.tags -join ','
            }

            foreach ($tag in $definitionDetails.tags) {
                $key = "/$orgName/$($pool.name)/$tag"
                if ($null -eq $summary.$key) {
                    $summary | Add-Member -MemberType NoteProperty -Name $key -Value 0
                }
                $summary.$key += ($finishedTime - $receivedTime).TotalSeconds
            }
        }

    }
}
$summaryList = $summary.PSObject.Properties | ForEach-Object {
    [PSCustomObject] @{
        Org = $_.Name.Split('/')[1]
        Pool = $_.Name.Split('/')[2]
        Tag = $_.Name.Split('/')[3]
        TotalSeconds = $_.Value
        StartDate = $startDate
    }
}
$summaryList | Export-Csv -Path "$outputDirectory/agent-pool-usage-summary_$startDate.csv" -NoTypeInformation -Force
$results | Export-Csv -Path "$outputDirectory/agent-pool-usage-results_$startDate.csv" -NoTypeInformation -Force