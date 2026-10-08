-- Functions for the ER diagram and tables -- need to be added way more 
-- DROP FUNCTION "restaurantsApplication".calculate_check_paid(int8);

CREATE OR REPLACE FUNCTION "restaurantsApplication".calculate_check_paid(p_check_id bigint)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_paid NUMERIC(12,2);
BEGIN
    SELECT COALESCE(
        SUM(amount),
        0
    )
    INTO v_paid
    FROM payment
    WHERE check_id = p_check_id
      AND status = 'COMPLETED';

    RETURN ROUND(v_paid, 2);
END;
$function$
;
--
-- DROP FUNCTION "restaurantsApplication".calculate_order_total(int8);

CREATE OR REPLACE FUNCTION "restaurantsApplication".calculate_order_total(p_order_id bigint)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(
        SUM(quantity * unit_price),
        0
    )
    INTO v_total
    FROM order_item
    WHERE order_id = p_order_id;

    RETURN ROUND(v_total, 2);
END;
$function$
;
-- DROP FUNCTION "restaurantsApplication".expire_past_reservations();

CREATE OR REPLACE FUNCTION "restaurantsApplication".expire_past_reservations()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
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
$function$
;
-- DROP FUNCTION "restaurantsApplication".is_check_reconciled(int8);

CREATE OR REPLACE FUNCTION "restaurantsApplication".is_check_reconciled(p_check_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total NUMERIC(12,2);
    v_paid  NUMERIC(12,2);
BEGIN

    SELECT total_amount
    INTO v_total
    FROM restaurant_check
    WHERE id = p_check_id;

    v_paid := calculate_check_paid(p_check_id);

    RETURN v_paid = v_total;

END;
$function$
;
-- DROP FUNCTION "restaurantsApplication".mock_id(varchar, int4);

CREATE OR REPLACE FUNCTION "restaurantsApplication".mock_id(p_prefix character varying, p_size integer)
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN p_prefix || '_' ||
           substring(md5(random()::text), 1, p_size);
END;
$function$
;
-- DROP FUNCTION "restaurantsApplication".mock_text(int4, int4);
CREATE OR REPLACE FUNCTION "restaurantsApplication".mock_text(p_min integer, p_max integer)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_text TEXT := '';
    v_length INTEGER;
BEGIN
    v_length := p_min +
                floor(random() * (p_max - p_min + 1))::INTEGER;

    WHILE length(v_text) < v_length LOOP
        v_text := v_text || ' ' ||
                  substring(
                      md5(random()::text),
                      1,
                      1 + floor(random() * 9)::INTEGER
                  );
    END LOOP;

    RETURN trim(left(v_text, v_length));
END;
$function$
;
