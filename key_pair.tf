# -------------------------
# EC2 KEY PAIR (GENERATED)
# -------------------------
# This creates a new SSH private key and saves it locally as:
#   ${pathexpand("~")}/Downloads/${var.key_name}.pem
# Example on your machine:
#   C:\Users\keert\Downloads\dev.pem
resource "tls_private_key" "ec2" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated" {
  key_name   = var.key_name
  public_key = tls_private_key.ec2.public_key_openssh

  tags = {
    Name = "${var.project_name}-keypair"

  }
}

resource "local_file" "ec2_private_key_pem" {
  content  = tls_private_key.ec2.private_key_pem
  filename = "${pathexpand("~")}/Downloads/${var.key_name}.pem"
}

