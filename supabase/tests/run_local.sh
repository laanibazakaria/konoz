#!/usr/bin/env bash
# يختبر الترحيل والبيانات الأولية على PostgreSQL محلي (بدون Supabase).
# الاستخدام: ./supabase/tests/run_local.sh   (يتطلب psql ومستخدماً له صلاحية إنشاء قاعدة)
set -euo pipefail
cd "$(dirname "$0")/.."
DB=${DB:-quiz_test}
dropdb --if-exists "$DB"; createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f tests/auth_stub.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f migrations/0001_init.sql
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f seed.sql >/dev/null
psql -q -d "$DB" -f tests/behavior_test.sql
