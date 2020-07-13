#To declare which provider we want
provider "aws" {
	region  = "ap-south-1"
}

#To create security group with http and ssh
resource "aws_security_group" "webos-sg" {
  name        = "webos-sg"
  description = "allow ssh and http traffic"
  vpc_id = "vpc-19574b71"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "0"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
#To create EFS
resource "aws_efs_file_system" "efs" {
	creation_token = "EFS Shared Data"
	performance_mode = "generalPurpose"
     	throughput_mode = "bursting"
	encrypted = "true"
	tags = {
		Name = "EFS Shared Data" 
	}
}
#To mount EFS
resource "aws_efs_mount_target" "efs" {
	file_system_id = "${aws_efs_file_system.efs.id}"
	subnet_id = "subnet-479aa02f"
	security_groups = ["${aws_security_group.webos-sg.id}"]
}

#To create instance 
resource "aws_instance" "webosec2" {
	ami		   = "ami-005956c5f0f757d37"
	availability_zone  = "ap-south-1a"
	subnet_id	   = "subnet-479aa02f"
	instance_type	   = "t2.micro"
	key_name	   = "amzlinux"     #"${aws_key_pair.generated_key.key_name}"
	security_groups	   = ["${aws_security_group.webos-sg.id}"]
	user_data	   = <<-EOF
			       #! /bin/bash
			       sudo su - root
			       yum install httpd -y
			       yum install php -y
			       yum install git -y
			       yum update -y
			       yum install amazon-efs-utils
			       service httpd start
			       chkconfig --add httpd
			       efs_id="${aws_efs_file_system.efs.id}"
			       mount -t efs $efs_id:/ /var/www/html
			       echo $efs_id:/ /var/www/html efs defaults,_netdev 0 0 >> /etc/fstab
			       rm -rf /var/www/html/*
                               git clone https://github.com/AnonMrNone/mutli-hybrid-cloud-2.git /var/www/html/


	EOF
	tags		   = {
		Name = "webserver-php"
	}
}

#To create S3 bucket
resource "aws_s3_bucket" "shubhambtesting1234" {
  bucket = "shubhambtesting1234"
  acl    = "public-read"
  force_destroy  = true
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["https://shubhambtesting1234"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}
#To upload data to S3 bucket
resource "null_resource" "remove_and_upload_to_s3" {
  provisioner "local-exec" {
    command = "F:/Hybrid-Multi-Cloud/terra/job2/s3update.bat"
  }
  depends_on  = ["aws_s3_bucket.shubhambtesting1234"]
}


# Create Cloudfront distribution
resource "aws_cloudfront_distribution" "distribution" {
    origin {
        domain_name = "${aws_s3_bucket.shubhambtesting1234.bucket_regional_domain_name}"
        origin_id = "S3-${aws_s3_bucket.shubhambtesting1234.bucket}"
 
        custom_origin_config {
            http_port = 80
            https_port = 443
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
    # By default, show index.html file
    default_root_object = "index.html"
    enabled = true

    # If there is a 404, return index.html with a HTTP 200 Response
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.html"
    }

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.shubhambtesting1234.bucket}"

        #Not Forward all query strings, cookies and headers
        forwarded_values {
            query_string = false
	    cookies {
		forward = "none"
	    }
            
        }

        viewer_protocol_policy = "redirect-to-https"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }

    # Distributes content to all
    price_class = "PriceClass_All"

    # Restricts who is able to access this content
    restrictions {
        geo_restriction {
            # type of restriction, blacklist, whitelist or none
            restriction_type = "none"
        }
    }

    # SSL certificate for the service.
    viewer_certificate {
        cloudfront_default_certificate = true
    }
}
output "cloudfront_ip_addr" {
  value = aws_cloudfront_distribution.distribution.domain_name
}
