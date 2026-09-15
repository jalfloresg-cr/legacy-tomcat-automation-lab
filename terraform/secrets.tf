resource "aws_secretsmanager_secret" "application" {
  name = "legacy-tomcat-demo/qa/application"

  depends_on = [
    docker_container.localstack
  ]
}