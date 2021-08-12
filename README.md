# k3d-dev-up

Deploy k3d dev environment to AWS, including:

- creating an ec2 security group
- creating a private key
- creating a local .pem file
- creating an ec2 keypair
- creating an ec2 instance
- creating a k3d cluster on the instance
- copying the cluster's kubeconfig to your local machine

## Prerequisites

- aws cli
- terraform
- kubectl

Shell commands used:

- `scp` - to copy the remote kubeconfig to local machine
- `sed` - to update the kubeconfig's server IP

## Instructions

1. Check for an existing AWS profile 
```shell
aws configure list-profiles
```
2. If desired profile is not present, configure a profile
```shell
aws configure --profile <PROFILE_NAME>
# aws_access_key_id - The AWS access key part of your credentials
# aws_secret_access_key - The AWS secret access key part of your credentials
# region - us-gov-west-1
# output - json
```
3. Create variables (or set in variables.tf)
```shell
# required
export TF_VAR_AWSPROFILE="<PROFILE_NAME>"
export TF_VAR_AWSUSERNAME=$( aws sts get-caller-identity --query Arn --output text --profile ${TF_VAR_AWSPROFILE} | cut -f 2 -d '/' )

# optional
export TF_VAR_INSTANCETYPE="<EC2_INSTANCE_TYPE>"            # defaults to "t2.xlarge" if not set
export TF_VAR_VOLUMESIZE="<EC2_EBS_VOLUME_SIZE>"            # defaults to "50" if not set (GiBs)
```
4. Initialize terraform (first time only)
```shell
terraform init
```
5. Create infrastructure (kubeconfig is dumped into working directory as `k3d.yaml`)
```shell
terraform apply
```
6. Test cluster access
```shell
kubectl --kubeconfig=./k3d.yaml get nodes
```

## Cleanup

```shell
terraform destroy
```

## Contributing

Please open an issue or PR if you'd like to see something changed.
