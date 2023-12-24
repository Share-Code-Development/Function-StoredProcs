-- ----------------------------------------------------------------------------------
-- Name:    get_snippet
-- Schema:  public
-- Author:  Alen
-- Description: Gets the aggregated data of a snippet
--
-- Parameters:  snippetId (UUID) - The identifier of the snippet to retrieve data for
--              requestedby (UUID) - The user who requests the snippets
--              updaterecent (bool) - Whether to Update the recent snippet of the requested user
-- 
-- Returns:     
--      TABLE [
--          "Id" (UUID) - The identifier of the snippet
--          "Title" (VARCHAR) - The title of the snippet
--          "Description" (VARCHAR) - The description of the snippet
--          "Language" (VARCHAR) - The programming language of the snippet
--          "PreviewCode" (TEXT) - The preview code of the snippet
--          "Tags" (VARCHAR) - The tags associated with the snippet
--          "Public" (BOOLEAN) - Indicates whether the snippet is public
--          "Views" (INTEGER) - The number of views the snippet has
--          "Copy" (TEXT) - The copied text of the snippet
--          "OwnerId" (UUID) - The identifier of the owner of the snippet
--      ]                                                  
--      TABLE [
--          "CommentCount" (INTEGER) - The count of comments for the snippet
--      ]
--      TABLE [
--          "Id" (UUID) - The identifier of the user who commented on the snippet
--          "FirstName" (VARCHAR) - The first name of the user
--          "MiddleName" (VARCHAR) - The middle name of the user
--          "LastName" (VARCHAR) - The last name of the user
--          "EmailAddress" (VARCHAR) - The email address of the user
--          "LineNumber" (INTEGER) - The line number of the commented code
--          "Text" (TEXT) - The text of the comment
--          "CreatedAt" (TIMESTAMP WITH TIME ZONE) - The creation timestamp of the comment
--          "ModifiedAt" (TIMESTAMP WITH TIME ZONE) - The modification timestamp of the comment
--      ]
--      TABLE [
--          "ReactionType" (VARCHAR) - The type of reaction
--          "Count" (INTEGER) - The count of reactions of the given type
--      ]
--      TABLE [
--          "UserId" (UUID) - The identifier of the user with access control
--          "Read" (BOOLEAN) - Indicates whether the user has read access
--          "Write" (BOOLEAN) - Indicates whether the user has write access
--          "Manage" (BOOLEAN) - Indicates whether the user has manage access
--      ]
--
-- Date:    22/December/2023
-- ----------------------------------------------------------------------------------
create or replace function get_snippet(snippetid uuid, requestedby uuid, updaterecent boolean DEFAULT false) returns SETOF refcursor
	language plpgsql
as $$
DECLARE snippet_cursor refcursor;
DECLARE comment_count_cursor refcursor;
DECLARE line_comments_cursor refcursor;
DECLARE reactions_cursor refcursor;
DECLARE access_controls_cursor refcursor;
DECLARE self_added_reaction refcursor;
DECLARE metadata_json JSONB;
DECLARE recent_snippets UUID[];
BEGIN    
    
    IF EXISTS(SELECT 1 FROM snippet."Snippets" WHERE "Id" = snippetid AND "Public" = false)
    THEN
        IF requestedby IS NULL OR NOT EXISTS(SELECT 1 FROM snippet."SnippetAccessControls" WHERE "SnippetId" = snippetid AND "Read" = true AND "UserId" = requestedby)
        THEN
            RAISE EXCEPTION 'No Access';
        END IF;
    END IF;
    
    OPEN snippet_cursor FOR
    SELECT "Id", "Title", "Description", "Language", "PreviewCode", "Tags", "Public", "Views", "Copy", "OwnerId", COALESCE("Metadata" ->> 'LIMIT_COMMENTS'::bool, false) AS "IsCommentsLimited"
    FROM snippet."Snippets"
    WHERE "Id" = snippetId AND "IsDeleted" = false;
    RETURN NEXT snippet_cursor;

    OPEN comment_count_cursor FOR
    SELECT COUNT(1) FROM snippet."SnippetComments" AS "CommentCount" 
    WHERE "SnippetId" = snippetId AND "ParentCommentId" IS NULL AND "IsDeleted" = false;
    RETURN NEXT comment_count_cursor;    
    
    OPEN line_comments_cursor FOR    
    SELECT SU."Id", SU."FirstName", SU."MiddleName", SU."LastName", SU."EmailAddress",
    SLC."LineNumber", SLC."Text", SLC."CreatedAt", SLC."ModifiedAt"
    FROM snippet."SnippetLineComments" SLC
    INNER JOIN sharecode."User" SU ON SU."Id" = SLC."UserId"
    WHERE "SnippetId" = snippetId;
    RETURN NEXT line_comments_cursor;
    
    OPEN reactions_cursor FOR        
    SELECT "ReactionType", COUNT("ReactionType") FROM snippet."SnippetReactions"
    WHERE "SnippetId" = snippetId  AND "IsDeleted" = false
    GROUP BY "ReactionType";
    RETURN NEXT reactions_cursor;    
    
    OPEN access_controls_cursor FOR        
    SELECT "UserId", "Read", "Write", "Manage" FROM snippet."SnippetAccessControls" SAC
    INNER JOIN snippet."Snippets" SS ON SS."Id" = SAC."SnippetId"
    WHERE "SnippetId" = snippetId AND SAC."IsDeleted" = false AND SS."Public" = false;
    RETURN NEXT access_controls_cursor;
    
    IF requestedby IS NOT NULL THEN
        OPEN self_added_reaction FOR
        SELECT "ReactionType" FROM snippet."SnippetReactions" SSR
        WHERE SSR."SnippetId" = snippetid AND SSR."UserId" = requestedby
        AND "IsDeleted" = false;
        RETURN NEXT self_added_reaction;
    END IF;
    

    IF requestedby IS NOT NULL AND updaterecent = true
    THEN
        SELECT "Metadata" INTO metadata_json FROM sharecode."User" WHERE "Id" = requestedby;
    
        IF jsonb_typeof(metadata_json->'RECENT_SNIPPETS') = 'array' THEN
            recent_snippets := ARRAY(
                SELECT jsonb_array_elements_text(COALESCE(metadata_json->'RECENT_SNIPPETS', '[]'::jsonb))::UUID
            );
        ELSE
            recent_snippets := ARRAY[snippetid];
        END IF;
        
        -- Remove the snippetid if it already exists in recent_snippets
        recent_snippets := array_remove(recent_snippets, snippetid);
        
        -- Add the new snippetid to the start of recent_snippets
        recent_snippets := ARRAY[snippetid] || recent_snippets;
        
        -- Ensure the array does not have more than 10 elements
        IF array_length(recent_snippets, 1) > 10 THEN
            recent_snippets := recent_snippets[1:10];
        END IF;
        
        -- Update the "RECENT_SNIPPETS" field in the Metadata JSON
        metadata_json := jsonb_set(
            metadata_json,
            '{RECENT_SNIPPETS}',
            to_jsonb(recent_snippets)
        );
        
        -- Update the "Metadata" column in the User table
        UPDATE sharecode."User" SET "Metadata" = metadata_json WHERE "Id" = requestedby;
    END IF;
END
$$;




