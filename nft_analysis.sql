Most Active Collectors 
SELECT u.username,u.user_id,
COUNT(DISTINCT(t.nft_id)) AS total_nft,
AVG(t.sale_price) AS avg_purchase
FROM transactions t
LEFT JOIN users u ON t.to_user_id = u.user_id
WHERE t.from_user_id IS NOT NULL
GROUP BY u.username,u.user_id
ORDER BY total_nft DESC
LIMIT 5;

Collection performance collectors
WITH avg_collection AS (
SELECT 
c.name AS collection_name,
AVG(t.sale_price) AS avg_per_collection
FROM collections c
LEFT JOIN nfts n ON c.collection_id = n.collection_id
LEFT JOIN transactions t ON t.nft_id = n.nft_id
WHERE t.from_user_id IS NOT NULL
GROUP BY c.name
),
market_place_avg AS(
SELECT AVG(sale_price) AS overall_avg 
FROM transactions WHERE from_user_id IS NOT NULL)
SELECT 
ca.collection_name,
ca.avg_per_collection,
ma.overall_avg AS marketplace_avg,
(ma.overall_avg - ca.avg_per_collection) AS difference
FROM avg_collection ca
CROSS JOIN market_place_avg ma
ORDER BY difference DESC;

Artist Revenue Breakdown
WITH initial_sale AS(
SELECT a.artist_id, a.username, SUM(t.sale_price) AS total_initial_sale
FROM artists a
JOIN collections c ON a.artist_id = c.artist_id
JOIN nfts n ON n.collection_id = c.collection_id
JOIN transactions t ON n.nft_id = t.nft_id
WHERE t.from_user_id IS NULL
GROUP BY a.artist_id, a.username),
secondary_sale AS (
SELECT a.artist_id, SUM(t.royalty_fee) AS total_secondary_sale
FROM artists a
JOIN collections c ON a.artist_id = c.artist_id
JOIN nfts n ON n.collection_id = c.collection_id
JOIN transactions t ON n.nft_id = t.nft_id
WHERE t.from_user_id IS NOT NULL
GROUP BY a.artist_id)
SELECT 
i.artist_id,
COALESCE(i.total_initial_sale,0), COALESCE(ss.total_secondary_sale,0),
COALESCE(i.total_initial_sale,0) + COALESCE(ss.total_secondary_sale,0) AS total_revenue
FROM initial_sale i
LEFT JOIN secondary_sale ss ON i.artist_id = ss.artist_id
ORDER BY total_revenue DESC;


Total sales volume
SELECT a.artist_id, a.username, a.verification_status,
a.total_sales_volume AS total_revenue_by_artists, COUNT(c.collection_id) AS total_collection
FROM artists a 
INNER JOIN collections c ON a.artist_id = c.artist_id
GROUP BY a.artist_id, a.username, a.verification_status
LIMIT 3;


Price appreciation Subquery
WITH new_price AS (
SELECT 
nft_id, sale_price, transaction_date,
LAG(sale_price) OVER (PARTITION BY nft_id ORDER BY transaction_date) AS prev_price
FROM transactions
WHERE from_user_id IS NOT NULL
)
SELECT nft_id, prev_price, sale_price,
ROUND(((sale_price - prev_price)/ prev_price * 100),1)AS price_appreciation_pct
FROM new_price
WHERE prev_price IS NOT NULL
ORDER BY price_appreciation_pct DESC;

Collection popularity 
WITH collection_unique AS (
SELECT c.collection_id, c.name,
COUNT(n.nft_id) AS unique_nft, 
COUNT(DISTINCT(o.owner_id)) AS unique_owner
FROM collections c
LEFT JOIN nfts n ON n.collection_id = c.collection_id
LEFT JOIN nft_ownership o ON n.nft_id = o.nft_id AND o.is_current_owner = TRUE
GROUP BY c.collection_id,c.name
)
SELECT collection_id,unique_nft,unique_owner, name,
ROUND((unique_owner:: DECIMAL/unique_nft *100),1) AS distribution_pct
FROM collection_unique
WHERE unique_nft > 0 AND ROUND((unique_owner:: DECIMAL/unique_nft *100),1) >= 50
ORDER BY distribution_pct DESC;

Auction success rate
SELECT COUNT(*) AS total_auctions,
SUM(CASE WHEN current_bid > reserve_price THEN 1 ELSE 0 END) AS successful_auctions,
ROUND((SUM(CASE WHEN current_bid > reserve_price THEN 1 ELSE 0 END)::DECIMAL 
/ COUNT(*) * 100), 1) AS success_rate_pct
FROM auctions
WHERE status = 'ended';

Users tier migration
SELECT u.username, u.user_id, u.total_spent, u.user_tier,
SUM(t.sale_price) OVER (PARTITION BY t.to_user_id ORDER BY t.transaction_date)
FROM users u
LEFT JOIN transactions t ON u.user_id = t.to_user_id
WHERE u.user_id = 1
ORDER BY t.transaction_date;
