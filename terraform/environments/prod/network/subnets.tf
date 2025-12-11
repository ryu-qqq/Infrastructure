# Public Subnets Data Source - Reference existing subnets

data "aws_subnet" "public" {
  count = 2

  id = count.index == 0 ? "subnet-0bd2fc282b0fb137a" : "subnet-0c8c0ad85064b80bb"
}

# Private Subnets Data Source - Reference existing subnets

data "aws_subnet" "private" {
  count = 2

  id = count.index == 0 ? "subnet-09692620519f86cf0" : "subnet-0d99080cbe134b6e9"
}
