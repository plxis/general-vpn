data "terraform_remote_state" "foundry" {
  backend = "s3"
  config {
    bucket = "${var.foundry_state_bucket}"
    key    = "${var.foundry_state_key}"
    region = "${var.aws_region}"
  }
}

provider "aws" {
  region = "${var.aws_region}"
}

/******************************************************************************
 * Commenting out the ELB/ASG since it's not needed at this time. Leaving it
 * in for future considering if there's a need for redundant VPN. This was
 * correctly working a the time of being commented out.

resource "aws_elb" "vpn-elb" {
  name            = "elb-${var.context}-vpn"
  subnets         = ["${data.terraform_remote_state.foundry.private_subnets}"]
  security_groups = ["${aws_security_group.vpn-elb-sg.id}"]
  internal        = true

  listener {
    instance_port     = 22
    instance_protocol = "tcp"
    lb_port           = 22
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 10
    target              = "TCP:22"
    interval            = 15
  }

  tags {
    Name    = "elb-${var.context}"
    Context = "${var.context}"
  }
}

resource "aws_route53_record" "vpn-dns" {
  zone_id   = "${data.terraform_remote_state.foundry.public_zone_id}"
  name      = "${var.context}"
  type      = "A"

  alias {
    name                   = "${aws_elb.vpn-elb.dns_name}"
    zone_id                = "${aws_elb.vpn-elb.zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_security_group" "vpn-elb-sg" {
  name        = "${var.context}-vpn-elb-sg"
  description = "VPN ELB security group"
  vpc_id      = "${data.terraform_remote_state.foundry.vpc_id}"

  tags {
    Name    = "sg-${var.context}-vpn-elb"
    Context = "${var.context}"
  }
}

resource "aws_security_group_rule" "elb-ssh-ingress" {
  type            = "ingress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${data.terraform_remote_state.foundry.jump_host_sg}"
  security_group_id = "${aws_security_group.vpn-elb-sg.id}"
}

resource "aws_security_group_rule" "elb-ssh-egress" {
  type            = "egress"
  from_port       = 22
  to_port         = 22
  protocol        = "tcp"
  source_security_group_id = "${aws_security_group.vpn-instance-sg.id}" 
  security_group_id = "${aws_security_group.vpn-elb-sg.id}"
}

resource "aws_autoscaling_group" "vpn-asg" {
  name                 = "asg-${var.context}-${aws_launch_configuration.vpn-lc.id}"
  max_size             = "${var.instance_count_max}"
  min_size             = "${var.instance_count_min}"
  desired_capacity     = "${var.instance_count_desired}"
  launch_configuration = "${aws_launch_configuration.vpn-lc.name}"
  min_elb_capacity     = 1
  vpc_zone_identifier  = [ "${data.terraform_remote_state.foundry.private_subnets}" ]
  load_balancers       = [ "${aws_elb.vpn-elb.id}" ]
  enabled_metrics      = [ "GroupMinSize","GroupMaxSize","GroupDesiredCapacity","GroupInServiceInstances","GroupPendingInstances","GroupStandbyInstances","GroupTerminatingInstances","GroupTotalInstances"]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.context}"
    propagate_at_launch = true
  }
  tag {
    key                 = "Context"
    value               = "${var.context}"
    propagate_at_launch = true
  }
}

resource "aws_launch_configuration" "vpn-lc" {
  name_prefix     = "lc-${var.context}-vpn-"
  image_id        = "${data.aws_ami_ids.amazon-linux.ids[0]}"
  instance_type   = "${var.instance_type}"
  security_groups = [ "${aws_security_group.vpn-instance-sg.id}" ]
  user_data       = "${data.template_file.user-data-script.rendered}"
  key_name        = "${aws_key_pair.vpn-key.key_name}"

  # Minimize downtime by creating a new launch config before destroying old one
  lifecycle {
    create_before_destroy = true
  }

  iam_instance_profile = "${aws_iam_instance_profile.vpn-profile.id}"
}

output "vpn_elb_dns_name" {
  value = "${aws_elb.vpn-elb.dns_name}"
}
* This marks the end of the disabled ELB/ASG section. Search for ELB for any
* other disabled section.
*******************************************************************************/

/*******************************************************************************
 * This direct EC2 instance is being used in place of the ELB, so that we can
 * reuse the same private IP address for the VPN. This consistent VPN IP is 
 * requested by partners.
 */ 
resource "aws_instance" "vpn_instance" {
  ami                  = "${data.aws_ami.amazon-linux.id}"
  instance_type        = "${var.instance_type}"
  user_data            = "${data.template_file.user-data-script.rendered}"
  key_name             = "${aws_key_pair.vpn-key.key_name}"
  network_interface {
    network_interface_id = "${aws_network_interface.vpn_interface.id}"
    device_index         = 0
  }
 
  tags {
    Name = "${var.context}"
    Context = "${var.context}"
  }
}

resource "aws_network_interface" "vpn_interface" {
  subnet_id       = "${data.terraform_remote_state.foundry.private_subnets[0]}"
  private_ips     = [ "${var.vpn_private_ip}" ]
  security_groups = [ "${aws_security_group.vpn-instance-sg.id}" ]
}

output "vpn_dns_name" {
  value = "${aws_instance.vpn_instance.private_dns}"
}


data "aws_ami" "amazon-linux" {
  owners = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn-ami-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "vpn-instance-sg" {
  name   = "elb-sg-${var.context}"
  vpc_id = "${data.terraform_remote_state.foundry.vpc_id}"

/******************************************************************************
 * Disabling this ingress rule since it's only used with ELB.
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [ "${aws_elb.vpn-elb.source_security_group_id}" ]
  }
*******************************************************************************/  

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [ "${data.terraform_remote_state.foundry.jump_host_sg}" ]
  }

  # Allow outbound IPSEC VPN
  egress {
    from_port   = "${var.vpn_dest_tcp_port}"
    to_port     = "${var.vpn_dest_tcp_port}"
    protocol    = "tcp"
    cidr_blocks = ["${var.vpn_dest_ip}/32"]
  }
  egress {
    from_port   = "${var.vpn_dest_tcp_port}"
    to_port     = "${var.vpn_dest_tcp_port}"
    protocol    = "udp"
    cidr_blocks = ["${var.vpn_dest_ip}/32"]
  }

  # Allow outbound IPSEC VPN
  egress {
    from_port   = "${var.vpn_dest_udp_port}"
    to_port     = "${var.vpn_dest_udp_port}"
    protocol    = "udp"
    cidr_blocks = ["${var.vpn_dest_ip}/32"]
  }

  # Allow outbound access to NFS (Foundry EFS)
  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound access to yum update
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound access to yum update
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound access to ssh 
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name    = "${var.context}-vpn"
    Context = "${var.context}"
  }
}

data "template_file" "user-data-script" {
  template = "${file("${path.module}/templates/vpn-bootstrap.tpl")}"
  vars {
    context           = "${var.context}"
    users_local_mount = "/users"
    users_efs_target  = "${data.terraform_remote_state.foundry.user_data_efs_dns_name}"
    log_group         = "${var.log_group}"
    vpn_dest_ip       = "${var.vpn_dest_ip}"
    vpn_dest_tcp_port = "${var.vpn_dest_tcp_port}"
    vpn_dest_udp_port = "${var.vpn_dest_udp_port}"
    vpn_dest_subnet   = "${var.vpn_dest_subnet}"
    vpn_dest_secret   = "${var.vpn_dest_secret}"
  }
}

resource "tls_private_key" "vpn-tls-key" {
  algorithm   = "RSA"
}

resource "aws_key_pair" "vpn-key" {
  key_name   = "${var.context}"
  public_key = "${tls_private_key.vpn-tls-key.public_key_openssh}"
}

data "aws_iam_policy_document" "vpn-assume-role-policy-document" {
  statement {
    actions = [ "sts:AssumeRole" ]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = [ "ec2.amazonaws.com" ]
    }
  }
}

data "aws_iam_policy_document" "vpn-role-policy-document" {
  # TODO: What IAM permissions does the vpn server need?
  statement {
    effect    = "Allow"
    actions   = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [ "*" ]
  }
}

resource "aws_iam_role" "vpn-role" {
  name               = "${var.context}-vpn-role"
  path               = "/"
  assume_role_policy = "${data.aws_iam_policy_document.vpn-assume-role-policy-document.json}"
}

resource "aws_iam_instance_profile" "vpn-profile" {
  name  = "${var.context}-vpn-instance-profile"
  role = "${aws_iam_role.vpn-role.name}"
}

resource "aws_iam_role_policy" "vpn-role-policy" {
  name   = "${var.context}-vpn-policy"
  role   = "${aws_iam_role.vpn-role.id}"
  policy = "${data.aws_iam_policy_document.vpn-role-policy-document.json}"
}

output "vpn_ssh_key" {
  value = "${tls_private_key.vpn-tls-key.private_key_pem}"
  sensitive = true
}
