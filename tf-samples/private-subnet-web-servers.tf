resource "aws_vpc" "workshop_vpc" {
    cidr_block = "10.0.1.0/24"
    tags {
      Name = "TerraformWorkshopVPC"
    }
}

resource "aws_subnet" "public_subnet_1" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.0/26"
    tags {
      Name = "PublicSubnet1"
    }
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1b"
    cidr_block = "10.0.1.192/26"
    tags {
      Name = "PublicSubnet2"
    }
}

resource "aws_instance" "bastion" {
    ami = "ami-c481fad3"
    subnet_id = "${aws_subnet.public_subnet_1.id}"
    associate_public_ip_address = true
    key_name = "Colins-Test-Key"
    instance_type = "t2.micro"
    vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
    tags {
      Name = "BastionHost"
    }
}

provider "aws" { region = "us-east-1" }

resource "aws_internet_gateway" "workshop_gw" {
  vpc_id = "${aws_vpc.workshop_vpc.id}"
}

resource "aws_route_table" "workshop_route_table" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.workshop_gw.id}"
    }
}

resource "aws_route_table_association" "route_subnet_1" {
    subnet_id = "${aws_subnet.public_subnet_1.id}"
    route_table_id = "${aws_route_table.workshop_route_table.id}"
}

resource "aws_route_table_association" "route_subnet_2" {
    subnet_id = "${aws_subnet.public_subnet_2.id}"
    route_table_id = "${aws_route_table.workshop_route_table.id}"
}

resource "aws_security_group" "bastion_sg" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"

    ingress {
        from_port = 8
        to_port = 0
        protocol = "icmp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

// part 2
resource "aws_subnet" "private_subnet_1" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.64/26"
    tags {
      Name = "PrivateSubnet1"
    }
}

resource "aws_subnet" "private_subnet_2" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1b"
    cidr_block = "10.0.1.128/26"
    tags {
      Name = "PrivateSubnet2"
    }
}

resource "aws_security_group" "alb_sg" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["10.0.1.0/24"]
    }
}

resource "aws_security_group" "web_sg" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [ "${aws_security_group.alb_sg.id}" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        security_groups = [ "${aws_security_group.bastion_sg.id}" ]
    }
}

resource "aws_alb" "workshop_alb" {
  name = "workshop-alb-colin"
  subnets = [
    "${aws_subnet.public_subnet_1.id}",
    "${aws_subnet.public_subnet_2.id}"
  ]
  security_groups = ["${aws_security_group.alb_sg.id}"]
}

resource "aws_alb_target_group" "workshop_alb" {
  name = "workshop-alb-target-colin"
  vpc_id = "${aws_vpc.workshop_vpc.id}"
  port = 80
  protocol = "HTTP"
  health_check {
    matcher = "200,301"
    interval = "10"
  }
}

resource "aws_alb_listener" "workshop_alb_http" {
  load_balancer_arn = "${aws_alb.workshop_alb.arn}"
  port = 80
  protocol = "HTTP"
  default_action {
    target_group_arn = "${aws_alb_target_group.workshop_alb.arn}"
    type = "forward"
  }
}

output "alb.dns" {
    value = "${aws_alb.workshop_alb.dns_name}"
}

resource "aws_eip" "workshop_eip" {
}

resource "aws_nat_gateway" "workshop_nat_gateway" {
  allocation_id = "${aws_eip.workshop_eip.id}"
  subnet_id     = "${aws_subnet.public_subnet_1.id}"
}

resource "aws_route_table" "workshop_main_route_table" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = "${aws_nat_gateway.workshop_nat_gateway.id}"
    }
}

resource "aws_main_route_table_association" "workshop_private_routes" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    route_table_id = "${aws_route_table.workshop_main_route_table.id}"
}

resource "aws_launch_configuration" "workshop_launch_conf" {
    image_id = "ami-c481fad3"
    instance_type = "t2.micro"
    key_name = "Colins-Test-Key"
    security_groups = ["${aws_security_group.web_sg.id}"]
    associate_public_ip_address = true
    lifecycle {
        create_before_destroy = true
    }
    depends_on = ["aws_main_route_table_association.workshop_private_routes"]
    user_data = <<EOF
#!/usr/bin/env bash
yum update -y
yum install -y httpd
echo '<html><head></head><body><h1>Hello World!</h1></body></html>' > /var/www/html/index.html
service httpd start
chkconfig httpd on
EOF
}

resource "aws_autoscaling_group" "workshop_autoscale" {
    name = "workshop-${aws_subnet.private_subnet_1.id}-${aws_subnet.private_subnet_2.id}"
    vpc_zone_identifier = ["${aws_subnet.private_subnet_1.id}",
                           "${aws_subnet.private_subnet_2.id}"]
    min_size = 2
    max_size = 2
    health_check_type = "EC2"
    health_check_grace_period = 300
    launch_configuration = "${aws_launch_configuration.workshop_launch_conf.id}"
    target_group_arns = ["${aws_alb_target_group.workshop_alb.arn}"]
    enabled_metrics = ["GroupInServiceInstances"]
}
