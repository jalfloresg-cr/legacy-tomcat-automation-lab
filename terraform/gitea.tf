resource "docker_network" "gitea" {
  name = "legacy-lab-gitea"
}

resource "docker_volume" "gitea_data" {
  name = "legacy-lab-gitea-data"
}

resource "docker_image" "gitea" {
  name         = "docker.gitea.com/gitea:${var.gitea_version}"
  keep_locally = true
}

resource "docker_container" "gitea" {
  name  = "legacy-lab-gitea"
  image = docker_image.gitea.image_id

  restart = "unless-stopped"

  ports {
    internal = 3000
    external = 3000
  }

  ports {
    internal = 22
    external = 2222
  }

  networks_advanced {
    name = docker_network.gitea.name
  }

  volumes {
    volume_name    = docker_volume.gitea_data.name
    container_path = "/data"
  }

  env = [
    "USER_UID=1000",
    "USER_GID=1000",

    "GITEA__database__DB_TYPE=sqlite3",

    "GITEA__server__ROOT_URL=http://localhost:3000/",
    "GITEA__server__SSH_PORT=2222",

    "GITEA__actions__ENABLED=true"
  ]
}