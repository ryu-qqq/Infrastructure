# AWS 리전
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# 환경
variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# 서비스 이름
variable "service_name" {
  description = "서비스 이름 (리소스 명명에 사용)"
  type        = string
  default     = "web-app"
}

# VPC ID
variable "vpc_id" {
  description = "ECS 서비스가 배포될 VPC ID"
  type        = string
}

# 컨테이너 설정
variable "container_image" {
  description = "컨테이너 이미지 (예: nginx:latest 또는 ECR URL)"
  type        = string
  default     = "nginx:latest"
}

variable "container_port" {
  description = "컨테이너가 수신 대기하는 포트"
  type        = number
  default     = 80
}

# Task 리소스 설정
variable "task_cpu" {
  description = "Task CPU 유닛 (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Task 메모리 (MiB)"
  type        = number
  default     = 512
}

# 서비스 설정
variable "desired_count" {
  description = "실행할 Task 개수"
  type        = number
  default     = 2
}

# 헬스체크 설정
variable "health_check_path" {
  description = "헬스체크 경로"
  type        = string
  default     = "/health"
}

# ACM 인증서 (HTTPS용)
variable "certificate_arn" {
  description = "ACM 인증서 ARN (HTTPS 리스너용, null이면 HTTPS 리스너 생성 안 함)"
  type        = string
  default     = null
}

# 환경 변수
variable "environment_variables" {
  description = "컨테이너에 전달할 환경 변수"
  type = list(object({
    name  = string
    value = string
  }))
  default = [
    {
      name  = "APP_ENV"
      value = "development"
    },
    {
      name  = "LOG_LEVEL"
      value = "info"
    }
  ]
}

# Auto Scaling 설정
variable "enable_autoscaling" {
  description = "Auto Scaling 활성화 여부"
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Auto Scaling 최소 Task 수"
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Auto Scaling 최대 Task 수"
  type        = number
  default     = 10
}

variable "autoscaling_target_cpu" {
  description = "Auto Scaling 목표 CPU 사용률 (%)"
  type        = number
  default     = 70
}

# ECS Exec 설정
variable "enable_ecs_exec" {
  description = "ECS Exec 활성화 여부 (컨테이너 디버깅용)"
  type        = bool
  default     = false
}
