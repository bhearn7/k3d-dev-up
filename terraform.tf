variable "AWSPROFILE" {
  type = string
}
variable "AWSUSERNAME" {
  type = string
}
variable "DATETIME" {
  type = string
}
variable "YOURLOCALPUBLICIP" {
  type = string
}
provider "aws" {
  profile = var.AWSPROFILE
  region  = "us-gov-west-1"
}
resource "aws_security_group" "allow_ingress" {
  name        = var.AWSUSERNAME
  description = "Created by ${var.AWSUSERNAME} at ${var.DATETIME}"
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["${var.YOURLOCALPUBLICIP}/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_instance" "ec2_instance" {
  ami           = "ami-84556de5"
  instance_type = "t2.xlarge"
  key_name      = var.AWSUSERNAME
  tags = {
    "Owner" = "${var.AWSUSERNAME}",
    "env"   = "bigbangdev"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 50
  }
  iam_instance_profile = "InstanceOpsRole"
  security_groups      = [aws_security_group.allow_ingress.name]
  user_data            = file("./userdata.txt")
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./${var.AWSUSERNAME}.pem")
    host        = self.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "sudo apt remove docker docker-engine docker.io containerd runc",
      "sudo apt update",
      "sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -",
      "sudo apt-key fingerprint 0EBFCD88",
      "sudo add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"",
      "sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io",
      "sudo usermod -aG docker $USER"
    ]
  }
}
resource "null_resource" "create_k3d_cluster" {
  depends_on = [aws_instance.ec2_instance]
  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("./${var.AWSUSERNAME}.pem")
    host        = aws_instance.ec2_instance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      "wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash",
      "export EC2_PUBLIC_IP=$( curl https://ipinfo.io/ip )",
      "echo $EC2_PUBLIC_IP",
      "k3d cluster create --servers 1 --agents 3 --volume /etc/machine-id:/etc/machine-id --k3s-server-arg --disable=traefik --k3s-server-arg --disable=metrics-server --k3s-server-arg --tls-san=$EC2_PUBLIC_IP --port 80:80@loadbalancer --port 443:443@loadbalancer --api-port 6443"
    ]
  }
}
resource "null_resource" "copy_kubeconfig" {
  depends_on = [null_resource.create_k3d_cluster]
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "scp -o StrictHostKeyChecking=no -i ./${var.AWSUSERNAME}.pem ubuntu@${aws_instance.ec2_instance.public_ip}:~/.kube/config ./k3d.yaml"
  }
}