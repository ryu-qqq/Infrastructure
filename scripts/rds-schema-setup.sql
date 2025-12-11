-- ============================================================================
-- RDS Schema and User Setup Script
-- prod-shared-mysql 데이터베이스용 스키마/유저 생성 스크립트
-- ============================================================================
--
-- 실행 방법:
-- 1. Terraform apply 실행하여 Secrets Manager에 비밀번호 생성
-- 2. AWS Secrets Manager에서 비밀번호 조회:
--    aws secretsmanager get-secret-value --secret-id prod-shared-mysql-setof-password --query SecretString --output text | jq -r '.password'
--    aws secretsmanager get-secret-value --secret-id prod-shared-mysql-auth-password --query SecretString --output text | jq -r '.password'
-- 3. admin 계정으로 RDS 접속 후 이 스크립트 실행
--
-- ============================================================================

-- ============================================================================
-- 1. setof 스키마 및 유저 생성
-- ============================================================================

-- 스키마(데이터베이스) 생성
CREATE DATABASE IF NOT EXISTS setof
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 유저 생성 (비밀번호는 Secrets Manager에서 조회하여 대체)
-- NOTE: '<SETOF_PASSWORD>'를 Secrets Manager에서 조회한 실제 비밀번호로 교체하세요
CREATE USER IF NOT EXISTS 'setof_user'@'%' IDENTIFIED BY '<SETOF_PASSWORD>';

-- 권한 부여: setof 스키마에 대한 전체 권한
GRANT ALL PRIVILEGES ON setof.* TO 'setof_user'@'%';

-- ============================================================================
-- 2. auth 스키마 및 유저 생성 (인증/인가용)
-- ============================================================================

-- 스키마(데이터베이스) 생성
CREATE DATABASE IF NOT EXISTS auth
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 유저 생성 (비밀번호는 Secrets Manager에서 조회하여 대체)
-- NOTE: '<AUTH_PASSWORD>'를 Secrets Manager에서 조회한 실제 비밀번호로 교체하세요
CREATE USER IF NOT EXISTS 'auth_user'@'%' IDENTIFIED BY '<AUTH_PASSWORD>';

-- 권한 부여: auth 스키마에 대한 전체 권한
GRANT ALL PRIVILEGES ON auth.* TO 'auth_user'@'%';

-- ============================================================================
-- 3. luxury 스키마 및 유저 삭제 (선택사항)
-- ============================================================================

-- 주의: luxury 스키마에 데이터가 있는지 먼저 확인하세요!
-- 데이터 확인:
-- SHOW TABLES IN luxury;
-- SELECT COUNT(*) FROM luxury.<테이블명>;

-- luxury 유저 삭제 (존재하는 경우)
-- DROP USER IF EXISTS 'luxury_user'@'%';
-- DROP USER IF EXISTS 'luxury'@'%';

-- luxury 스키마 삭제 (존재하는 경우)
-- DROP DATABASE IF EXISTS luxury;

-- ============================================================================
-- 4. 권한 적용
-- ============================================================================

FLUSH PRIVILEGES;

-- ============================================================================
-- 5. 검증 쿼리
-- ============================================================================

-- 생성된 데이터베이스 확인
SHOW DATABASES LIKE 'setof';
SHOW DATABASES LIKE 'auth';

-- 생성된 유저 확인
SELECT User, Host FROM mysql.user WHERE User IN ('setof_user', 'auth_user');

-- 권한 확인
SHOW GRANTS FOR 'setof_user'@'%';
SHOW GRANTS FOR 'auth_user'@'%';
