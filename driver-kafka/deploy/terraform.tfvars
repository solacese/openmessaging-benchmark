region          = "us-west-2"
ami             = "ami-9fa343e7" // RHEL-7.4
profile         = "default"
ownerTag = "thomas.kunnumpurath@solace.com"
daysTag = "5"

instance_types = {
  "kafka"      = "i3en.2xlarge"
  "zookeeper"  = "t2.small"
  "client"     = "c5n.2xlarge"
  "prometheus" = "c5.2xlarge"
}

num_instances = {
  "client"     = 4
  "kafka"      = 3
  "zookeeper"  = 3
  "prometheus" = 1
}

