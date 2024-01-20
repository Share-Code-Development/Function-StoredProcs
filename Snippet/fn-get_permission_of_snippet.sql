-- ----------------------------------------------------------------------------------
-- Name:    get_permission_of_snippet
-- Schema:  public
-- Author:  Alen
-- Description: Gets the access control permissions for a snippet
--
-- Parameters:  snippetId (UUID) - The identifier of the snippet to retrieve permissions for
--              requestedUser (UUID) - The user who requests the permissions
--              checkAdminPermission (boolean) - Whether to check admin permissions
-- 
-- Returns:     
--      TABLE [
--          "Read" (BOOLEAN) - Indicates whether the user has read access
--          "Write" (BOOLEAN) - Indicates whether the user has write access
--          "Manage" (BOOLEAN) - Indicates whether the user has manage access
--      ]                                                  
--
-- Date:    31/December/2023
-- ----------------------------------------------------------------------------------
create function get_permission_of_snippet(snippetid uuid, requesteduser uuid, checkadminpermission boolean DEFAULT true)
    returns TABLE("Read" boolean, "Write" boolean, "Manage" boolean)
    language plpgsql
as
$$
DECLARE
    permissions jsonb;
    "read" bool;
    "write" bool;
    "manage" bool;
    ownerId uuid;
    public bool;
BEGIN
    -- Getting the owner id and public status of the snippet
    SELECT SS."OwnerId", SS."Public" INTO ownerId, public
    FROM snippet."Snippets" SS
    WHERE SS."Id" = snippetId;

    -- If the user is the owner of the snippet, he has every permission
    IF ownerId = requestedUser THEN
        "read" := true;
        "write" := true;
        "manage" := true;
    ELSE
        -- Else check whether he has permission defined in the access control if he is not the owner
        SELECT SAC."Read", SAC."Write", SAC."Manage" INTO "read", "write", "manage"
        FROM snippet."SnippetAccessControls" SAC
        WHERE SAC."UserId" = requestedUser AND SAC."SnippetId" = snippetId;

        -- If the snippet is public and he is not the owner,
        -- he would eventually have the view permission
        IF public THEN
            "read" := true;
        END IF;
    END IF;

    -- Also check whether the requesting user is admin or not if needed
    IF checkAdminPermission = true AND (read = false OR write = false OR manage = false)
    THEN
        SELECT COALESCE("Permissions", '[]'::jsonb) into permissions FROM sharecode."User"
        WHERE "Id" = requestedUser;

        IF "read" = false
        THEN
            "read" := permissions @> '["view-snippet-others-admin"]';
        END IF;

        IF "write" = false
        THEN
            "write" := permissions @> '["update-snippet-others-admin"]';
        END IF;

        IF "manage" = false
        THEN
            "manage" := permissions @> '["delete-snippet-others-admin"]';
        END IF;

    END IF;

  RETURN QUERY SELECT "read", "write", "manage", "public";
END
$$;


