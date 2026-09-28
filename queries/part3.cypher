// ============================================================
// PART 3 — CYPHER QUERIES
// ============================================================


// ------------------------------------------------------------
// Query 1
// Thriller movies with average rating > 4.0
// ------------------------------------------------------------

MATCH (m:Movie)-[:HAS_GENRE]->(:Genre {name: 'Thriller'})
MATCH (m)<-[r:RATED]-(:User)
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE avgRating > 4.0
RETURN
    m.movieId AS movieId,
    m.title AS title,
    m.year AS year,
    round(avgRating, 3) AS avgRating,
    ratingCount
ORDER BY avgRating DESC, ratingCount DESC
LIMIT 10;


// ------------------------------------------------------------
// Query 2
// Users who gave rating 5 to more than 50 movies
// ------------------------------------------------------------

MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5
WITH u, count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN
    u.userId AS userId,
    u.gender AS gender,
    u.age AS age,
    u.occupation AS occupation,
    fiveStarRatings
ORDER BY fiveStarRatings DESC
LIMIT 10;


// ------------------------------------------------------------
// Query 3
// Movies highly rated by both User 1 and User 2
// ------------------------------------------------------------

MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
MATCH (u2:User {userId: 2})-[r2:RATED]->(m)
WHERE r1.rating >= 4
  AND r2.rating >= 4
RETURN
    m.movieId AS movieId,
    m.title AS title,
    r1.rating AS user1Rating,
    r2.rating AS user2Rating
ORDER BY m.title;


// ------------------------------------------------------------
// Query 4
// Genres with consistently high ratings
// ------------------------------------------------------------

MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-(:User)
WITH
    g,
    avg(r.rating) AS avgRating,
    count(r) AS ratingCount
RETURN
    g.name AS genre,
    round(avgRating, 3) AS avgRating,
    ratingCount
ORDER BY avgRating DESC, ratingCount DESC;


// ------------------------------------------------------------
// Query 5
// Recommendation:
// similar users also liked movies that target user has not seen
// ------------------------------------------------------------

MATCH (target:User {userId: 1})-[tr:RATED]->(common:Movie)
      <-[sr:RATED]-(similar:User)
WHERE tr.rating >= 4
  AND sr.rating >= 4
  AND similar <> target

WITH
    target,
    similar,
    count(common) AS commonHighRatedMovies
WHERE commonHighRatedMovies >= 5

WITH target, similar, commonHighRatedMovies
ORDER BY commonHighRatedMovies DESC
LIMIT 20

MATCH (similar)-[rec:RATED]->(candidate:Movie)
WHERE rec.rating >= 4
  AND NOT EXISTS {
      MATCH (target)-[:RATED]->(candidate)
  }

RETURN
    candidate.movieId AS movieId,
    candidate.title AS title,
    count(DISTINCT similar) AS similarUsers,
    round(avg(rec.rating), 3) AS avgSimilarUserRating,
    max(commonHighRatedMovies) AS similarityStrength
ORDER BY
    similarUsers DESC,
    avgSimilarUserRating DESC,
    similarityStrength DESC
LIMIT 10;


// ------------------------------------------------------------
// Query 6
// Shortest connection between two users through rated movies
// ------------------------------------------------------------

MATCH
    (u1:User {userId: 1}),
    (u2:User {userId: 2})

MATCH p = shortestPath(
    (u1)-[:RATED*..6]-(u2)
)

RETURN
    length(p) AS pathLength,
    [n IN nodes(p) |
        CASE
            WHEN n:User THEN 'User ' + toString(n.userId)
            WHEN n:Movie THEN 'Movie: ' + n.title
            ELSE 'Unknown'
        END
    ] AS path;
