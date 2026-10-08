variable "aws_region" {
  description = "Region de AWS"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de trabajo (3): dev, qa o prod"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El entorno debe ser dev, qa o prod."
  }

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "El entorno debe ser dev, qa o prod."
  }
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "icc-procesador-imagenes"
}

variable "alert_email" {
  description = "Correo para recibir alertas SNS"
  type        = string
  default     = ""
}

variable "enable_nat" {
  description = "Habilitar los NAT Gateway"
  type        = bool
  default     = false
}

variable "enable_sqs_endpoint" {
  description = "Habilitar el endpoint privado de SQS"
  type        = bool
  default     = false
}