resource "aws_elasticache_replication_group" "tp2_redis" {
  replication_group_id          = "tf-rep-group-1"
  availability_zones            = [var.availability_zone]
  replication_group_description = "TP2 redis"
  node_type                     = "cache.t2.micro"
  number_cache_clusters         = 1
  port                          = 6379
  security_group_ids            = [aws_security_group.apps.id]

  provisioner "local-exec" {
    command = "echo ${aws_elasticache_replication_group.tp2_redis.primary_endpoint_address} > redis_url"
  }

  provisioner "local-exec" {
    command = "sed -Ei.bak \"s#(host:)[^,]*,#\\1 '$(cat redis_url)',#\" node/config.js"
  }
}
