-- Exceute: myslq -h YOUR_MYSQL_HOST -u root -p < sensordb_DDL.sql
DROP DATABASE IF EXISTS `sensors`;

CREATE DATABASE IF NOT EXISTS `sensors`;

ALTER DATABASE `sensors` DEFAULT COLLATE latin1_spanish_ci;

USE `sensors`;

CREATE TABLE IF NOT EXISTS `sensors`.`sensors_users` (
  `user_id` INT(11) unsigned NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(150) DEFAULT NULL,
  `password` VARCHAR(150) DEFAULT NULL,
  `name` VARCHAR(150) COLLATE latin1_spanish_ci DEFAULT NULL,
  `surname` VARCHAR(150) COLLATE latin1_spanish_ci DEFAULT NULL,
  `description` VARCHAR(150) COLLATE latin1_spanish_ci DEFAULT NULL,
  `creation_ts_user` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `ts_last_update` DATETIME DEFAULT NULL,
  `enabled` BOOLEAN NOT NULL DEFAULT 1,
  `deleted` BOOLEAN NOT NULL  DEFAULT 0,
  `is_admin` BOOLEAN NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_spanish_ci;

CREATE TABLE IF NOT EXISTS `sensors`.`sensors_tokens` (
  `token_user_id` INT(11) unsigned NOT NULL,
  `token` VARCHAR(150) COLLATE latin1_spanish_ci DEFAULT NULL,
  `creation_ts_token` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `expired` BOOLEAN NOT NULL DEFAULT 0,
  `deleted` BOOLEAN NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_spanish_ci;

TRUNCATE TABLE `sensors`.`sensors_users`;
TRUNCATE TABLE `sensors`.`sensors_tokens`;

-- User: admin / Passord: admin1234
INSERT INTO `sensors_users` (`user_id`, `username`, `password`, `name`, `surname`, `description`, `creation_ts_user`, `ts_last_update`, `enabled`, `deleted`, `is_admin`)
VALUES (1, 'admin', 'e3a4a072704063daf779344cfbc804044289edd17a81913dda1b910108cc654c', 'Sergio', 'Martinez Losa', 'Admin API user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1, 0, 1);

INSERT INTO `sensors_tokens` (`token_user_id`, `token`, `creation_ts_token`, `expired`, `deleted`)
VALUES (1, 'aca6038665c811e8a96100089be8caec', CURRENT_TIMESTAMP, 0, 0);

-- User: user_api / Passord: user_api1234
INSERT INTO `sensors_users` (`user_id`, `username`, `password`, `name`, `surname`, `description`, `creation_ts_user`, `ts_last_update`, `enabled`, `deleted`, `is_admin`)
VALUES (2, 'api_user', 'de602fd56127486f6cbfa2cd3c5035a5e9b0a5ab976f38251f177d313981f207', 'Sergio', 'Martinez Losa', 'API user', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 1, 0, 0);

INSERT INTO `sensors_tokens` (`token_user_id`, `token`, `creation_ts_token`, `expired`, `deleted`)
VALUES (2, '7b774d0765d011e8a96100089be8caec', CURRENT_TIMESTAMP, 0, 0);

-- Insert a new token when user inserts new data
DROP TRIGGER IF EXISTS `sensors`.`trigger_insert_sensor_tokensnew_user`;
DROP PROCEDURE IF EXISTS `sensors`.`insert_new_row_sensors_tokens`;

DELIMITER //
CREATE TRIGGER `sensors`.`trigger_insert_sensor_tokens`
AFTER INSERT ON `sensors`.`sensors_users` FOR EACH ROW
    BEGIN
      CALL `sensors`.`insert_new_row_sensors_tokens`(NEW.`user_id`);
    END; //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE `sensors`.`insert_new_row_sensors_tokens`(IN new_user_id INT(11))
MODIFIES SQL DATA
    BEGIN
		 SET @token_id := new_user_id;
		 SET @token := (SELECT REPLACE(LOWER(LEFT(UUID(), 110)), '-', ''));
     SET @date_now := NOW();

     INSERT INTO `sensors`.`sensors_tokens` (`token_user_id`, `token`, `creation_ts_token`)
     VALUES (@token_id, @token, @date_now);

    END; //
DELIMITER ;

-- Update tokens after user updates its data
DROP TRIGGER IF EXISTS `sensors`.`trigger_update_sensor_tokens`;

DELIMITER //
CREATE TRIGGER `sensors`.`trigger_update_sensor_tokens`
AFTER UPDATE ON `sensors`.`sensors_users` FOR EACH ROW
    BEGIN

		  SET @deleted_value := OLD.`deleted`;
      SET @token_id := OLD.`user_id`;

     	UPDATE `sensors`.`sensors_tokens`
      SET `sensors_tokens`.`deleted` = @deleted_value
      WHERE `sensors_tokens`.`token_user_id` = @token_id;

    END; //
DELIMITER ;

-- Delete tokens after user deletes its data
DROP TRIGGER IF EXISTS `sensors`.`trigger_delete_sensor_tokens`;

DELIMITER //
CREATE TRIGGER `sensors`.`trigger_delete_sensor_tokens`
AFTER DELETE ON `sensors`.`sensors_users` FOR EACH ROW
    BEGIN

      SET @token_id := OLD.`user_id`;

     	DELETE FROM `sensors`.`sensors_tokens`
      WHERE `sensors_tokens`.`token_user_id` = @token_id;

    END; //
DELIMITER ;

-- Create procudure to manage user login
DROP PROCEDURE IF EXISTS `sensors`.`login_user_actions`;

DELIMITER //
CREATE PROCEDURE `sensors`.`login_user_actions`(IN username VARCHAR(150), IN password VARCHAR(150))
MODIFIES SQL DATA
    BEGIN

     SET @temp_username := username;
		 SET @temp_password := password;

     SET @temp_user_id := (SELECT user_id FROM `sensors`.`sensors_users`
                           WHERE `sensors_users`.`username` = @temp_username AND `sensors_users`.`password` = @temp_password LIMIT 1);

     SET @is_token_expired := (SELECT s2.expired FROM `sensors`.`sensors_users` AS s1 INNER JOIN `sensors`.`sensors_tokens` AS s2
                               ON s1.`user_id` = s2.`token_user_id`
                               WHERE s1.`username` = @temp_username AND s1.`password` = @temp_password LIMIT 1);


     IF @is_token_expired = 1 THEN

        DELETE FROM `sensors`.`sensors_tokens`
        WHERE `sensors_tokens`.`token_user_id` = @temp_user_id;

        CALL `sensors`.`insert_new_row_sensors_tokens`(@temp_user_id);

     END IF;

     SET @token_value := (SELECT token FROM `sensors`.`sensors_tokens` WHERE `sensors_tokens`.`token_user_id` = @temp_user_id);
     SET @user_id_value := @temp_user_id;

     SELECT @token_value AS token, @user_id_value AS user_id;
    END; //
DELIMITER ;

-- Create an event that checks tokens' timestamps, if timestamp >= 24 hours token expires
DROP EVENT IF EXISTS `sensors`.`event_expire_tokens`;
DROP PROCEDURE IF EXISTS `sensors`.`procedure_expire_timestamps`;

SET GLOBAL event_scheduler = ON;

CREATE EVENT `sensors`.`event_expire_tokens`
ON SCHEDULE EVERY 1 HOUR
COMMENT 'Event that sets expired = 0 on table sensors.sensors_tokens getting the field creation_ts_token - NOW() >= 24 hours'
    DO CALL `sensors`.`procedure_expire_timestamps`();

DELIMITER //

CREATE PROCEDURE `sensors`.`procedure_expire_timestamps`()
MODIFIES SQL DATA
BEGIN
    DECLARE done INT DEFAULT 0;
  	DECLARE creation_ts TIMESTAMP;
  	DECLARE token_id INT(11);
  	DECLARE cursor_tokens CURSOR FOR SELECT creation_ts_token, token_user_id FROM `sensors`.`sensors_tokens`;
  	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;

	  OPEN cursor_tokens;

  	read_loop: LOOP
      FETCH cursor_tokens INTO creation_ts, token_id;
      	IF done THEN
        		LEAVE read_loop;
      	END IF;

      	# Do substraction for creation_ts
        SET @date_char := creation_ts;
      	SET @diff_days := (SELECT CAST(DATEDIFF(CURDATE(), @date_char) AS UNSIGNED));

        SET @token_identifier := token_id;

        # Date diff bigger or equal than one day
      	IF @diff_days >= 1 THEN
      		UPDATE `sensors`.`sensors_tokens` AS s2
          INNER JOIN `sensors`.`sensors_users`AS s1 ON s2.`token_user_id` = s1.`user_id`
          SET s2.`expired` = 1
          WHERE s2.`token_user_id` = @token_identifier AND s1.`is_admin` = 0;
    	  END IF;
  	END LOOP;

  	CLOSE cursor_tokens;

END; //
DELIMITER ;

COMMIT;