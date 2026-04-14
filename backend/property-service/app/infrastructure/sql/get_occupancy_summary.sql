-- Function: property.get_occupancy_summary
-- Returns per-property occupancy counts and rate.
-- Applied by migration: 002_create_occupancy_function.py

CREATE OR REPLACE FUNCTION property.get_occupancy_summary(p_property_id UUID)
RETURNS TABLE (
    total_units       INT,
    occupied          INT,
    vacant            INT,
    under_maintenance INT,
    occupancy_rate    NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE status = 'OCCUPIED')::INT,
        COUNT(*) FILTER (WHERE status = 'VACANT')::INT,
        COUNT(*) FILTER (WHERE status = 'UNDER_MAINTENANCE')::INT,
        ROUND(
            COUNT(*) FILTER (WHERE status = 'OCCUPIED') * 100.0 / NULLIF(COUNT(*), 0),
            2
        )
    FROM property.units
    WHERE property_id = p_property_id;
END;
$$ LANGUAGE plpgsql;
