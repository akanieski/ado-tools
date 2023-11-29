# Azure DevOps Agent Management Tools

This repository contains a collection of PowerShell scripts for managing Azure DevOps. The tools in this repository are designed to help with various aspects of managing Azure DevOps agents. They interact with the Azure DevOps REST API to perform tasks such as querying agent details, managing agent pools, and more.

Currently, the repository includes the following tools:
## Functions
### `Get-Agents`
This script queries Azure DevOps for agent details across multiple organizations.

| Parameter        | Description                                                                                           | Mandatory | Default Value       |
|------------------|-------------------------------------------------------------------------------------------------------|-----------|---------------------|
| `organizations`  | A comma-separated list of organization names that the script will query for agents.                   | Yes       | None                |
| `pat`            | The Personal Access Token (PAT) used for authentication with the Azure DevOps REST API.               | Yes       | None                |
| `hostingBasePath`| The base URL for the Azure DevOps instance.                                                           | No        | "https://dev.azure.com" |
| `outputPath`     | The file path where the script will output the CSV file with the agent details.                       | No        | "agents.csv"        |
| `capabilities`   | A comma-separated list of capabilities that the script will query for each agent.                     | No        | None                |

```
.\Get-Agents.ps1 `
  -organizations "org1,org2,org3" `
  -pat "yourPAT" `
  -hostingBasePath "https://dev.azure.com" `
  -outputPath "agents.csv" `
  -capabilities "Agent.ComputerName,NUMBER_OF_CORES"
```

### `Add-PipelineTag`
This script adds a tag to a specific Azure DevOps pipeline.

| Parameter        | Description                                                                                           | Mandatory | Default Value       |
|------------------|-------------------------------------------------------------------------------------------------------|-----------|---------------------|
| `orgName`        | The name of the organization that contains the pipeline.                                              | Yes       | None                |
| `pat`            | The Personal Access Token (PAT) used for authentication with the Azure DevOps REST API.               | Yes       | None                |
| `projectName`    | The name of the project that contains the pipeline.                                                   | Yes       | None                |
| `pipelinePath`   | The path to the pipeline within the project.                                                          | Yes       | None                |
| `pipelineName`   | The name of the pipeline to which the tag will be added.                                              | Yes       | None                |
| `tag`            | The tag that will be added to the pipeline.                                                           | Yes       | None                |

```
.\Add-PipelineTag.ps1 `
  -orgName "yourOrg" `
  -pat "yourPAT" `
  -projectName "yourProject" `
  -pipelinePath "yourPath" `
  -pipelineName "yourPipeline" `
  -tag "yourTag"
```
## Usage

Each script in the repository is a standalone PowerShell script. To run a script, open a PowerShell terminal, navigate to the directory containing the script, and run it. Each script includes detailed comments explaining its parameters and functionality.

## Future Tools

This repository is intended to be a growing collection of tools for Azure DevOps agent management. Future tools may include scripts for creating and deleting agent pools, updating agent settings, and more.

## Contributions

Contributions to this repository are welcome. If you have a tool or script that you think would be useful to others, feel free to submit a pull request.

## License

These scripts are provided as-is with no warranty. They are for educational purposes and should be used with caution in production environments.