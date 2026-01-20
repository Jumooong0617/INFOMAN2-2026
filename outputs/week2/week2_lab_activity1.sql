
-- ACTIVITY 1
CREATE OR REPLACE FUNCTION public.get_flight_duration(p_flight_id integer)
RETURNS INTERVAL AS $$

DECLARE
   flight_duration INTERVAL;

BEGIN
    SELECT arrival_time - departure_time
    INTO flight_duration
    FROM flights
    WHERE flight_id = p_flight_id;

    RETURN flight_duration;
END;
$$ LANGUAGE plpgsql;

-- ACTIVITY 2
CREATE OR REPLACE FUNCTION get_price_category(p_flight_id integer)
RETURNS text AS $$

DECLARE var_base_price NUMERIC;

BEGIN
	SELECT base_price
	INTO var_base_price	
	FROM flights
	WHERE flight_id = p_flight_id;

	IF var_base_price < 300 THEN
		RETURN 'BUDGET';
	ELSEIF var_base_price > 800 THEN
		RETURN 'PREMIUM';
	ELSE 
		RETURN 'STANDARD';
	END IF;
END;
$$  LANGUAGE plpgsql;

-- ACTUVUTY 3
CREATE OR REPLACE PROCEDURE book_flight(
    p_passenger_id INT,
    p_flight_id INT,
    p_seat_number VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO bookings (
        passenger_id,
        flight_id,
        seat_number,
        status,
        booking_date
    )
    VALUES (
        p_passenger_id,
        p_flight_id,
        p_seat_number,
        'Confirmed',
        CURRENT_DATE
    );
END;
$$;

-- ACTIVITY 4
CREATE OR REPLACE PROCEDURE increase_prices_for_airline(p_airline_id NUMERIC, p_percentage_increase NUMERIC)
AS $$
DECLARE
	increased_price RECORD;
BEGIN

	FOR increased_price IN SELECT flight_id, base_price FROM flights WHERE airline_id = p_airline_id LOOP
		UPDATE flights
		SET base_price = base_price * (1 + p_percentage_increase / 100)
		WHERE flight_id = increased_price.flight_id;
	END LOOP;

END;

$$ LANGUAGE plpgsql;