provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      project = var.project_name
    }
  }
}

# Logging
resource "aws_s3_bucket" "app_logs_bucket" {
  bucket = "${var.project_name}-logs"
}

resource "aws_s3_bucket_public_access_block" "logs_public_access_block" {
  bucket                  = aws_s3_bucket.app_logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3
resource "aws_s3_bucket" "app_bucket" {
  bucket = var.project_name
}
resource "aws_s3_bucket_logging" "app_logging" {
  bucket        = aws_s3_bucket.app_bucket.bucket
  target_bucket = aws_s3_bucket.app_logs_bucket.bucket
  target_prefix = "s3"
}

resource "aws_s3_bucket_public_access_block" "app_public_access_block" {
  bucket                  = aws_s3_bucket.app_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "app_bucket_policy" {
  count  = "${var.domain_name}" == "" ? 0 : 1
  bucket = aws_s3_bucket.app_bucket.bucket
  policy = data.aws_iam_policy_document.app_bucket_policy_doc[0].json
}
data "aws_iam_policy_document" "app_bucket_policy_doc" {
  count = "${var.domain_name}" == "" ? 0 : 1
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.app_bucket.arn}/*"]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.app_cf_distribution[0].arn]
    }
  }
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "app_bucket_oac" {
  count                             = "${var.domain_name}" == "" ? 0 : 1
  name                              = var.project_name
  description                       = "OAC policy for ${var.project_name} bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
data "aws_cloudfront_cache_policy" "caching_optimized_policy" {
  count = "${var.domain_name}" == "" ? 0 : 1
  name  = "Managed-CachingOptimized"
}
data "aws_acm_certificate" "app_certificate" {
  count    = "${var.domain_name}" == "" ? 0 : 1
  domain   = var.domain_name
  provider = aws.us-east-1
}
# CloudFront Distribution
resource "aws_cloudfront_distribution" "app_cf_distribution" {
  count = "${var.domain_name}" == "" ? 0 : 1
  origin {
    domain_name              = aws_s3_bucket.app_bucket.bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.app_bucket_oac[0].id
    origin_id                = aws_s3_bucket.app_bucket.bucket
  }
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_All"
  aliases             = ["${var.domain_name}", "www.${var.domain_name}"]

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.app_logs_bucket.bucket_domain_name
    prefix          = "cloudfront"
  }

  default_cache_behavior {
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized_policy[0].id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.app_bucket.bucket
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.app_certificate[0].arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Route 53 records for root and www.
data "aws_route53_zone" "project_hosted_zone" {
  count = "${var.domain_name}" == "" ? 0 : 1
  name  = var.domain_name
}

resource "aws_route53_record" "app_record" {
  count   = "${var.domain_name}" == "" ? 0 : 1
  zone_id = data.aws_route53_zone.project_hosted_zone[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app_cf_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.app_cf_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "app_record_www" {
  count   = "${var.domain_name}" == "" ? 0 : 1
  zone_id = data.aws_route53_zone.project_hosted_zone[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app_cf_distribution[0].domain_name
    zone_id                = aws_cloudfront_distribution.app_cf_distribution[0].hosted_zone_id
    evaluate_target_health = false
  }
}