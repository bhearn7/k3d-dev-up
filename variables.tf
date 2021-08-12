variable "AWSUSERNAME" {
  type = string
  # default = ""
}
variable "AWSPROFILE" {
  type = string
  # default = ""
}
variable "INSTANCETYPE" {
  type    = string
  default = "t2.xlarge"
}
variable "VOLUMESIZE" {
  type    = string
  default = "50"
}