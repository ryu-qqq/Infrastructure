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
  default     = "myapp"
}

# VPC ID
variable "vpc_id" {
  description = "RDS가 배포될 VPC ID"
  type        = string
}

# 허용할 보안 그룹 ID
variable "allowed_security_group_ids" {
  description = "RDS에 접근을 허용할 보안 그룹 ID 목록 (예: ECS Tasks, EC2 등)"
  type        = list(string)
}

# MySQL 버전
variable "mysql_version" {
  description = "MySQL 엔진 버전"
  type        = string
  default     = "8.0.35"
}

# 인스턴스 클래스
variable "instance_class" {
  description = "RDS 인스턴스 클래스 (예: db.t3.small, db.t3.medium)"
  type        = string
  default     = "db.t3.small"
}

# 스토리지 설정
variable "allocated_storage" {
  description = "초기 할당 스토리지 (GB)"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "자동 확장 최대 스토리지 (GB, 0이면 자동 확장 비활성화)"
  type        = number
  default     = 100
}

# 데이터베이스 설정
variable "database_name" {
  description = "초기 데이터베이스 이름"
  type        = string
  default     = "myappdb"
}

variable "master_username" {
  description = "마스터 사용자 이름"
  type        = string
  default     = "admin"
}

# 고가용성 설정
variable "enable_multi_az" {
  description = "Multi-AZ 배포 활성화 여부"
  type        = bool
  default     = true
}

variable "availability_zone" {
  description = "단일 AZ 배포 시 사용할 가용 영역 (Multi-AZ가 false일 때만 사용)"
  type        = string
  default     = null
}

# 백업 설정
variable "backup_retention_days" {
  description = "자동 백업 보존 기간 (일, 0이면 백업 비활성화)"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "삭제 시 최종 스냅샷 생성 건너뛰기 (개발 환경에서만 true 권장)"
  type        = bool
  default     = false
}

# 삭제 방지
variable "enable_deletion_protection" {
  description = "삭제 방지 활성화 (운영 환경에서는 true 권장)"
  type        = bool
  default     = true
}

# 데이터베이스 파라미터
variable "max_connections" {
  description = "최대 동시 연결 수"
  type        = number
  default     = 100
}

# 알람 설정
variable "alarm_sns_topic_arn" {
  description = "CloudWatch 알람을 전송할 SNS Topic ARN (null이면 알람 액션 없음)"
  type        = string
  default     = null
}
