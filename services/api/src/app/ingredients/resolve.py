from dataclasses import dataclass
from typing import List, Optional, Tuple
from functools import lru_cache
from app.db import get_conn

@dataclass(frozen=True)
class SynRule:
    canonical_id: str
    canonical_name: str
    synonym: str
    match_type: str  # 'exact' | 'contains'

def norm(s: str) -> str:
    return " ".join(s.strip().lower().split())

@lru_cache
def load_rules() -> List[SynRule]:
    sql = """
      WITH rules AS (
        -- Treat canonical name as an exact synonym
        SELECT
          c.id::text AS canonical_id,
          c.name      AS canonical_name,
          c.name      AS synonym,
          'exact'     AS match_type
        FROM ingredient_canonical c

        UNION ALL

        -- User-defined synonyms
        SELECT
          c.id::text,
          c.name,
          s.synonym,
          s.match_type
        FROM ingredient_synonyms s
        JOIN ingredient_canonical c ON c.id = s.canonical_id
        WHERE s.is_active = true
      )
      SELECT canonical_id, canonical_name, synonym, match_type
      FROM rules
      ORDER BY
        CASE WHEN match_type = 'exact' THEN 0 ELSE 1 END,
        length(synonym) DESC
    """

    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql)
            rows = cur.fetchall()

    return [SynRule(r[0], r[1], r[2], r[3]) for r in rows]

def resolve_to_canonical(raw_text: str, rules: List[SynRule]) -> Optional[Tuple[str, str]]:
    t = norm(raw_text)
    if not t:
        return None

    for rule in rules:
        syn = norm(rule.synonym)
        if rule.match_type == "exact" and t == syn:
            return (rule.canonical_id, rule.canonical_name)
        if rule.match_type == "contains" and syn in t:
            return (rule.canonical_id, rule.canonical_name)

    return None
