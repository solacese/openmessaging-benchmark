provider "aws" {
  region  = "${var.region}"
  version = "~> 2.7"
  profile = var.profile
}

provider "random" {
  version = "~> 2.1"
}

variable "ownerTag" {}
variable "daysTag" {}
variable "descriptionTag" {}

variable "public_key_path" {
  description = <<DESCRIPTION
Path to the SSH public key to be used for authentication.
Ensure this keypair is added to your local SSH agent so provisioners can
connect.

Example: ~/.ssh/solace_aws.pub
DESCRIPTION
}

variable "private_key_path" {}

resource "random_id" "hash" {
  byte_length = 8
}

variable "key_name" {
  default     = "solace-benchmark-key"
  description = "Desired name prefix for the AWS key pair"
}

variable "region" {}

variable "profile" {}

variable "instance_types" {
  type = "map"
}

variable "num_instances" {
  type = "map"
}

variable "centOS_ami" {
  type = "map"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "benchmark_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Solace-Benchmark-VPC-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"
  }
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "solace" {
  vpc_id = "${aws_vpc.benchmark_vpc.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.benchmark_vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.solace.id}"
}

# Create 3 subnets to launch each broker instance into one of them
resource "aws_subnet" "benchmark_subnet_1" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = {
    Name = "Solace-Benchmark-subnet1-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"
  }
}

resource "aws_subnet" "benchmark_subnet_2" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"
  tags = {
    Name = "Solace-Benchmark-subnet2-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }  
}

resource "aws_subnet" "benchmark_subnet_3" {
  vpc_id                  = "${aws_vpc.benchmark_vpc.id}"
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}c"
  tags = {
    Name = "Solace-Benchmark-subnet3-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }  
}


# Get public IP of this machine
data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "benchmark_security_group_broker" {
  name   = "terraform-solace-broker-${random_id.hash.hex}"
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress{
    from_port = 2222
    to_port = 2222
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  ingress{
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

 ingress{
    from_port = 8741
    to_port = 8741
    protocol = "tcp"
    self      = true
  }

 ingress{
    from_port = 8300
    to_port = 8302
    protocol = "tcp"
    self      = true
  }
 
 ingress{
    from_port = 8301
    to_port = 8302
    protocol = "udp"
    self      = true
  }

  ingress{
    from_port = 55555
    to_port = 55555
    protocol = "tcp"
    self      = true
  }

  ingress{
    from_port = 55555
    to_port = 55555
    protocol = "tcp"
    security_groups = [aws_security_group.benchmark_security_group_client.id]
  }

  # outbound internet access
  egress{
    from_port = 0
    to_port = 0 
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Benchmark-Security-Group-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }
}

resource "aws_security_group" "benchmark_security_group_client" {
  name   = "terraform-solace-client-${random_id.hash.hex}"
  vpc_id = "${aws_vpc.benchmark_vpc.id}"

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.body)}/32"]
  }

  tags = {
    Name = "Benchmark-Security-Group-${random_id.hash.hex}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }
}


resource "aws_key_pair" "auth" {
  key_name   = "${var.key_name}-${random_id.hash.hex}"
  public_key = "${file(var.public_key_path)}"
}

resource "aws_instance" "solace-broker-primary" {
  ami                    = "${var.centOS_ami[var.region]}"
  instance_type          = "${var.instance_types["messaging"]}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group_broker.id}"]
  monitoring             = true

  subnet_id              = "${aws_subnet.benchmark_subnet_1.id}"
  availability_zone      = "${var.region}a" #Each node of the Cluster on a different AZ

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }
  
  ebs_block_device {
    device_name = "/dev/sdc"
    volume_size = 200
    iops = 5000
    delete_on_termination = true
    volume_type = "io1"
  }

  tags = {
    Name    = "solbroker-primary"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }

# Do not flag the aws_instance resource as completed, until the VM is able to accept SSH connections, otherwise the Ansible call will fail  
  provisioner "remote-exec" {
    inline = ["echo 'SSH ready to rock'"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file(var.private_key_path)
    }
  }
}

resource "aws_instance" "solace-broker-backup" {
  ami                    = "${var.centOS_ami[var.region]}"
  instance_type          = "${var.instance_types["messaging"]}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group_broker.id}"]
  monitoring             = true

  subnet_id              = "${aws_subnet.benchmark_subnet_2.id}"
  availability_zone      = "${var.region}b" #Each node of the Cluster on a different AZ

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }
  
  ebs_block_device {
    device_name = "/dev/sdc"
    volume_size = 200
    iops = 5000
    delete_on_termination = true
    volume_type = "io1"
  }

  tags = {
    Name    = "solbroker-backup"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }

  # Do not flag the aws_instance resource as completed, until the VM is able to accept SSH connections, otherwise the Ansible call will fail  
  provisioner "remote-exec" {
    inline = ["echo 'SSH ready to rock'"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file(var.private_key_path)
    }
  }
}

resource "aws_instance" "solace-broker-monitor" {
  ami                    = "${var.centOS_ami[var.region]}"
  instance_type          = "${var.instance_types["monitor"]}"
  key_name               = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group_broker.id}"]
  monitoring             = true

  subnet_id              = "${aws_subnet.benchmark_subnet_3.id}"
  availability_zone      = "${var.region}c" #Each node of the Cluster on a different AZ

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }
  
  ebs_block_device {
    device_name = "/dev/sdc"
    volume_size = 30
    delete_on_termination = true
    volume_type = "gp2"
  }

  tags = {
    Name    = "solbroker-monitor"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }

  # Do not flag the aws_instance resource as completed, until the VM is able to accept SSH connections, otherwise the Ansible call will fail  
  provisioner "remote-exec" {
    inline = ["echo 'SSH ready to rock'"]

    connection {
      host        = self.public_ip
      type        = "ssh"
      user        = "centos"
      private_key = file(var.private_key_path)
    }
  }
}

resource "aws_instance" "client" {
  ami                    = "${var.centOS_ami[var.region]}"
  instance_type          = "${var.instance_types["client"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet_1.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group_client.id}"]
  count                  = "${var.num_instances["client"]}"
  monitoring             = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "solace-client-${count.index}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }
}

resource "aws_instance" "prometheus" {
  ami                    = "${var.centOS_ami[var.region]}"
  instance_type          = "${var.instance_types["prometheus"]}"
  key_name               = "${aws_key_pair.auth.id}"
  subnet_id              = "${aws_subnet.benchmark_subnet_1.id}"
  vpc_security_group_ids = ["${aws_security_group.benchmark_security_group_client.id}"]
  count                  = "${var.num_instances["prometheus"]}"

  root_block_device {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
  }

  tags = {
    Name = "solace-prometheus-${count.index}"
    Owner = "${var.ownerTag}"
    Days = "${var.daysTag}"
    Description = "${var.descriptionTag}"    
  }
}

output "clients" {
  value = {
    for instance in aws_instance.client :
    instance.public_ip => instance.private_ip
  }
}

# Create Ansible inventory from template file
resource "local_file" "solbroker_ha_inv_file" {
  content = templatefile("./templates/solace-benchmark-nodes.tpl",
    {
      solace-primary-ip = aws_instance.solace-broker-primary.public_ip,
      solace-backup-ip = aws_instance.solace-broker-backup.public_ip,
      solace-monitor-ip = aws_instance.solace-broker-monitor.public_ip,
      solace-primary-privateip = aws_instance.solace-broker-primary.private_ip,
      solace-backup-privateip = aws_instance.solace-broker-backup.private_ip,
      solace-monitor-privateip = aws_instance.solace-broker-monitor.private_ip,
      prometheus-ips = aws_instance.prometheus.*.public_ip

    }
  )
  filename = "./aws-solace-benchmark-nodes.inventory"
}

# Trigger Ansible Tasks for the Brokers - Only after all the VM resources and Ansible Inventories & Playbooks have been created
resource "null_resource" "trigger_broker_ansible" {
  provisioner "local-exec" {
    command = "ansible-playbook --user centos --inventory ${local_file.solbroker_ha_inv_file.filename} ./deploy.yaml"
  }

  depends_on = [
    local_file.solbroker_ha_inv_file
  ]
}

output "solace-broker-primary-public-ip" {
  value = "${aws_instance.solace-broker-primary.public_ip}"
}

output "solace-broker-backup-public-ip" {
  value = "${aws_instance.solace-broker-backup.public_ip}"
}

output "solace-broker-monitor-public-ip" {
  value = "${aws_instance.solace-broker-monitor.public_ip}"
}

output "solace-broker-primary-private-ip" {
  value = "${aws_instance.solace-broker-primary.private_ip}"
}

output "solace-broker-backup-private-ip" {
  value = "${aws_instance.solace-broker-backup.private_ip}"
}

output "solace-broker-monitor-private-ip" {
  value = "${aws_instance.solace-broker-monitor.private_ip}"
}
output "prometheus_host" {
  value = ["${aws_instance.prometheus.*.public_ip}"]
}
