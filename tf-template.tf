################################### Provider
provider "aws" {
  access_key = "AKIAJPSW4P44SMOTWECQ" /* null and void */
  secret_key = "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"
  /* Luckily those were not the Root account creds.
  Always create a new user with limited permissions
  when using Terraform. */
  region = "us-west-2"
}

################################### Variables
variable "server_type" {
  type = "map"
  default = {
    ubuntu = "ami-efd0428f"
    redhat = "ami-6f68cf0f"
    windows = "ami-c2c3a2a2"
  }
}

################################### VPC et al
resource "aws_vpc" "SandboxVPC" {
  cidr_block = "10.0.0.0/16"
  tags {
    Name = "terraform-demo"
  }
}
resource "aws_subnet" "main" {
  vpc_id = "${aws_vpc.SandboxVPC.id}"
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = "true"
  tags {
    Name = "Main"
  }
}
resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.SandboxVPC.id}"
  tags {
    Name = "main"
  }
}
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.SandboxVPC.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags {
    Name = "main"
  }
}
resource "aws_route_table_association" "a" {
  subnet_id = "${aws_subnet.main.id}"
  route_table_id = "${aws_route_table.r.id}"
}

################################### Servers
resource "aws_instance" "control" {
  ami = "ami-efd0428f"
  instance_type = "t2.micro"
  key_name = "cf-demo"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]

  tags {
    Name = "ansible-control"
    Project = "terraform-demo"
  }
}
resource "aws_instance" "server" {
  count = 7
  ami = "${element(values(var.server_type), count.index)}"
  instance_type = "t2.micro"
  key_name = "cf-demo"
  vpc_security_group_ids = ["${aws_security_group.allow_all.id}"]
  tags {
    Name = "server-${count.index}-${element(keys(var.server_type), count.index)}"
    Project = "terraform-demo"
  }
}

################################### Security Group
resource "aws_security_group" "allow_all" {
  name = "allow_all"
  description = "Allow all inbound traffic"
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags {
    Name = "main"
  }
}

################################### Outputs
output "control_ip" {
  value = "${aws_instance.control.public_ip}"
}
output "the_map_master" {
  value = "${zipmap(aws_instance.server.*.tags.Name, aws_instance.server.*.public_ip)}"
}
