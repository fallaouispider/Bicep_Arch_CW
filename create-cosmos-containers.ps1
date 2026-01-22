# Azure Cosmos DB Container Creation Script (Serverless Account)
# Account: cosmos-webapp-dev-eus2-001
# Resource Group: rg-webapp-dev-eus2-001
# Note: Serverless accounts don't support setting throughput - scaling is automatic

$accountName = "cosmos-webapp-dev-eus2-001"
$resourceGroup = "rg-webapp-dev-eus2-001"

# Read the JSON configuration
$config = Get-Content -Raw -Path "cosmos_architecture_config.json" | ConvertFrom-Json

# Get all database names (top-level keys)
$databases = $config.PSObject.Properties.Name

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Cosmos DB Container Creation Script" -ForegroundColor Cyan
Write-Host "(Serverless Account - No throughput settings)" -ForegroundColor Cyan
Write-Host "Account: $accountName" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Track totals
$totalDatabases = $databases.Count
$totalContainers = 0
$successCount = 0
$skipCount = 0

foreach ($dbName in $databases) {
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "Processing Database: $dbName" -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
    
    # Create the database
    Write-Host "Creating database: $dbName..." -ForegroundColor Green
    az cosmosdb sql database create `
        --account-name $accountName `
        --resource-group $resourceGroup `
        --name $dbName 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Database $dbName already exists. Continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "  Database created successfully." -ForegroundColor Green
    }
    
    # Get all containers for this database
    $containers = $config.$dbName.PSObject.Properties
    
    foreach ($container in $containers) {
        $containerName = $container.Name
        $containerConfig = $container.Value
        
        # Get partition key path (from the simple partitionKey object, not the nested config)
        $partitionKeyPath = $containerConfig.partitionKey.paths[0]
        
        # Get configured throughput (for reference only - not used in serverless)
        $configuredThroughput = if ($containerConfig.throughput) { $containerConfig.throughput } else { 400 }
        
        Write-Host "  Creating container: $containerName" -ForegroundColor Cyan
        Write-Host "    - Partition Key: $partitionKeyPath" -ForegroundColor Gray
        Write-Host "    - Config RU/s: $configuredThroughput (serverless - auto-scaling)" -ForegroundColor DarkGray
        
        # For serverless accounts, don't specify throughput
        az cosmosdb sql container create `
            --account-name $accountName `
            --resource-group $resourceGroup `
            --database-name $dbName `
            --name $containerName `
            --partition-key-path $partitionKeyPath 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [SUCCESS] Container created" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "    [SKIPPED] Container already exists" -ForegroundColor Yellow
            $skipCount++
        }
        
        $totalContainers++
    }
    
    Write-Host ""
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Total Databases: $totalDatabases" -ForegroundColor Green
Write-Host "Total Containers Processed: $totalContainers" -ForegroundColor Green
Write-Host "  - Created: $successCount" -ForegroundColor Green
Write-Host "  - Already Existed: $skipCount" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan

