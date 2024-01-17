output "frontend_dns_name" {
  description = "DNS name of the frontend lb"
  value       = aws_lb.lb_frontend.dns_name
}