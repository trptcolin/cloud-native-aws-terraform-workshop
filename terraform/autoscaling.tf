// Unit 4: Autoscaling Groups
resource "aws_alb" "workshop_alb" {
  name = "workshop-alb-APPNAMEHERE"
  subnets = ["${aws_subnet.public_subnet_1.id}",
             "${aws_subnet.public_subnet_2.id}"]
  security_groups = ["${aws_security_group.alb_sg.id}"]
}

resource "aws_alb_target_group" "workshop_alb" {
  name = "workshop-alb-target-APPNAMEHERE"
  vpc_id = "${aws_vpc.workshop_vpc.id}"
  port = 80
  protocol = "HTTP"
  health_check {
    matcher = "200,301"
    path = "/status.php"
  }
}

resource "aws_alb_listener" "workshop_alb_http" {
  load_balancer_arn = "${aws_alb.workshop_alb.arn}" // using AWS identifier here, first time using that instead of TF's id?
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

resource "aws_launch_configuration" "workshop_launch_conf" {
  image_id = "ami-c481fad3"
  instance_type = "t2.micro"
  key_name = "colin-mbp-touchbar"
  security_groups = ["${aws_security_group.web_sg.id}"]
  associate_public_ip_address = true
  lifecycle {
    create_before_destroy = true
  }
  iam_instance_profile = "${aws_iam_instance_profile.workshop_profile.arn}" // key to being able to access s3 i guess?
  user_data = <<EOF
#!/usr/bin/env bash
aws s3 cp s3://trptcolin-terraform-workshop/credentials /etc/environment
echo "export HTTP_DB_URI=${aws_db_instance.workshop_db.endpoint}" \
  >> /etc/environment
aws s3 cp s3://trptcolin-terraform-workshop/provision.sh /root/
bash /root/provision.sh
EOF
}

resource "aws_autoscaling_group" "workshop_autoscale" {
  vpc_zone_identifier = ["${aws_subnet.public_subnet_1.id}",
                         "${aws_subnet.public_subnet_2.id}"]
  min_size = 2
  max_size = 2
  health_check_type = "EC2"
  health_check_grace_period = 300
  launch_configuration = "${aws_launch_configuration.workshop_launch_conf.id}"
  target_group_arns = ["${aws_alb_target_group.workshop_alb.arn}"]
  enabled_metrics = ["GroupInServiceInstances"]
}

