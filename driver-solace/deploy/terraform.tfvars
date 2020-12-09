public_key_path = "~/.ssh/solace_aws.pub"
private_key_path="~/.ssh/solace_aws"
region          = "us-west-2"
profile         = "default"

ownerTag = "manuel.moreno@solace.com"
daysTag = "5"
descriptionTag = "OpenBenchmark Test"

instance_types = {
  "messaging"  = "m5.xlarge" # "i3en.2xlarge"
  "monitor"    = "t2.medium"
  "client"     = "c5n.2xlarge"
  "prometheus" = "c5.2xlarge"
}

num_instances = {
  "client"     = 2
  "prometheus" = 0
}

centOS_ami = {
  "us-east-1" = "ami-02eac2c0129f6376b"
  "us-east-2" = "ami-0f2b4fc905b0bd1f1"
  "us-west-1" = "ami-074e2d6769f445be5"
  "us-west-2" = "ami-01ed306a12b7d1c96"
}
