resource "aws_vpc" "workshop_vpc" {
  cidr_block = "10.0.1.0/24" // 10.0.1.0 -> 10.0.1.255, since the /24 means the first 24 bits (3 bytes) are consistent, with 8 bits remaining (2**8 - 1 == 255)
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id = "${aws_vpc.workshop_vpc.id}"
  availability_zone = "us-east-1a"
  cidr_block = "10.0.1.0/26" // 10.0.1.0 -> 10.0.1.63, see above but also since 6 bytes remain, 2**6 - 1 = 63
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = "${aws_vpc.workshop_vpc.id}"
  availability_zone = "us-east-1d" // note: we're in a second AZ
  cidr_block = "10.0.1.64/26" // 10.0.1.64 -> 10.0.1.127 [same deal as above]
}

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

// TODO: open question, surely we can clean this up and not duplicate all this jive nonsense.
// or do we generate the tf file w/ a Go library or some jive like that instead?
// does terraform have a plugin system? could be :+1:
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
    security_groups = ["${aws_security_group.alb_sg.id}"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = ["${aws_security_group.bastion_sg.id}"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "db_subnet_1" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.1.128/26"  // 10.0.1.128 -> 10.0.1.191
    map_public_ip_on_launch = false
}

resource "aws_subnet" "db_subnet_2" {
    vpc_id = "${aws_vpc.workshop_vpc.id}"
    availability_zone = "us-east-1d"
    cidr_block = "10.0.1.192/26" // 10.0.1.192 -> 10.0.1.255
    map_public_ip_on_launch = false
}

resource "aws_db_subnet_group" "db_subnet_group" {
    name = "db-subnet-group"
    subnet_ids = ["${aws_subnet.db_subnet_1.id}",
        "${aws_subnet.db_subnet_2.id}"]
}

resource "aws_security_group" "db" {
  name = "db"
  vpc_id = "${aws_vpc.workshop_vpc.id}"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [ "${aws_security_group.web_sg.id}",
        "${aws_security_group.bastion_sg.id}" ]
  }
}
