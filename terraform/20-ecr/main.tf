# main.tf (20-ecr)
# -------------------
# Repositorio ECR donde el pipeline de CI/CD (build:image en
# ci/gitlab/10-build.yml, o dockerBuildPush en Jenkins) pushea las
# imágenes cuando se despliega en AWS "de verdad" (en vez de usar el
# Container Registry propio de GitLab).
provider "aws" {
  region = var.aws_region
}

resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "IMMUTABLE" # una vez pusheado un tag, no se puede sobreescribir: fuerza a usar tags únicos (el SHA del commit), evitando el problema de "until:latest cambió sin que nadie se diera cuenta".

  # scan_on_push: ECR escanea automáticamente cada imagen pusheada
  # buscando CVEs conocidas (usa la misma base de datos que Trivy en
  # espíritu). Es una capa MÁS de defensa, redundante a propósito con el
  # job image-scan:trivy del pipeline: ninguna herramienta sola detecta
  # el 100% de los problemas, y tener el scan también del lado del
  # registry protege incluso imágenes pusheadas por fuera del pipeline
  # (por ejemplo, alguien probando algo a mano con docker push).
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# Lifecycle policy: borra automáticamente imágenes viejas para no
# acumular costo de almacenamiento indefinidamente. La regla de abajo
# dice "de las imágenes con tag que empiece con un SHA de git (7+
# caracteres hex), quedate sólo con las últimas N; el resto, borralas".
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Mantener sólo las últimas ${var.max_images_to_keep} imágenes taggeadas"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-", "v", "main-", "dev-", "prod-"]
          countType     = "imageCountMoreThan"
          countNumber   = var.max_images_to_keep
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Borrar imágenes SIN tag (quedan huérfanas de builds fallidos) después de 1 día"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
