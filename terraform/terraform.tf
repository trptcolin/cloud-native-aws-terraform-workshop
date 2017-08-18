resource "aws_vpc" "workshop_vpc" {
    cidr_block = "10.0.1.0/24"
}

resource "aws_subnet" "public_subnet_1" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.0/26"
}

resource "aws_instance" "bastion" {
    ami = "ami-c481fad3"
    subnet_id = "${aws_subnet.public_subnet_1.id}"
    associate_public_ip_address = true
    key_name = "Colins-Test-Key"
    instance_type = "t2.micro"
    vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
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
