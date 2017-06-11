resource "aws_db_instance" "workshop_db" {
  allocated_storage = 10
  engine = "mysql"
  multi_az = false # True in real life for HA
  instance_class = "db.t2.micro"
  name = "db18fworkshop"
  username = "workshop"
  password = "dummy_password"
  publicly_accessible = false
  storage_type = "gp2"
  publicly_accessible = false
  db_subnet_group_name = "${aws_db_subnet_group.db_subnet_group.id}"
  vpc_security_group_ids = [ "${aws_security_group.db.id}" ]
  skip_final_snapshot = true
}

output "rds_instance_id" {
  value = "${aws_db_instance.workshop_db.id}"
}
