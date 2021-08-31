data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
provider "aws" {
  region  = "us-gov-west-1"
  profile = yamldecode(file("variables.yaml"))["awsProfile"]
}

resource "aws_security_group" "allow_personal_ingress" {
  name = yamldecode(file("variables.yaml"))["awsUsername"]
  lifecycle {
    ignore_changes = [description]
  }
  description = "Created by ${yamldecode(file("variables.yaml"))["awsUsername"]} at ${timestamp()}"
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "local_file" "pem" {
  filename        = "${yamldecode(file("variables.yaml"))["awsUsername"]}.pem"
  content         = tls_private_key.ssh.private_key_pem
  file_permission = "400"
}
resource "aws_key_pair" "ec2_keypair" {
  key_name   = yamldecode(file("variables.yaml"))["awsUsername"]
  public_key = tls_private_key.ssh.public_key_openssh
}
resource "aws_instance" "ec2_instance" {
  ami           = "ami-84556de5"
  instance_type = yamldecode(file("variables.yaml"))["instanceType"]
  key_name      = aws_key_pair.ec2_keypair.key_name
  tags = {
    "Name"  = "${yamldecode(file("variables.yaml"))["awsUsername"]}-k3d-dev",
    "Owner" = yamldecode(file("variables.yaml"))["awsUsername"],
    "env"   = "bigbangdev"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = yamldecode(file("variables.yaml"))["volumeSize"]
  }
  iam_instance_profile = "InstanceOpsRole"
  security_groups      = [aws_security_group.allow_personal_ingress.name]
  user_data            = file("./userdata.txt")
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
    host        = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt remove docker docker-engine docker.io containerd runc",
      "sudo apt update",
      "sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo apt-key fingerprint 0EBFCD88",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io",
      "curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\"",
      "sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl",
      "kubectl version --client",
      "curl -s https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh | bash",
      "sudo mv kustomize /usr/local/bin/",
      "sudo usermod -aG docker $USER"
    ]
  }
}

resource "null_resource" "setup_cluster" {
  depends_on = [aws_instance.ec2_instance]
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.ssh.private_key_pem
    host        = aws_instance.ec2_instance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=${yamldecode(file("variables.yaml"))["k3dVersion"]} bash",
      "export EC2_PUBLIC_IP=$( curl https://ipinfo.io/ip )",
      "echo $EC2_PUBLIC_IP",
      "k3d cluster create --servers 1 --agents 3 --volume /etc/machine-id:/etc/machine-id --k3s-server-arg --disable=traefik --k3s-server-arg --tls-san=$EC2_PUBLIC_IP --port 80:80@loadbalancer --port 443:443@loadbalancer --api-port 6443",
      "git clone https://repo1.dso.mil/platform-one/big-bang/bigbang.git",
      "cd bigbang",
      "./scripts/install_flux.sh -u ${yamldecode(file("variables.yaml"))["registryUsername"]} -p ${yamldecode(file("variables.yaml"))["registryPassword"]}"
    ]
  }
}
resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.setup_cluster]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "scp -o StrictHostKeyChecking=no -i ./${local_file.pem.filename} ubuntu@${aws_instance.ec2_instance.public_ip}:~/.kube/config ./config; sed -e 's/0.0.0.0/${aws_instance.ec2_instance.public_ip}/' config > k3d.yaml; rm ./config"
  }
}

output "ec2_instance_ip" {
  value = aws_instance.ec2_instance.public_ip
}