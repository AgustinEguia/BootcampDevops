# Terraform — infraestructura en AWS

Este directorio contiene la infraestructura como código para desplegar el
demo en AWS real: ECR (registry de imágenes) y EKS (cluster de
Kubernetes), sobre una VPC dedicada.

## ADVERTENCIA DE COSTOS

**Aplicar este Terraform crea recursos REALES y FACTURABLES en AWS.**
En particular:

- Un cluster **EKS** tiene un costo fijo del control plane (~USD 0.10/hora,
  ~USD 73/mes) SIN CONTAR los nodos worker (EC2) que corren sobre él.
- Los **NAT Gateways** (uno por subnet pública en el módulo de red) cuestan
  por hora ENCENDIDOS más por GB transferido, incluso sin tráfico. Con 2-3
  AZs esto solo ya puede rondar USD 60-100/mes.
- Las instancias EC2 del **node group** de EKS facturan por hora
  encendidas, independientemente de si hay carga de trabajo corriendo.

**Recomendación para el curso:** usar esto SÓLO en una cuenta de AWS de
práctica/sandbox (con budget alerts configuradas), y ejecutar
`terraform destroy` apenas se termine el laboratorio del día. Si sólo
querés practicar Kubernetes sin gastar en AWS, usá
`scripts/kind-cluster.sh` (cluster local con kind) — todo el material de
`k8s/` y `helm/` funciona igual contra un cluster local.

## Orden de aplicación

Los módulos están numerados porque **tienen dependencias entre sí** y hay
que aplicarlos en orden (cada uno lee outputs del anterior via
`terraform_remote_state` o variables pasadas a mano):

1. **`00-backend/`** — crea el bucket S3 (guarda el `.tfstate` de forma
   remota y versionada) y la tabla DynamoDB (locking, para que dos
   personas no corran `apply` al mismo tiempo y corrompan el state).
   Este módulo es especial: su PROPIO state arranca en local (todavía no
   existe el backend remoto) y después de aplicarlo, los módulos
   siguientes SÍ usan el backend S3 que este creó.

2. **`10-network/`** — VPC con subnets públicas y privadas en varias AZs,
   NAT Gateway(s), usando el módulo público `terraform-aws-modules/vpc`.
   Los nodos de EKS van a vivir en las subnets privadas (no expuestas
   directamente a Internet).

3. **`20-ecr/`** — repositorio ECR donde el pipeline de CI/CD pushea las
   imágenes Docker (reemplaza al registry de GitLab/Docker Hub si se
   despliega en AWS "de verdad"). Incluye lifecycle policy (borra
   imágenes viejas automáticamente) y scan-on-push (escaneo de
   vulnerabilidades nativo de ECR, complementario a Trivy en el pipeline).

4. **`30-eks/`** — el cluster de Kubernetes en sí, con un managed node
   group y soporte para IRSA (IAM Roles for Service Accounts, para que
   los pods puedan asumir roles de IAM sin manejar credenciales de AWS a
   mano).

## Cómo aplicar cada módulo

```bash
cd terraform/00-backend
cp terraform.tfvars.example terraform.tfvars   # y completar con tus valores
terraform init
terraform plan
terraform apply

cd ../10-network
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply

# ... y así con 20-ecr y 30-eks
```

`make tf-plan TF_DIR=terraform/10-network` corre `init` + `plan` para
cualquiera de estos módulos sin tener que recordar el comando completo.

## Cómo destruir todo (¡en orden INVERSO!)

```bash
cd terraform/30-eks   && terraform destroy
cd ../20-ecr           && terraform destroy
cd ../10-network         && terraform destroy
cd ../00-backend           && terraform destroy   # último: nadie más lo necesita ya
```

Si se destruye `10-network` antes que `30-eks`, Terraform va a fallar (o
peor, dejar recursos huérfanos) porque el cluster EKS todavía depende de
la VPC. El orden inverso al de creación es la regla general para evitar
esto.
