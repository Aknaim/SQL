--Question 1---------------------------------------------------------------------
--I picked query #1 because it had a consistant gets value of 20
--while query #2 had a consistant gets value of 1156
CREATE OR REPLACE VIEW CURRENT_SHAREHOLDER_SHARES
AS
SELECT 
   nvl(buy.buyer_id, sell.seller_id) AS shareholder_id,
   sh.type,
   nvl(buy.stock_id, sell.stock_id) AS  stock_id, 
   CASE nvl(buy.buyer_id, sell.seller_id)
      WHEN c.company_id THEN NULL
      ELSE nvl(buy.shares,0) - nvl(sell.shares,0)
   END AS shares
FROM (SELECT 
        t_sell.seller_id,
        t_sell.stock_id,
      sum(t_sell.shares) AS shares
      FROM trade t_sell
      WHERE t_sell.seller_id IS NOT NULL
      GROUP BY t_sell.seller_id, t_sell.stock_id) sell
  FULL OUTER JOIN
     (SELECT 
        t_buy.buyer_id,  
        t_buy.stock_id,
        sum(t_buy.shares) AS shares
      FROM trade t_buy
      WHERE t_buy.buyer_id IS NOT NULL
      GROUP BY t_buy.buyer_id, t_buy.stock_id) buy
   ON sell.seller_id = buy.buyer_id
   AND sell.stock_id = buy.stock_id
  JOIN shareholder sh
    ON sh.shareholder_id = nvl(buy.buyer_id, sell.seller_id)
  JOIN company c
    ON c.stock_id = nvl(buy.stock_id, sell.stock_id)
WHERE nvl(buy.shares,0) - nvl(sell.shares,0) != 0
ORDER BY 1,3
;
--Question 2--------------------------------------------------------------------
--I picked query #2 because it had a consistant gets value of 16
--while query #1 had a consistant gets value of 94
CREATE OR REPLACE VIEW CURRENT_STOCK_STATS
AS
SELECT
  co.stock_id,
  si.authorized current_authorized,
  SUM(DECODE(t.seller_id,co.company_id,t.shares)) 
    -NVL(SUM(CASE WHEN t.buyer_id = co.company_id 
             THEN t.shares END),0) AS total_outstanding
FROM company co
  INNER JOIN shares_authorized si
     ON si.stock_id = co.stock_id
    AND si.time_end IS NULL
  LEFT OUTER JOIN trade t
      ON t.stock_id = co.stock_id
GROUP BY co.stock_id, si.authorized
ORDER BY stock_id
;
--Question 3--------------------------------------------------------------------
SELECT
  c.name,
  css.total_outstanding,
  css.current_authorized,
  ROUND(SUM(css.total_outstanding/css.current_authorized)*100,2) AS percent_of_authorized_shares
  FROM company c
    JOIN current_stock_stats css
      ON c.stock_id = css.stock_id
GROUP BY c.name, css.total_outstanding, css.current_authorized
ORDER BY css.total_outstanding DESC
;
--Question 4--------------------------------------------------------------------
--SELECT * FROM shareholder;
--SELECT * FROM company;
--SELECT * FROM direct_holder;
SELECT
  --*
  dh.first_name,   --|| ' '  || 
  dh.last_name, --AS direct_holder_name,
  c.name,
  css.shares,
  ROUND(SUM(css.shares/cst.total_outstanding)*100,2) AS perc_outstanding_shares,
  ROUND(SUM(css.shares/cst.current_authorized)*100,2) AS perc_total_authorized_shares
  FROM direct_holder dh
    JOIN current_shareholder_shares css
      ON dh.direct_holder_id = css.shareholder_id
    JOIN company c
      ON css.stock_id = c.stock_id
    JOIN current_stock_stats cst
      ON cst.stock_id = c.stock_id
GROUP BY dh.first_name, dh.last_name, c.name, css.shares
ORDER BY dh.last_name, dh.first_name, c.name
;
--Question 5--------------------------------------------------------------------
SELECT * FROM company;
SELECT * FROM current_shareholder_shares;
SELECT
  --*
  c.name,
  cc.name,
  css.shares,
  ROUND(SUM(css.shares/cst.total_outstanding)*100,2) AS perc_outstanding_shares,
  ROUND(SUM(css.shares/cst.current_authorized)*100,2) AS perc_total_authorized_shares
  FROM company c
    JOIN current_shareholder_shares css --see what stocks the company holds using the company_id
      ON c.company_id = css.shareholder_id 
    JOIN company cc --see what companies are invested in by the original company
      ON css.stock_id = cc.stock_id
      AND c.name != cc.name --remove treasury shares
    JOIN current_stock_stats cst --check current share stats on the currently HELD shares by the original company
      ON css.stock_id = cst.stock_id
GROUP BY c.name, cc.name, css.shares
ORDER BY c.name, cc.name
;
--Question 6--------------------------------------------------------------------
SELECT * FROM trade;
SELECT * FROM stock_exchange;
SELECT
--  *
  t.trade_id,
  sl.stock_symbol,
  c.name AS company_name,
  se.symbol AS stock_exchange_symbol,
  t.shares,
  t.price_total,
  cur.symbol
  FROM trade t
    JOIN company c
      ON t.stock_id = c.stock_id
    JOIN stock_listing sl
      ON t.stock_id = sl.stock_id -- do both stock_id and stock_ex_id as they are a composite primary key
      AND t.stock_ex_id = sl.stock_ex_id
    JOIN stock_exchange se
      ON t.stock_ex_id = se.stock_ex_id
    JOIN currency cur
      ON cur.currency_id = se.currency_id
WHERE t.shares > 50000 AND (t.stock_ex_id IS NOT null)
;
--Question 7--------------------------------------------------------------------
SELECT * FROM stock_exchange;
SELECT * FROM stock_listing;

SELECT
--  *
  t.stock_id,
  se.name AS stock_exchange_name,
  sl.stock_symbol,
  TO_CHAR(MAX(t.transaction_time),'YYYY-MM-DD HH:MI:SSAM') AS date_and_time
  FROM stock_listing sl
    JOIN stock_exchange se
      ON sl.stock_ex_id = se.stock_ex_id
    LEFT JOIN trade t  --left join so that you show all stock even those not being traded
      ON t.stock_id = sl.stock_id  --primary composite key so join on both
      AND t.stock_ex_id = sl.stock_ex_id
  GROUP BY t.stock_id,se.name,sl.stock_symbol
  ORDER BY se.name, sl.stock_symbol
;

--SELECT 
--  sl.stock_symbol,
--  se.name
--FROM stock_exchange se
--  JOIN stock_listing sl
--    ON se.stock_ex_id = sl.stock_ex_id;
--  WHERE t.transaction_time = 
--  (
--    SELECT -- find the max transaction time for each stock (i.e. max date)
--      t.stock_id,
--      MAX(t.transaction_time) as latest_trade_date
--      FROM trade t
--      --WHERE t.stock_id = sl.stock_id
--    GROUP BY t.stock_id;
--  )
--WHERE t.trade_id IS null SET t.trade_id = 'NULL'
--GROUP BY MAX(t.transaction_time)
--ORDER BY t.stock_id, se.name, sl.stock_symbol, t.transaction_time
--;
--Question 8--------------------------------------------------------------------
SELECT
  --*
  t.trade_id,
  c.name,
  t.shares
  FROM trade t
    JOIN company c
      ON t.stock_id = c.stock_id
    AND t.shares = 
    (SELECT MAX(t.shares)
     FROM trade t
     WHERE t.stock_ex_id IS NOT NULL
    )
WHERE t.stock_ex_id IS NOT NULL
ORDER BY t.shares DESC
;
--Question 9--------------------------------------------------------------------
SELECT * FROM shareholder;
SELECT * FROM direct_holder;
SELECT * FROM company;

INSERT INTO shareholder VALUES (26, 'Direct_Holder');
INSERT INTO direct_holder VALUES (26, 'Jeff', 'Adams');
--ROLLBACK;

--Question 10-------------------------------------------------------------------
SELECT * FROM shareholder;
SELECT * FROM company;
SELECT * FROM place;

INSERT INTO shareholder VALUES (27, 'Company');
INSERT INTO company (company_id,name,place_id)VALUES (27,'Makoto Investing',4);

--Question 11-------------------------------------------------------------------
SELECT * FROM shareholder;
SELECT * FROM company;
SELECT * FROM shares_authorized;
SELECT * FROM currency;

UPDATE company SET starting_price=50,stock_id=9,currency_id=5 WHERE company_id=27;
INSERT INTO shares_authorized (stock_id, time_start, authorized) VALUES (9,sysdate,100000);
ROLLBACK;

--Question 12-------------------------------------------------------------------
SELECT * FROM stock_listing;
SELECT * FROM stock_price
ORDER BY stock_ex_id DESC;
SELECT * FROM stock_exchange;

INSERT INTO stock_listing (stock_ex_id, stock_id, stock_symbol) VALUES (4,9,Makoto);
INSERT INTO stock_price (stock_ex_id, stock_id, time_start, price) VALUES (4,9,sysdate,50);

--Question 13-------------------------------------------------------------------

DROP SEQUENCE shareholder_id; --drop old shareholder_id sequence
CREATE SEQUENCE shareholder_id --create a shareholder_id sequence
   INCREMENT BY 1
   START WITH 28
;

CREATE OR REPLACE PROCEDURE INSERT_DIRECT_HOLDER 
  (p_first_name IN direct_holder.first_name%TYPE, --set procedure var to dh var type
   p_last_name IN direct_holder.last_name%TYPE) --set procedure var to dh var type
   --p_type IN shareholder.type%TYPE)    --set procedure var to dh var type
AS
BEGIN
  INSERT INTO shareholder   
   (shareholder_id, type) -- insert into shareholder_id the next id number, and into type the name
   VALUES
   (shareholder_id.NEXTVAL, 'Direct_Holder');
  INSERT INTO direct_holder
   (direct_holder_id, first_name, last_name)
   VALUES
   (shareholder_id.CURRVAL, p_first_name, p_last_name);
END;
/


SHOW ERRORS PROCEDURE INSERT_DIRECT_HOLDER;
EXEC insert_direct_holder ('Bob', 'Dunne');

SELECT * FROM shareholder;
SELECT * FROM direct_holder;

--Question 14-------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE INSERT_COMPANY
  (p_name IN company.name%TYPE, --set procedure var type
   p_city IN place.city%TYPE, --set procedure var type
   p_country IN place.country%TYPE)  --set procedure var type
AS
  l_place_id place.place_id%TYPE;
BEGIN
  SELECT
    place.place_id INTO l_place_id
    FROM place
    WHERE p_city = place.city AND p_country = place.country;
  INSERT INTO shareholder
   (shareholder_id, type) -- insert into shareholder_id the next id number, and into type the name
  VALUES
   (shareholder_id.NEXTVAL, 'Company');
  INSERT INTO company
   (company_id, name, place_id)
   VALUES
   (shareholder_id.CURRVAL, p_name, l_place_id);
END;
/

SHOW ERRORS PROCEDURE INSERT_COMPANY;
EXEC insert_company ('Bob the Builder', 'Moscow', 'Russia');

SELECT * FROM shareholder;
SELECT * FROM company;
SELECT * FROM direct_holder;
ROLLBACK;

--Question 15-------------------------------------------------------------------

DROP SEQUENCE stock_id; --drop old shareholder_id sequence
CREATE SEQUENCE stock_id --create a shareholder_id sequence
   INCREMENT BY 1
   START WITH 10
;

CREATE OR REPLACE PROCEDURE DECLARE_STOCK
  (p_name IN company.name%TYPE,                       --set procedure var type
   p_shares_ath IN shares_authorized.authorized%TYPE, --set procedure var type
   p_start_price IN company.starting_price%TYPE,      --set procedure var type
   p_currency_name IN currency.name%TYPE)             --set procedure var type
AS
  l_currency_id currency.currency_id%TYPE;            --set l_currency_id to currency_id TYPE
  l_stock_ex_id stock_exchange.stock_ex_id%TYPE;      --set l_stock_ex_id to stock_ex_id
  l_stock_id company.stock_id%TYPE;                   --set l_stock_id to stock_id TYPE
BEGIN
  SELECT                                              --take currency_id and put it into l_currency_id after making sure the currency name matches
      currency.currency_id INTO l_currency_id
      FROM currency 
      WHERE p_currency_name = currency.name;
  UPDATE company
     SET stock_id = stock_id.NEXTVAL, starting_price = p_start_price, currency_id = l_currency_id               --update the start price into company the start_price and currency_id
     WHERE name = 'Bob the Builder';
  INSERT INTO shares_authorized                       --insert the shares authorized into the authorized table the stock_id, time_start, and shares
     (stock_id,time_start,authorized)         
     VALUES
     (stock_id.CURRVAL, sysdate, p_shares_ath);
END;
/

SHOW ERRORS PROCEDURE DECLARE_STOCK;
EXEC DECLARE_STOCK ('Bob the Builder',10000,50,'Euro');
ROLLBACK;

SELECT * FROM shareholder;
SELECT * FROM company;
SELECT * FROM stock_listing;
SELECT * FROM stock_exchange;
SELECT * FROM direct_holder;
SELECT * FROM shares_authorized;
SELECT * FROM currency; --need to add condition if stock_id exists already

--Question 16-------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE LIST_STOCK
  (p_stock_id IN stock_listing.stock_id%TYPE,
   p_stock_ex_id IN stock_listing.stock_ex_id%TYPE,
   p_stock_symbol IN stock_listing.stock_symbol %TYPE
  )
AS
  l_starting_price company.starting_price%TYPE;
  l_company_name company.name%TYPE;
BEGIN
  INSERT INTO stock_listing
   (stock_id, stock_ex_id, stock_symbol) -- insert into shareholder_id the next id number, and into type the name
   VALUES
   (p_stock_id, p_stock_ex_id, p_stock_symbol);
   SELECT company.starting_price INTO l_starting_price
    FROM company
    WHERE company.stock_id = p_stock_id;
  INSERT INTO stock_price
    (stock_ex_id,stock_id,time_start,price)
    VALUES (p_stock_ex_id,p_stock_id,sysdate,l_starting_price);
END;
/

SHOW ERRORS PROCEDURE LIST_STOCK;
EXEC LIST_STOCK (7,4,'GLOP'); --need to convert currencies

SELECT * FROM shareholder;
SELECT * FROM direct_holder;
SELECT * FROM company;
SELECT * FROM stock_listing;
SELECT * FROM stock_price;

--Question 19-------------------------------------------------------------------
SELECT * FROM broker;

SELECT
  --*
  t.trade_id,
  t.stock_id,
  round(SUM(price_total * exchange_rate),2) AS "Total"
FROM trade t
   JOIN stock_exchange se
    ON se.stock_ex_id = t.stock_ex_id
  JOIN conversion con
    ON con.from_currency_id = se.currency_id
      AND con.to_currency_id = 1
GROUP BY t.trade_id, t.stock_id
ORDER BY "Total" DESC
; --need to select the largest trade









