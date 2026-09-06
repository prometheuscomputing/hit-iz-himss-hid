-- Schemas and the account the tool connects as. Runs once, when MySQL
-- initialises an empty data directory.
--
-- The tool needs mysql_native_password: its JDBC driver predates MySQL 8's
-- default caching_sha2_password and cannot authenticate against it.
--
-- These schemas are deliberately EMPTY. The tool populates them from the test
-- content baked into its own image on first boot. No data is carried over from
-- any deployed instance.
CREATE DATABASE IF NOT EXISTS `hit_himss2`;
CREATE DATABASE IF NOT EXISTS `hit_himss2_account`;
CREATE USER IF NOT EXISTS 'himss'@'%' IDENTIFIED WITH mysql_native_password BY 'db_password';
GRANT ALL PRIVILEGES ON `hit_himss2`.* TO 'himss'@'%';
GRANT ALL PRIVILEGES ON `hit_himss2_account`.* TO 'himss'@'%';
FLUSH PRIVILEGES;
