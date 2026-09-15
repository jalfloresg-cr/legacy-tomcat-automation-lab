resource "docker_image" "localstack" {
  name         = "localstack/localstack:4.4.0"
  keep_locally = true
}

resource "docker_container" "localstack" {
  name  = "legacy-tomcat-localstack"
  image = docker_image.localstack.image_id

  ports {
    internal = 4566
    external = 4566
  }

  networks_advanced {
    name = docker_network.gitea.name
  }

  env = [
    "SERVICES=s3,secretsmanager"
  ]
}