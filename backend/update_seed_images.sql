-- Update existing production menu items and venues with image URLs.
-- Run this against the RDS PostgreSQL instance after deploying the
-- updated DataInitializer.cs so existing records get images too.
--
-- Usage:
--   PGPASSWORD=<password> psql -h pyconnect.ch2i68eyk0ii.eu-north-1.rds.amazonaws.com \
--     -U postgres -d pondyconnect -f update_seed_images.sql

BEGIN;

-- ── Fuoco Pizzeria menu items (vendor 00000000-0000-0000-0000-000000000001) ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1604068549290-fa44e08c421a?w=400' WHERE "Name" = 'Woodfired Margherita' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1639024471283-03518883512d?w=400' WHERE "Name" = 'Truffle Fries' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1621219309024-eb8f4b4b6b3b?w=400' WHERE "Name" = 'Pepperoni Pizza' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1573140246462-332f2d2b4c91?w=400' WHERE "Name" = 'Garlic Bread' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=400' WHERE "Name" = 'Tiramisu' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1567620832903-9fc6debc209f?w=400' WHERE "Name" = 'Chicken Wings (6 pc)' AND "VendorId" = '00000000-0000-0000-0000-000000000001';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1639024471283-03518883512d?w=400' WHERE "Name" = 'Chicken Shawarma' AND "VendorId" = '00000000-0000-0000-0000-000000000001';

-- ── Satsanga Garden Kitchen ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1567188040759-fb8a883dc6d8?w=400' WHERE "Name" = 'Veg Thali';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1569058242253-92a9e75c47a9?w=400' WHERE "Name" = 'Chicken Chettinad';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400' WHERE "Name" = 'Paneer Butter Masala';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1601304549427-2e9c8f4b4b1f?w=400' WHERE "Name" = 'Gulab Jamun (2 pc)';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1668236970733-d2a5e4b7b8c3?w=400' WHERE "Name" = 'Masala Dosa';

-- ── La Maison Rose ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=400' WHERE "Name" = 'Coq au Vin';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1574484284002-953d92462f60?w=400' WHERE "Name" = 'Ratatouille';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1547592180-85f173990554?w=400' WHERE "Name" = 'French Onion Soup';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1470124182917-cc6e71b22944?w=400' WHERE "Name" = 'Crème Brûlée';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1631108306864-496a0f4a39c0?w=400' WHERE "Name" = 'Quiche Lorraine';

-- ── Baker Street Bistro ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1555507036-ab1f4038808a?w=400' WHERE "Name" = 'Butter Croissant';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1612203985729-70726954388c?w=400' WHERE "Name" = 'Chocolate Eclair';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1631108306864-496a0f4a39c0?w=400' WHERE "Name" = 'Quiche Vegetarian';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1595435172879-2c8f4b4b8b3f?w=400' WHERE "Name" = 'Cinnamon Roll';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1597079910443-6c15d4b9b4b2?w=400' WHERE "Name" = 'Fresh Baguette';

-- ── Café des Arts ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1572442388796-11668a67e63d?w=400' WHERE "Name" = 'Cappuccino';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400' WHERE "Name" = 'Cold Brew';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1528740561666-dc2479dc08ab?w=400' WHERE "Name" = 'Club Sandwich';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1626700051175-6818013ad1a8?w=400' WHERE "Name" = 'Veg Wrap';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1551024506-0bccd828d307?w=400' WHERE "Name" = 'Brownie with Ice Cream';

-- ── The Turtles Cafe ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1525351484163-7529414344d8?w=400' WHERE "Name" = 'Full English Breakfast';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1567620905720-1372c9c8c4ad?w=400' WHERE "Name" = 'Pancake Stack';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1608039759621-1e5b1c3670a3?w=400' WHERE "Name" = 'Eggs Benedict';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1559056199-641a0ac8b55e?w=400' WHERE "Name" = 'Filter Coffee';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1541519227354-08fa5a50a504?w=400' WHERE "Name" = 'Avocado Toast';

-- ── Pondy Pizzeria ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1604068549290-fa44e08c421a?w=400' WHERE "Name" = 'Margherita Pizza';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1574071318508-1cdbab80b25f?w=400' WHERE "Name" = 'Veg Supreme Pizza';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1593564705826-36b9403c0c66?w=400' WHERE "Name" = 'Chicken Tikka Pizza';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1573140246462-332f2d2b4c91?w=400' WHERE "Name" = 'Garlic Knots (6 pc)';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1606313562571-483c5b9c6c4c?w=400' WHERE "Name" = 'Choco Lava Cake';

-- ── Dragon Wok ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1525755662778-989d4823f364?w=400' WHERE "Name" = 'Kung Pao Chicken';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1612929633738-8e90e9c3b9da?w=400' WHERE "Name" = 'Veg Hakka Noodles';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7?w=400' WHERE "Name" = 'Chilli Paneer';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1606851090710-3c9b8b0b3b3b?w=400' WHERE "Name" = 'Spring Rolls (4 pc)';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1603133872878-684f208fb84b?w=400' WHERE "Name" = 'Schezwan Fried Rice';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1547592180-85f173990554?w=400' WHERE "Name" = 'Wonton Soup';

-- ── Spice Route ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=400' WHERE "Name" = 'Chettinad Chicken Biryani';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400' WHERE "Name" = 'Mutton Pepper Fry';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1531750026848-8ada13a40d8a?w=400' WHERE "Name" = 'Fish Moilee';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400' WHERE "Name" = 'Rasam';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1601304549427-2e9c8f4b4b1f?w=400' WHERE "Name" = 'Payasam';

-- ── Shawarma Junction ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1639024471283-03518883512d?w=400' WHERE "Name" = 'Chicken Shawarma Roll';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1626700051175-6818013ad1a8?w=400' WHERE "Name" = 'Falafel Wrap';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1595940814762-2c9c0b4b4b3f?w=400' WHERE "Name" = 'Chicken Shawarma Plate';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1571197119282-8c4b4b4b4b4b?w=400' WHERE "Name" = 'Hummus & Pita';

-- ── Brew & Bean ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1572442388796-11668a67e63d?w=400' WHERE "Name" = 'Flat White';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400' WHERE "Name" = 'Iced Latte';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1605278286492-3c8b4b4b4b4b?w=400' WHERE "Name" = 'Veg Puff';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1605278286492-3c8b4b4b4b4b?w=400' WHERE "Name" = 'Egg Puff';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400' WHERE "Name" = 'Cold Coffee';

-- ── Coastal Catch ──
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1535140728325-a4d3707eee84?w=400' WHERE "Name" = 'Grilled Sea Bass';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1535140728325-a4d3707eee84?w=400' WHERE "Name" = 'Fish & Chips';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1531750026848-8ada13a40d8a?w=400' WHERE "Name" = 'Prawn Curry';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1599909366516-6c4b4b4b4b4b?w=400' WHERE "Name" = 'Calamari Rings';
UPDATE menu_items SET "ImageUrl" = 'https://images.unsplash.com/photo-1606491956687-8e76de41a91e?w=400' WHERE "Name" = 'Crab Masala';

-- ── Venues missing images ──
UPDATE venues SET "ImageUrl" = 'https://images.unsplash.com/photo-1517248135467-4c7ed8826398?w=400' WHERE "Name" = 'Satsanga Restaurant' AND "ImageUrl" IS NULL;
UPDATE venues SET "ImageUrl" = 'https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=400' WHERE "Name" = 'Pondy Pizzeria' AND "ImageUrl" IS NULL;
UPDATE venues SET "ImageUrl" = 'https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=800' WHERE "Name" = 'Fuoco Pizzeria' AND "ImageUrl" IS NULL;

-- ── Fuoco vendor image ──
UPDATE vendors SET "ImageUrl" = 'https://images.unsplash.com/photo-1513104890138-746a492e0b31?w=800' WHERE "Name" = 'Fuoco Pizzeria' AND "ImageUrl" IS NULL;

COMMIT;

-- Verify
SELECT "Name", "ImageUrl" FROM menu_items WHERE "ImageUrl" IS NOT NULL LIMIT 5;
SELECT "Name", "ImageUrl" FROM venues WHERE "ImageUrl" IS NOT NULL LIMIT 5;
