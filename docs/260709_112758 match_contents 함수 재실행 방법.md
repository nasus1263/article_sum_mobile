# match_contents 함수 재실행 방법

## 배경

`match_threshold` 기본값이 여전히 `0.75`로 남아있으면(문서 `260709_103616 ...md`에서 `-1`로 낮추기로 한 SQL이 실제 반영 안 된 상태) 관련기사 검색이 계속 0건으로 나옴. 재실행 방법.

## 절차

1. Supabase 대시보드 → **SQL Editor** → New query.
2. 아래 SQL 실행.

```sql
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

- `create or replace function` — 파라미터 개수/타입(bigint, int, float) 동일하므로 기존 함수를 그대로 덮어씀. `drop function` 별도로 안 해도 됨.

## 반영 확인

```sql
select pg_get_functiondef(oid)
from pg_proc
where proname = 'match_contents';
```

결과에 `match_threshold float DEFAULT ...` 부분이 `(-1)`로 나오면 반영된 것. 여전히 `0.75`면 위 SQL이 실행 안 된 것.

## 관련 문서

- `{cwd}/docs/260709_103616 관련기사 RAG pgvector SQL 적용 방법.md` — 최초 SQL 적용 방법 + threshold를 -1로 낮춘 이유
