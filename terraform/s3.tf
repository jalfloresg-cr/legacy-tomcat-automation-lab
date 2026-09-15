resource "aws_s3_bucket" "artifacts" {
  bucket = "legacy-artifacts"

  depends_on = [
    docker_container.localstack
  ]
}