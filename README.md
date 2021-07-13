# k3d-dev-up

Deploy k3d dev environment to AWS, including:

- creating a security group
- creating an instance
- creating a k3d cluster on the instance
- copying the k3d cluster's kubeconfig to your local machine

## Prerequisites

- aws cli
- terraform
- bash
- kubectl

Commands used:

- `chmod` - to set permissions on the private key
- `openssl` - to verify private key
- `scp` - to copy the remote kubeconfig to local machine
- `sed` - to update the kubeconfig's server IP

## Instructions

1. Configure aws credentials

```shell
aws configure
# aws_access_key_id - The AWS access key part of your credentials
# aws_secret_access_key - The AWS secret access key part of your credentials
# region - us-gov-west-1
# output - json

# verify configuration
aws configure list
```

1. Set username variable and disable local pager

```shell
export TF_VAR_AWSUSERNAME=$( aws sts get-caller-identity --query Arn --output text | cut -f 2 -d '/' )
export AWS_PAGER=""

# verify username
echo $TF_VAR_AWSUSERNAME
```

1. Recreate keypair

```shell
rm -f $TF_VAR_AWSUSERNAME.pem
aws ec2 delete-key-pair --key-name $TF_VAR_AWSUSERNAME
aws ec2 create-key-pair --key-name $TF_VAR_AWSUSERNAME --query 'KeyMaterial' --output text > $TF_VAR_AWSUSERNAME.pem
chmod 400 $TF_VAR_AWSUSERNAME.pem

# verify private key
openssl rsa -noout -inform PEM -in $TF_VAR_AWSUSERNAME.pem
aws ec2 describe-key-pairs --key-name $TF_VAR_AWSUSERNAME
```

1. Create infrastructure (kubeconfig is dumped into working directory as `k3d.yaml`)

```shell
terraform apply
```

1. Test cluster access

```shell
kubectl --kubeconfig=./k3d.yaml get nodes
```

## Cleanup

```shell
terraform destroy
```

## Contributing

Please open an issue or PR if you'd like to see something changed.
