resource "aws_iam_instance_profile" "workshop_profile" {
    name = "workshop_profile_APPNAMEHERE"
    role = "${aws_iam_role.ec2_role.name}"
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role_APPNAMEHERE"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3_bucket_policy" {
  name = "s3_deploy_bucket_policy_APPNAMEHERE"
  role  = "${aws_iam_role.ec2_role.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:Get*", "s3:List*"],
      "Resource": ["arn:aws:s3:::trptcolin-terraform-workshop",
                   "arn:aws:s3:::trptcolin-terraform-workshop/*"]
    },
    {
      "Effect": "Allow",
      "Action": [ "logs:CreateLogGroup", "logs:CreateLogStream",
        "logs:PutLogEvents", "logs:DescribeLogStreams" ],
      "Resource": [ "arn:aws:logs:*:*:*" ]
    }
  ]
}
EOF
}
