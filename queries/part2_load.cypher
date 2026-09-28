// ============================================================
// PART 2 — LOAD MOVIELENS DATA
// ============================================================


// ------------------------------------------------------------
// 1. Indexes
// ------------------------------------------------------------

CREATE INDEX user_id IF NOT EXISTS
FOR (u:User)
ON (u.userId);

CREATE INDEX movie_id IF NOT EXISTS
FOR (m:Movie)
ON (m.movieId);

CREATE INDEX genre_name IF NOT EXISTS
FOR (g:Genre)
ON (g.name);

CALL db.awaitIndexes(300);


// ------------------------------------------------------------
// 2. Users
// ------------------------------------------------------------

LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row

MERGE (u:User {userId: toInteger(row.userId)})
SET
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);


// ------------------------------------------------------------
// 3. Movies + Genres
// ------------------------------------------------------------

LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row

MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET
    m.title = trim(
        substring(
            row.title,
            0,
            size(row.title) - 6
        )
    ),
    m.year = toInteger(
        substring(
            row.title,
            size(row.title) - 5,
            4
        )
    )

WITH m, row
UNWIND split(row.genres, '|') AS genreName

MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);


// ------------------------------------------------------------
// 4. Ratings — batch loading
// ------------------------------------------------------------

CALL apoc.periodic.iterate(
    "
    LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
    RETURN row
    ",
    "
    MATCH (u:User {userId: toInteger(row.userId)})
    MATCH (m:Movie {movieId: toInteger(row.movieId)})

    MERGE (u)-[r:RATED]->(m)
    SET
        r.rating = toInteger(row.rating),
        r.timestamp = toInteger(row.timestamp)
    ",
    {
        batchSize: 10000,
        parallel: false
    }
)
YIELD
    batches,
    total,
    failedBatches,
    failedOperations,
    errorMessages

RETURN
    batches,
    total,
    failedBatches,
    failedOperations,
    errorMessages;


// ------------------------------------------------------------
// 5. Verification
// ------------------------------------------------------------

MATCH (u:User)
RETURN count(u) AS users;

MATCH (m:Movie)
RETURN count(m) AS movies;

MATCH (g:Genre)
RETURN count(g) AS genres;

MATCH ()-[r:RATED]->()
RETURN count(r) AS ratings;

MATCH ()-[r:HAS_GENRE]->()
RETURN count(r) AS genreRelationships;
