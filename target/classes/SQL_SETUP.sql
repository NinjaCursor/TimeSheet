
DROP PROCEDURE IF EXISTS NEW_EVENT #
DROP PROCEDURE IF EXISTS GET_LOG_DATA #
DROP PROCEDURE IF EXISTS GET_SUM_DATA #
DROP PROCEDURE IF EXISTS RECOVER_LOG_DATA #
DROP PROCEDURE IF EXISTS SETUP_EVENT_TABLE #


-- NEW_EVENT FUNCTION
-- @PARAMS: UUID, TIMESTAMP, EVENT, AND NAME OF TABLE
-- @POSTCONDITION: SUM AND LOG TABLES ARE UPDATED WITH APPROPRIATE INFORMATION BASED ON TIMESTAMP AND EVENT
CREATE PROCEDURE NEW_EVENT(IN IN_UUID VARCHAR(36), IN IN_TIME BIGINT, IN IN_EVENT ENUM('START', 'STOP', 'UPDATE'), IN EVENT_NAME VARCHAR(100))
BEGIN

    SET @readable_time = from_unixtime(floor(`IN_TIME`)/1000);

    IF (IN_EVENT = 'START') THEN

        SET @sum_sql := CONCAT('INSERT INTO ', EVENT_NAME, '_SUM(UUID, TOTAL, LAST_ACTIVE, COUNT, FIRST_START, ACTIVE_NOW) VALUES(\"', IN_UUID,'\", 0,', IN_TIME,', 1,', IN_TIME,', TRUE) ON DUPLICATE KEY UPDATE LAST_ACTIVE=', IN_TIME, ', COUNT=(COUNT+1), ACTIVE_NOW=TRUE;');
        SET @log_sql := CONCAT('INSERT INTO ', EVENT_NAME, '_LOG(UUID, TIME_STAMP, LOG_EVENT, READABLE_TIMESTAMP) VALUES(\"', IN_UUID, '\", ', IN_TIME,', \"START\", ?);');

        PREPARE SUM_SQL_COMMAND FROM @sum_sql;
        PREPARE LOG_SQL_COMMAND FROM @log_sql;

        EXECUTE SUM_SQL_COMMAND;
        EXECUTE LOG_SQL_COMMAND USING @readable_time;

    ELSEIF (IN_EVENT = 'UPDATE') THEN

        SET @sum_sql := CONCAT('UPDATE ', EVENT_NAME, '_SUM SET TOTAL=TOTAL+(', IN_TIME,'-LAST_ACTIVE), LAST_ACTIVE=', IN_TIME,' WHERE UUID=\"',IN_UUID,'\";');

        PREPARE SUM_SQL FROM @sum_sql;

        EXECUTE SUM_SQL;

    ELSE
        SET @sum_sql := CONCAT('UPDATE ', EVENT_NAME, '_SUM SET TOTAL=TOTAL+(',IN_TIME,'-LAST_ACTIVE), LAST_ACTIVE=',IN_TIME,', ACTIVE_NOW=FALSE WHERE UUID=\"',IN_UUID,'\";');
        SET @log_sql := CONCAT('INSERT INTO ', EVENT_NAME,'_LOG(UUID, TIME_STAMP, LOG_EVENT, READABLE_TIMESTAMP) VALUES(\"', IN_UUID,'\", ', IN_TIME,', \'STOP\', ?);');

        PREPARE SUM_SQL FROM @sum_sql;
        PREPARE LOG_SQL FROM @log_sql;

        EXECUTE SUM_SQL;
        EXECUTE LOG_SQL USING @readable_time;

    END IF;

END; #

-- SETUP_EVENT_TABLES
-- @PARAMS: EVENT_NAME
-- @POSTCONDITION: TWO TABLES WITH NAMES EVENT_NAME_LOG AND EVENT_NAME_SUM
CREATE PROCEDURE SETUP_EVENT_TABLE(IN EVENT_NAME VARCHAR(100))
BEGIN
    SET @sql_log := CONCAT('CREATE TABLE ', EVENT_NAME,'_LOG(ID INT NOT NULL AUTO_INCREMENT PRIMARY KEY, UUID VARCHAR(36) NOT NULL, TIME_STAMP BIGINT NOT NULL, READABLE_TIMESTAMP DATETIME NOT NULL, LOG_EVENT ENUM(\'START\', \'STOP\') NOT NULL);');
    SET @sql_sum := CONCAT('CREATE TABLE ', EVENT_NAME, '_SUM(UUID VARCHAR(36) NOT NULL PRIMARY KEY, TOTAL BIGINT NOT NULL, LAST_ACTIVE BIGINT NOT NULL, COUNT BIGINT NOT NULL, FIRST_START BIGINT NOT NULL, ACTIVE_NOW BOOLEAN NOT NULL);');

    PREPARE LOG_CREATION FROM @sql_log;
    PREPARE SUM_CREATION FROM @sql_sum;

    EXECUTE LOG_CREATION;
    EXECUTE SUM_CREATION;

END; #

-- GET_LOG_DATA
-- @PARAMS: IN_UUID, EVENT_NAME
-- @POSTCONDITION: NONE
-- @RETURNS: ALL ROWS IN LOG TABLE FOR IN_UUID
CREATE PROCEDURE GET_LOG_DATA(IN IN_UUID VARCHAR(36), IN EVENT_NAME VARCHAR(100))
BEGIN
    SET @sql_query := CONCAT('SELECT * FROM ', EVENT_NAME ,'_LOG;');

    PREPARE QUERY_COMMAND FROM @sql_query;

    EXECUTE QUERY_COMMAND;

END; #


-- GET_SUM_DATA
-- @PARAMS: IN_UUID, EVENT_NAME
-- @POSTCONDITION: NONE
-- @RETURNS: ALL ROWS IN SUM TABLE FOR IN_UUID

CREATE PROCEDURE GET_SUM_DATA(IN IN_UUID VARCHAR(36), IN EVENT_NAME VARCHAR(100))
BEGIN
    SET @sql_query := CONCAT('SELECT * FROM ', EVENT_NAME ,'_SUM;');

    PREPARE QUERY_COMMAND FROM @sql_query;

    EXECUTE QUERY_COMMAND;
END; #

-- RECOVER_LOG_DATA
-- @PARAMS: EVENT_NAME
-- @POSTCONDITION: ANY UUID'S WITH A HANGING START VALUE WILL RECEIVE A STOP ROW AT THE TIME OF THE SUM DATA'S LAST_ACTIVE FOR THAT PERSON WHICH WILL HOPEFULLY TAKE CARE OF ISSUES WHERE THE SERVER CRASHES AND THE STOP EVENT NEVER OCCURS FOR SOME PEOPLE
CREATE PROCEDURE RECOVER_LOG_DATA(IN EVENT_NAME VARCHAR(100))
BEGIN
    DECLARE CURRENT_UUID VARCHAR(36);
    DECLARE LAST_LOG_EVENT ENUM('START', 'STOP');
    DECLARE LAST_TIME BIGINT;
    DECLARE START_ROWS BIGINT;

    SET START_ROWS=0;
    SET @sql_last_row = CONCAT('SET @rowcount = (SELECT COUNT(*) FROM ', EVENT_NAME,'_SUM);');
    PREPARE SQL_COMMAND FROM @sql_last_row;
    EXECUTE SQL_COMMAND;


    WHILE START_ROWS < @rowcount DO

            -- GET CURRENT UUID
            SET @sql_get_uuid := CONCAT('SET @currentuuid = (SELECT UUID FROM ', EVENT_NAME, '_SUM LIMIT 1 OFFSET ', START_ROWS, ');');
            PREPARE SQL_UUID FROM @sql_get_uuid;
            EXECUTE SQL_UUID;

            SELECT @currentuuid;


            -- GET LAST LOG EVENT
            SET @sql_get_last := CONCAT('SET @lastlogevent = (SELECT LOG_EVENT FROM ', EVENT_NAME, '_LOG WHERE UUID=? ORDER BY ID DESC LIMIT 1);');
            PREPARE SQL_LOG_EVENT FROM @sql_get_last;
            EXECUTE SQL_LOG_EVENT USING @currentuuid;

            -- GET LAST TIME FROM SUM TABLE WHICH SHOULD BE CLOSE TO ACTUAL TIME OF SERVER CRASH
            SET @sql_get_time := CONCAT('SET @lasttime = (SELECT LAST_ACTIVE FROM ', EVENT_NAME, '_SUM WHERE UUID=?);');
            PREPARE SQL_TIME FROM @sql_get_time;
            EXECUTE SQL_TIME USING @currentuuid;

            IF (@lastlogevent = 'START') THEN
                CALL NEW_EVENT(@currentuuid, @lasttime, 'STOP', EVENT_NAME);
            END IF;

            SET START_ROWS=START_ROWS+1;
        END WHILE;

END; #