resource "aws_instance" "bastion" {
  ami = "ami-c481fad3"
  subnet_id = "${aws_subnet.public_subnet_1.id}"
  associate_public_ip_address = true
  key_name = "colin-mbp-touchbar"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
}
