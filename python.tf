resource "aws_instance" "python" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.apps.id]

  tags = {
    Name = "tp_arqsoft_python"
  }

  # Store the resulting IP
  provisioner "local-exec" {
    command = "echo ${aws_instance.python.public_ip} > python/ip"
  }

  # Use the python app IP in node code
  provisioner "local-exec" {
    command = "sed -Ei.bak \"s/(remoteBaseUri:)[^,]*,/\\1 'http:\\/\\/$(cat python/ip):3000',/\" node/config.js"
  }

  # Environment setup
  provisioner "remote-exec" {
    inline = [
      "echo ------- Create application directory: ${var.root} -------",
      "mkdir ${var.root}",
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }

  # Upload installer script
  provisioner "file" {
    source      = "install_datadog.sh"
    destination = "~/install_datadog.sh"

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }

  # Execute installer script
  provisioner "remote-exec" {
    inline = [
      "chmod +x ~/install_datadog.sh",
      "~/install_datadog.sh ${var.datadog_key}",
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }

  # Upload app
  provisioner "file" {
    source      = "python/app.py"
    destination = "${var.root}/app.py"

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }

  provisioner "file" {
    source      = "python/requirements.txt"
    destination = "${var.root}/requirements.txt"

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }

  # Install app deps and run
  provisioner "remote-exec" {
    inline = [
      "echo ------- Move into application directory: ${var.root} -------",
      "cd ${var.root}",
      "echo ------- Install dependencies -------",
      "sudo yum install -y python-pip",
      "sudo pip install -r requirements.txt",
    ]

    connection {
      host        = coalesce(self.public_ip, self.private_ip)
      type        = "ssh"
      user        = "ec2-user"
      private_key = file(var.private_key_location)
    }
  }
}

