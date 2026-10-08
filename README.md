# restaurantsApp-Crypto
Restaurants application with mock data created to show some SQL logic with creating tables, views, functions, indexes, constraints and so.

Restaurant POS & Business Intelligence Database

A production-grade PostgreSQL relational database system for multi-location restaurant POS management, order fulfillment tracking, session dynamics, dynamic discount handling, and enterprise analytical reporting.

 Features & Architecture
* **Multi-Location Hierarchy:** Supports multiple restaurant entities, floor zones, physical tables with capacity metrics, and active menu items.
* **Dynamic Menu Discounting:** Automatically handles menu item promotion pricing and line-item revenue calculations.
* **Order & POS State Machine:** Real-time tracking of order lifecycles (`OPEN` $\rightarrow$ `SUBMITTED` $\rightarrow$ `PREPARING` $\rightarrow$ `READY` $\rightarrow$ `SERVED`).
* **Session & Check Splitting:** Maps walk-in traffic and reservation sessions to checks and payments (Card, Cash, Bank Transfer).
* **Automated Maintenance:** Custom triggers and functions for expiring overdue reservations and auditing time-sensitive records.
* **Business Intelligence (BI) Layer:** Built-in analytical views for waiter performance, hourly traffic heatmaps, top-selling items, and daily financial summaries.

 🗂️ Script Execution Sequence
The project files are numbered sequentially to ensure smooth execution without breaking Foreign Key dependencies or missing dependencies:

| File | Description |
| :--- | :--- |
| **`01 DDL PostgreSQL Restaurants table Creation.sql`** | Defines all base tables, data types, primary keys, and foreign key constraints. |
| **`02 Functions.sql`** | Core business logic, validation rules, and automated trigger functions. |
| **`03 DDL For populating tables with mock data.sql`** | Seeds foundational static data (Restaurants, Floor Plans, Menu Items). |
| **`04 DDL Dinning session and payments data seeding.sql`** | Seeds complex dynamic records (Sessions, Orders, Order Items, Checks, Payments). |
| **`05 Extra Indexes for faster data manipulation.sql`** | Performance tuning via targeted indexes for foreign keys, timestamps, and search filters. |
| **`07 Functions expire_past_reservation func.sql`** | Background automation function for reservation status lifecycle updates. |
| **`08 Analytical Views.sql`** | Pre-built views for reporting and REST API integration. |
| **`09 Installation script.sql`** | Master orchestration script that builds the entire system in one command. |

Run the master setup script using `psql` from your terminal or Git Bash inside the project directory:
```bashaer
psql -U postgres -d restaurant_db -f "09 Installation script.sql"

After installing the reports from the views can be ran like this :
-- 1. Daily Financial & Revenue Summary
SELECT * FROM v_daily_revenue WHERE restaurant_id = 1;
-- 2. Top-Selling Menu Item per Restaurant (Rank #1)
SELECT * FROM v_top_ordered_item_per_restaurant;
-- 3. Staff Upselling & Kitchen Fulfillment Performance Scorecard
SELECT * FROM v_employee_performance WHERE restaurant_id = 1;
-- 4. Hourly Customer Traffic Heatmap
SELECT * FROM v_peak_dining_hours WHERE restaurant_id = 1 ORDER BY day_number, hour_of_day;
