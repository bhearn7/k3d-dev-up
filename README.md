# k3d-dev-up

Deploy k3d to AWS.

### Pre Reqs
- terraform
- scp

### Instructions

1. **ensure userdata.txt and private key are in current directory**

2. export required terraform variables
```
export TF_VAR_AWSPROFILE="default"
export TF_VAR_AWSUSERNAME="blake.hearn"
export TF_VAR_DATETIME=$( date +%Y%m%d%H%M%S )
export TF_VAR_YOURLOCALPUBLICIP=$( curl https://checkip.amazonaws.com )
```

3. create infrastructure (Kubeconfig is dumped into working directory as `k3d.yaml`)
```
terraform apply
```

4. Edit `k3d.yaml`, replace the server host `0.0.0.0` with the public IP of the EC2 instance, and test cluster access
```
kubectl --kubeconfig=./k3d.yaml get nodes
```

### Cleanup

`terraform destroy`

### Contributing

Please open an issue or PR if you'd like to see something changed.