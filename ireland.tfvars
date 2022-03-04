// Set-up main info
region        = "eu-west-1"
ami_id        = "ami-0bf84c42e04519c85"
// Set-up Auto Scaling Group
name             = "load_test"
desired_capacity = 28
min_size         = 0
max_size         = 64

deploy_bucket = 1

