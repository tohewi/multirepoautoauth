Function GetDevOpsAuthorizationHeader () {
    Param(
        $userEmail,
        $Token
    )

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $userEmail, $token)))
    
    return @{Authorization = ("Basic {0}" -f $base64AuthInfo) }
}

# Install AZ Cli DevOps module
Write-host "Installing Az Cli ADO extension"
az extension add --name azure-devops
# Logging in.
$devopsorg = "https://dev.azure.com/tomwir"
Write-host "Signing in to DevOps organization: '$($devopsorg)'"
az devops login --organization "$($devopsorg)"


$templateProjectName = "CloudTemplates"
$templateProjectId = ""
$templateProjectRepositoryName = "CloudTemplates"
$templateProjectRepositoryId = ""

$projectName = "Application X"
$projectId = ""
$pipelineName = "Core Infrastructure Pipeline"


# Get Project Id of Project
$result = az devops project show --project "$($projectname)" `
    --organization "$($devopsorg)" `
    |ConvertFrom-Json
if (($? -eq $true) -and ($result)) {   
    Write-Host "Application Project Found: '$($projectname)'"
    $projectId = $result.id    
}
else {
    Write-host "Could not find Application Project. Error : $($?)"
}
# Get Pipeline Id for Core Infra Pipeline
$pipeline = az pipelines list `
    --folder-path "/" `
    --organization "$($devopsorg)" `
    --project "$($projectname)" `
    --query "[?name=='$($pipelineName)'].{name:name,Id:id}" `
| ConvertFrom-Json
if ($? -eq $false) {    
    Write-Host  "Could not retrieve Id for Core Infra Pipeline. Error : $($?)"
}

# Get the Template Repository Id and Template Project Id
$result = az repos show --repository "$($templateProjectRepositoryName)" `
    --organization "$($devopsorg)" `
    --project "$($templateProjectName)" `
    |ConvertFrom-Json
if (($? -eq $true) -and ($result)) {   
    Write-Host "Template Repository found: '$($templateProjectName)'"
    $templateProjectRepositoryId = $result.id    
    $templateProjectId = $result.project.id
}
else {
    Write-host "Could not find Template Repository. Error : $($?)"
}

Write-Host "Generating JSON payload for permissions update."
$body = @"
{    
    "pipelines": [
        {
            "id": $($pipeline.Id),
            "authorized": true
        }
    ],
    "resource": {       
    }
}
"@

$authorization = GetDevOpsAuthorizationHeader -Token $pat -userEmail $userEmail

$uri = "$($devopsorg)/$($projectId)/_apis/pipelines/pipelinePermissions/repository/$($templateProjectId).$($templateProjectRepositoryId)?api-version=6.1-preview.1"

try {
    $result = Invoke-RestMethod -Uri $uri -Method Patch -ContentType "application/json" -Headers $authorization -Body $body
}
catch{
    Write-Host  "Could not Authorize. Error: $($_.Exception.Message)"
}

