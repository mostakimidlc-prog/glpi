-- GLPI Database Initialization
-- Set proper encoding and collation
ALTER DATABASE glpidb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant all privileges to GLPI user
GRANT ALL PRIVILEGES ON glpidb.* TO 'glpi_user'@'%';
FLUSH PRIVILEGES;

-- Optimize for GLPI
SET GLOBAL sql_mode = 'ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
