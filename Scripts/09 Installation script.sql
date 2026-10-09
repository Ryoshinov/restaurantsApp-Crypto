-- ============================================================================
-- MASTER INSTALLATION SCRIPT
-- Executes the complete database lifecycle in sequential order. 
-- Needed to be added several more sequencies.
-- ============================================================================

\echo '-------------------------------------------------------'
\echo '1/8: Creating Base Tables and Relational Constraints...'
\echo '-------------------------------------------------------'
\i '01 DDL PostgreSQL Restaurants table Creation.sql'

\echo '-------------------------------------------------------'
\echo '2/8: Creating Functions & Triggers...'
\echo '-------------------------------------------------------'
\i '02 Functions.sql'

\echo '-------------------------------------------------------'
\echo '3/8: Seeding Core Master Data (Restaurants, Menus, Tables)...'
\echo '-------------------------------------------------------'
\i '03 DDL For populating tables with mock data.sql'

\echo '-------------------------------------------------------'
\echo '4/8: Seeding Dynamic Dining Sessions, Orders & Payments...'
\echo '-------------------------------------------------------'
\i '04 DDL Dinning session and payments data seeding.sql'

\echo '-------------------------------------------------------'
\echo '5/8: Applying Performance Indexes...'
\echo '-------------------------------------------------------'
\i '05 Extra Indexes for faster data manipulation.sql'

\echo '-------------------------------------------------------'
\echo '6/8: Installing Reservation Maintenance Automation...'
\echo '-------------------------------------------------------'
\i '07 Functions expire_past_reservation func.sql'

\echo '-------------------------------------------------------'
\echo '7/8: Creating Analytical Views and Business Intelligence'
\echo '-------------------------------------------------------'
\i '08 Analytical Views.sql'

\echo '-------------------------------------------------------'
\echo 'DATABASE INSTALLATION WAS COMPLETED SUCCESSFULLY! YEAH!'
\echo '-------------------------------------------------------'