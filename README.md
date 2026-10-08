# Procesamiento de Imágenes con AWS y Terraform

## *** GRUPO 05 ***

## Descripción

Trabajo de laboratorio S4 - Infraestructura como Código 

El objetivo es implementar una arquitectura que permita recibir imágenes, almacenarlas en Amazon S3 y procesarlas automáticamente mediante AWS Lambda para generar imágenes circulares de 40x40 píxeles.

La infraestructura se podrá desplegar en tres entornos independientes: DEV, QA y PROD.

## Tecnologías

- Terraform
- Amazon Web Services (AWS)
- AWS Lambda
- Amazon S3
- Amazon SQS
- Amazon API Gateway
- Amazon CloudWatch
- AWS IAM
- Node.js
- Git y GitHub

## Requisitos previos

Para ejecutar el proyecto es necesario tener instalados:

- Visual Studio Code
- Terraform
- AWS CLI
- Git
- Node.js y npm

También se necesita una cuenta AWS con los permisos necesarios (ya habiendolo creado en horario de laboratorio).

## Configuración de AWS CLI

Configurar un perfil local de AWS:

```powershell
aws configure --profile terraform-lab
```

Verificar la identidad autenticada:

```powershell
aws sts get-caller-identity --profile terraform-lab
```

Verificar la región:

```powershell
aws configure get region --profile terraform-lab
```

La región utilizada será `us-east-1`.

**Importante:** las credenciales AWS no deben almacenarse en el repositorio, solo se adjuntara en la documentación entregable como parte de la evidencia.

## Arquitectura

El diseño de referencia se encuentra en `architecture.mermaid`.

El flujo principal contempla:

1. Recepción de solicitudes mediante API Gateway.
2. Gestión de cargas mediante Lambda.
3. Almacenamiento de imágenes originales en S3.
4. Notificación de eventos mediante SQS.
5. Procesamiento mediante Lambda y Sharp.
6. Almacenamiento de imágenes procesadas en S3.
7. Monitoreo de errores mediante CloudWatch.

## Entornos

El proyecto tendrá tres entornos:

| Entorno | Propósito |
|---|---|
| DEV | Desarrollo |
| QA | Pruebas |
| PROD | Producción |

Cada entorno tendrá una configuración y un estado de Terraform independientes.

## Despliegue

Pendiente de implementar y documentar en los siguientes sprints.

Se incluirán los comandos de `terraform init`, `terraform plan` y `terraform apply`.

## Pruebas

Pendiente de implementar.

## Evidencias

Se incluirán capturas reales del despliegue en AWS, pruebas funcionales y datos de identificación de la cuenta utilizada.

## Destrucción de recursos

Pendiente de ejecutar.

Se documentará el uso de `terraform destroy` para eliminar los recursos de DEV, QA y PROD.

## Desarrollo por sprints

| Sprint | Actividad | Estado |
|---|---|---|
| 1 | Preparación del entorno y GitHub | En progreso |
| 2 | Configuración Terraform y entornos | Pendiente |
| 3 | Red y S3 | Pendiente |
| 4 | SQS e IAM | Pendiente |
| 5 | Funciones Lambda | Pendiente |
| 6 | API Gateway y CloudWatch | Pendiente |
| 7 | Despliegue y pruebas | Pendiente |
| 8 | Evidencias y destrucción | Pendiente |

## Repositorio GitHub

Pendiente de publicar.