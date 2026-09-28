// ============================================================
// PART 4 — SUPERNODES
// ============================================================

MATCH (n)-[r]-()
WITH n, count(r) AS degree
RETURN
    labels(n)[0] AS label,
    CASE
        WHEN n:User THEN 'User ' + toString(n.userId)
        WHEN n:Movie THEN n.title
        WHEN n:Genre THEN n.name
        ELSE 'Unknown'
    END AS node,
    degree
ORDER BY degree DESC
LIMIT 20;

MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)
RETURN
    g.name AS genre,
    count(m) AS movieCount
ORDER BY movieCount DESC;

MATCH (m:Movie)<-[r:RATED]-(:User)
RETURN
    m.movieId AS movieId,
    m.title AS title,
    count(r) AS ratingCount
ORDER BY ratingCount DESC
LIMIT 10;

MATCH (u:User)-[r:RATED]->(:Movie)
RETURN
    u.userId AS userId,
    count(r) AS ratingCount
ORDER BY ratingCount DESC
LIMIT 10;
