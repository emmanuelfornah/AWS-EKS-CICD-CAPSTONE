resource "aws_dynamodb_table" "announcements" {
  name         = "DEV_Announcement" # matches the name already in use
  billing_mode = "PAY_PER_REQUEST"  # no capacity planning needed at demo traffic; also what makes the DR Global Table cheap
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }
}
