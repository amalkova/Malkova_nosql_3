// ============================================================
// PART 5 — GRAPH DATA SCIENCE
// PageRank, Louvain, Dijkstra
// ============================================================


// ============================================================
// 5.1 PAGERANK — MOVIE GRAPH
// ============================================================

// Movies are connected when the same users rated both >= 4.

MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4
  AND r2.rating >= 4
  AND id(m1) < id(m2)

WITH m1, m2, count(u) AS weight

WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20

WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000

MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;


// Create GDS projection

CALL gds.graph.project(
    'movieGraph',
    'Movie',
    {
        CO_RATED: {
            orientation: 'UNDIRECTED',
            properties: 'weight'
        }
    }
)
YIELD graphName, nodeCount, relationshipCount

RETURN
    graphName,
    nodeCount,
    relationshipCount;


// Run PageRank

CALL gds.pageRank.stream(
    'movieGraph',
    {
        relationshipWeightProperty: 'weight'
    }
)
YIELD nodeId, score

RETURN
    gds.util.asNode(nodeId).movieId AS movieId,
    gds.util.asNode(nodeId).title AS title,
    score

ORDER BY score DESC
LIMIT 10;


// Cleanup PageRank graph

CALL gds.graph.drop('movieGraph')
YIELD graphName
RETURN graphName;

MATCH ()-[co:CO_RATED]-()
DELETE co;


// ============================================================
// 5.2 LOUVAIN — USER SIMILARITY GRAPH
// ============================================================

// The original >= 4 / LIMIT 50000 version exceeded the local
// Neo4j transaction memory limit.
//
// The homework explicitly allows reducing LIMIT or increasing
// the rating threshold. Therefore this local run uses:
// rating = 5 and LIMIT 20000.

MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating = 5
  AND r2.rating = 5
  AND id(u1) < id(u2)

WITH u1, u2, count(m) AS weight
ORDER BY weight DESC
LIMIT 20000

MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;


// Create similarity projection

CALL gds.graph.project(
    'userSimilarity',
    'User',
    {
        SIMILAR: {
            orientation: 'UNDIRECTED',
            properties: 'weight'
        }
    }
)
YIELD graphName, nodeCount, relationshipCount

RETURN
    graphName,
    nodeCount,
    relationshipCount;


// Louvain

CALL gds.louvain.write(
    'userSimilarity',
    {
        relationshipWeightProperty: 'weight',
        writeProperty: 'communityId'
    }
)
YIELD
    communityCount,
    modularity,
    ranLevels,
    nodePropertiesWritten

RETURN
    communityCount,
    modularity,
    ranLevels,
    nodePropertiesWritten;


// 10 largest communities

MATCH (u:User)
WHERE u.communityId IS NOT NULL

RETURN
    u.communityId AS communityId,
    count(u) AS users

ORDER BY users DESC
LIMIT 10;


// Top 3 genres for 10 largest communities

MATCH (u:User)
WHERE u.communityId IS NOT NULL

WITH
    u.communityId AS communityId,
    count(u) AS communitySize

ORDER BY communitySize DESC
LIMIT 10

MATCH (member:User)
WHERE member.communityId = communityId

MATCH (member)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4

WITH
    communityId,
    communitySize,
    g.name AS genre,
    count(*) AS highRatings

ORDER BY
    communityId,
    highRatings DESC

WITH
    communityId,
    communitySize,
    collect({
        genre: genre,
        highRatings: highRatings
    })[0..3] AS topGenres

RETURN
    communityId,
    communitySize,
    topGenres

ORDER BY communitySize DESC;


// Louvain projection is no longer needed.
// SIMILAR relationships stay in Neo4j because Dijkstra reuses them.

CALL gds.graph.drop('userSimilarity')
YIELD graphName
RETURN graphName;


// ============================================================
// 5.3 DIJKSTRA — SHORTEST PATH BETWEEN USERS
// ============================================================

// Create a new projection from the same SIMILAR relationships.

CALL gds.graph.project(
    'userGraph',
    'User',
    {
        SIMILAR: {
            orientation: 'UNDIRECTED'
        }
    }
)
YIELD graphName, nodeCount, relationshipCount

RETURN
    graphName,
    nodeCount,
    relationshipCount;


// Example pair: User 17 -> User 181.
//
// No relationship weight is supplied here because SIMILAR.weight
// means similarity strength (larger = stronger), while Dijkstra
// minimizes cost. For the "degrees of separation" analysis,
// every SIMILAR edge therefore has cost 1.

MATCH
    (source:User {userId: 17}),
    (target:User {userId: 181})

CALL gds.shortestPath.dijkstra.stream(
    'userGraph',
    {
        sourceNode: source,
        targetNode: target
    }
)
YIELD
    totalCost,
    nodeIds

RETURN
    totalCost AS pathLength,
    [nodeId IN nodeIds |
        gds.util.asNode(nodeId).userId
    ] AS userPath;


// Test several user pairs

UNWIND [
    [17, 181],
    [33, 175],
    [81, 169],
    [139, 166],
    [151, 157]
] AS pair

MATCH
    (source:User {userId: pair[0]}),
    (target:User {userId: pair[1]})

CALL gds.shortestPath.dijkstra.stream(
    'userGraph',
    {
        sourceNode: source,
        targetNode: target
    }
)
YIELD
    totalCost,
    nodeIds

RETURN
    pair[0] AS sourceUser,
    pair[1] AS targetUser,
    totalCost AS pathLength,
    [nodeId IN nodeIds |
        gds.util.asNode(nodeId).userId
    ] AS userPath;


// Average path length for tested pairs

UNWIND [
    [17, 181],
    [33, 175],
    [81, 169],
    [139, 166],
    [151, 157]
] AS pair

MATCH
    (source:User {userId: pair[0]}),
    (target:User {userId: pair[1]})

CALL gds.shortestPath.dijkstra.stream(
    'userGraph',
    {
        sourceNode: source,
        targetNode: target
    }
)
YIELD totalCost

RETURN
    count(*) AS testedPairs,
    avg(totalCost) AS averagePathLength,
    min(totalCost) AS minPathLength,
    max(totalCost) AS maxPathLength;


// Final cleanup

CALL gds.graph.drop('userGraph')
YIELD graphName
RETURN graphName;

MATCH ()-[sim:SIMILAR]-()
DELETE sim;
