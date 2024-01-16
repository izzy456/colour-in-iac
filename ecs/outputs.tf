output "frontend_dns_name" {
  description = "DNS name of the frontend lb"
  value       = aws_lb.lb_frontend.dns_name
}

output "frontend_port" {
  description = "Port of the frontend lb listener"
  value       = aws_lb_listener.lb_listener_frontend.port
}