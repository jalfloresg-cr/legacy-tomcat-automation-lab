resource "docker_image" "gitea_runner" {
  name         = "docker.io/gitea/runner:2"
  keep_locally = true
}

resource "docker_volume" "gitea_runner_data" {
  name = "legacy-lab-gitea-runner-data"
}

resource "docker_container" "gitea_runner" {
  name  = "legacy-lab-gitea-runner"
  image = docker_image.gitea_runner.image_id

  restart = "unless-stopped"

  networks_advanced {
    name = docker_network.gitea.name
  }

  env = [
    "CONFIG_FILE=/config.yaml",

    # The runner container reaches Gitea through the Docker network,
    # not through localhost.
    "GITEA_INSTANCE_URL=http://legacy-lab-gitea:3000/",

    "GITEA_RUNNER_REGISTRATION_TOKEN_FILE=/run/secrets/runner_token",
    "GITEA_RUNNER_NAME=legacy-lab-runner"
  ]

  volumes {
    volume_name    = docker_volume.gitea_runner_data.name
    container_path = "/data"
  }

  volumes {
    host_path      = abspath("${path.root}/templates/gitea-runner-config.yaml")
    container_path = "/config.yaml"
    read_only      = true
  }

  volumes {
    host_path      = abspath("${path.root}/../.secrets/gitea-runner-token")
    container_path = "/run/secrets/runner_token"
    read_only      = true
  }

  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }

  depends_on = [
    docker_container.gitea
  ]
}