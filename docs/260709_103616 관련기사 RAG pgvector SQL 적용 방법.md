# 관련기사 RAG — pgvector SQL 적용 방법

## 절차

1. Supabase 대시보드 접속 → 대상 프로젝트 선택.
2. 왼쪽 메뉴 **SQL Editor** → **New query**.
3. 아래 SQL 전체 붙여넣기 → **Run**.

## SQL

```sql
create extension if not exists vector;

alter table contents add column embedding vector(1536);

create or replace function match_contents(
  source_id bigint,
  match_count int default 5,
  match_threshold float default -1
)
returns table (
  id bigint,
  url text,
  tag text,
  status text,
  data jsonb,
  created_at timestamptz,
  similarity float
)
language sql
stable
as $$
  select c.id, c.url, c.tag, c.status, c.data, c.created_at,
         1 - (c.embedding <=> s.embedding) as similarity
  from contents c, (select embedding from contents where id = source_id) s
  where c.status = 'approved'
    and c.id <> source_id
    and c.embedding is not null
    and s.embedding is not null
    and 1 - (c.embedding <=> s.embedding) >= match_threshold
  order by c.embedding <=> s.embedding
  limit match_count;
$$;
```

## 주의

- `contents` 테이블에 `user_id`/RLS 정책 없으면 함수가 `SECURITY INVOKER`(기본값)라도 소유자 필터 안 걸림 — 실행 전 스키마에 `user_id`/RLS 존재 여부 먼저 확인. 없으면 함수는 정상 동작하되 전체 유저 기사 대상으로 검색됨.
- 벡터 차원(1536)은 OpenAI `text-embedding-3-small` 기준. 다른 임베딩 모델로 바꾸면 컬럼 재생성 필요.
- `match_count`(5)는 함수 파라미터 기본값. `match_threshold`는 최소 유사도 하한선 필터인데, 문서 초안이 발이 되었던 0.75가 데이터 적은 초기 상태에서 결과를 죄다 걸러버려 **-1(사실상 무제한)로 낮춤** — 코사인 유사도는 -1~1 범위라 -1이면 절대 안 걸림. 대신 클라이언트 UI에서 유사도 0.5 이하 항목은 반투명하게 표시(카드 자체는 숨기지 않음).
- 앱 코드가 자동 마이그레이션하지 않으므로, 이 SQL을 실행해야 `{cwd}/lib/services/content_repository.dart`의 `getRelated()` RPC 호출이 정상 동작함. 기존에 `match_threshold default 0.75`로 이미 함수를 만들었다면, 파라미터 시그니처(개수/타입)는 그대로라 `create or replace function ...`만 다시 실행하면 덮어써짐 — 별도 `drop function` 불필요.

## 관련 구현 (참고)

- `{cwd}/lib/services/content_repository.dart` — `processLink()`(임베딩 결과 저장), `getRelated()`(RPC 호출)
- `{cwd}/../article-sum-back/main.py` — `/process` 응답에 `embedding`/`embeddingError` 추가
- `{cwd}/lib/pages/archive_detail_page.dart` — 관련 기사 UI, 임베딩 실패 뱃지
