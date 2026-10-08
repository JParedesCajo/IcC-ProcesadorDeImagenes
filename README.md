# Procesador de Imágenes en AWS con Terraform

## 1. Descripción del proyecto

Este proyecto implementa una arquitectura de procesamiento automático de imágenes en Amazon Web Services (AWS), utilizando **Terraform como herramienta de Infraestructura como Código (IaC)**.

La aplicación permite que un usuario solicite una autorización para subir una imagen, almacene el archivo original en Amazon S3 y obtenga automáticamente una versión procesada en formato PNG, recortada de forma circular y con dimensiones de **40 × 40 píxeles**.

La solución utiliza servicios administrados de AWS y un mecanismo de procesamiento asíncrono mediante Amazon SQS y AWS Lambda.

**Repositorio:** https://github.com/JParedesCajo/IcC-ProcesadorDeImagenes

**Región de despliegue:** `us-east-1`

**Entornos contemplados:** DEV, QA y PROD.

**Estado actual:** entorno DEV desplegado y prueba funcional principal completada exitosamente.

---

## 2. Objetivos

### Objetivo general

Diseñar, implementar y validar una infraestructura de procesamiento de imágenes en AWS mediante Terraform, aplicando principios de automatización, seguridad, modularidad y monitoreo.

### Objetivos específicos

- Definir los recursos de infraestructura mediante archivos Terraform.
- Separar los entornos DEV, QA y PROD mediante Terraform Workspaces.
- Implementar una API HTTP para solicitar autorizaciones de subida.
- Almacenar imágenes originales y procesadas en Amazon S3.
- Utilizar Amazon SQS para desacoplar la recepción y el procesamiento.
- Procesar imágenes mediante AWS Lambda y la biblioteca Sharp.
- Implementar registros, métricas y alertas con CloudWatch y SNS.
- Aplicar controles de seguridad y permisos IAM.
- Validar el funcionamiento mediante pruebas reales.
- Permitir la creación y eliminación controlada de la infraestructura.

---

## 3. Tecnologías utilizadas

| Tecnología | Función |
|---|---|
| Terraform | Definición y despliegue de infraestructura |
| AWS | Plataforma de servicios en la nube |
| Amazon VPC | Red virtual de la arquitectura |
| Amazon S3 | Almacenamiento de imágenes |
| Amazon API Gateway | Exposición de la API HTTP |
| AWS Lambda | Ejecución del procesamiento |
| Amazon SQS | Comunicación asíncrona entre servicios |
| Amazon CloudWatch | Registros, métricas y alarmas |
| Amazon SNS | Notificaciones de alertas |
| AWS IAM | Gestión de roles y permisos |
| Node.js 22 | Entorno de ejecución de las funciones |
| Sharp | Procesamiento y transformación de imágenes |
| AWS CLI | Administración y validación desde terminal |
| Git y GitHub | Control de versiones |

---

## 4. Arquitectura de la solución

### 4.1. Flujo general

La arquitectura sigue el siguiente recorrido:

```text
                  USUARIO / CLIENTE
                         |
                         v
                  API GATEWAY HTTP
                    POST /upload
                         |
                         v
                    LAMBDA UPLOAD
               Validación y formulario
                    POST firmado
                         |
                         v
                    AMAZON S3
                     uploads/
                         |
                  Notificación S3
                         |
                         v
                    AMAZON SQS
                  Cola de mensajes
                         |
                         v
                     LAMBDA CROP
                  Node.js + Sharp
                         |
                         v
                    AMAZON S3
                    processed/
                  PNG circular 40x40
```

La solución incluye adicionalmente:

- Una cola de mensajes fallidos (DLQ).
- Registros y métricas en Amazon CloudWatch.
- Una alarma asociada a la DLQ.
- Un tema Amazon SNS para notificaciones.
- Una VPC con subredes públicas y privadas.
- Un endpoint Gateway de S3 para acceso privado desde la VPC.

### 4.2. Descripción de los componentes

**Amazon API Gateway**

Expone el endpoint HTTP `POST /upload`, que permite solicitar una autorización temporal para subir una imagen.

**Lambda Upload**

Recibe los datos de la imagen, valida el formato y el tamaño declarado, y genera un formulario POST firmado de Amazon S3.

**Amazon S3**

Almacena los archivos en dos prefijos:

- `uploads/`: imágenes originales.
- `processed/`: imágenes transformadas.

El bucket utiliza controles de acceso público, cifrado del lado del servidor y versionado.

**Amazon SQS**

Recibe las notificaciones generadas cuando se almacena una imagen en el prefijo `uploads/`. Permite desacoplar la subida de imágenes del procesamiento.

**Lambda Crop**

Obtiene las imágenes originales, utiliza Sharp para redimensionarlas y aplicar un recorte circular, y guarda el resultado como PNG.

**Amazon CloudWatch**

Centraliza los registros de las funciones Lambda y permite observar la ejecución, duración, memoria utilizada y posibles errores.

**Amazon SNS**

Se utiliza como destino de notificaciones para la alarma relacionada con mensajes acumulados en la DLQ.

**Amazon VPC**

Proporciona una red aislada con subredes públicas y privadas distribuidas entre dos zonas de disponibilidad.

**IAM**

Define los permisos necesarios para que cada función acceda únicamente a los recursos requeridos.

---

## 5. Organización del proyecto

```text
IcC-ProcesadorDeImagenes/
|
|-- terraform/
|   |-- environments/
|   |
|   |-- lambda/
|   |   |-- upload/
|   |   |   |-- index.js
|   |   |   |-- package.json
|   |   |   `-- package-lock.json
|   |   |
|   |   `-- crop/
|   |       |-- index.js
|   |       |-- package.json
|   |       `-- package-lock.json
|   |
|   |-- providers.tf
|   |-- variables.tf
|   |-- main.tf
|   |-- network.tf
|   |-- nat.tf
|   |-- endpoints.tf
|   |-- storage.tf
|   |-- queues.tf
|   |-- iam.tf
|   |-- lambda.tf
|   |-- api.tf
|   |-- monitoring.tf
|   `-- outputs.tf
|
|-- docs/
|   `-- evidencias/
|       `-- dev/
|
|-- .gitignore
`-- README.md
```

Los archivos `.tf` separan la infraestructura por responsabilidades para facilitar su mantenimiento.

Los directorios `node_modules/`, `.terraform/`, los archivos de estado y los planes de Terraform no deben incluirse en el repositorio.

---

## 6. Configuración de la red

La arquitectura utiliza una VPC con el rango:

`10.0.0.0/16`

Se contemplan subredes públicas y privadas distribuidas en dos zonas de disponibilidad de AWS.

| Subred | CIDR | Zona |
|---|---|---|
| Pública A | `10.0.1.0/24` | `us-east-1a` |
| Pública B | `10.0.2.0/24` | `us-east-1b` |
| Privada A | `10.0.11.0/24` | `us-east-1a` |
| Privada B | `10.0.12.0/24` | `us-east-1b` |

### Configuración de DEV

Para reducir el consumo de créditos durante las pruebas, el entorno DEV utiliza:

- NAT Gateway deshabilitado.
- Endpoint Interface de SQS deshabilitado.
- Endpoint Gateway de S3 habilitado.

Las funciones Lambda Crop pueden acceder a S3 mediante el endpoint Gateway asociado a las tablas de rutas privadas.

La integración de eventos de SQS con Lambda es administrada por AWS y no requiere que Lambda establezca directamente una conexión a SQS para recibir los lotes de mensajes.

La ausencia de NAT limita las conexiones salientes generales desde las subredes privadas. Cualquier dependencia futura de servicios externos deberá considerar esta restricción.

---

## 7. Seguridad

La arquitectura incorpora las siguientes medidas:

### 7.1. Almacenamiento privado

El bucket S3 tiene bloqueado el acceso público y utiliza cifrado del lado del servidor mediante AES-256.

### 7.2. Permisos IAM

Se emplean roles específicos para las funciones Lambda.

**Lambda Upload:**

Permisos de escritura sobre el prefijo `uploads/` del bucket.

**Lambda Crop:**

Permisos para leer objetos de `uploads/`, escribir resultados en `processed/` y trabajar con los mensajes de la cola SQS.

### 7.3. Validación de archivos

La aplicación contempla:

- Formatos JPEG, PNG, GIF y WEBP.
- Límite de tamaño declarado de 10 MB.
- Validación del archivo durante el procesamiento.
- Autorizaciones temporales para subir archivos a S3.

El formulario firmado utiliza una condición de tamaño de contenido. Al tratarse de una solicitud multipart, el tamaño total incluye también los campos del formulario.

### 7.4. Control de acceso a la red

Lambda Crop utiliza subredes privadas de la VPC.

El acceso a S3 se realiza mediante un endpoint Gateway.

### 7.5. Protección de credenciales

Las credenciales AWS no se almacenan en el código fuente. Se utiliza un perfil local de AWS CLI.

Los archivos de estado de Terraform deben protegerse porque pueden contener información sensible de la infraestructura.

---

## 8. Requisitos previos

Para trabajar con el proyecto se requiere:

- Una cuenta AWS con permisos adecuados.
- AWS CLI configurado.
- Terraform instalado.
- Node.js y npm.
- Git.
- Visual Studio Code o un editor equivalente.
- PowerShell, para seguir los comandos de este documento en Windows.

### Verificar herramientas

```powershell
terraform version
aws --version
node --version
npm --version
git --version
```

### Verificar identidad AWS

```powershell
aws sts get-caller-identity --profile terraform-lab
```

Antes de desplegar, debe confirmarse que la cuenta y el usuario corresponden al entorno autorizado para las pruebas.

---

## 9. Configuración de Terraform

El proveedor AWS se configura en `providers.tf`.

La región utilizada es `us-east-1` y el perfil local de AWS es `terraform-lab`.

### Inicialización

Desde la carpeta `terraform`:

```powershell
terraform init
```

### Validación

```powershell
terraform fmt -recursive
terraform validate
```

### Entornos mediante Workspaces

Los entornos previstos son:

- `dev`: desarrollo y pruebas iniciales.
- `qa`: pruebas de calidad.
- `prod`: entorno de producción.

Crear el workspace DEV, si todavía no existe:

```powershell
terraform workspace new dev
```

Seleccionarlo:

```powershell
terraform workspace select dev
```

Confirmar el workspace:

```powershell
terraform workspace show
```

El resultado esperado para el entorno de desarrollo es `dev`.

**Importante:** antes de ejecutar un despliegue, el valor de la variable `environment` debe corresponder al workspace seleccionado.

---

## 10. Despliegue del entorno DEV

### 10.1. Generar el plan

```powershell
terraform plan '-var=environment=dev' '-out=dev.tfplan'
```

El plan debe revisarse antes de aplicar cambios.

Durante la preparación del entorno DEV se obtuvo un plan de 50 recursos por crear, sin NAT Gateway ni endpoint Interface de SQS.

### 10.2. Aplicar la infraestructura

```powershell
terraform apply "dev.tfplan"
```

Este comando crea o modifica recursos reales de AWS y puede consumir créditos.

### 10.3. Consultar recursos

```powershell
terraform state list
```

### 10.4. Consultar outputs

```powershell
terraform output
```

Los outputs configurados incluyen:

- `api_url`
- `s3_bucket_name`
- `sqs_queue_url`
- `sns_topic_arn`

Para obtener un valor específico:

```powershell
terraform output -raw api_url
```

---

## 11. Despliegue de QA y PROD

Los workspaces permiten mantener estados independientes para distintos entornos.

### QA

```powershell
terraform workspace select qa
terraform plan '-var=environment=qa' '-out=qa.tfplan'
```

### PROD

```powershell
terraform workspace select prod
terraform plan '-var=environment=prod' '-out=prod.tfplan'
```

Si un workspace todavía no existe, debe crearse antes de seleccionarlo.

**Estado:** QA y PROD se encuentran contemplados en el diseño, pero no se documentan aquí como desplegados o validados.

Antes de aplicar cualquiera de estos entornos se deben revisar los costos, las variables y los recursos que se crearán.

---

## 12. Pruebas funcionales realizadas en DEV

**Fecha:** 8 de octubre de 2026.

**Entorno:** DEV.

**Región:** `us-east-1`.

**Resultado general:** prueba funcional principal exitosa.

### 12.1. Prueba de API Gateway

Se realizó una solicitud HTTP POST al endpoint `/upload`, enviando información sobre el tipo de archivo y su tamaño.

La API respondió con los datos necesarios para realizar una subida autorizada a Amazon S3.

**Resultado:** exitoso.

### 12.2. Validación de tamaño

Se envió una solicitud que declaraba una imagen superior al límite de 10 MB.

La API rechazó la solicitud.

**Resultado:** exitoso para la validación del tamaño declarado.

### 12.3. Subida de imagen JPEG

Se utilizó una imagen de prueba llamada `test.jpeg`.

El cliente solicitó un formulario firmado y realizó una subida HTTP POST a Amazon S3.

El archivo se almacenó correctamente bajo el prefijo `uploads/`.

**Resultado:** exitoso.

### 12.4. Procesamiento asíncrono

La notificación del objeto almacenado activó el flujo de procesamiento configurado mediante SQS y Lambda Crop.

Se generó el archivo correspondiente en el prefijo `processed/`.

**Resultado:** exitoso.

### 12.5. Recorte circular

Se descargó el archivo procesado y se comparó visualmente con la imagen original.

La salida presentó un recorte circular de la fotografía.

La configuración de la función establece dimensiones de 40 × 40 píxeles.

**Resultado:** recorte visual exitoso. La verificación independiente de las dimensiones exactas puede registrarse como evidencia adicional.

### 12.6. Monitoreo en CloudWatch

Se consultaron los registros de la función:

`icc-procesador-imagenes-dev-crop`

Los registros incluyeron un mensaje `INFO Procesada`, confirmando la transformación del objeto original y la creación del PNG.

No se observaron errores en la ejecución de procesamiento registrada.

**Resultado:** exitoso.

---

## 13. Matriz de pruebas

| ID | Caso de prueba | Resultado esperado | Estado |
|---|---|---|---|
| CP-01 | Solicitud a API Gateway | Generar formulario firmado | Exitoso |
| CP-02 | Solicitud mayor de 10 MB | Rechazar tamaño declarado | Exitoso |
| CP-03 | Subida de imagen JPEG | Almacenar en `uploads/` | Exitoso |
| CP-04 | Procesamiento con SQS y Lambda | Generar archivo en `processed/` | Exitoso |
| CP-05 | Recorte circular | Producir imagen circular | Exitoso visualmente |
| CP-06 | Registros de CloudWatch | Registrar la ejecución | Exitoso |
| CP-07 | Dimensiones exactas | Confirmar 40 × 40 píxeles | Pendiente de comprobación independiente |
| CP-08 | Envío a DLQ ante errores | Retener mensajes fallidos | Pendiente |
| CP-09 | Alerta SNS | Notificar condición de alarma | Pendiente |
| CP-10 | Rendimiento bajo carga | Cumplir objetivos definidos | Pendiente |

---

## 14. Resultados técnicos obtenidos

### Imagen original

- Nombre local: `test.jpeg`.
- Formato almacenado: JPEG.
- Tamaño almacenado: **120 669 bytes**.
- Prefijo: `uploads/`.

### Imagen procesada

- Formato: PNG.
- Tamaño almacenado: **4 525 bytes**.
- Prefijo: `processed/`.
- Recorte: circular.

### Ejecución de Lambda Crop

| Métrica | Resultado |
|---|---|
| Runtime | Node.js 22 |
| Duración | 858,10 ms |
| Memoria configurada | 512 MB |
| Memoria máxima utilizada | 127 MB |
| Estado de procesamiento observado | Exitoso |

Los valores corresponden a una ejecución específica de la función. No representan una medición de rendimiento bajo carga ni garantizan tiempos de respuesta para futuras solicitudes.

---

## 15. Evidencias del entorno DEV

Las capturas se organizan en:

`docs/evidencias/dev/`

| Archivo | Evidencia |
|---|---|
| `01-terraform-apply.png` | Despliegue de Terraform |
| `02-terraform-outputs.png` | Outputs de los recursos |
| `03-api-upload.png` | Respuesta de API Gateway |
| `04-validacion-10mb.png` | Rechazo de tamaño superior al límite |
| `05-s3-objetos.png` | Archivos originales y procesados en S3 |
| `06-comparacion-imagenes.png` | Comparación de imagen original y PNG circular |
| `07-cloudwatch-crop.png` | Registros de procesamiento en CloudWatch |

Los nombres anteriores corresponden a la organización prevista. Deben agregarse los archivos de captura reales para completar esta sección.

### Comprobación de los objetos S3

```powershell
$bucket = terraform output -raw s3_bucket_name

aws s3 ls "s3://$bucket/" --recursive --profile terraform-lab
```

### Consulta de registros

```powershell
aws logs tail "/aws/lambda/icc-procesador-imagenes-dev-crop" `
    --since 1h `
    --profile terraform-lab
```

---

## 16. Monitoreo y manejo de errores

La arquitectura incorpora mecanismos para observar errores y gestionar mensajes que no pueden procesarse correctamente.

### CloudWatch Logs

Permite consultar los registros de Lambda Upload y Lambda Crop.

La retención configurada para los grupos de registros es de 14 días.

### Amazon SQS

La cola principal recibe las notificaciones de S3 y entrega los mensajes a Lambda Crop.

La función informa los elementos fallidos de un lote para permitir su tratamiento individual.

### Dead Letter Queue (DLQ)

Se dispone de una cola de mensajes fallidos.

La configuración contempla que un mensaje sea redirigido a la DLQ después de superar el número permitido de intentos de recepción.

### CloudWatch Alarm y SNS

Se configura una alarma para detectar mensajes en la DLQ.

El tema SNS puede utilizarse para enviar notificaciones cuando la alarma se activa, siempre que exista una suscripción configurada y confirmada.

**Nota:** la existencia de estos mecanismos no implica que se hayan ejecutado pruebas de fallo o entrega de alertas. Esas pruebas permanecen pendientes.

---

## 17. Atributos de calidad

### Disponibilidad

Se utilizan servicios administrados de AWS y una distribución de subredes entre dos zonas de disponibilidad.

Esto contribuye al diseño de disponibilidad, aunque no sustituye una prueba de recuperación ante fallos.

### Escalabilidad

Lambda permite ejecutar procesamiento bajo demanda y SQS ayuda a desacoplar la llegada de eventos del procesamiento.

### Seguridad

Se aplican roles IAM, almacenamiento privado, cifrado y acceso controlado a los recursos.

### Mantenibilidad

La infraestructura se divide en archivos Terraform según su responsabilidad.

### Observabilidad

CloudWatch proporciona registros y métricas de ejecución.

### Tolerancia a fallos

SQS permite reintentos de mensajes y la DLQ permite conservar mensajes que no se procesan correctamente después de los intentos configurados.

### Recuperación

El versionado de S3 contribuye a conservar versiones de los objetos, sujeto a las reglas de ciclo de vida y a la configuración aplicada.

---

## 18. Consideraciones de costos

El proyecto utiliza una cuenta AWS con créditos disponibles.

Los recursos desplegados pueden consumir créditos o generar cargos según el tipo de cuenta, los servicios utilizados y el tiempo de uso.

Para DEV se deshabilitaron componentes opcionales de red que podían incrementar el costo:

- NAT Gateway.
- Endpoint Interface de SQS.

Se recomienda:

- Desplegar únicamente los entornos necesarios.
- Revisar los planes antes de ejecutar `terraform apply`.
- Consultar AWS Billing y los créditos restantes.
- Evitar mantener recursos de prueba activos sin necesidad.
- Eliminar los recursos al finalizar las pruebas.

La disponibilidad de créditos no garantiza que todos los recursos estén incluidos en una capa gratuita.

---

## 19. Limpieza de infraestructura

Terraform permite eliminar los recursos administrados cuando dejan de ser necesarios.

Antes de ejecutar la destrucción:

1. Confirmar el workspace seleccionado.
2. Guardar las evidencias necesarias.
3. Verificar que no existan datos que deban conservarse.
4. Revisar los recursos que Terraform eliminará.
5. Considerar que el bucket S3 utiliza versionado y puede contener objetos y versiones anteriores.

### Seleccionar DEV

```powershell
terraform workspace select dev
```

### Revisar la destrucción

```powershell
terraform plan '-destroy' '-var=environment=dev'
```

### Ejecutar la destrucción

```powershell
terraform destroy '-var=environment=dev'
```

**Advertencia:** el comando anterior elimina recursos reales de AWS y requiere confirmación. Debe ejecutarse únicamente cuando se haya autorizado el cierre del entorno.

Si el bucket S3 contiene objetos o versiones, la eliminación podría fallar. En ese caso se debe revisar y vaciar el bucket de manera controlada antes de completar la destrucción.

La ejecución de `terraform destroy` todavía no se documenta como completada.

---

## 20. Control de versiones

El proyecto utiliza Git y GitHub para mantener un historial de cambios.

Las modificaciones se organizan por avances de implementación, configuración, pruebas y documentación.

Ejemplos de mensajes de commit:

```text
feat: configurar red y subredes AWS
feat: implementar almacenamiento S3
feat: configurar colas SQS y DLQ
feat: implementar funciones Lambda
feat: integrar API Gateway
feat: configurar monitoreo CloudWatch y SNS
docs: documentar pruebas funcionales de DEV
```

Estos mensajes son ejemplos de organización; el historial real puede consultarse mediante:

```powershell
git log --oneline
```

### Archivos que no deben publicarse

- Credenciales AWS.
- Archivos `.tfstate` y copias de respaldo.
- Planes `.tfplan`.
- Directorios `.terraform/`.
- Directorios `node_modules/`.
- Paquetes ZIP generados para despliegue.
- Archivos locales de prueba innecesarios.
- Archivos con información sensible.

---

## 21. Estado de los entornos

| Entorno | Estado | Observaciones |
|---|---|---|
| DEV | Desplegado y probado | Flujo principal exitoso |
| QA | Pendiente de validación | No se registra despliegue confirmado |
| PROD | Pendiente de validación | No se registra despliegue confirmado |

---

## 22. Conclusiones

Se implementó una infraestructura AWS mediante Terraform capaz de recibir y procesar imágenes de manera asíncrona.

Durante las pruebas de DEV se confirmó el funcionamiento de API Gateway, Lambda Upload, Amazon S3, Amazon SQS, Lambda Crop y Amazon CloudWatch dentro del flujo principal de procesamiento.

La imagen JPEG utilizada en la prueba fue almacenada correctamente y se generó una versión PNG con recorte circular.

La arquitectura demuestra el uso práctico de Infraestructura como Código, servicios administrados, procesamiento por eventos, controles de seguridad y observabilidad.

Como trabajo pendiente se consideran las pruebas de recuperación ante fallos, validación de la DLQ, notificaciones SNS, rendimiento bajo carga y despliegues de QA y PROD.

El siguiente paso operativo consiste en completar las evidencias, revisar el repositorio y realizar la destrucción controlada del entorno DEV cuando finalicen las pruebas.