# Azure Service Bus Resource Creation Script
# Resource Group: rg-webapp-dev-eus2-001

$namespaceName = "sb-webapp-dev-eus2-001"
$resourceGroup = "rg-webapp-dev-eus2-001"

# Read the JSON configuration
$config = Get-Content -Raw -Path "servicebus_architecture_config.json" | ConvertFrom-Json

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Service Bus Resource Creation Script" -ForegroundColor Cyan
Write-Host "Namespace: $namespaceName" -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Counters
$queueCount = 0
$topicCount = 0
$subscriptionCount = 0

# Helper function to normalize TTL (handle extremely large values)
function Get-NormalizedTTL {
    param($ttl)
    # If TTL is the "infinite" value, use a large but valid value (10 years)
    if ($ttl -match "P10675199") {
        return "P3650D"  # 10 years
    }
    return $ttl
}

# =============================================
# CREATE QUEUES
# =============================================
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "CREATING QUEUES" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

$queues = $config.queues.PSObject.Properties

foreach ($queue in $queues) {
    $queueName = $queue.Name
    $queueConfig = $queue.Value
    
    Write-Host "Creating queue: $queueName" -ForegroundColor Cyan
    
    $enableBatched = if ($queueConfig.enableBatchedOperations) { "true" } else { "false" }
    $ttl = Get-NormalizedTTL $queueConfig.defaultMessageTimeToLive
    
    $result = az servicebus queue create `
        --resource-group $resourceGroup `
        --namespace-name $namespaceName `
        --name $queueName `
        --max-size $queueConfig.maxSizeInMegabytes `
        --lock-duration $queueConfig.lockDuration `
        --max-delivery-count $queueConfig.maxDeliveryCount `
        --default-message-time-to-live $ttl `
        --enable-batched-operations $enableBatched 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [SUCCESS] Queue created" -ForegroundColor Green
        $queueCount++
    } else {
        if ($result -match "already exists" -or $result -match "Conflict") {
            Write-Host "  [SKIPPED] Queue already exists" -ForegroundColor Yellow
        } else {
            Write-Host "  [ERROR] $result" -ForegroundColor Red
        }
    }
}

Write-Host ""

# =============================================
# CREATE TOPICS AND SUBSCRIPTIONS
# =============================================
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "CREATING TOPICS AND SUBSCRIPTIONS" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow

$topics = $config.topics.PSObject.Properties

foreach ($topic in $topics) {
    $topicName = $topic.Name
    $topicConfig = $topic.Value
    
    Write-Host ""
    Write-Host "Creating topic: $topicName" -ForegroundColor Cyan
    
    $enableBatched = if ($topicConfig.enableBatchedOperations) { "true" } else { "false" }
    $enableOrdering = if ($topicConfig.supportOrdering) { "true" } else { "false" }
    $ttl = Get-NormalizedTTL $topicConfig.defaultMessageTimeToLive
    
    $result = az servicebus topic create `
        --resource-group $resourceGroup `
        --namespace-name $namespaceName `
        --name $topicName `
        --max-size $topicConfig.maxSizeInMegabytes `
        --default-message-time-to-live $ttl `
        --enable-batched-operations $enableBatched `
        --enable-ordering $enableOrdering 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [SUCCESS] Topic created" -ForegroundColor Green
        $topicCount++
    } else {
        if ($result -match "already exists" -or $result -match "Conflict") {
            Write-Host "  [SKIPPED] Topic already exists" -ForegroundColor Yellow
        } else {
            Write-Host "  [ERROR] $result" -ForegroundColor Red
        }
    }
    
    # Create subscriptions for this topic
    if ($topicConfig.subscriptions.PSObject.Properties.Count -gt 0) {
        $subscriptions = $topicConfig.subscriptions.PSObject.Properties
        
        foreach ($subscription in $subscriptions) {
            $subName = $subscription.Name
            $subConfig = $subscription.Value
            
            Write-Host "    Creating subscription: $subName" -ForegroundColor Magenta
            
            $subEnableBatched = if ($subConfig.enableBatchedOperations) { "true" } else { "false" }
            $subTtl = Get-NormalizedTTL $subConfig.defaultMessageTimeToLive
            
            $subResult = az servicebus topic subscription create `
                --resource-group $resourceGroup `
                --namespace-name $namespaceName `
                --topic-name $topicName `
                --name $subName `
                --lock-duration $subConfig.lockDuration `
                --max-delivery-count $subConfig.maxDeliveryCount `
                --default-message-time-to-live $subTtl `
                --enable-batched-operations $subEnableBatched 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "      [SUCCESS] Subscription created" -ForegroundColor Green
                $subscriptionCount++
            } else {
                if ($subResult -match "already exists" -or $subResult -match "Conflict") {
                    Write-Host "      [SKIPPED] Subscription already exists" -ForegroundColor Yellow
                } else {
                    Write-Host "      [ERROR] $subResult" -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Queues created: $queueCount" -ForegroundColor Green
Write-Host "Topics created: $topicCount" -ForegroundColor Green
Write-Host "Subscriptions created: $subscriptionCount" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
