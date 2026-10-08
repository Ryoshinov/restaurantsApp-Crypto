select * from dining_session ds ;

select * from restaurant r ;


CREATE OR REPLACE FUNCTION expire_past_reservations()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Mark past PENDING/CONFIRMED reservations as NO_SHOW if past end_time
    UPDATE reservation
    SET 
        status = 'NO_SHOW',
        updated_at = CURRENT_TIMESTAMP
    WHERE 
        status IN ('PENDING', 'CONFIRMED')
        AND (end_time < CURRENT_TIMESTAMP OR (end_time IS NULL AND start_time + interval '2 hours' < CURRENT_TIMESTAMP));

    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql;
select expire_past_reservations();

select * from payment p ;