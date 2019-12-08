# Killing stubborn namespaces

```
export NS="stubborn"
kubectl get ns $NS -ojson > $NS.json

## edit $NS.json and remove finalizers
## TODO - achieve this via jq

curl -kH "Content-Type: application/json" \
  -H "Authorization: Bearer <kubeconfig token>" \
  -X PUT --data-binary @$NS.json \
  https://<apiserver IP>:<apiserver PORT>/api/v1/namespaces/$NS/finalize
```

