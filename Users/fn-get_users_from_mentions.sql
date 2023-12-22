-- ----------------------------------------------------------------------------------
-- Name:    get_users_from_mentions
-- Schema:  public
-- Author:  Alen
-- Description: Retrieves user data for a given array of user identifiers used in mentions.
--
-- Parameters:  
--      users (UUID[]) - An array of user identifiers for whom to retrieve data
-- 
-- Returns:     
--      TABLE [
--          "Id" (UUID) - The identifier of the user
--          "EmailAddress" (VARCHAR) - The email address of the user
--          "FirstName" (VARCHAR) - The first name of the user
--          "MiddleName" (VARCHAR) - The middle name of the user
--          "LastName" (VARCHAR) - The last name of the user
--          "ProfilePicture" (TEXT) - The URL or path to the user's profile picture
--      ]                                              
-- Date:    22/December/2023
-- ----------------------------------------------------------------------------------
create or replace function get_users_from_mentions(users uuid[]) returns TABLE 
    ("Id" uuid, "EmailAddress" character varying, "FirstName" character varying, "MiddleName" character varying, 
     "LastName" character varying, "ProfilePicture" text)
language plpgsql
as $$
BEGIN
    RETURN QUERY
    SELECT su."Id", su."EmailAddress", su."FirstName", su."MiddleName", su."LastName", su."ProfilePicture" 
    FROM sharecode."User" su
    INNER JOIN unnest(users) u ON su."Id" = u;
END
$$;