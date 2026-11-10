name,description,query,id,parentId,isFolder,isProtected
Uts Community Detection Movie,,,0,,true,false
Buat Database Awal,,CREATE DATABASE uts IF NOT EXISTS;,1,0,false,false
Gunakan Database Movie,,:use uts,2,0,false,false
Buat Constraint Movie ID,,"CREATE CONSTRAINT movie_id IF NOT EXISTS
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;",3,0,false,false
Buat Constraint Genre Name,,"CREATE CONSTRAINT genre_name IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;",4,0,false,false
Tampilkan Semua Constraint,,"SHOW CONSTRAINTS
YIELD name
RETURN name;",5,0,false,false
Impor Data Movie,,"LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET m.title = row.title,
    m.genres = split(row.genres, '|');",6,0,false,false
Jumlah Data Movie,,"MATCH (m:Movie)
RETURN count(m) AS jumlah_film;",7,0,false,false
Cek Data Movie,,"MATCH (m:Movie)
RETURN m.movieId AS ID, m.title AS Judul, m.genres AS Genre
LIMIT 10;",8,0,false,false
Buat Node dan Relasi Genre,,"MATCH (m:Movie)
UNWIND m.genres AS genreName
WITH m, genreName
WHERE genreName <> '(no genres listed)'
MERGE (g:Genre {name: genreName})
MERGE (m)-[:HAS_GENRE]->(g);",9,0,false,false
Jumlah Genre,,"MATCH (g:Genre)
RETURN count(g) AS jumlah_genre;",10,0,false,false
Jumlah Relasi Genre,,"MATCH ()-[r:HAS_GENRE]->()
RETURN count(r) AS jumlah_relasi_genre;",11,0,false,false
Jumlah Movie Tanpa Genre,,"MATCH (m:Movie)
WHERE m.genres = ['(no genres listed)']
RETURN count(m) AS movieTanpaGenre;",12,0,false,false
Jumlah Movie dengan Genre,,"MATCH (m:Movie)-[:HAS_GENRE]->(:Genre)
RETURN count(DISTINCT m) AS movieDenganGenre;",13,0,false,false
Jumlah Film Per Genre,,"MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
RETURN g.name AS genre, count(DISTINCT m) AS jumlah_film
ORDER BY jumlah_film DESC;",14,0,false,false
Proyeksi Graf Movie Genre,,"CALL gds.graph.drop('movieGenreBipartite', false);

CALL gds.graph.project(
    'movieGenreBipartite',
    ['Movie', 'Genre'],
    'HAS_GENRE'
);
",15,0,false,false
Visualisasi Hubungan Film dan Genre,,"CALL gds.graph.relationships.stream('movieGenreBipartite')
YIELD sourceNodeId, targetNodeId, relationshipType
WITH gds.util.asNode(sourceNodeId) AS source,
     gds.util.asNode(targetNodeId) AS target
MATCH (source)-[r:HAS_GENRE]->(target)
RETURN source, r, target
LIMIT 100;",16,0,false,false
Hitung Jaccard Similarity antar Movie,,"CALL gds.nodeSimilarity.write('movieGenreBipartite', {
    similarityMetric: 'JACCARD',
    topK: 50,
    similarityCutoff: 0.1,
    concurrency: 1,
    writeRelationshipType: 'SIMILAR_JACCARD',
    writeProperty: 'jaccard'
})
YIELD nodesCompared, relationshipsWritten
RETURN nodesCompared, relationshipsWritten;",17,0,false,false
Distribusi Nilai Jaccard,,"MATCH ()-[r:SIMILAR_JACCARD]->()
RETURN count(r) AS totalRelasi,
       min(r.jaccard) AS minJaccard,
       max(r.jaccard) AS maxJaccard,
       avg(r.jaccard) AS rataJaccard,
       count(CASE WHEN r.jaccard <= 0 THEN 1 END) AS nonPositive;",18,0,false,false
Label Movie Jaccard,,"MATCH (m:Movie)-[:SIMILAR_JACCARD]-()
SET m:JaccardMovie;",19,0,false,false
Jumlah Film dengan Jaccard,,"MATCH (m:JaccardMovie)
RETURN count(m) AS filmDalamGrafJaccard;",20,0,false,false
Index untuk Setiap Genre,,"MATCH (g:Genre)
WITH g
ORDER BY g.name
WITH collect(g) AS daftarGenre
UNWIND range(0, size(daftarGenre) - 1) AS i
WITH daftarGenre[i] AS g, i
SET g.idx = i;",21,0,false,false
Vektor Biner Genre pada Tiap Movie,,"MATCH (g:Genre)
WITH count(g) AS jumlahGenre
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
WITH jumlahGenre, m, collect(g.idx) AS indeksGenre
SET m.genreVector =
        [i IN range(0, jumlahGenre - 1) |
            CASE WHEN i IN indeksGenre THEN 1.0 ELSE 0.0 END],
    m.nGenres = size(indeksGenre),
    m:VectorMovie;",22,0,false,false
Cek Hasil Vektor,,"MATCH (m:VectorMovie)
RETURN m.title AS film,
       m.genres AS genre,
       m.genreVector AS vektor
LIMIT 5;",23,0,false,false
Proyeksi Node Vektor Genre,,"CALL gds.graph.drop('genreVectorGraph', false);

CALL gds.graph.project(
    'genreVectorGraph',
    { VectorMovie: { properties: ['genreVector', 'nGenres'] } },
    '*'
);",24,0,false,false
Hitung Metrik Pearson antar Movie,,"CALL gds.knn.write('genreVectorGraph', {
    nodeProperties: { genreVector: 'PEARSON' },
    topK: 50,
    similarityCutoff: 0.0,
    randomSeed: 42,
    concurrency: 1,
    writeRelationshipType: 'SIMILAR_PEARSON',
    writeProperty: 'knnScore'
})
YIELD nodesCompared, relationshipsWritten
RETURN nodesCompared, relationshipsWritten;",25,0,false,false
Korelasi Pearson dari Vektor Biner Genre,,"MATCH (g:Genre) // Menghitung jumlah seluruh genre yang tersedia dalam database
WITH count(g) AS G

// Mengambil pasangan film yang memiliki relasi SIMILAR_PEARSON
MATCH (a:VectorMovie)-[r:SIMILAR_PEARSON]->(b:VectorMovie)

CALL (r, a, b, G) {

    // Mengambil jumlah genre pada masing-masing film
    WITH r, G,
         toFloat(a.nGenres) AS na,
         toFloat(b.nGenres) AS nb,

         // Menghitung jumlah genre yang sama antara film A dan film B
         toFloat(size([x IN a.genres WHERE x IN b.genres])) AS c

    // Menghitung komponen-komponen dalam rumus korelasi Pearson
    WITH r,

         // Pembilang: G dikali jumlah genre yang sama, kemudian dikurangi hasil perkalian jumlah genre film A dan B
         (G * c - na * nb) AS pembilang,

         // Penyebut bagian A: G dikali jumlah genre film A, dikurangi kuadrat jumlah genre film A
         (G * na - na * na) AS penyebutA,

         // Penyebut bagian B: G dikali jumlah genre film B, dikurangi kuadrat jumlah genre film B
         (G * nb - nb * nb) AS penyebutB

    // Memastikan kedua bagian penyebut bernilai positif agar tidak terjadi pembagian dengan nol
    WHERE penyebutA > 0 AND penyebutB > 0

    // Menghitung nilai Pearson:
    // pembilang dibagi akar kuadrat dari perkalian penyebut A dan B
    // Hasilnya disimpan pada properti pearson di relasi SIMILAR_PEARSON
    SET r.pearson = pembilang / sqrt(penyebutA * penyebutB)

}

// Menjalankan proses dalam beberapa transaksi, dengan maksimal 10.000 baris untuk setiap transaksi
IN TRANSACTIONS OF 10000 ROWS;",26,0,false,false
"Hapus Relasi dengan Pearson < 0,1",,"MATCH ()-[r:SIMILAR_PEARSON]->()
WHERE r.pearson IS NULL OR r.pearson < 0.1
CALL (r) {
    DELETE r
} IN TRANSACTIONS OF 10000 ROWS;",27,0,false,false
Label Movie Pearson,,"MATCH (m:Movie)-[:SIMILAR_PEARSON]-()
SET m:PearsonMovie;",28,0,false,false
Distribusi Nilai Pearson,,"MATCH ()-[r:SIMILAR_PEARSON]->()
RETURN count(r) AS totalRelasi,
       min(r.pearson) AS minPearson,
       max(r.pearson) AS maxPearson,
       avg(r.pearson) AS rataPearson,
       count(CASE WHEN r.pearson <= 0 THEN 1 END) AS nonPositive;",29,0,false,false
Jumlah Movie Pearson,,"MATCH (m:PearsonMovie)
RETURN count(m) AS filmDalamGrafPearson;",30,0,false,false
Bandingkan Movie Pearson dan Jaccard,,"MATCH (a:Movie)-[r:SIMILAR_PEARSON]->(b:Movie)
OPTIONAL MATCH (a)-[j:SIMILAR_JACCARD]-(b)
RETURN a.title AS film1,
       a.genres AS genre1,
       b.title AS film2,
       b.genres AS genre2,
       r.pearson AS pearson,
       max(j.jaccard) AS jaccard
ORDER BY rand()
LIMIT 30;",31,0,false,false
Jaccard yang ada di Pearson,,"MATCH (a:Movie)-[r:SIMILAR_JACCARD]->(b:Movie)
RETURN count(r) AS totalJaccard,
       sum(CASE WHEN EXISTS { (a)-[:SIMILAR_PEARSON]-(b) }
                THEN 1 ELSE 0 END) AS jugaAdaDiPearson;",32,0,false,false
Pearson yang ada di Jaccard,,"MATCH (a:Movie)-[r:SIMILAR_PEARSON]->(b:Movie)
RETURN count(r) AS totalPearson,
       sum(CASE WHEN EXISTS { (a)-[:SIMILAR_JACCARD]-(b) }
                THEN 1 ELSE 0 END) AS jugaAdaDiJaccard;",33,0,false,false
Proyeksi Graf Jaccard,,"CALL gds.graph.project(
    'jaccardGraph',
    'JaccardMovie',
    {
        SIMILAR_JACCARD: {
            orientation: 'UNDIRECTED',
            properties: 'jaccard'
        }
    }
);",34,0,false,false
Visualisasi Similar Jaccard,,"CALL gds.graph.relationships.stream('jaccardGraph')
YIELD sourceNodeId, targetNodeId, relationshipType
WITH gds.util.asNode(sourceNodeId) AS source,
     gds.util.asNode(targetNodeId) AS target
MATCH (source)-[r:SIMILAR_JACCARD]-(target)
RETURN source, r, target
LIMIT 500;",35,0,false,false
Proyeksi Graf Pearson,,"CALL gds.graph.project(
    'pearsonGraph',
    'PearsonMovie',
    {
        SIMILAR_PEARSON: {
            orientation: 'UNDIRECTED',
            properties: 'pearson'
        }
    }
);",36,0,false,false
Visualisasi Similar Pearson,,"CALL gds.graph.relationships.stream('pearsonGraph')
YIELD sourceNodeId, targetNodeId, relationshipType
WITH gds.util.asNode(sourceNodeId) AS source,
     gds.util.asNode(targetNodeId) AS target
MATCH (source)-[r:SIMILAR_PEARSON]-(target)
RETURN source, r, target
LIMIT 500;",37,0,false,false
Degree Jaccard,,"CALL gds.degree.stats('jaccardGraph')
YIELD centralityDistribution
RETURN 'Jaccard' AS graf,
       centralityDistribution.min  AS minimum,
       centralityDistribution.max  AS maximum,
       centralityDistribution.mean AS mean,
       centralityDistribution.p50  AS median;",38,0,false,false
Degree Pearson,,"CALL gds.degree.stats('pearsonGraph')
YIELD centralityDistribution
RETURN 'Pearson' AS graf,
       centralityDistribution.min  AS minimum,
       centralityDistribution.max  AS maximum,
       centralityDistribution.mean AS mean,
       centralityDistribution.p50  AS median;",39,0,false,false
10 Film Edge Terbanyak Jaccard,,"MATCH (m:Movie)-[:SIMILAR_JACCARD]-(n:Movie)
RETURN m.title AS film,
       m.genres AS genres,
       count(DISTINCT n) AS degree
ORDER BY degree DESC
LIMIT 10;",40,0,false,false
10 Film Edge Terbanyak Pearson,,"MATCH (m:Movie)-[:SIMILAR_PEARSON]-(n:Movie)
RETURN m.title AS film,
       m.genres AS genres,
       count(DISTINCT n) AS degree
ORDER BY degree DESC
LIMIT 10;",41,0,false,false
Jaccard + Leiden,,"CALL gds.leiden.write('jaccardGraph', {
    relationshipWeightProperty: 'jaccard',
    writeProperty: 'leidenJaccard',
    randomSeed: 42,
    concurrency: 1,
    maxLevels: 10,
    gamma: 1.0,
    theta: 0.01
})
YIELD communityCount, modularity, ranLevels,
      didConverge, nodePropertiesWritten
RETURN 'Jaccard + Leiden' AS metode,
       communityCount, modularity, ranLevels,
       didConverge, nodePropertiesWritten;",42,0,false,false
Pearson + Leiden,,"CALL gds.leiden.write('pearsonGraph', {
    relationshipWeightProperty: 'pearson',
    writeProperty: 'leidenPearson',
    randomSeed: 42,
    concurrency: 1,
    maxLevels: 10,
    gamma: 1.0,
    theta: 0.01
})
YIELD communityCount, modularity, ranLevels,
      didConverge, nodePropertiesWritten
RETURN 'Pearson + Leiden' AS metode,
       communityCount, modularity, ranLevels,
       didConverge, nodePropertiesWritten;",43,0,false,false
Perbandingan Jumlah Film dan Komunitas,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
RETURN 'Jaccard + Leiden' AS metode,
       count(m) AS jumlahFilm,
       count(DISTINCT m.leidenJaccard) AS jumlahKomunitas
UNION
MATCH (m:Movie)
WHERE m.leidenPearson IS NOT NULL
RETURN 'Pearson + Leiden' AS metode,
       count(m) AS jumlahFilm,
       count(DISTINCT m.leidenPearson) AS jumlahKomunitas;",44,0,false,false
Genre Dominan Jaccard,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
  AND m.leidenPearson IS NOT NULL
WITH m.leidenJaccard AS communityId, collect(m) AS anggota
UNWIND anggota AS film
UNWIND film.genres AS genre
WITH communityId, size(anggota) AS ukuranKomunitas,
     genre, count(DISTINCT film) AS jumlahGenre
WITH communityId, max(ukuranKomunitas) AS ukuranKomunitas,
     max(jumlahGenre) AS jumlahGenreDominan
RETURN 'Jaccard + Leiden' AS metode,
       sum(jumlahGenreDominan) * 1.0 /
       sum(ukuranKomunitas) AS konsentrasiGenreDominan;",45,0,false,false
Genre Dominan Pearson,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
  AND m.leidenPearson IS NOT NULL
WITH m.leidenPearson AS communityId, collect(m) AS anggota
UNWIND anggota AS film
UNWIND film.genres AS genre
WITH communityId, size(anggota) AS ukuranKomunitas,
     genre, count(DISTINCT film) AS jumlahGenre
WITH communityId, max(ukuranKomunitas) AS ukuranKomunitas,
     max(jumlahGenre) AS jumlahGenreDominan
RETURN 'Pearson + Leiden' AS metode,
       sum(jumlahGenreDominan) * 1.0 /
       sum(ukuranKomunitas) AS konsentrasiGenreDominan;",46,0,false,false
Uji partisi Jaccard dan Pearson pada relasi Jaccard,,"MATCH (a:Movie)-[r:SIMILAR_JACCARD]->(b:Movie)
WHERE a.leidenJaccard IS NOT NULL
  AND a.leidenPearson IS NOT NULL
  AND b.leidenJaccard IS NOT NULL
  AND b.leidenPearson IS NOT NULL
RETURN 'Relasi Jaccard' AS referensi,
       sum(CASE WHEN a.leidenJaccard = b.leidenJaccard
                THEN r.jaccard ELSE 0 END) / sum(r.jaccard)
           AS kohesiPartisiJaccard,
       sum(CASE WHEN a.leidenPearson = b.leidenPearson
                THEN r.jaccard ELSE 0 END) / sum(r.jaccard)
           AS kohesiPartisiPearson;",47,0,false,false
Uji partisi Jaccard dan Pearson pada relasi Pearson,,"MATCH (a:Movie)-[r:SIMILAR_PEARSON]->(b:Movie)
WHERE a.leidenJaccard IS NOT NULL
  AND a.leidenPearson IS NOT NULL
  AND b.leidenJaccard IS NOT NULL
  AND b.leidenPearson IS NOT NULL
RETURN 'Relasi Pearson' AS referensi,
       sum(CASE WHEN a.leidenJaccard = b.leidenJaccard
                THEN r.pearson ELSE 0 END) / sum(r.pearson)
           AS kohesiPartisiJaccard,
       sum(CASE WHEN a.leidenPearson = b.leidenPearson
                THEN r.pearson ELSE 0 END) / sum(r.pearson)
           AS kohesiPartisiPearson;",48,0,false,false
Cross Community,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
  AND m.leidenPearson IS NOT NULL
RETURN m.leidenJaccard AS komunitasJaccard,
       m.leidenPearson AS komunitasPearson,
       count(*) AS jumlahFilm
ORDER BY jumlahFilm DESC;",49,0,false,false
Komunitas di Jaccard,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
RETURN m.leidenJaccard AS communityId,
       count(m) AS totalMovies
ORDER BY totalMovies DESC;",50,0,false,false
Komunitas di Pearson,,"MATCH (m:Movie)
WHERE m.leidenPearson IS NOT NULL
RETURN m.leidenPearson AS communityId,
       count(m) AS totalMovies
ORDER BY totalMovies DESC;",51,0,false,false
3 genre terbanyak pada 10 komunitas terbesar Jaccard,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
WITH m.leidenJaccard AS communityId, count(*) AS total
ORDER BY total DESC
LIMIT 10
WITH collect(communityId) AS topCommunities
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE m.leidenJaccard IN topCommunities
WITH m.leidenJaccard AS communityId,
     g.name AS genre,
     count(DISTINCT m) AS totalMovies
ORDER BY communityId, totalMovies DESC
WITH communityId,
     collect({genre: genre, total: totalMovies})[0..3] AS topGenres
RETURN communityId, topGenres
ORDER BY communityId;",52,0,false,false
3 genre terbanyak pada 10 komunitas terbesar Pearson,,"MATCH (m:Movie)
WHERE m.leidenPearson IS NOT NULL
WITH m.leidenPearson AS communityId, count(*) AS total
ORDER BY total DESC
LIMIT 10
WITH collect(communityId) AS topCommunities
MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE m.leidenPearson IN topCommunities
WITH m.leidenPearson AS communityId,
     g.name AS genre,
     count(DISTINCT m) AS totalMovies
ORDER BY communityId, totalMovies DESC
WITH communityId,
     collect({genre: genre, total: totalMovies})[0..3] AS topGenres
RETURN communityId, topGenres
ORDER BY communityId;
",53,0,false,false
Contoh Film Komunitas Terbesar Jaccard,,"MATCH (m:Movie)
WHERE m.leidenJaccard IS NOT NULL
WITH m.leidenJaccard AS communityId, count(*) AS total
// ORDER BY total DESC
LIMIT 1
MATCH (x:Movie {leidenJaccard: communityId})
RETURN communityId, x.title AS judul, x.genres AS genre
LIMIT 20;",54,0,false,false
Contoh Film Komunitas Terbesar Pearson,,"MATCH (m:Movie)
WHERE m.leidenPearson IS NOT NULL
WITH m.leidenPearson AS communityId, count(*) AS total
ORDER BY total DESC
LIMIT 1
MATCH (x:Movie {leidenPearson: communityId})
RETURN communityId, x.title AS judul, x.genres AS genre
LIMIT 20;",55,0,false,false
Tampilkan relasi Jaccard pada komunitas yang sama,,"MATCH (m1:Movie)-[r:SIMILAR_JACCARD]->(m2:Movie)
WHERE m1.leidenJaccard = m2.leidenJaccard
WITH m1.leidenJaccard AS komunitas,
     collect({a: m1, r: r, b: m2})[0..15] AS contoh
ORDER BY komunitas
// LIMIT 10
UNWIND contoh AS x
RETURN x.a AS m1, x.r AS r, x.b AS m2;",56,0,false,false
Tampilkan relasi Pearson pada komunitas yang sama,,"MATCH (m1:Movie)-[r:SIMILAR_PEARSON]->(m2:Movie)
WHERE m1.leidenPearson = m2.leidenPearson
WITH m1.leidenPearson AS komunitas,
     collect({a: m1, r: r, b: m2})[0..25] AS contoh
ORDER BY komunitas
LIMIT 10
UNWIND contoh AS x
RETURN x.a AS m1, x.r AS r, x.b AS m2;",57,0,false,false
Tampilkan Komunitas Jaccard Tertentu,,"MATCH (m1:Movie)-[r:SIMILAR_JACCARD]-(m2:Movie)
WHERE m1.leidenJaccard = 1
  AND m2.leidenJaccard = 1
RETURN m1, r, m2
LIMIT 500;",58,0,false,false
Tampilkan Komunitas Pearson Tertentu,,"MATCH (m1:Movie)-[r:SIMILAR_PEARSON]-(m2:Movie)
WHERE m1.leidenPearson = 1
  AND m2.leidenPearson = 1
RETURN m1, r, m2
LIMIT 500;",59,0,false,false