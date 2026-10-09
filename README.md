# Procesador de Imágenes en AWS con Terraform

**GRUPO: 05**
**URL del proyecto:** https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes  
**Región AWS utilizada:** `us-east-1`  
**Entornos:** `dev`, `qa`, `prod` (Terraform Workspaces)  


## 1. Descripción del proyecto

Este laboratorio implementa en **Amazon Web Services (AWS)** una arquitectura de procesamiento automático de imágenes, definida y administrada con **Terraform**. Un cliente solicita a una API una autorización temporal para subir una imagen; la subida se realiza directamente a **Amazon S3**. La creación del objeto desencadena un procesamiento **asíncrono** mediante **Amazon SQS** y **AWS Lambda**, que utiliza **Sharp** para generar un **PNG de 40 × 40 píxeles con recorte circular y transparencia**.

La infraestructura se reproduce en tres entornos independientes —DEV, QA y PROD— mediante Terraform Workspaces y la variable `environment`. Se documentan la creación, las pruebas, el monitoreo, los controles de seguridad y la eliminación de los recursos para controlar el consumo de AWS.

### Objetivos

- Automatizar la creación de infraestructura AWS mediante código versionado.
- Separar los entornos DEV, QA y PROD sin duplicar la arquitectura.
- Recibir imágenes de manera segura mediante formularios S3 POST firmados y temporales.
- Desacoplar la subida y el procesamiento con SQS.
- Generar imágenes PNG circulares mediante Lambda y Sharp.
- Incorporar registros, una cola de mensajes fallidos (DLQ) y una alarma.
- Validar el funcionamiento y documentar evidencias reproducibles.
- Destruir de manera controlada los recursos de laboratorio al terminar.

## 2. Arquitectura y funcionamiento

```text
                        CLIENTE / USUARIO
                               |
              POST /upload (nombre, tipo, tamaño)
                               v
                     API GATEWAY HTTP
                               |
                               v
                        LAMBDA UPLOAD
                Valida y genera POST firmado
                               |
                    Devuelve URL + campos
                               v
                    CLIENTE SUBE A S3
                               |
                               v
                   S3 privado: uploads/
                               |
                    Notificación de S3
                               v
                         SQS PRINCIPAL
                               |
                     Evento para Lambda
                               v
                    LAMBDA CROP + SHARP
                     Lee, recorta, guarda
                               |
                               v
                  S3 privado: processed/
                       PNG circular 40×40

   SQS principal ---> DLQ (errores) ---> CloudWatch Alarm ---> SNS
   CloudWatch Logs <--- Lambda Upload y Lambda Crop
   IAM: roles y permisos separados para cada función
   VPC: 2 AZ, subredes públicas/privadas y S3 Gateway Endpoint
```

**Detalle del flujo:**

1. El cliente envía `fileName`, `contentType` y `size` a `POST /upload`.
2. **Lambda Upload** valida los datos y devuelve un formulario POST firmado de S3, válido durante **300 segundos**.
3. El cliente envía el archivo **directamente a S3**, sin transmitir el contenido por API Gateway.
4. S3 almacena el original en `uploads/` y notifica la creación a SQS.
5. La integración de SQS invoca **Lambda Crop**, que lee el objeto, aplica el recorte circular y guarda el PNG en `processed/`.
6. CloudWatch registra las ejecuciones; la DLQ y la alarma permiten observar mensajes que no se procesan correctamente.

### Servicios utilizados y justificación

| Servicio | Función en el proyecto | Atributo de calidad |
|---|---|---|
| Terraform | Define, planifica, crea y elimina infraestructura | Reproducibilidad, mantenibilidad |
| Amazon VPC | Organiza subredes y rutas de red | Aislamiento, seguridad |
| Amazon API Gateway HTTP API | Expone `POST /upload` | Integración, disponibilidad administrada |
| AWS Lambda Upload | Valida solicitudes y firma formularios S3 | Seguridad, ejecución bajo demanda |
| Amazon S3 | Almacena originales y resultados | Durabilidad, seguridad |
| Amazon SQS | Desacopla eventos de subida y procesamiento | Escalabilidad, tolerancia a fallos |
| AWS Lambda Crop | Transforma imágenes con Sharp | Procesamiento bajo demanda |
| SQS DLQ | Conserva mensajes tras fallos repetidos | Diagnóstico y recuperación operativa |
| Amazon CloudWatch | Registros, métricas y alarma | Observabilidad |
| Amazon SNS | Destino de alertas | Notificación operativa |
| AWS IAM | Controla permisos por función | Seguridad, mínimo privilegio |

### Configuración de red

La VPC usa `10.0.0.0/16` y distribuye subredes en dos zonas de disponibilidad:

| Subred | CIDR | Zona |
|---|---|---|
| Pública A | `10.0.1.0/24` | `us-east-1a` |
| Pública B | `10.0.2.0/24` | `us-east-1b` |
| Privada A | `10.0.11.0/24` | `us-east-1a` |
| Privada B | `10.0.12.0/24` | `us-east-1b` |

Para reducir costos de laboratorio se utilizaron `enable_nat = false` y `enable_sqs_endpoint = false`, manteniendo el **S3 Gateway Endpoint**. Lambda Crop utiliza subredes privadas. Sin NAT, esas subredes no disponen de acceso saliente general a Internet; el consumo de eventos SQS por Lambda se realiza mediante la integración administrada por AWS. La configuración debe revisarse si se añaden dependencias externas.

## 3. Organización del repositorio

```text
IcC-ProcesadorDeImagenes/
├── terraform/
│   ├── environments/
│   ├── lambda/
│   │   ├── upload/
│   │   │   ├── index.js
│   │   │   ├── package.json
│   │   │   └── package-lock.json
│   │   └── crop/
│   │       ├── index.js
│   │       ├── package.json
│   │       └── package-lock.json
│   ├── providers.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── network.tf
│   ├── nat.tf
│   ├── endpoints.tf
│   ├── storage.tf
│   ├── queues.tf
│   ├── iam.tf
│   ├── lambda.tf
│   ├── api.tf
│   ├── monitoring.tf
│   └── outputs.tf
├── docs/
│   └── evidencias/
│       ├── dev/
│       ├── qa/
│       └── prod/
├── .gitignore
└── README.md
```


## 4. Requisitos previos

Para reproducir el laboratorio se necesita:

- Cuenta AWS con permisos para VPC, IAM, S3, SQS, Lambda, API Gateway, CloudWatch y SNS.
- **Terraform**, **AWS CLI**, **Node.js y npm**, **Git**.
- PowerShell en Windows (los ejemplos de este README están escritos para PowerShell).
- Perfil local AWS CLI denominado `terraform-lab`, o adaptación del proveedor y los comandos a otro perfil.
- Dependencias de Lambda preparadas para el runtime correspondiente; **Sharp** debe ser compatible con **Linux x64** para su ejecución en Lambda.
- Un archivo JPEG de prueba, por ejemplo `test.jpeg`, colocado en la raíz del repositorio.

Comprobar herramientas:

```powershell
terraform version
aws --version
node --version
npm --version
git --version
```

Configurar el perfil si todavía no existe:

```powershell
aws configure --profile terraform-lab
aws sts get-caller-identity --profile terraform-lab
```

**No introduzcas claves AWS en archivos del repositorio.** Comprueba la identidad y cuenta devueltas por STS antes de desplegar. Si utilizas otro perfil, ajusta la configuración del proveedor y los comandos de AWS CLI.

## 5. Instrucciones de instalación y despliegue

### 5.1. Clonar y preparar el proyecto

```powershell
git clone https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes.git
cd .\IcC-ProcesadorDeImagenes\terraform
```

Preparar dependencias de las funciones si no se encuentran instaladas localmente:

```powershell
npm ci --prefix .\lambda\upload
npm ci --prefix .\lambda\crop
```

Inicializar y validar Terraform:

```powershell
terraform init
terraform fmt -check -recursive
terraform validate
```

### 5.2. Seleccionar el entorno

Se usan los workspaces `dev`, `qa` y `prod`:

```powershell
terraform workspace list
terraform workspace select dev
terraform workspace show
```

Si el workspace aún no existe:

```powershell
terraform workspace new dev
```

**Regla esencial:** el workspace y `-var=environment=...` deben coincidir. Un workspace nuevo puede mostrar `No state file was found!` al ejecutar `terraform state list`; esto es normal antes del primer despliegue.

### 5.3. Planificar el despliegue

Ejemplo DEV:

```powershell
terraform workspace select dev
terraform plan '-var=environment=dev' '-out=dev.tfplan'
terraform show -no-color dev.tfplan
```

Revisar especialmente la cantidad de recursos, los nombres con sufijo `dev`, NAT Gateways, endpoints y costos potenciales. **Un plan no crea infraestructura**, pero puede contener información sensible: no publiques el archivo `.tfplan`.

### 5.4. Crear la infraestructura

```powershell
terraform apply "dev.tfplan"
```

Este comando **crea recursos reales y puede generar cargos o consumir créditos AWS**. En las pruebas documentadas se crearon **50 recursos por entorno**.

Consultar salidas:

```powershell
terraform output
terraform output -raw api_url
terraform output -raw s3_bucket_name
terraform output -raw sqs_queue_url
terraform output -raw sns_topic_arn
```

### 5.5. Repetir en QA o PROD

Usar **un entorno a la vez** y revisar cada plan antes de aplicar:

```powershell
# QA
terraform workspace select qa
terraform plan '-var=environment=qa' '-out=qa.tfplan'
terraform apply "qa.tfplan"

# PROD: ejecutar solo cuando esté autorizado
terraform workspace select prod
terraform plan '-var=environment=prod' '-out=prod.tfplan'
terraform apply "prod.tfplan"
```

Si `qa` o `prod` todavía no existen, crearlos primero con `terraform workspace new qa` o `terraform workspace new prod`. No apliques un plan de un entorno en un workspace distinto. Los planes guardados deben regenerarse si cambian el código, las variables o el estado.

## 6. Instrucciones para probar la aplicación

Los comandos se ejecutan desde `terraform/`, con el entorno deseado **ya desplegado y seleccionado**. Se utiliza un archivo `test.jpeg` ubicado en la raíz del repositorio.

### 6.1. Solicitar autorización a la API

```powershell
$apiUrl = terraform output -raw api_url
$imagePath = (Resolve-Path "..\test.jpeg").Path
Test-Path $imagePath

$body = @{
    fileName    = "test.jpeg"
    contentType = "image/jpeg"
    size        = (Get-Item $imagePath).Length
} | ConvertTo-Json

$response = Invoke-RestMethod `
    -Uri $apiUrl `
    -Method POST `
    -ContentType "application/json" `
    -Body $body

$response | Select-Object message, key, uploadUrl, expiresIn
```

**Resultado esperado:** mensaje de formulario generado, clave bajo `uploads/`, URL de S3 y expiración `300`. La respuesta también incluye campos firmados: **no publicar** `Policy`, `X-Amz-Signature`, `X-Amz-Security-Token` ni la respuesta completa.

### 6.2. Subir el JPEG a S3

Ejecutar antes de que caduque el formulario firmado (5 minutos):

```powershell
$curlArgs = @("-sS", "-i", "-X", "POST")
foreach ($field in $response.fields.PSObject.Properties) {
    $curlArgs += @("-F", "$($field.Name)=$($field.Value)")
}
$curlArgs += @("-F", "file=@$imagePath;type=image/jpeg", $response.uploadUrl)
& curl.exe @curlArgs
```

**Resultado observado:** `HTTP/1.1 204 No Content`, que indica que S3 aceptó la subida. Si la firma expira, genera una nueva respuesta ejecutando otra vez el paso 6.1.

### 6.3. Comprobar el procesamiento

```powershell
$bucket = terraform output -raw s3_bucket_name
aws s3 ls "s3://$bucket/" --recursive --profile terraform-lab
```

**Resultado esperado:** un original en `uploads/<identificador>.jpg` y su resultado en `processed/<identificador>.png`. El procesamiento es asíncrono; puede requerir unos segundos.

### 6.4. Descargar e inspeccionar el PNG

```powershell
$outputKey = $response.key -replace '^uploads/', 'processed/'
$outputKey = $outputKey -replace '\.[^.]+$', '.png'
aws s3 cp "s3://$bucket/$outputKey" ".\resultado.png" --profile terraform-lab
```

Abrir `resultado.png` y comprobar visualmente el recorte circular. Para acreditar las **dimensiones exactas 40 × 40**, usar un inspector de imágenes y conservar una captura de sus propiedades; la configuración de código por sí sola no sustituye una medición independiente.

### 6.5. Consultar CloudWatch

```powershell
$envName = (terraform workspace show).Trim()
aws logs tail "/aws/lambda/icc-procesador-imagenes-$envName-crop" `
    --since 1h `
    --profile terraform-lab
```

Buscar un registro `INFO Procesada: uploads/... -> processed/...`, además de duración, memoria y posibles excepciones. Los grupos de registros se configuraron con retención de **14 días**.

### 6.6. Pruebas negativas y alcance

La API contempla formatos **JPEG, PNG, GIF y WEBP**, con límite declarado de **10 MiB** (`10 485 760` bytes). El POST firmado restringe el tamaño del cuerpo multipart, que también incluye los campos del formulario; por ello el tamaño efectivo del archivo puede ser ligeramente inferior. La validación del contenido durante el procesamiento aporta una comprobación adicional.

En DEV se verificó el rechazo de una solicitud que declaraba un archivo mayor al límite. **No se documentaron** pruebas forzadas de DLQ/SNS, carga, conmutación ante fallos ni una verificación independiente de dimensiones en los tres entornos. No se presentan como pruebas aprobadas.

## 7. Resultados obtenidos: DEV, QA y PROD

### 7.1. Resumen de entornos

| Entorno | Despliegue | Pruebas del flujo principal | Estado de destrucción |
|---|---|---|---|
| **DEV** | `50 added, 0 changed, 0 destroyed` | Exitosas: API, validación de tamaño, S3, SQS, Crop y CloudWatch | **Completada**; últimos 2 roles IAM eliminados en reintento |
| **QA** | `50 added, 0 changed, 0 destroyed` | Exitosas: API, HTTP 204, JPEG y PNG en S3 | **Completada**; últimos 2 roles IAM eliminados en reintento; estado vacío |
| **PROD** | `50 added, 0 changed, 0 destroyed` | Exitosas: API, HTTP 204, Crop y CloudWatch | **Completada**: `Destroy complete! Resources: 50 destroyed`; `terraform state list` vacío |

**Nota:** los 50 recursos de cada entorno corresponden a despliegues sucesivos, no necesariamente a 150 recursos simultáneamente activos.

### 7.2. DEV

- Se creó la infraestructura con 50 recursos y se ejecutó la prueba de extremo a extremo.
- La API rechazó correctamente una solicitud con tamaño declarado superior a 10 MiB.
- Se obtuvo el PNG procesado y se verificó visualmente el recorte circular.
- En CloudWatch se registró `INFO Procesada`.
- Una ejecución observada de Lambda Crop duró **858,10 ms**, con **512 MB** configurados y **127 MB** de memoria máxima utilizada.
- En la destrucción surgió un error IAM; después de corregir el permiso, Terraform informó `Destroy complete! Resources: 2 destroyed` para los recursos restantes.

### 7.3. QA

- Terraform informó `Apply complete! Resources: 50 added, 0 changed, 0 destroyed`.
- La API generó un formulario firmado; la subida a S3 devolvió **HTTP 204**.
- Se observaron los objetos correspondientes: **JPEG de 102 069 bytes** en `uploads/` y **PNG de 4 525 bytes** en `processed/`.
- El plan de cierre indicó **50 recursos por destruir**; tras la eliminación parcial, la falta del permiso IAM impidió borrar dos roles.
- Se corrigió el permiso y el reintento terminó con `Destroy complete! Resources: 2 destroyed`; `terraform state list` quedó vacío.

### 7.4. PROD

- Terraform informó `Apply complete! Resources: 50 added, 0 changed, 0 destroyed`.
- API Gateway y Lambda Upload generaron la autorización de subida; S3 respondió **HTTP 204**.
- CloudWatch registró `INFO Procesada: uploads/... -> processed/...`, confirmando el procesamiento de Lambda Crop.
- Una ejecución observada duró **728,92 ms**, con **512 MB** configurados y **120 MB** de memoria máxima utilizada.
- Se comprobó que el bucket versionado quedó vacío (`Versions: null`, `DeleteMarkers: null`) y el plan de destrucción indicó **50 recursos por destruir**.
- Se confirmó que se ejecutó `terraform destroy` en PROD. Ejecutar `terraform workspace select prod` y `terraform state list` para verificar que el estado quedó vacío.


### 7.5. Matriz de validación

| Caso | DEV | QA | PROD |
|---|---|---|---|
| Terraform aplica 50 recursos | Sí | Sí | Sí |
| API genera formulario firmado | Sí | Sí | Sí |
| S3 acepta subida JPEG | Sí | Sí | Sí |
| Se crea PNG procesado | Sí | Sí | Sí, registrado en CloudWatch |
| Recorte circular inspeccionado visualmente | Sí | Evidencia recopilada; resultado no detallado | No consta verificación visual independiente |
| CloudWatch confirma procesamiento | Sí | Evidencia recopilada; resultado no detallado | Sí |
| Rechazo de tamaño declarado excesivo | Sí | No consta prueba | No consta prueba |
| Dimensiones 40 × 40 verificadas con inspector | No consta | No consta | No consta |
| DLQ / SNS con fallo forzado | No probado | No probado | No probado |
| Prueba de carga | No probada | No probada | No probada |
| Destrucción confirmada | Sí | Sí | sí |

## 8. Seguridad, monitoreo y manejo de fallos

**Seguridad aplicada:**

- Bucket S3 privado, con bloqueo de acceso público, cifrado del lado del servidor **AES-256** y versionado.
- Separación entre `uploads/` y `processed/` y reglas de ciclo de vida.
- Roles IAM diferenciados para Lambda Upload y Lambda Crop.
- Formularios S3 POST firmados, temporales, con restricciones de tipo/tamaño contempladas en la aplicación.
- Lambda Crop ubicada en subredes privadas y acceso a S3 mediante endpoint Gateway.
- Uso de perfil AWS CLI local en lugar de credenciales incrustadas en el código.

**Manejo de fallos y observabilidad:**

- SQS desacopla la subida y el procesamiento; permite reintentos ante fallos.
- La integración con Lambda contempla la respuesta de fallos parciales de lote (`batchItemFailures`).
- La **DLQ** conserva mensajes tras superar el máximo de intentos configurado.
- Una **alarma de CloudWatch** observa mensajes en la DLQ y utiliza **SNS** como destino. Para recibir correos u otras notificaciones se requiere una suscripción válida y confirmada.
- CloudWatch Logs permite investigar excepciones, duración y memoria.

**Limitaciones importantes:** la API de laboratorio genera autorizaciones temporales, pero ello **no equivale a autenticación de usuarios ni protección completa frente a abuso**. Una producción pública real debería evaluar autenticación, cuotas, monitoreo de costos, políticas de retención, recuperación ante desastres y pruebas de carga. La arquitectura incorpora mecanismos de disponibilidad y tolerancia a fallos, pero no se ejecutaron pruebas de conmutación ni se estableció un SLA medido.

## 9. Destrucción controlada de la infraestructura

### 9.1. Revisar el entorno y el plan

Ejemplo para `prod` (sustituir `prod` por `qa` o `dev` cuando corresponda):

```powershell
terraform workspace select prod
terraform workspace show
terraform plan '-destroy' '-var=environment=prod'
$bucket = terraform output -raw s3_bucket_name
Write-Host "Bucket a revisar: $bucket"
```

### 9.2. Revisar las versiones del bucket

```powershell
aws s3api list-object-versions `
    --bucket $bucket `
    --query "{Versiones: Versions[].{Archivo:Key,VersionId:VersionId},Marcadores: DeleteMarkers[].{Archivo:Key,VersionId:VersionId}}" `
    --output json `
    --profile terraform-lab
```

**Un bucket S3 con versionado puede conservar versiones antiguas y marcadores de eliminación**. Borrar solo los objetos visibles mediante `aws s3 rm` puede no ser suficiente. Se deben identificar y eliminar **todas** las versiones y marcadores del bucket correcto antes de destruirlo. Por seguridad, este README no incluye un comando genérico que borre todos los datos sin revisión.

Una vez vaciado, repetir `list-object-versions` y comprobar que no queden versiones ni marcadores.

### 9.3. Ejecutar y verificar la destrucción

```powershell
terraform destroy '-var=environment=prod'
terraform state list
```

Revisar el plan interactivo y escribir `yes` solo si se autoriza la destrucción. Una finalización correcta presenta `Destroy complete!` y `terraform state list` no debe mostrar recursos administrados.

**Si ocurre un fallo parcial, no borrar el estado Terraform:** corregir la causa y ejecutar de nuevo el plan o `destroy` para los recursos restantes.

### 9.4. Incidencia IAM encontrada y solución

Durante la destrucción de **DEV y QA**, Terraform no pudo eliminar dos roles Lambda debido a:

```text
AccessDenied: iam:ListInstanceProfilesForRole
```

El usuario IAM que ejecuta Terraform necesita ese permiso sobre los roles que administra. Se actualizó la política personalizada `TerraformProcesadorImagenesIAM`, limitando el permiso a los roles del entorno correspondiente, y se volvió a ejecutar la destrucción. En ambos casos se completó la eliminación de los **dos roles pendientes**.

Para evitar la misma incidencia al cerrar PROD, verificar que el usuario tenga `iam:ListInstanceProfilesForRole` sobre:

```text
icc-procesador-imagenes-prod-upload-role
icc-procesador-imagenes-prod-crop-role
```

Ejemplo de permiso **acotado** para añadir al arreglo `Statement` de una política IAM existente, con autorización del administrador:

```json
{
  "Sid": "ListInstanceProfilesForProdRoles",
  "Effect": "Allow",
  "Action": "iam:ListInstanceProfilesForRole",
  "Resource": [
    "arn:aws:iam::287238357612:role/icc-procesador-imagenes-prod-upload-role",
    "arn:aws:iam::287238357612:role/icc-procesador-imagenes-prod-crop-role"
  ]
}
```

Si se reproduce el laboratorio en **otra cuenta AWS**, sustituir el identificador de cuenta y los nombres de los roles. El ejemplo no sustituye la revisión integral de permisos IAM.

## 10. Evidencias para el docente

Las evidencias se organizan por entorno:

```text
docs/evidencias/
├── dev/
├── qa/
└── prod/
```

| Evidencia a conservar | Qué demuestra |
|---|---|
| `terraform apply` y outputs | Creación de infraestructura y nombres del entorno |
| Solicitud API `/upload` | Integración API Gateway + Lambda Upload |
| HTTP 204 de S3 | Subida correcta del archivo |
| Lista de objetos S3 | Original en `uploads/` y resultado en `processed/` |
| PNG descargado | Resultado del procesamiento y recorte |
| CloudWatch Logs | Ejecución de Lambda Crop y métricas |
| `terraform plan -destroy` | Recursos previstos para eliminar |
| `Destroy complete!` y estado vacío | Cierre controlado del entorno |

**Importante:** revisar los nombres reales de los archivos en `docs/evidencias/` antes de insertar enlaces de imágenes en el README. No publicar capturas con firmas temporales S3, tokens, claves AWS o datos privados.

### Evidencia adicional recomendada

Capturar una inspección de propiedades del PNG que muestre **40 × 40 píxeles**, una prueba de rechazo de archivo demasiado grande y, si el alcance académico lo exige, una prueba controlada de fallo hacia DLQ. Estas pruebas no deben marcarse como realizadas sin su evidencia correspondiente.

## 11. Costos y recomendaciones

AWS puede consumir créditos o generar cargos por Lambda, API Gateway, S3, SQS, CloudWatch y otros recursos. **No se garantiza costo cero**, aunque exista saldo promocional o capa gratuita.

Durante el laboratorio se aplicaron estas medidas:

- Deshabilitar NAT Gateway y el endpoint Interface de SQS, manteniendo el endpoint Gateway de S3.
- Desplegar los entornos de manera sucesiva y destruir los anteriores al terminar.
- Revisar cada plan antes de `apply` y `destroy`.
- Conservar evidencias antes de vaciar S3.
- Consultar periódicamente **AWS Billing** y los créditos disponibles.

Destruir recursos evita su uso posterior, pero **no elimina costos ya generados**. Revisar además cualquier recurso fuera del estado de Terraform y los cargos pendientes en la cuenta.

## 12. Publicación del proyecto en GitHub

Desde la raíz del repositorio o la carpeta `terraform/`, revisar el estado de Git y agregar **solo** los archivos que deben publicarse:

```powershell
# Desde terraform/
git status --short
git add ../README.md
git add ../docs/evidencias/
git diff --cached --stat
git commit -m "docs: documentar arquitectura, despliegues y pruebas DEV QA PROD"
git push origin main
```

**No publicar:** `*.tfstate`, copias de estado, `*.tfplan`, `.terraform/`, `node_modules/`, ZIP generados, credenciales AWS, formularios firmados completos ni imágenes privadas. Revisar `.gitignore` y el resultado de `git diff --cached --stat` antes de confirmar.

**Enlace al repositorio:**

https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes

## 13. Conclusiones

Se implementó y reprodujo una arquitectura AWS mediante Terraform en **DEV, QA y PROD**, con 50 recursos creados por despliegue. Las pruebas demostraron la integración de API Gateway, Lambda Upload, Amazon S3, Amazon SQS y Lambda Crop para procesar imágenes de forma asíncrona. CloudWatch permitió verificar las ejecuciones y observar métricas puntuales.

Los entornos **DEV y QA** fueron cerrados mediante Terraform; ambos cierres permitieron identificar y resolver un problema de permisos IAM durante la eliminación de roles. En **PROD**, se verificó el funcionamiento del flujo principal, se vació el bucket versionado y se ejecutó la destrucción completa (`Destroy complete! Resources: 50 destroyed`), con el estado de Terraform vacío.

El proyecto demuestra **automatización, reproducibilidad, separación de entornos, seguridad básica, observabilidad y gestión responsable de recursos**. Como mejoras futuras quedan la autenticación y protección de la API, pruebas de carga, simulación de fallos, verificación independiente de dimensiones y validación de alertas DLQ/SNS.

---

**Repositorio:** [JParedesCajo/IcC-ProcesadorDeImagenes](https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes)  
**Documento:** `README.md` — instrucciones de instalación, despliegue, pruebas, evidencias y destrucción.
