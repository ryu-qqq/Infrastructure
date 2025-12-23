디비 # prod-shared-mysql 데이터베이스 접속 가이드

> **생성일**: 2025-11-10
> **RDS 인스턴스**: prod-shared-mysql
> **엔진**: MySQL 8.0.42
> **환경**: Production
> **VPC**: vpc-0f162b9e588276e09

---

## 📋 목차

1. [공통 접속 정보](#공통-접속-정보)
2. [프로젝트별 접속 정보](#프로젝트별-접속-정보)
3. [환경 변수 설정 방법](#환경-변수-설정-방법)
4. [연결 테스트](#연결-테스트)
5. [보안 주의사항](#보안-주의사항)

---

## 공통 접속 정보

```yaml
Host: prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
Port: 3306
Region: ap-northeast-2
VPC: vpc-0f162b9e588276e09
```

---

## 프로젝트별 접속 정보

### 1️⃣ FileFlow 프로젝트

**데이터베이스**: `fileflow`

**계정 정보**:
```yaml
Username: fileflow_user
Password: ?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9
```

**권한**:
- ✅ `fileflow.*`: ALL PRIVILEGES (전체 권한)
- ✅ `common.*`: SELECT, INSERT, UPDATE

**환경 변수 예시**:
```bash
# .env 파일
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=fileflow
DB_USER=fileflow_user
DB_PASSWORD=?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9
```

**연결 문자열 예시**:
```
# MySQL URL
mysql://fileflow_user:?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9@prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/fileflow

# JDBC URL
jdbc:mysql://prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/fileflow?user=fileflow_user&password=?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9
```

---

### 2️⃣ setof 프로젝트

**데이터베이스**: `setof`

**계정 정보**:
```yaml
Username: setof_user
Password: 0l8RgpL1clTdr06XyQ9DjfUOcF2ryBIN
```

**권한**:
- ✅ `luxury.*`: ALL PRIVILEGES (전체 권한)
- ✅ `common.*`: SELECT, INSERT, UPDATE

**환경 변수 예시**:
```bash
# .env 파일
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=setof
DB_USER=setof_user
DB_PASSWORD='0l8RgpL1clTdr06XyQ9DjfUOcF2ryBIN'
```

**연결 문자열 예시**:
```
# MySQL URL
mysql://setof_user:0l8RgpL1clTdr06XyQ9DjfUOcF2ryBIN@prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/setof
```

---

### 2️⃣ auth 프로젝트

**데이터베이스**: `auth`

**계정 정보**:
```yaml
Username: auth_user
Password: E8Sbh4FDEv5mSdgf8VUp5BcuOZ0eTgOe
```

**권한**:
- ✅ `luxury.*`: ALL PRIVILEGES (전체 권한)
- ✅ `common.*`: SELECT, INSERT, UPDATE

**환경 변수 예시**:
```bash
# .env 파일
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=auth
DB_USER=auth_user
DB_PASSWORD='E8Sbh4FDEv5mSdgf8VUp5BcuOZ0eTgOe'
```

**연결 문자열 예시**:
```
# MySQL URL
mysql://auth_user:E8Sbh4FDEv5mSdgf8VUp5BcuOZ0eTgOe@prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/auth

```

---

### 3️⃣ Crawler 프로젝트

**데이터베이스**: `crawler`

**계정 정보**:
```yaml
Username: crawler_user
Password: K0g)yCq%QOhJsVCj4-PYTUrVAA$8e4j-
```

**권한**:
- ✅ `crawler.*`: ALL PRIVILEGES (전체 권한)
- ✅ `common.*`: SELECT, INSERT, UPDATE

**환경 변수 예시**:
```bash
# .env 파일
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=crawler
DB_USER=crawler_user
DB_PASSWORD='K0g)yCq%QOhJsVCj4-PYTUrVAA$8e4j-'
```

**연결 문자열 예시**:
```
# MySQL URL
mysql://crawler_user:K0g)yCq%QOhJsVCj4-PYTUrVAA$8e4j-@prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/crawler
```

---

### 4️⃣ Market 프로젝트

**데이터베이스**: `market`

**계정 정보**:
```yaml
Username: market_user
Password: SpupfgrgZfeQ6ZutDgxCoumLUKjaTy4c
```

**권한**:
- ✅ `market.*`: ALL PRIVILEGES (전체 권한)
- ✅ `common.*`: SELECT, INSERT, UPDATE

**환경 변수 예시**:
```bash
# .env 파일
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=market
DB_USER=market_user
DB_PASSWORD='SpupfgrgZfeQ6ZutDgxCoumLUKjaTy4c'
```

**연결 문자열 예시**:
```
# MySQL URL
mysql://market_user:SpupfgrgZfeQ6ZutDgxCoumLUKjaTy4c@prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/market

# JDBC URL
jdbc:mysql://prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com:3306/market?user=market_user&password=SpupfgrgZfeQ6ZutDgxCoumLUKjaTy4c
```

---

### 5️⃣ 공통 데이터베이스 (Common)

**데이터베이스**: `common`

여러 프로젝트에서 공유하는 데이터를 저장하는 데이터베이스입니다.

**접근 방식**:
- 각 프로젝트 사용자(fileflow_user, setof_user, crawler_user, market_user)는 `common` 데이터베이스에 SELECT, INSERT, UPDATE 권한을 가집니다.
- 프로젝트별 연결을 사용하되, 필요시 `common` 데이터베이스의 테이블에 접근 가능합니다.

**사용 예시 (Python)**:
```python
import pymysql

# FileFlow 프로젝트에서 common 데이터 읽기
connection = pymysql.connect(
    host='prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com',
    port=3306,
    user='fileflow_user',
    password='?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9',
    database='fileflow'
)

# common 데이터베이스의 테이블 조회
cursor = connection.cursor()
cursor.execute("SELECT * FROM common.shared_config")
```

---

### 6️⃣ 읽기 전용 계정 (Monitoring/Analytics)

**계정 정보**:
```yaml
Username: readonly_user
Password: T7!C-cCXR[LvZg<!5p*a5>HHeCGu?v+s
```

**권한**:
- ✅ `fileflow.*`: SELECT (읽기 전용)
- ✅ `luxury.*`: SELECT (읽기 전용)
- ✅ `crawler.*`: SELECT (읽기 전용)
- ✅ `market.*`: SELECT (읽기 전용)
- ✅ `common.*`: SELECT (읽기 전용)
- ✅ `shared_db.*`: SELECT (읽기 전용)

**사용 목적**:
- 데이터 분석 도구 (Metabase, Superset 등)
- 모니터링 및 로깅
- 리포팅 시스템
- 운영 조회

**환경 변수 예시**:
```bash
# .env 파일 (Analytics/Monitoring)
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_USER=readonly_user
DB_PASSWORD='T7!C-cCXR[LvZg<!5p*a5>HHeCGu?v+s'
```

---

### 7️⃣ DMS 복제 전용 계정

**계정 정보**:
```yaml
Username: dms_user
Password: sDY!N+LEErO13dpxIf<!TT)r[mD<wP!4
```

**권한**:
- ✅ `luxury.*`: SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
- ✅ `*.*`: REPLICATION CLIENT, REPLICATION SLAVE

**사용 목적**:
- AWS DMS를 통한 데이터 마이그레이션
- EC2 MySQL → RDS MySQL 복제

⚠️ **주의**: 이 계정은 DMS 전용이며, 애플리케이션에서 직접 사용하지 마세요.

---

AWS_DB_USER=admin
AWS_DB_PASSWORD=E[&mUlOgA+ucv31nRmSDlbOr398VyGep

---

## 환경 변수 설정 방법

### Node.js 프로젝트

**1. `.env` 파일 생성**:
```bash
# .env
DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
DB_PORT=3306
DB_NAME=fileflow
DB_USER=fileflow_user
DB_PASSWORD=?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9
```

**2. `dotenv` 사용 (TypeScript 예시)**:
```typescript
import * as dotenv from 'dotenv';
import { createConnection } from 'mysql2/promise';

dotenv.config();

const connection = await createConnection({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
});
```

---

### Python 프로젝트

**1. `.env` 파일 생성** (동일)

**2. `python-dotenv` 사용**:
```python
import os
from dotenv import load_dotenv
import pymysql

load_dotenv()

connection = pymysql.connect(
    host=os.getenv('DB_HOST'),
    port=int(os.getenv('DB_PORT')),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD'),
    database=os.getenv('DB_NAME')
)
```

---

### Docker Compose

```yaml
version: '3.8'

services:
  app:
    image: your-app:latest
    environment:
      - DB_HOST=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com
      - DB_PORT=3306
      - DB_NAME=fileflow
      - DB_USER=fileflow_user
      - DB_PASSWORD=?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9
    # 또는 env_file 사용
    env_file:
      - .env
```

---

### Kubernetes Secrets

```bash
# 1. Secret 생성
kubectl create secret generic db-credentials \
  --from-literal=host=prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com \
  --from-literal=port=3306 \
  --from-literal=database=fileflow \
  --from-literal=username=fileflow_user \
  --from-literal=password='?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9'

# 2. Deployment에서 사용
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fileflow-app
spec:
  template:
    spec:
      containers:
      - name: app
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: host
        - name: DB_PORT
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: port
        - name: DB_NAME
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: database
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: username
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
```

---

## 연결 테스트

### MySQL CLI로 테스트

```bash
# FileFlow 사용자로 연결
mysql -h prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com \
  -P 3306 \
  -u fileflow_user \
  -p'?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9' \
  fileflow

# 연결 확인
mysql> SELECT 'Connection successful!' AS status;
mysql> SHOW TABLES;
mysql> SELECT DATABASE(), USER();
```

### Python 스크립트로 테스트

```python
#!/usr/bin/env python3
import pymysql

# 연결 테스트 함수
def test_connection(host, port, user, password, database):
    try:
        connection = pymysql.connect(
            host=host,
            port=port,
            user=user,
            password=password,
            database=database
        )
        with connection.cursor() as cursor:
            cursor.execute("SELECT DATABASE(), USER(), VERSION()")
            result = cursor.fetchone()
            print(f"✅ 연결 성공!")
            print(f"   Database: {result[0]}")
            print(f"   User: {result[1]}")
            print(f"   Version: {result[2]}")
        connection.close()
    except Exception as e:
        print(f"❌ 연결 실패: {e}")

# 테스트 실행
test_connection(
    host='prod-shared-mysql.cfacertspqbw.ap-northeast-2.rds.amazonaws.com',
    port=3306,
    user='fileflow_user',
    password='?EiAm&i&8uQUX47&3AHMtHy-GkpxDTf9',
    database='fileflow'
)
```

---

## 보안 주의사항

### ⚠️ 비밀번호 관리

1. **환경 변수 사용**
    - `.env` 파일에 저장하고 `.gitignore`에 추가
    - 절대 코드에 하드코딩하지 마세요

2. **Secret Manager 권장**
    - AWS Secrets Manager 사용 권장
    - GitHub Secrets, Kubernetes Secrets 활용

3. **접근 제어**
    - VPC 내부에서만 접근 가능하도록 설정
    - 보안 그룹으로 IP 제한

### 🔒 네트워크 보안

**현재 설정**:
- RDS는 `vpc-0f162b9e588276e09` 내부에 위치
- Private subnet에 배치
- 인터넷에서 직접 접근 불가

**접근 방법**:
1. VPC 내부 EC2/ECS에서 접근
2. VPN/Bastion을 통한 접근
3. VPC Peering을 통한 다른 VPC에서 접근

### 📋 권장 사항

1. **비밀번호 주기적 변경**
   ```sql
   ALTER USER 'fileflow_user'@'%' IDENTIFIED BY 'new_secure_password';
   ```

2. **최소 권한 원칙**
    - 필요한 권한만 부여
    - 프로덕션 환경에서는 DROP, TRUNCATE 권한 제거 고려

3. **연결 모니터링**
    - CloudWatch Logs 활성화
    - 비정상 접근 패턴 모니터링

---

## 📞 문의 및 지원

데이터베이스 접속 문제나 권한 관련 문의사항이 있으시면 인프라팀에 문의해주세요.

**관련 문서**:
- [RDS Terraform 구성](../terraform/shared/rds.tf)
- [DMS 마이그레이션 가이드](./DMS_MIGRATION_GUIDE.md)
- [보안 가이드](./SECURITY_GUIDE.md)