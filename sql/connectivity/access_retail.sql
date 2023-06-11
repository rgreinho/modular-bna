----------------------------------------
-- Input variables:
--      :max_score - Maximum score value
--      :first - Value of first available destination (if 0 then ignore--a basic ratio is used for the score)
--      :second - Value of second available destination (if 0 then ignore--a basic ratio is used after 1)
--      :third - Value of third available destination (if 0 then ignore--a basic ratio is used after 2)
----------------------------------------
-- set block-based raw numbers
UPDATE  neighborhood_census_blocks
SET     retail_low_stress = (
            SELECT  COUNT(id)
            FROM    neighborhood_retail
            WHERE   EXISTS (
                        SELECT  1
                        FROM    neighborhood_connected_census_blocks
                        WHERE   neighborhood_connected_census_blocks.source_blockid10 = neighborhood_census_blocks.blockid10
                        AND     neighborhood_connected_census_blocks.target_blockid10 = ANY(neighborhood_retail.blockid10)
                        AND     neighborhood_connected_census_blocks.low_stress
                    )
        ),
        retail_high_stress = (
            SELECT  COUNT(id)
            FROM    neighborhood_retail
            WHERE   EXISTS (
                        SELECT  1
                        FROM    neighborhood_connected_census_blocks
                        WHERE   neighborhood_connected_census_blocks.source_blockid10 = neighborhood_census_blocks.blockid10
                        AND     neighborhood_connected_census_blocks.target_blockid10 = ANY(neighborhood_retail.blockid10)
                    )
        )
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary AS b
            WHERE   ST_Intersects(neighborhood_census_blocks.geom,b.geom)
        );

-- set block-based score
UPDATE  neighborhood_census_blocks
SET     retail_score =  CASE
                        WHEN retail_high_stress IS NULL THEN NULL
                        WHEN retail_high_stress = 0 THEN NULL
                        WHEN retail_low_stress = 0 THEN 0
                        WHEN retail_high_stress = retail_low_stress THEN :max_score
                        WHEN :first = 0 THEN retail_low_stress::FLOAT / retail_high_stress
                        WHEN :second = 0
                            THEN    :first
                                    + ((:max_score - :first) * (retail_low_stress::FLOAT - 1))
                                    / (retail_high_stress - 1)
                        WHEN :third = 0
                            THEN    CASE
                                    WHEN retail_low_stress = 1 THEN :first
                                    WHEN retail_low_stress = 2 THEN :first + :second
                                    ELSE :first + :second
                                            + ((:max_score - :first - :second) * (retail_low_stress::FLOAT - 2))
                                            / (retail_high_stress - 2)
                                    END
                        ELSE        CASE
                                    WHEN retail_low_stress = 1 THEN :first
                                    WHEN retail_low_stress = 2 THEN :first + :second
                                    WHEN retail_low_stress = 3 THEN :first + :second + :third
                                    ELSE :first + :second + :third
                                            + ((:max_score - :first - :second - :third) * (retail_low_stress::FLOAT - 3))
                                            / (retail_high_stress - 3)
                                    END
                        END;

-- set population shed for each retail destination in the neighborhood
UPDATE  neighborhood_retail
SET     pop_high_stress = (
            SELECT  SUM(shed.pop)
            FROM    ( 
                    SELECT  cb.blockid10, MAX(cb.pop10) as pop 
                    FROM    neighborhood_census_blocks cb,
                            neighborhood_connected_census_blocks cbs
                    WHERE   cbs.source_blockid10 = cb.blockid10
                    AND     cbs.target_blockid10 = ANY(neighborhood_retail.blockid10)
                    GROUP BY cb.blockid10) as shed
        ),
        pop_low_stress = (
            SELECT  SUM(shed.pop)
            FROM    (
                    SELECT  cb.blockid10, MAX(cb.pop10) as pop
                    FROM    neighborhood_census_blocks cb,
                            neighborhood_connected_census_blocks cbs
                    WHERE   cbs.source_blockid10 = cb.blockid10
                    AND     cbs.target_blockid10 = ANY(neighborhood_retail.blockid10)
                    AND     cbs.low_stress
                    GROUP BY cb.blockid10) as shed
        )
WHERE   EXISTS (
            SELECT  1
            FROM    neighborhood_boundary as b
            WHERE   ST_Intersects(neighborhood_retail.geom_poly,b.geom)
        );

UPDATE  neighborhood_retail
SET     pop_score = CASE    WHEN pop_high_stress IS NULL THEN NULL
                            WHEN pop_high_stress = 0 THEN 0
                            ELSE pop_low_stress::FLOAT / pop_high_stress
                            END;
