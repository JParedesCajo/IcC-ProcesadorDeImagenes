# Procesador de Imágenes en AWS con Terraform

**Repositorio:** https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes  
**Plataforma:** Amazon Web Services (AWS)  
**Región:** `us-east-1`  
**Entornos:** DEV, QA y PROD  
**Estado actual:** DEV completado y destruido; QA desplegado y con flujo principal probado; PROD pendiente.

---

## 1. Descripción del laboratorio

Este trabajo implementa una arquitectura de procesamiento automático de imágenes en AWS mediante **Terraform**, una herramienta de Infraestructura como Código (IaC). Permite solicitar una autorización temporal de subida, almacenar una imagen original en Amazon S3 y generar de manera asíncrona una versión PNG con **recorte circular de 40 × 40 píxeles**.

La solución utiliza una API HTTP, funciones AWS Lambda, notificaciones de Amazon S3, una cola Amazon SQS y monitoreo mediante Amazon CloudWatch. El código de infraestructura es reutilizable para los entornos **DEV**, **QA** y **PROD**, cada uno con su propio estado de Terraform y recursos diferenciados.

### Estado de los entornos

| Entorno | Despliegue | Pruebas funcionales | Destrucción | Situación |
|---|---|---|---|---|
| **DEV** | Completado (50 recursos) | Flujo principal exitoso | **Completada** | Cerrado |
| **QA** | Completado (50 recursos) | API, subida JPEG y procesamiento exitosos | Pendiente | Activo al último registro |
| **PROD** | Pendiente | Pendiente | No aplica | Por evaluar |


---

## 2. Objetivos

### Objetivo general

Diseñar, implementar y validar una infraestructura de procesamiento automático de imágenes en AWS mediante Terraform, aplicando automatización, separación de entornos, seguridad, procesamiento asíncrono y observabilidad.

### Objetivos específicos

- Definir los recursos AWS mediante archivos Terraform versionados en Git.
- Mantener entornos independientes mediante Terraform Workspaces.
- Exponer un endpoint HTTP `POST /upload` para solicitar autorizaciones de subida.
- Almacenar originales en `uploads/` y resultados en `processed/` dentro de Amazon S3.
- Desacoplar la subida y el procesamiento mediante Amazon SQS.
- Transformar imágenes con AWS Lambda, Node.js y Sharp.
- Aplicar permisos IAM diferenciados, cifrado y bloqueo del acceso público a S3.
- Registrar ejecuciones y configurar mecanismos de alerta mediante CloudWatch, DLQ y SNS.
- Verificar el flujo de extremo a extremo en DEV y QA.
- Demostrar la creación y destrucción controlada de recursos AWS mediante Terraform.

---

## 3. Tecnologías utilizadas

| Tecnología | Función |
|---|---|
| Terraform | Definición, planificación, despliegue y destrucción de infraestructura |
| Amazon VPC | Red virtual, subredes y controles de conectividad |
| Amazon S3 | Almacenamiento privado de imágenes originales y procesadas |
| Amazon API Gateway (HTTP API) | Endpoint HTTP para solicitar subidas |
| AWS Lambda | Autorización de subida y procesamiento de imágenes |
| Amazon SQS | Cola de mensajes para procesamiento asíncrono |
| Amazon CloudWatch | Logs, métricas y alarma de mensajes fallidos |
| Amazon SNS | Destino de notificaciones de la alarma |
| AWS IAM | Roles y políticas de acceso |
| Node.js 22 | Entorno de ejecución de Lambda |
| Sharp | Redimensionamiento y recorte circular |
| AWS CLI | Operación y comprobaciones desde terminal |
| Git y GitHub | Historial y documentación del proyecto |
| PowerShell / VS Code | Entorno local de trabajo |

---

## 4. Arquitectura de la solución

### 4.1. Flujo principal

```text
USUARIO / CLIENTE
      |
      | POST /upload (nombre, tipo y tamaño)
      v
API GATEWAY HTTP
      |
      v
LAMBDA UPLOAD
      | Valida solicitud y devuelve POST firmado
      v
CLIENTE ENVÍA IMAGEN DIRECTAMENTE A S3
      |
      v
S3: uploads/
      |
      | Notificación de creación de objeto
      v
SQS: cola principal
      |
      | Integración de eventos administrada por AWS
      v
LAMBDA CROP (Node.js + Sharp)
      |
      | Lee original y transforma imagen
      v
S3: processed/
      |
      v
PNG circular de 40 x 40 píxeles
```

**Componentes complementarios:** DLQ para mensajes fallidos, alarma CloudWatch, tema SNS, roles IAM, VPC con dos zonas de disponibilidad y endpoint Gateway de S3.

### 4.2. Función de cada componente

**API Gateway.** Publica el endpoint `POST /upload` y envía las solicitudes a Lambda Upload. La API devuelve los datos necesarios para subir el archivo directamente a S3.

**Lambda Upload.** Comprueba el nombre, formato y tamaño declarado del archivo y genera un formulario **POST firmado** con una vigencia de 300 segundos. No transporta el contenido de la imagen a través de API Gateway.

**Amazon S3.** Mantiene los originales en `uploads/` y los resultados en `processed/`. Se configura como bucket privado, con cifrado AES-256, versionado, reglas de ciclo de vida y CORS para la subida POST.

**Amazon SQS.** Recibe las notificaciones de creación de objetos del prefijo `uploads/` y permite desacoplar la recepción de imágenes del procesamiento. Una DLQ conserva mensajes que superan los intentos configurados.

**Lambda Crop.** Consume eventos de SQS, obtiene la imagen desde S3, valida el contenido, realiza el recorte circular con Sharp y guarda el PNG en `processed/`.

**CloudWatch.** Registra la ejecución de las funciones, su duración, consumo de memoria y errores. También incorpora una alarma vinculada a la DLQ.

**SNS.** Proporciona un destino para notificaciones de la alarma. La entrega de correos requiere una suscripción configurada y confirmada.

**VPC e IAM.** La VPC organiza las subredes y el acceso de red; IAM restringe los permisos de cada función a las operaciones necesarias.

---

## 5. Organización del repositorio

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
│       └── qa/
├── .gitignore
└── README.md
```

La estructura separa la configuración de red, almacenamiento, mensajería, funciones, API, permisos y monitoreo. Los paquetes de dependencias locales, planes y estados no deben publicarse en Git.

---

## 6. Configuración de red

La VPC utiliza el bloque `10.0.0.0/16` y subredes en dos zonas de disponibilidad.

| Subred | CIDR | Zona |
|---|---|---|
| Pública A | `10.0.1.0/24` | `us-east-1a` |
| Pública B | `10.0.2.0/24` | `us-east-1b` |
| Privada A | `10.0.11.0/24` | `us-east-1a` |
| Privada B | `10.0.12.0/24` | `us-east-1b` |

### Configuración aplicada en DEV y QA

| Elemento | Configuración |
|---|---|
| NAT Gateway | Deshabilitado (`enable_nat = false`) |
| Endpoint Interface SQS | Deshabilitado (`enable_sqs_endpoint = false`) |
| Endpoint Gateway S3 | Habilitado |
| Lambda Crop | Asociada a subredes privadas |
| Región | `us-east-1` |

El endpoint Gateway permite el acceso privado a S3 desde las subredes configuradas. La integración de SQS con Lambda es administrada por AWS, por lo que el consumo de eventos no requiere que la función inicie una conexión directa a SQS. Sin NAT, las funciones en subredes privadas no disponen de salida general a Internet.

**PROD:** sus parámetros se revisarán antes del despliegue. No se presupone que deba habilitarse NAT o un endpoint Interface sin evaluar necesidad, costo y restricciones de la cuenta.

---

## 7. Seguridad y validación

### 7.1. Almacenamiento

- Bloqueo de acceso público en S3.
- Cifrado del lado del servidor mediante AES-256.
- Versionado de objetos y reglas de ciclo de vida.
- Prefijos diferenciados para originales y resultados.

### 7.2. Permisos IAM

- **Lambda Upload:** autorización de escritura en `uploads/`.
- **Lambda Crop:** lectura de `uploads/`, escritura en `processed/` y permisos requeridos para la integración con SQS.
- Las credenciales de AWS se configuran localmente mediante el perfil `terraform-lab`; no deben incluirse en Git.

### 7.3. Restricciones de archivos

- Formatos contemplados: JPEG, PNG, GIF y WEBP.
- Límite declarado de tamaño: **10 MiB** (`10 485 760` bytes).
- Formulario firmado con vigencia de **300 segundos**.
- Comprobación del formato y tamaño durante el procesamiento.
- El límite del POST firmado se aplica al cuerpo multipart completo, incluidos sus campos; por ello, el archivo efectivo máximo puede ser ligeramente menor que 10 MiB.

### 7.4. Consideraciones adicionales

La API genera autorizaciones temporales, pero ello no sustituye controles de autenticación, cuotas o protección contra abuso para una exposición pública de producción. La configuración de seguridad y costos debe revisarse antes de desplegar PROD.

---

## 8. Requisitos previos

- Cuenta AWS autorizada y permisos IAM suficientes.
- AWS CLI configurado con el perfil `terraform-lab`.
- Terraform, Node.js, npm y Git instalados.
- PowerShell y Visual Studio Code, o herramientas equivalentes.
- Dependencias de las funciones Lambda preparadas y paquetes ZIP compatibles con su entorno de ejecución.

Comprobar las herramientas:

```powershell
terraform version
aws --version
node --version
npm --version
git --version
```

Comprobar la identidad AWS:

```powershell
aws sts get-caller-identity --profile terraform-lab
```

**Antes de aplicar cualquier plan:** verificar la cuenta, región, workspace y presupuesto disponible.

---

## 9. Operación con Terraform

Los comandos siguientes se ejecutan desde la carpeta `terraform/`.

### 9.1. Inicializar y validar

```powershell
terraform init
terraform fmt -recursive
terraform validate
```

### 9.2. Administrar workspaces

```powershell
terraform workspace list
terraform workspace show
```

Para crear un workspace que aún no exista:

```powershell
terraform workspace new qa
```

Para seleccionar uno existente:

```powershell
terraform workspace select qa
```

Los workspaces `dev`, `qa` y `prod` utilizan estados separados. **El workspace seleccionado y `-var=environment=...` deben coincidir.** La comprobación declarativa del proyecto no sustituye esta revisión manual.

En un workspace nuevo, `terraform state list` puede indicar `No state file was found!`; esto es normal antes del primer despliegue.

### 9.3. Generar y revisar un plan

Ejemplo para QA:

```powershell
terraform workspace select qa
terraform plan '-var=environment=qa' '-out=qa.tfplan'
terraform show -no-color qa.tfplan |
    Select-String 'aws_nat_gateway|aws_eip|aws_vpc_endpoint|Plan:'
```

Los planes `.tfplan` pueden contener información sensible y **no deben subirse al repositorio**.

### 9.4. Aplicar un plan aprobado

```powershell
terraform apply "qa.tfplan"
```

Este comando crea recursos reales de AWS y puede consumir créditos. Debe ejecutarse únicamente después de revisar el plan y autorizar el despliegue.

### 9.5. Consultar outputs

```powershell
terraform output
terraform output -raw api_url
terraform output -raw s3_bucket_name
```

Outputs definidos:

- `api_url`
- `s3_bucket_name`
- `sqs_queue_url`
- `sns_topic_arn`

---

## 10. Despliegue y validación de DEV

**Fecha de las pruebas:** 8 de octubre de 2026.  
**Workspace:** `dev`.  
**Región:** `us-east-1`.

### 10.1. Despliegue

```powershell
terraform workspace select dev
terraform plan '-var=environment=dev' '-out=dev.tfplan'
terraform apply "dev.tfplan"
```

**Resultado registrado:** 50 recursos creados, con NAT Gateway y endpoint Interface de SQS deshabilitados.

### 10.2. Pruebas realizadas

| ID | Prueba | Resultado DEV |
|---|---|---|
| CP-01 | Solicitud POST a API Gateway | Exitosa |
| CP-02 | Rechazo de tamaño declarado superior al límite | Exitoso |
| CP-03 | Subida de imagen JPEG mediante POST firmado | Exitosa |
| CP-04 | Almacenamiento de original en `uploads/` | Exitoso |
| CP-05 | Procesamiento S3 → SQS → Lambda Crop | Exitoso |
| CP-06 | Generación de PNG en `processed/` | Exitoso |
| CP-07 | Recorte circular visual | Exitoso |
| CP-08 | Registro de procesamiento en CloudWatch | Exitoso |
| CP-09 | Comprobación independiente de dimensiones exactas | No documentada |
| CP-10 | Envío de errores a DLQ y alerta SNS | No probado |
| CP-11 | Rendimiento bajo carga | No probado |

Se utilizó una imagen de prueba local denominada `test.jpeg`. El flujo produjo una imagen PNG circular, que se descargó y comparó visualmente con el original.

### 10.3. Evidencia de CloudWatch

En los registros de `icc-procesador-imagenes-dev-crop` se observó un mensaje `INFO Procesada` con la ruta del objeto original y la del resultado.

| Métrica observada | Valor |
|---|---|
| Runtime | Node.js 22 |
| Duración de la ejecución observada | 858,10 ms |
| Memoria configurada | 512 MB |
| Memoria máxima utilizada | 127 MB |
| Resultado | Procesamiento exitoso |

Los valores anteriores corresponden a **una ejecución concreta**; no representan pruebas de rendimiento ni un SLA.

### 10.4. Destrucción de DEV

Tras guardar las evidencias, se revisó un plan de **50 recursos por destruir** y se vació el bucket S3 versionado.

La primera ejecución de `terraform destroy` eliminó la mayor parte de la infraestructura, pero dejó pendientes dos roles IAM por falta del permiso:

```text
iam:ListInstanceProfilesForRole
```

Después de actualizar la política IAM utilizada por el usuario de Terraform, se reintentó la destrucción y se obtuvo:

```text
Plan: 0 to add, 0 to change, 2 to destroy.
Destroy complete! Resources: 2 destroyed.
```

**Resultado final:** cierre de DEV completado mediante Terraform. El mensaje final indica los **2 recursos restantes**; los demás ya se habían eliminado en el intento anterior. Para confirmar el estado vacío se puede ejecutar, con `dev` seleccionado:

```powershell
terraform state list
```

---

## 11. Despliegue y pruebas funcionales de QA

**Fecha de las pruebas:** 8 de octubre de 2026 (hora local registrada en las evidencias).  
**Workspace:** `qa`.  
**Región:** `us-east-1`.

### 11.1. Preparación y despliegue

Se seleccionó el workspace `qa`, que existía sin estado de infraestructura. Se verificó que:

```hcl
enable_nat          = false
enable_sqs_endpoint = false
```

Comandos utilizados:

```powershell
terraform workspace select qa
terraform validate
terraform plan '-var=environment=qa' '-out=qa.tfplan'
terraform apply "qa.tfplan"
```

**Resultado confirmado:**

```text
Plan: 50 to add, 0 to change, 0 to destroy.
Apply complete! Resources: 50 added, 0 changed, 0 destroyed.
```

Se crearon recursos propios de QA, entre ellos su API HTTP, bucket S3, colas SQS, funciones Lambda y componentes de monitoreo.

### 11.2. Prueba de API Gateway y Lambda Upload

Se envió una solicitud HTTP `POST /upload` con los datos de la imagen JPEG. La API respondió con:

- Mensaje de formulario generado.
- Clave única de almacenamiento en `uploads/`.
- URL de subida a S3.
- Campos del formulario POST firmado.
- Tiempo de expiración de 300 segundos.

**Resultado:** exitoso. No deben publicarse los campos temporales `Policy`, `X-Amz-Signature`, `X-Amz-Security-Token` ni credenciales en capturas o documentación.

### 11.3. Subida de JPEG a Amazon S3

La subida se realizó con `curl.exe` utilizando los campos devueltos por Lambda Upload.

**Respuesta recibida:**

```text
HTTP/1.1 204 No Content
```

La respuesta confirma que S3 aceptó la solicitud de subida.

### 11.4. Procesamiento de la imagen

La consulta al bucket S3 de QA mostró ambos objetos:

| Prefijo | Formato | Tamaño |
|---|---|---:|
| `uploads/` | JPEG | **102 069 bytes** |
| `processed/` | PNG | **4 525 bytes** |

La presencia del PNG correspondiente al JPEG subido confirma el procesamiento del flujo principal. La inspección visual de la forma circular y los registros de CloudWatch deben consignarse como verificaciones adicionales cuando estén documentadas en las capturas.

### 11.5. Matriz de QA

| ID | Caso de prueba | Estado QA |
|---|---|---|
| QA-01 | Despliegue mediante Terraform | **Exitoso** |
| QA-02 | Solicitud HTTP a `/upload` | **Exitoso** |
| QA-03 | Generación de POST firmado | **Exitoso** |
| QA-04 | Subida de JPEG a S3 (HTTP 204) | **Exitoso** |
| QA-05 | Creación del original en `uploads/` | **Exitoso** |
| QA-06 | Generación de PNG en `processed/` | **Exitoso** |
| QA-07 | Inspección visual del PNG circular | Captura realizada; resultado por consignar |
| QA-08 | Registros de Lambda Crop en CloudWatch | Captura realizada; resultado por consignar |
| QA-09 | Verificación independiente de 40 × 40 píxeles | Pendiente de registro |
| QA-10 | Prueba de DLQ, SNS y fallos forzados | Pendiente |
| QA-11 | Prueba de carga | Pendiente |

**Estado de cierre:** al último avance registrado, QA continúa desplegado. Su destrucción aún no se ha confirmado.

---

## 12. Procedimiento de prueba reproducible

Los ejemplos siguientes usan PowerShell desde `terraform/`, con el workspace del entorno que se desea probar ya seleccionado.

### 12.1. Obtener la API y localizar la imagen

```powershell
$apiUrl = terraform output -raw api_url
$imagePath = (Resolve-Path "..\test.jpeg").Path
Test-Path $imagePath
```

El último comando debe devolver `True`.

### 12.2. Solicitar formulario firmado

```powershell
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

Write-Host "Autorización recibida para:" $response.key
```

No imprimir ni publicar el objeto `$response.fields` completo.

### 12.3. Subir a S3

Ejecutar dentro de los 300 segundos de vigencia de la firma:

```powershell
$curlArgs = @("-sS", "-i", "-X", "POST")

foreach ($field in $response.fields.PSObject.Properties) {
    $curlArgs += @("-F", "$($field.Name)=$($field.Value)")
}

$curlArgs += @(
    "-F", "file=@$imagePath;type=image/jpeg",
    $response.uploadUrl
)

& curl.exe @curlArgs
```

Se espera una respuesta de S3 como `HTTP/1.1 204 No Content` o `201 Created`, según la configuración del formulario.

### 12.4. Comprobar originales y resultados

```powershell
$bucket = terraform output -raw s3_bucket_name
aws s3 ls "s3://$bucket/" --recursive --profile terraform-lab
```

### 12.5. Descargar el resultado

```powershell
$outputKey = $response.key -replace '^uploads/', 'processed/'
$outputKey = $outputKey -replace '\.[^.]+$', '.png'

aws s3 cp "s3://$bucket/$outputKey" ".\resultado-qa.png" `
    --profile terraform-lab
```

Abrir `resultado-qa.png` en VS Code para inspeccionar el resultado. Para comprobar dimensiones exactas, utilizar una herramienta de inspección de imágenes y registrar el resultado.

### 12.6. Consultar CloudWatch

Para QA:

```powershell
aws logs tail "/aws/lambda/icc-procesador-imagenes-qa-crop" `
    --since 30m `
    --profile terraform-lab
```

Para DEV (solo mientras el entorno exista y conserve sus logs):

```powershell
aws logs tail "/aws/lambda/icc-procesador-imagenes-dev-crop" `
    --since 1h `
    --profile terraform-lab
```

Buscar mensajes de procesamiento, excepciones, duración y memoria utilizada.

---

## 13. Evidencias del laboratorio

Las evidencias se organizan por entorno. Antes de publicar capturas, **ocultar firmas temporales, tokens, credenciales y cualquier dato sensible**.

### 13.1. DEV

Ruta: `docs/evidencias/dev/`.

| Evidencia sugerida | Contenido |
|---|---|
| `01-terraform-apply.png` | Despliegue DEV |
| `02-terraform-outputs.png` | Outputs de Terraform |
| `03-api-upload.png` | Respuesta de la API sin credenciales temporales |
| `04-validacion-10mb.png` | Rechazo de tamaño declarado superior al límite |
| `05-s3-objetos.png` | Original y PNG en S3 |
| `06-comparacion-imagenes.png` | Comparación visual |
| `07-cloudwatch-crop.png` | Registros de Lambda Crop |
| `08-plan-destroy-dev.png` | Plan de destrucción |
| `09-destroy-complete.png` | Finalización del cierre DEV |

Los nombres son una **convención recomendada**: comprobar los nombres reales antes de crear enlaces en GitHub.

### 13.2. QA

Ruta: `docs/evidencias/qa/`.

| Evidencia sugerida | Contenido |
|---|---|
| `01-terraform-apply.png` | `Apply complete! Resources: 50 added` |
| `02-api-upload.png` | Formulario generado por API Gateway / Lambda Upload, con campos sensibles ocultos |
| `03-s3-archivos.png` | JPEG original y PNG procesado |
| `04-resultado-qa.png` | Imagen circular descargada |
| `05-cloudwatch.png` | Registros de Lambda Crop, si fueron verificados |
| `06-plan-destroy-qa.png` | Plan de destrucción, pendiente |
| `07-destroy-complete-qa.png` | Destrucción completa, pendiente |

---

## 14. Monitoreo y manejo de errores

### CloudWatch Logs

Los grupos de logs de Lambda permiten consultar invocaciones, excepciones, duración y consumo de memoria. La retención configurada es de **14 días**.

### Cola principal de SQS

Recibe notificaciones de S3 y entrega lotes a Lambda Crop. La función informa fallos individuales del lote mediante la respuesta `batchItemFailures`, evitando marcar como fallidos todos los elementos cuando solo algunos fallan.

### Dead Letter Queue (DLQ)

Se configura una cola para mensajes que exceden el máximo de intentos de recepción. Su existencia no demuestra que se hayan probado fallos forzados.

### CloudWatch Alarm y SNS

Una alarma observa mensajes en la DLQ y utiliza un tema SNS como destino. La entrega de alertas depende de una suscripción válida y confirmada.

---

## 15. Atributos de calidad

| Atributo | Implementación | Alcance de validación |
|---|---|---|
| Disponibilidad | Servicios administrados y distribución de subredes entre dos zonas | No se ha probado conmutación por fallos |
| Escalabilidad | Lambda bajo demanda y cola SQS | Sin prueba de carga |
| Seguridad | IAM, bucket privado, cifrado y firmas temporales | Configuración implementada; requiere revisión adicional para PROD |
| Mantenibilidad | Terraform organizado por responsabilidades | Despliegue reproducido en DEV y QA |
| Observabilidad | CloudWatch Logs y alarmas | Logs comprobados en DEV |
| Tolerancia a fallos | Reintentos de SQS y DLQ | Configurada, sin prueba forzada |
| Recuperación | Versionado S3 y recreación mediante Terraform | DEV recreable a partir de código; los datos borrados no se recuperan automáticamente |
| Portabilidad entre entornos | Workspaces y variables `environment` | Despliegues DEV y QA realizados |

---

## 16. Costos y restricciones

La infraestructura utiliza servicios de AWS que pueden consumir créditos o generar cargos. **No se debe asumir que todos los recursos son gratuitos**.

Medidas aplicadas en DEV y QA:

- NAT Gateways deshabilitados.
- Endpoint Interface de SQS deshabilitado.
- Uso del endpoint Gateway de S3.
- Despliegue secuencial de entornos en lugar de mantenerlos todos activos.
- Destrucción de DEV tras finalizar las pruebas.

Buenas prácticas operativas:

1. Revisar el plan antes de cada `apply`.
2. Consultar los créditos y el consumo en AWS Billing.
3. Evitar mantener entornos de laboratorio activos sin necesidad.
4. Guardar las evidencias antes de eliminar recursos.
5. Confirmar que el plan de PROD sea viable antes de desplegar.

La eliminación de infraestructura detiene el uso futuro de los recursos efectivamente destruidos, pero no necesariamente elimina cargos o consumo ya acumulados.

---

## 17. Destrucción controlada de infraestructura

**Advertencia:** los siguientes comandos pueden eliminar recursos reales y datos de forma irreversible. Deben utilizarse únicamente después de guardar evidencias, revisar el workspace y autorizar la eliminación.

### 17.1. Seleccionar el entorno

Ejemplo QA:

```powershell
terraform workspace select qa
terraform workspace show
```

### 17.2. Revisar qué se eliminaría

```powershell
terraform plan '-destroy' '-var=environment=qa'
```

### 17.3. Revisar el bucket S3 versionado

```powershell
$bucket = terraform output -raw s3_bucket_name
Write-Host "Bucket que se revisará: $bucket"

aws s3api list-object-versions `
    --bucket $bucket `
    --query "{Versiones: Versions[].{Archivo:Key,VersionId:VersionId},Marcadores: DeleteMarkers[].{Archivo:Key,VersionId:VersionId}}" `
    --output json `
    --profile terraform-lab
```

Antes de eliminar versiones o marcadores, verificar que el bucket corresponde a QA y que los objetos de prueba pueden perderse definitivamente. Un simple `aws s3 rm` no garantiza el vaciado de un bucket versionado.

### 17.4. Ejecutar la destrucción

**Solo después de vaciar correctamente el bucket y autorizar el cierre:**

```powershell
terraform destroy '-var=environment=qa'
```

Terraform solicitará escribir `yes`. Al finalizar correctamente, mostrará `Destroy complete!`.

### 17.5. Verificar el estado

```powershell
terraform workspace show
terraform state list
```

El estado del workspace debería quedar sin recursos administrados. Si la destrucción falla parcialmente, **no borrar los archivos de estado**: corregir el error y volver a planificar la eliminación de los recursos restantes.

### 17.6. Lección aprendida en DEV

Durante el cierre de DEV, Terraform necesitó el permiso `iam:ListInstanceProfilesForRole` para eliminar los roles de Lambda. La política IAM se ajustó y la segunda ejecución completó los dos recursos pendientes. Este permiso debe conservarse para las futuras operaciones de cierre de QA y PROD, con el alcance autorizado correspondiente.

---

## 18. Plan para PROD

El workspace `prod` ya existe, pero **no se ha documentado ningún despliegue de infraestructura PROD**.

Antes de desplegar:

1. Confirmar la cuenta y los permisos AWS.
2. Revisar si la configuración de red y seguridad es adecuada para producción.
3. Evaluar los costos de NAT, endpoints y servicios complementarios.
4. Verificar los controles de acceso a la API y los límites de solicitudes.
5. Preparar y revisar el plan de Terraform.
6. Obtener autorización para crear recursos reales.

Comandos de planificación, **sin desplegar todavía**:

```powershell
terraform workspace select prod
terraform workspace show
terraform validate
terraform plan '-var=environment=prod' '-out=prod.tfplan'
```

El despliegue de PROD y sus pruebas se incorporarán a este README cuando se hayan realizado y comprobado.

---

## 19. Control de versiones y publicación

El proyecto utiliza Git y GitHub para documentar la evolución del código y las evidencias.

Ejemplo de publicación de README y evidencias QA desde `terraform/`:

```powershell
git status --short
git add ../README.md
git add ../docs/evidencias/qa/
git diff --cached --stat
git commit -m "docs: actualizar README y evidencias de QA"
git push origin main
```

Antes del commit, comprobar que no se incluyen secretos, firmas S3 ni archivos temporales.

**No publicar:**

- Credenciales o tokens AWS.
- Archivos `*.tfstate`, `*.tfstate.backup` o estados de workspaces.
- Archivos `*.tfplan`.
- Directorios `.terraform/` y `node_modules/`.
- Paquetes ZIP de despliegue generados localmente.
- Respuestas completas de formularios firmados.
- Imágenes de prueba innecesarias o con información sensible.

Consultar el historial real:

```powershell
git log --oneline
```

---

## 20. Conclusiones y próximos pasos

La arquitectura se implementó mediante Terraform y **se reprodujo con éxito en dos entornos independientes: DEV y QA**.

En DEV se validó el flujo principal de subida, almacenamiento y procesamiento de imágenes, así como la observabilidad mediante CloudWatch. Posteriormente, se realizó la destrucción controlada de la infraestructura. Durante ese proceso se identificó y resolvió un permiso IAM faltante, lo que permitió finalizar el cierre del entorno.

En QA se desplegaron **50 recursos** y se comprobó la respuesta de API Gateway, la generación de un POST firmado, la subida exitosa de una imagen JPEG a S3 y la creación del archivo PNG procesado. Las capturas correspondientes se recopilaron para el informe.

El proyecto demuestra la utilidad de IaC para reproducir infraestructura, separar entornos, automatizar el procesamiento por eventos y mantener evidencia técnica de las operaciones realizadas.

### Próximas actividades

1. Completar la verificación y organización de evidencias de QA, incluida CloudWatch y las dimensiones exactas si se requiere.
2. Documentar y ejecutar la destrucción controlada de QA después de vaciar el bucket S3 versionado.
3. Revisar costos, permisos y configuración antes de decidir el despliegue de PROD.
4. Ejecutar las pruebas de PROD únicamente si el despliegue es viable y autorizado.
5. Consolidar las capturas, resultados, limitaciones y conclusiones en el informe final.

---
