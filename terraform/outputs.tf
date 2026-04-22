output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "route53_zone_id" {
  value = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Point these at Namecheap DNS"
  value       = module.route53.name_servers
}
