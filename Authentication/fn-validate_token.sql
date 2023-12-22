-- ----------------------------------------------------------------------------------
-- Name:    validate_token
-- Schema:  public
-- Author:  Alen

-- Description: Validates the refresh token and returns a new UUID if the user is active,
--              not locked etc.
--
-- Parameters:  token (UUID) -  The identifier that is retrived from the refresh token
--              issuedFor (UUID) - The owner of the user id in the refresh token
--              newExpiry (Timestamp W TZ) - The new expiry if the token is validated
-- 
-- Returns:     TABLE [
--                      TokenIdentifier (UUID) - The new identifier if the existsing 
--                      one is valid
--                      EmailAddress (VARCHAR) - The email address of the owner
--                      FirstName (VARCHAR) - The first name
--                      MiddleName (VARCHAR) - The middle name
--                      LastName (VARCHAR) - The LastName
--                    ]                                                  
-- Date:    22/December/2023
-- ----------------------------------------------------------------------------------
create or replace function validate_token(token uuid, issuedfor uuid, newexpiry timestamp with time zone) returns TABLE("TokenIdentifier" uuid, "EmailAddress" character varying, "FirstName" character varying, "MiddleName" character varying, "LastName" character varying)
	language plpgsql
as $$
DECLARE 
    exists BOOLEAN;
    newToken uuid;
BEGIN
    -- Check if the token is valid and not deleted
    SELECT u."IsValid" INTO exists
    FROM sharecode."UserRefreshToken" u
    INNER JOIN sharecode."User" su ON su."Id" = u."IssuedFor"
    WHERE u."TokenIdentifier" = token
      AND u."IssuedFor" = issuedFor
      AND u."IsValid" = true
      AND u."IsDeleted" = false
      AND su."AccountLocked" = false
      AND su."Active" = true
      AND su."IsDeleted" = false;
    

    -- If the token is valid, delete the old one
    IF exists THEN
        -- Generate a new token UUID
        newToken := uuid_generate_v4();
        -- Update the old token to mark it as deleted using an alias for the table
        UPDATE sharecode."UserRefreshToken" AS u
        SET
            "IsDeleted" = true,
            "IsValid" = false,
            "ModifiedAt" = CURRENT_TIMESTAMP AT TIME ZONE 'UTC'
        WHERE u."TokenIdentifier" = token;

        -- Insert the new token into the table
        INSERT INTO sharecode."UserRefreshToken" ("TokenIdentifier", "IssuedFor", "IsValid", "IsDeleted", "CreatedAt", "ModifiedAt", "Expiry")
        VALUES (newToken, issuedFor, true, false, CURRENT_TIMESTAMP AT TIME ZONE 'UTC', CURRENT_TIMESTAMP AT TIME ZONE 'UTC', newExpiry);

        -- Fetch user details for the response
        RETURN QUERY 
        SELECT 
        newToken AS "TokenIdentifier", u."EmailAddress", u."FirstName", u."MiddleName", u."LastName"
        FROM sharecode."User" u
        WHERE u."Id" = issuedFor AND "IsDeleted" = false AND "Active" = true AND "AccountLocked" = false
        LIMIT 1;
    ELSE
        -- Return NULL if the token is not valid
        RETURN;
    END IF;
END;
$$;

alter function validate_token(uuid, uuid, timestamp with time zone) owner to "dev-admin";

