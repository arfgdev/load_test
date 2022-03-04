// Default AWS provider vars
variable "region" {
  type        = string
  description = "AWS Region"
}

// Default AWS provider vars
variable "profile" {
  type        = string
  description = "AWS profile"
  default     = "default"
}

variable "bucket_name" {
  type        = string
  description = "AWS profile"
  default     = "proxiesbuckettest1"
}

variable "deploy_bucket" {
  type        = number
  description = "1 if you need to deploy bucket"
  default     =  0
}




variable "ami_id" {
  type        = string
  description = "AWS AMI"
}

variable "name" {
  type        = string
  description = "deployment name"
}

variable "instance_type" {
  type        = string
  description = "Instance type"
  default     = "t2.micro"
}



variable "max_size" {
  type        = number
  description = "Max size of autoscale group"
}

variable "min_size" {
  type        = number
  description = "Min size of autoscale group"
}


// Mixed instances policy part
variable "desired_capacity" {
  type        = number
  description = ""
  default     = 30
}