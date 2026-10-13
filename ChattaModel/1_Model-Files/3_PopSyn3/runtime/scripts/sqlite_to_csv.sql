.headers on
.mode csv
.nullvalue 0

-- Change output directory once
.cd intermediate

-- -----------------------------------------------------------------------
-- Truncation rule (mirrors coerce_output_data.bat):
--   Any numeric field with 10+ digits -> keep last 9 digits (val % 1e9)
--   NULL integer fields -> 0
-- -----------------------------------------------------------------------

.once control_totals_maz.csv
WITH mz_id_source AS (
    SELECT MZ_ID AS exact_mz_id FROM control_totals_maz
    UNION
    SELECT MZ_ID AS exact_mz_id FROM geographicCWalk
),
mz_id_map AS (
    SELECT
        exact_mz_id,
        ROW_NUMBER() OVER (ORDER BY exact_mz_id) AS MZ_ID
    FROM mz_id_source
)
SELECT
    control.HH,
    control.POPGQ,
    control.POPNGQ,
    control.POP,
    control.MAZ,
    control.TAZ,
    control.PUMA,
    control.REGION
FROM control_totals_maz AS control
JOIN mz_id_map AS map ON map.exact_mz_id = control.MZ_ID
ORDER BY control.MAZ;

.once control_totals_taz.csv
WITH tract_id_source AS (
    SELECT GEOID10_tract AS exact_geoid10_tract
    FROM control_totals_taz
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM FINAL_TAZ_PUMA_MAPPING
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM geographicCWalk
    WHERE GEOID10_tract IS NOT NULL
),
tract_id_map AS (
    SELECT
        exact_geoid10_tract,
        ROW_NUMBER() OVER (ORDER BY exact_geoid10_tract) AS GEOID10_tract
    FROM tract_id_source
)
SELECT
    map.GEOID10_tract,
    control.HHSIZE1,
    control.HHSIZE2,
    control.HHSIZE3,
    control.HHSIZE4PLUS,
    control.INCOME_25K,
    control.INCOME_50K,
    control.INCOME_75K,
    control.INCOME_100K,
    control.INCOME_100KPLUS,
    control.WORKERS_0,
    control.WORKERS_1,
    control.WORKERS_2,
    control.WORKERS_3PLUS,
    control.HHWCHILD,
    control.HHWOCHILD,
    control.NGQ0TO17,
    control.NGQ18TO34,
    control.NGQ35TO64,
    control.NGQ65PLUS,
    control.FemaleNGQ,
    control.MaleNGQ,
    control.TAZ,
    control.PUMA,
    control.REGION
FROM control_totals_taz AS control
JOIN tract_id_map AS map ON map.exact_geoid10_tract = control.GEOID10_tract
ORDER BY control.TAZ;

.once control_totals_meta.csv
SELECT
    COALESCE(REGION,  0) AS REGION,
    COALESCE(POPGQ,   0) AS POPGQ,
    COALESCE(POPNGQ,  0) AS POPNGQ
FROM control_totals_meta;

.once FINAL_TAZ_PUMA_MAPPING.csv
WITH tract_id_source AS (
    SELECT GEOID10_tract AS exact_geoid10_tract
    FROM control_totals_taz
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM FINAL_TAZ_PUMA_MAPPING
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM geographicCWalk
    WHERE GEOID10_tract IS NOT NULL
),
tract_id_map AS (
    SELECT
        exact_geoid10_tract,
        ROW_NUMBER() OVER (ORDER BY exact_geoid10_tract) AS GEOID10_tract
    FROM tract_id_source
)
SELECT
    map.GEOID10_tract,
    final.PUMA,
    final.STATE,
    final.tazpumapop,
    final.tazpop
FROM FINAL_TAZ_PUMA_MAPPING final
JOIN tract_id_map AS map ON map.exact_geoid10_tract = final.GEOID10_tract
ORDER BY map.GEOID10_tract, final.PUMA, final.STATE;

.once geographicCWalk.csv
WITH mz_id_source AS (
    SELECT MZ_ID AS exact_mz_id FROM control_totals_maz
    UNION
    SELECT MZ_ID AS exact_mz_id FROM geographicCWalk
),
mz_id_map AS (
    SELECT
        exact_mz_id,
        ROW_NUMBER() OVER (ORDER BY exact_mz_id) AS MZ_ID
    FROM mz_id_source
),
tract_id_source AS (
    SELECT GEOID10_tract AS exact_geoid10_tract
    FROM control_totals_taz
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM FINAL_TAZ_PUMA_MAPPING
    WHERE GEOID10_tract IS NOT NULL
    UNION
    SELECT GEOID10_tract
    FROM geographicCWalk
    WHERE GEOID10_tract IS NOT NULL
),
tract_id_map AS (
    SELECT
        exact_geoid10_tract,
        ROW_NUMBER() OVER (ORDER BY exact_geoid10_tract) AS GEOID10_tract
    FROM tract_id_source
)
SELECT
    crosswalk.TZ_ID,
    crosswalk.STATE,
    crosswalk.STATEFP10,
    crosswalk.COUNTY,
    crosswalk.COUNTYFP10,
    tract_map.GEOID10_tract,
    crosswalk.TRACTCE10,
    crosswalk.GEOID10_block,
    crosswalk.BLOCKCE10,
    crosswalk.PUMA2000,
    crosswalk.PUMACE2010,
    crosswalk.AFFGEOID10,
    crosswalk.GEOID10_PUMA10,
    crosswalk.REGION,
    crosswalk.PUMA,
    crosswalk.MAZ,
    crosswalk.TAZ,
    crosswalk.MZ_ID AS EXACT_MZ_ID,
    crosswalk.GEOID10_tract AS EXACT_GEOID10_tract
FROM geographicCWalk AS crosswalk
JOIN mz_id_map AS map ON map.exact_mz_id = crosswalk.MZ_ID
JOIN tract_id_map AS tract_map ON tract_map.exact_geoid10_tract = crosswalk.GEOID10_tract
ORDER BY crosswalk.MAZ;

.once psam_h11.csv
SELECT * FROM psam_h11;

.once psam_p11.csv
SELECT * FROM psam_p11;

-- hhtable preserves its generated values. SQLite may omit insignificant trailing
-- zeroes from decimal values, e.g. 103725.10 becomes 103725.1.
.once hhtable.csv
SELECT
    PUMA, WGTP, GQWGTP, SERIALNO, DIVISION, NP,
    CAST(ROUND(hhincAdj, 0) AS INT) AS hhincAdj,
    NULLIF(TEN, '') AS TEN, NULLIF(BLD, '') AS BLD, nwrkrs_esr, ADJINC,
    NULLIF(HINCP, '') AS HINCP, NULLIF(VEH, '') AS VEH,
    NULLIF(HHT, '') AS HHT, TYPE, NULLIF(NPF, '') AS NPF,
    NULLIF(HUPAC, '') AS HUPAC, gqflag,
    gqtype, htype, hhchild, hhnum
FROM hhtable
-- WHERE TYPE < 3
ORDER BY hhnum;


-- .once hhtableGQ.csv
-- SELECT
--     PUMA, WGTP, GQWGTP, SERIALNO, DIVISION, NP,
--     CAST(ROUND(hhincAdj, 0) AS INT) AS hhincAdj,
--     NULLIF(TEN, '') AS TEN, NULLIF(BLD, '') AS BLD, nwrkrs_esr, ADJINC,
--     NULLIF(HINCP, '') AS HINCP, NULLIF(VEH, '') AS VEH,
--     NULLIF(HHT, '') AS HHT, TYPE, NULLIF(NPF, '') AS NPF,
--     NULLIF(HUPAC, '') AS HUPAC, gqflag,
--     gqtype, htype, hhchild, hhnum
-- FROM hhtable
-- WHERE TYPE > 2
-- ORDER BY hhnum;


-- Retain generated string codes (including leading zeroes such as 0170) and
-- export in deterministic household/person order.
.output perstable.csv
SELECT
    NULLIF(p.PUMA, '') AS PUMA, NULLIF(p.WGTP, '') AS WGTP,
    NULLIF(p.GQWGTP, '') AS GQWGTP, NULLIF(p.SERIALNO, '') AS SERIALNO,
    NULLIF(p.SPORDER, '') AS SPORDER, NULLIF(p.AGEP, '') AS AGEP,
    NULLIF(p.SEX, '') AS SEX, NULLIF(p.WKHP, '') AS WKHP,
    NULLIF(p.COW, '') AS COW, NULLIF(p.ESR, '') AS ESR,
    NULLIF(p.SCHG, '') AS SCHG, NULLIF(p.employed, '') AS employed,
    NULLIF(p.WKW, '') AS WKW, NULLIF(p.MIL, '') AS MIL,
    NULLIF(p.SCHL, '') AS SCHL, NULLIF(p.indp02, '') AS indp02,
    NULLIF(p.indp07, '') AS indp07, NULLIF(p.occp02, '') AS occp02,
    NULLIF(p.occp10, '') AS occp10, NULLIF(p.socp00, '') AS socp00,
    NULLIF(p.socp10, '') AS socp10, NULLIF(p.gqflag, '') AS gqflag,
    NULLIF(p.gqtype, '') AS gqtype, NULLIF(p.soc, '') AS soc,
    NULLIF(p.occp, '') AS occp, NULLIF(p.hhnum, '') AS hhnum
FROM perstable p
-- WHERE p.gqflag = 0
ORDER BY p.hhnum, p.SPORDER;

-- .once perstableGQ.csv
-- SELECT
--     NULLIF(p.PUMA, '') AS PUMA, NULLIF(p.WGTP, '') AS WGTP,
--     NULLIF(p.GQWGTP, '') AS GQWGTP, NULLIF(p.SERIALNO, '') AS SERIALNO,
--     NULLIF(p.SPORDER, '') AS SPORDER, NULLIF(p.AGEP, '') AS AGEP,
--     NULLIF(p.SEX, '') AS SEX, NULLIF(p.WKHP, '') AS WKHP,
--     NULLIF(p.COW, '') AS COW, NULLIF(p.ESR, '') AS ESR,
--     NULLIF(p.SCHG, '') AS SCHG, NULLIF(p.employed, '') AS employed,
--     NULLIF(p.WKW, '') AS WKW, NULLIF(p.MIL, '') AS MIL,
--     NULLIF(p.SCHL, '') AS SCHL, NULLIF(p.indp02, '') AS indp02,
--     NULLIF(p.indp07, '') AS indp07, NULLIF(p.occp02, '') AS occp02,
--     NULLIF(p.occp10, '') AS occp10, NULLIF(p.socp00, '') AS socp00,
--     NULLIF(p.socp10, '') AS socp10, NULLIF(p.gqflag, '') AS gqflag,
--     NULLIF(p.gqtype, '') AS gqtype, NULLIF(p.soc, '') AS soc,
--     NULLIF(p.occp, '') AS occp, NULLIF(p.hhnum, '') AS hhnum
-- FROM perstable p
-- WHERE p.gqflag = 1
-- ORDER BY p.hhnum, p.SPORDER;

.output stdout