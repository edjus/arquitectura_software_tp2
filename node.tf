locals {
  src_location = "https://s3.amazonaws.com/${file("${path.module}/source_location")}/src.zip"
}

data "template_file" "node_user_data" {
  template = file("${path.module}/node_user_data.sh")

  vars = {
    root         = var.root
    datadog_key  = var.datadog_key
    node_version = var.node_version
    src_location = local.src_location
  }
}

resource "aws_launch_template" "node_lt" {
  image_id               = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.apps.id]
  user_data              = base64encode(data.template_file.node_user_data.rendered)
  name_prefix            = "node_lt-"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_elb" "node_asg_elb" {
  name_prefix        = "node-"
  availability_zones = [var.availability_zone]
  security_groups    = [aws_security_group.elb.id]

  listener {
    instance_port     = 3000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  provisioner "local-exec" {
    command = "echo ${aws_elb.node_asg_elb.dns_name} > node/elb_dns"
  }
}

resource "aws_autoscaling_group" "node_asg" {
  name_prefix      = "node_asg-"
  max_size         = 3
  min_size         = 0
  desired_capacity = 1

  load_balancers     = [aws_elb.node_asg_elb.name]
  availability_zones = [var.availability_zone]

  launch_template {
    id      = aws_launch_template.node_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "tp_arqsoft_node_asg_instance"
    propagate_at_launch = true
  }
}
