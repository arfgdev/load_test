// Set-up main info
region        = "us-west-1"
ami_id        = "ami-051317f1184dd6e92"
// Set-up Auto Scaling Group
name         = "load_test_usw2"
desired_capacity = 32
min_size         = 0
max_size         = 64


