provider "aws" {
      region = "us-east-2"
      access_key = "${var.access_key}"
      secret_key = "${var.secret_key}"
 } 
resource "aws_vpc" "A" {
     cidr_block        = "10.0.0.0/16"
     
     tags = {
       Name = "A"
   }
}
resource "aws_vpc" "B" {
     cidr_block        = "192.168.0.0/16"
     
     tags = {
       Name = "B"
   }
}

data "aws_availability_zones" "azs" {
  state = "available"
}

resource "aws_subnet" "subnet_A_az1"
   availability_zone = "${data.aws_availability_zones.azs.names[0]}"
   cidr_block        = "10.0.1.0/24"
   vpc_id            = "${aws_vpc.A.id}"
   map_public_ip_on_launch = "true"
   tag = {
    Name = "A-public-subnet"
   }
}
resource "aws_subnet" "subnet_A_az2"
   availability_zone = "${data.aws_availability_zones.azs.names[1]}"
   cidr_block        = "10.0.3.0/24"
   vpc_id            = "${aws_vpc.A.id}"
   tag = {
    Name = "A-private-subnet"
   }
}
resource "aws_subnet" "subnet_B_az1"
   availability_zone = "${data.aws_availability_zones.azs.names[0]}"
   cidr_block        = "192.168.0.0/24"
   vpc_id            = "${aws_vpc.B.id}"
   map_public_ip_on_launch = "true"
   tag = {
    Name = "B-public-subnet"
   }
}
resource "aws_subnet" "subnet_B_az2"
   availability_zone = "${data.aws_availability_zones.azs.names[1]}"
   cidr_block        = "192.168.2.0/24"
   vpc_id            = "${aws_vpc.B.id}"
   tag = {
    Name = "B-private-subnet"
   }
}

resource "aws_vpc_peering_connection" "A2B" {
  # Main VPC ID.
  vpc_id = "${aws_vpc.A.id}"

  # AWS Account ID. This can be  queried using the aws_caller_identity data resource.
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"

  # Secondary VPC ID.
  peer_vpc_id = "${aws_vpc.B.id}"

  # Flags that the peering connection should be automatically confirmed.
  auto_accept = true
}

#Instance on VPC A which is on private subnet.
resource "aws_security_group" "default" {
     name        = "http-https-allow"
     description = "Allow incoming HTTP and HTTPS and Connections"
     vpc_id      = "${aws_vpc.A.id}"
     ingress {
         from_port = 80
         to_port = 80
         protocol = "tcp"
         cidr_blocks = ["0.0.0.0/0"]
    }
     ingress {
         from_port = 443
         to_port = 443
         protocol = "tcp"
         cidr_blocks = ["0.0.0.0/0"]
    }
resource "aws_instance" "dev_instance" {
  ami           = "ami-07a0844029df33d7d "
  instance_type = "t2.micro"
  key_name = "terraform-dev"
  vpc_id            = "${aws_vpc.A.id}"
  vpc_security_group_ids = [ "${aws_security_group.allow_ssh.id}" ]
  subnet_id = "${aws_subnet.private.id}"
  associate_public_ip_address = true

  tags = {
    Name = "Dev Instance1"
    Environment = "Development"
  }
}

#Instance on VPC B on private subnet.
resource "aws_security_group" "default" {
     name        = "http-https-allow"
     description = "Allow incoming HTTP and HTTPS and Connections"
     vpc_id      = "${aws_vpc.B.id}"
     ingress {
         from_port = 80
         to_port = 80
         protocol = "tcp"
         cidr_blocks = ["0.0.0.0/0"]
    }
     ingress {
         from_port = 443
         to_port = 443
         protocol = "tcp"
         cidr_blocks = ["0.0.0.0/0"]
    }
resource "aws_instance" "dev_instance" {
  ami           = "ami-07a0844029df33d7d "
  instance_type = "t2.micro"
  key_name = "terraform-dev"
  vpc_id            = "${aws_vpc.B.id}"
  vpc_security_group_ids = [ "${aws_security_group.allow_ssh.id}" ]
  subnet_id = "${aws_subnet.private.id}"
  associate_public_ip_address = true

  tags = {
    Name = "Dev Instance2"
    Environment = "Development"
  }
}

#creating cluster on  existing vpc B

data "aws_eks_cluster" "cluster" {
  name = module.my-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.my-cluster.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "1.9"
}

module "my-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = "my-cluster"
  cluster_version = "1.17"
  subnet         = ["${aws_subnet.public.id}"] 
  vpc_id          = "${aws_vpc.B.id}"

  worker_groups = [
    {
      instance_type = "m4.large"
      asg_max_size  = 4
    }
  ]
}