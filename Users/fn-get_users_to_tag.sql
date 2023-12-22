-- ----------------------------------------------------------------------------------
-- Name:    get_users_to_tag
-- Schema:  public
-- Author:  Alen
-- Description: Retrieves user data for tagging based on specified criteria.
--
-- Parameters:  
--      searchQuery (VARCHAR) - The search query to filter users by name or email address
--      skip (INTEGER) - The number of records to skip in the result set
--      take (INTEGER) - The maximum number of records to return in the result set
--      onlyEnabled (BOOLEAN) - Indicates whether to include only enabled users with tagging allowed
--      includeDeleted (BOOLEAN) - Indicates whether to include deleted users in the result set
-- 
-- Returns:     
--      TABLE [
--          "EmailAddress" (VARCHAR) - The email address of the user
--          "FirstName" (VARCHAR) - The first name of the user
--          "MiddleName" (VARCHAR) - The middle name of the user
--          "LastName" (VARCHAR) - The last name of the user
--          "Id" (UUID) - The identifier of the user
--          "ProfilePicture" (TEXT) - The URL or path to the user's profile picture
--      ]     
--                                          
-- Date:    22/December/2023
-- ----------------------------------------------------------------------------------
create or replace function get_users_to_tag(searchquery character varying, skip integer, take integer, onlyenabled boolean, includedeleted boolean) returns TABLE("EmailAddress" character varying, "FirstName" character varying, "MiddleName" character varying, "LastName" character varying, "Id" uuid, "ProfilePicture" text)
	language plpgsql
as $$
    BEGIN
        
        IF onlyEnabled THEN
            RETURN QUERY 
            SELECT SU."EmailAddress", SU."FirstName", SU."MiddleName", SU."LastName", SU."Id" AS "Id", SU."ProfilePicture" 
            FROM sharecode."User" SU
            INNER JOIN sharecode."AccountSetting" SA ON SU."Id" = SA."UserId"
            WHERE SA."AllowTagging" = true AND CONCAT(SU."NormalizedFullName", ' ', SU."EmailAddress") ILIKE CONCAT('%',searchQuery,'%')
            AND CASE
                WHEN includeDeleted = true THEN true
                ELSE SU."IsDeleted" = false
            END
            OFFSET skip LIMIT take
            ;
        ELSE
            RETURN QUERY 
            SELECT SU."EmailAddress", SU."FirstName", SU."MiddleName", SU."LastName", SU."Id", SU."ProfilePicture" 
            FROM sharecode."User" SU
            WHERE CONCAT(SU."NormalizedFullName", ' ', SU."EmailAddress") ILIKE CONCAT('%',searchQuery,'%')
            AND CASE
                WHEN includeDeleted = true THEN true
                ELSE SU."IsDeleted" = false
            END            
            OFFSET skip LIMIT take
            ;            
        END IF;
    END
$$;

alter function get_users_to_tag(varchar, integer, integer, boolean, boolean) owner to "dev-admin";

