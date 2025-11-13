# Claude Commands 설치 가이드

이 디렉토리는 infrastructure 프로젝트 작업 시 유용한 Claude Code 커맨드를 포함하고 있습니다.

## 📦 포함된 커맨드

### `/if/` 패키지 - Infrastructure 관리 커맨드
- `/if/validate` - 모듈 검증
- `/if/module` - 모듈 관리 및 재사용
  - `/if/module list` - 사용 가능한 모듈과 버전 조회
  - `/if/module info <module>` - 모듈 상세 정보
  - `/if/module get <module>[@version]` - Terraform source 생성
  - `/if/module init <module>[@version]` - 프로젝트에 모듈 설정 파일 생성
- `/if/shared` - 공유 인프라 참조 ⭐ **NEW**
  - `/if/shared list` - 사용 가능한 공유 리소스 조회
  - `/if/shared info <resource>` - 공유 리소스 상세 정보 및 SSM 파라미터
  - `/if/shared get <resource>` - Terraform data source 코드 생성
- `/if/atlantis` - Atlantis 프로젝트 관리
- `/if/deploy` - Atlantis 설정 배포 (Git commit & push)

## 🚀 설치 방법

### Option 1: 심볼릭 링크 (권장)
```bash
# if/ 패키지 전체를 심볼릭 링크로 연결
ln -s /Users/sangwon-ryu/infrastructure/docs/claude-commands/if \
      ~/.claude/commands/if

# 확인
ls -la ~/.claude/commands/if
```

**장점**:
- ✅ 프로젝트 업데이트 시 자동 반영
- ✅ 중앙 관리 (한 곳에서 수정)
- ✅ Git으로 버전 관리

### Option 2: 복사
```bash
# if/ 패키지 복사
cp -r /Users/sangwon-ryu/infrastructure/docs/claude-commands/if \
      ~/.claude/commands/

# 확인
ls -la ~/.claude/commands/if
```

**단점**:
- ⚠️ 프로젝트 업데이트 시 수동으로 다시 복사 필요
- ⚠️ 여러 사람이 사용 시 동기화 어려움

## ✅ 설치 확인

```bash
# Claude Code에서 사용 가능한지 확인
claude code --help | grep "/if"

# 또는 Claude Code 세션에서:
# /if/validate --help
```

## 📋 사용 예시

### 모듈 검증
```bash
/if/validate              # 모든 모듈 검증
/if/validate alb          # 특정 모듈만 검증
/if/validate --quick      # 빠른 검증 (governance 제외)
```

### 모듈 재사용
```bash
/if/module list              # 사용 가능한 모듈과 버전 목록
/if/module info ecr          # ECR 모듈 상세 정보 및 버전
/if/module get ecr@v1.0.0    # ECR 모듈 Terraform source 생성
/if/module init ecr          # 현재 프로젝트에 ECR 설정 파일 생성
```

### 공유 인프라 참조
```bash
/if/shared list              # 사용 가능한 공유 리소스 목록 (RDS, VPC, S3 등)
/if/shared info rds          # RDS 상세 정보 및 SSM 파라미터
/if/shared get rds           # RDS 참조 Terraform 코드 생성
/if/shared get vpc           # VPC 참조 Terraform 코드 생성
```

### Atlantis 관리
```bash
/if/atlantis add          # 새 프로젝트 추가 (대화형)
/if/atlantis list         # 등록된 프로젝트 목록
/if/atlantis health       # Atlantis 상태 확인
```

### Atlantis 설정 배포
```bash
/if/deploy                # atlantis.yaml 변경사항 배포

# 또는 스크립트 직접 실행
./scripts/atlantis/deploy-config.sh
./scripts/atlantis/deploy-config.sh "feat: Add new ECR project"
```

## 🔧 문제 해결

### 커맨드가 인식되지 않는 경우
```bash
# 1. 디렉토리 경로 확인
ls -la ~/.claude/commands/if

# 2. 권한 확인
chmod +x ~/.claude/commands/if/*.md

# 3. Claude Code 재시작
```

### 심볼릭 링크 제거
```bash
rm ~/.claude/commands/if
```

## 📚 관련 문서

- [프로젝트 워크플로우 가이드](../ko/infrastructure-workflow.md)
- [모듈 검증 스크립트](../../scripts/validators/validate-modules.sh)
- [Atlantis 자동화 스크립트](../../scripts/atlantis/add-project.sh)

## 🔄 업데이트

프로젝트에서 커맨드가 업데이트되면:

**심볼릭 링크 사용 시**: 자동으로 반영됨 ✨

**복사 사용 시**: 다시 복사 필요
```bash
rm -rf ~/.claude/commands/if
cp -r /Users/sangwon-ryu/infrastructure/docs/claude-commands/if ~/.claude/commands/
```

## 🤝 기여

커맨드 개선 사항이 있으면 이 디렉토리의 파일을 수정하고 커밋하세요.
다른 팀원들도 심볼릭 링크 사용 시 자동으로 업데이트를 받게 됩니다.
