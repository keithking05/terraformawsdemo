# Local Variables
locals {
    # Defines the IP Range in CIDR notation to be used to create the VPC
    vpc_cidr_block = "10.255.0.0/16"
    # Defines the IP Range in CIDR notation to be used to create a subnet.  This must be contained in the range of the VPC it is created within.
    subnet1 = "10.255.0.0/24"
    availability_zone = "us-east-1a"
}


# Define provider settings for AWS
provider "aws" {
  profile = "default"
  region  = "us-east-1"
}


# Define VPC settings
resource "aws_vpc" "demo-terraform-vpc" {
    # Use the variable vpc_cidr_block to set the CIDR Block for the VPC
    cidr_block = local.vpc_cidr_block
    enable_dns_hostnames = true
}


# Define a Internet Gateway to assign with a VPC
resource "aws_internet_gateway" "demo-terraform-ig" {
    # Define which VPC to use
    vpc_id = aws_vpc.demo-terraform-vpc.id
    
}

# Define the route table to associate with the subnets
resource "aws_route_table" "demo-terraform-vpc-rt" {
    # Define which VPC to use
    vpc_id = aws_vpc.demo-terraform-vpc.id
    
    # Create a default route to the internet gateway that was created earlier
    # This will enable virtual machines in this VPC to access the internet
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.demo-terraform-ig.id
    }
}


# Define the subnet to create in the VPC
resource "aws_subnet" "demo-terraform-subnet" {
    # Define which VPC to use
    vpc_id = aws_vpc.demo-terraform-vpc.id

    # Use the variable subnet1 to set the CIDR Block for this subnet
    cidr_block = local.subnet1

    # Use the variable availability_zone to set the Availability zone for this subnet
    availability_zone = local.availability_zone

    # Allow EC2 instances to have a public IP address associated with them
    map_public_ip_on_launch = true

}


# Associate the Route Table that was defined above with the subnet
resource "aws_route_table_association" "demo-terraform-vpc-rt" {
    subnet_id = aws_subnet.demo-terraform-subnet.id
    route_table_id = aws_route_table.demo-terraform-vpc-rt.id
}


# Define Security Groups
# This will allow SSH (TCP/22) and HTTP (TCP/80) from anywhere
resource "aws_security_group" "ec2_sg" {
  # Define which VPC to use
  vpc_id = aws_vpc.demo-terraform-vpc.id

  name        = "ec2_sg"
  description = "Allow SSH and HTTP inbound traffic"

  # Allow ingress on TCP/22 from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  # Allow ingress on TCP/80 from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["72.12.52.36/32"]
  }


  # Allow egress on any protocol (!), on any port (!!), to anywhere (!!!)
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}

# Define EC2 Instance Settings
resource "aws_instance" "demo-ec2-1" {
  # Select the Amazon Machine Image to use.  This one is Ubuntu 18.04
  ami = "ami-0bcc094591f354be2"

  # Assign the security group that was created above to this virtual machine
  vpc_security_group_ids = ["${aws_security_group.ec2_sg.id}"]

  # Set the instance type, t2.micro has 1 vCPU and 1GiB of RAM
  instance_type = "t2.micro"

  # Set the SSH Key Pair to use for this.  This must be created and downloaded in advance.
  key_name = "demo-key-pair"

  # Set the subnet to create this EC2 instance within.  
  # This effectively assigns the VPC since a subnet can only belong to one VPC
  subnet_id = "${aws_subnet.demo-terraform-subnet.id}"

  # Executes this as a bootstrap script installing Apache2 on the server and creating a new index.html file
  user_data = <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y apache2
sudo systemctl start apache2
sudo systemctl enable apache2
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html
EOF

}


# Output the Public IP Address of the demo-ec2-1 EC2 Instance after it has been created so we don't have to go looking for it
output "IP" {
  value = "${aws_instance.demo-ec2-1.public_ip}"
}