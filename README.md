# k3d-dev-up

Deploy k3d to AWS.

## Prerequisites

- terraform
- scp

## Instructions

1. **ensure userdata.txt and private key are in current directory**

1. export required terraform variables

```shell
export TF_VAR_AWSPROFILE=<YOUR_PROFILE> # example: "default"
export TF_VAR_AWSUSERNAME=<YOUR_USERNAME> # example: "first.last"
export TF_VAR_DATETIME=$( date +%Y%m%d%H%M%S )
export TF_VAR_YOURLOCALPUBLICIP=$( curl https://checkip.amazonaws.com )
```

1. Create infrastructure (Kubeconfig is dumped into working directory as `k3d.yaml`)

```shell
terraform apply
```

1. Edit `k3d.yaml`, replace the server host `0.0.0.0` with the public IP of the EC2 instance, and test cluster access

```shell
kubectl --kubeconfig=./k3d.yaml get nodes
```

## Cleanup

```shell
terraform destroy
```

## Contributing

Please open an issue or PR if you'd like to see something changed.
