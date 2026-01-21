# AGIC Test Deployment

This folder contains Kubernetes manifests for testing Application Gateway Ingress Controller (AGIC) with a simple echo server deployment.

## Resources

1. **namespace.yaml** - Creates the `fouadtesting` namespace
2. **deployment.yaml** - Deploys 3 replicas of an echo server
3. **service.yaml** - ClusterIP service to expose the echo pods
4. **ingress.yaml** - AGIC Ingress resource with Application Gateway annotations

## Deployment Process

```bash
# Apply all manifests
kubectl apply -f namespace.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f ingress.yaml

# Verify deployment
kubectl get all -n fouadtesting
kubectl get ingress -n fouadtesting

# Get Application Gateway public IP
az network application-gateway show --resource-group rg-webapp-dev-eus2-001 --name appgw-webapp-dev-eus2-001 --query frontendIPConfigurations[0].publicIPAddress.id -o tsv | xargs az network public-ip show --ids --query ipAddress -o tsv
```

## Testing

Once deployed, access the echo server using the Application Gateway public IP address:

```bash
curl http://<APPGW_PUBLIC_IP>/
```

## AGIC Annotations

The ingress includes several AGIC-specific annotations:
- `kubernetes.io/ingress.class`: Specifies AGIC as the ingress controller
- `appgw.ingress.kubernetes.io/backend-path-prefix`: Backend path rewrite
- `appgw.ingress.kubernetes.io/ssl-redirect`: Disable SSL redirect
- `appgw.ingress.kubernetes.io/connection-draining`: Enable connection draining
- `appgw.ingress.kubernetes.io/request-timeout`: Set request timeout
