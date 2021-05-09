variable "hosted_region" {
  type = string
}

//default = "www.rishabh-web.io"
variable "www_domain_name" {
  type        = string
  description = "ex. www.rishabh-web.io"
}

//  default = "rishabh-web.io"
// We'll also need the root domain (also known as zone apex or naked domain).
variable "root_domain_name" {
  type        = string
  description = "ex. rishabh-web.io"
}

provider "aws" {
  region = var.hosted_region
}
resource "aws_s3_bucket" "web_storage" {
  // Bucket name(usually same as domain name)  
  bucket = var.www_domain_name
  acl    = "public-read"
  policy = <<POLICY
{
  "Version":"2012-10-17",
  "Statement":[
    {
      "Sid":"AddPerm",
      "Effect":"Allow",
      "Principal": "*",
      "Action":["s3:GetObject"],
      "Resource":["arn:aws:s3:::${var.www_domain_name}/*"]
    }
  ]
}
POLICY

  website {
    // Here we tell S3 what to use when a request comes in to the root
    index_document = "index.html"
  }
  tags = {
    Name = "Web Storage"
  }
}

resource "aws_cloudfront_distribution" "www_distribution" {
  // origin is where CloudFront gets its content from.
  origin {
    // We need to set up a "custom" origin because otherwise CloudFront won't
    // redirect traffic from the root domain to the www domain, that is from
    // abc.io to www.abc.io.
    custom_origin_config {
      // These are all the defaults.
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }

    // Here we're using our S3 bucket's URL!
    domain_name = aws_s3_bucket.web_storage.website_endpoint
    // This can be any name to identify this origin.
    origin_id = var.www_domain_name
  }

  enabled             = true
  default_root_object = "index.html"

  // All values are defaults from the AWS console.
  default_cache_behavior {
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    // This needs to match the `origin_id` above.
    target_origin_id = var.www_domain_name
    min_ttl          = 0
    default_ttl      = 86400
    max_ttl          = 31536000

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  // # If 404 error is there then it serve index.html and frontend framework handle error accordingly 
  custom_error_response {
    error_code         = 404
    response_page_path = "/index.html"
    response_code      = 200
  }

  # If You want to add your custom certificate 
  # viewer_certificate = {
  #   acm_certificate_arn = "<<<arn-of-acm>>>"
  #   ssl_support_method  = "sni-only"
  # }
  // Here's where our certificate is loaded in!
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = "<<<hostedZoneId>>>"

  name = var.root_domain_name

  type = "A"

  alias {
    name = "${aws_cloudfront_distribution.www_distribution.domain_name}"

    zone_id = "${aws_cloudfront_distribution.www_distribution.hosted_zone_id}"

    evaluate_target_health = true
  }

  depends_on = [aws_cloudfront_distribution.www_distribution]
}
