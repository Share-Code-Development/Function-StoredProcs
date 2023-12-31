-- ----------------------------------------------------------------------------------
-- Name:    list_user_snippets
-- Schema:  public
-- Author:  Alen
-- Description: Retrieves a list of snippets based on user-specific criteria.
--
-- Parameters:  
--      userid (UUID) - The identifier of the user for whom snippets are retrieved.
--      onlyOwned (bool) - Indicates whether to include only snippets owned by the user.
--      recent (bool) - If true, retrieves the user's recent snippets; otherwise, retrieves all snippets.
--      skip (int) - Number of records to skip for pagination (default: 0).
--      take (int) - Number of records to retrieve for pagination (default: 20).
--      order (character varying) - The sorting order (default: 'ASC').
--      orderby (character varying) - The field to order by (default: 'ModifiedAt').
-- 
-- Returns:     
--      SETOF refcursor - A set of refcursors containing the following tables:
--          TABLE [
--              "Id" (UUID) - The identifier of the snippet
--              "Title" (VARCHAR) - The title of the snippet
--              "Description" (VARCHAR) - The description of the snippet
--              "Language" (VARCHAR) - The programming language of the snippet
--              "PreviewCode" (TEXT) - The preview code of the snippet
--              "Tags" (VARCHAR) - The tags associated with the snippet
--              "Public" (BOOLEAN) - Indicates whether the snippet is public
--              "Views" (BIGINT) - The number of views the snippet has
--              "Copy" (BIGINT) - The copied text of the snippet
--              "OwnerId" (UUID) - The identifier of the owner of the snippet
--          ]    
-- 
--          TABLE [
--              "ReactionType" (VARCHAR) - The type of reaction
--              "Count" (BIGINT) - The count of reactions of the given type
--          ]
-- 
-- Date:    22/December/2023
create or replace function list_user_snippets(userid uuid, onlyOwned bool, recent bool, skip int = 0, take int = 20, "order" character varying = 'ASC', orderby character varying = null, searchQuery character varying = null) returns SETOF refcursor
language plpgsql
$$
    DECLARE snippet_list uuid[];
    DECLARE snippet_list_ref refcursor;
    DECLARE reaction_list_ref refcursor;
    DECLARE metadata_json JSONB;
    DECLARE search_pattern character varying;
    BEGIN
        -- Handle the order by
        IF (orderby IS NULL OR orderby = '')
        THEN
            orderby = 'ModifiedAt';
        END IF;
        "order" := upper("order");
        
        -- creating search pattern
        search_pattern := concat('%', searchquery, '%');
        
        IF (recent = true)
        THEN
            -- Get the metadata of the user to get his/her recent snippets
            SELECT "Metadata" INTO metadata_json FROM sharecode."User" WHERE "Id" = userid;            
            IF jsonb_typeof(metadata_json->'RecentSnippets') = 'array' THEN
                snippet_list := ARRAY(
                    SELECT jsonb_array_elements_text(COALESCE(metadata_json->'RecentSnippets', '[]'::jsonb))::UUID
                );
            ELSE
                -- if a column like that is missing, use the snippet_list
                snippet_list := ARRAY[];
            END IF;            
         
        ELSE
            IF (onlyOwned = true)
            THEN
                snippet_list := ARRAY(SELECT "Id" FROM snippet."Snippets" SS
                WHERE "OwnerId" = userid AND "IsDeleted" = false);
            ELSE
                
                snippet_list := ARRAY (
                SELECT SS."Id" FROM snippet."Snippets" SS
                INNER JOIN snippet."SnippetAccessControls" SAC ON SAC."SnippetId" = SS."Id"
                WHERE SS."OwnerId" = userid AND SS."IsDeleted" = false AND SAC."IsDeleted" = false
                AND (concat(SS."Title", SS."Description", SS."Language", SS."PreviewCode", "Tags"::TEXT) ILIKE search_pattern )
                AND (SAC."Read" = true OR SAC."Write" = true OR SAC."Manage" = true)
                
                UNION 
                
                SELECT "Id" FROM snippet."Snippets" SS
                WHERE "OwnerId" = userid AND "IsDeleted" = false
                AND (concat(SS."Title", SS."Description", SS."Language", SS."PreviewCode", "Tags"::TEXT) ILIKE search_pattern ));
            END IF;
        END IF;
        
        IF(recent = true)
        THEN
            OPEN snippet_list_ref FOR
            SELECT "Id", "Title", "Description", "Public", "Views", "Copy", "Language", "PreviewCode", "OwnerId", (
                SELECT count(1) FROM snippet."SnippetComments" SSC WHERE SSC."SnippetId" = SS."Id" AND 
                SSC."ParentCommentId" IS NULL AND SSC."IsDeleted" = false
                )  AS "CommentCount", 10 AS "TotalCount" FROM snippet."Snippets" SS
            INNER JOIN unnest(snippet_list) S ON SS."Id" = S
            WHERE (concat(SS."Title", SS."Description", SS."Language", SS."PreviewCode", "Tags"::TEXT) ILIKE search_pattern )
            AND "IsDeleted" = 0;
            RETURN NEXT snippet_list_ref;
        ELSE 
            -- No where condition is required, bcs if the snippets are not my recent snippets, the snippet id will be already
            -- match properly
            OPEN snippet_list_ref FOR
            SELECT "Id", "Title", "Description", "Public", "Views", "Copy", "Language", "PreviewCode", "OwnerId", (
                SELECT count(1) FROM snippet."SnippetComments" SSC WHERE SSC."SnippetId" = SS."Id" AND 
                SSC."ParentCommentId" IS NULL AND SSC."IsDeleted" = false
                )  AS "CommentCount", COUNT(1) OVER () AS "TotalCount"  FROM snippet."Snippets" SS
            INNER JOIN unnest(snippet_list) S ON SS."Id" = S
            ORDER BY 
                CASE WHEN orderby = 'ModifiedAt' AND "order" = 'ASC' THEN SS."ModifiedAt" END,
                CASE WHEN orderby = 'ModifiedAt' AND "order" = 'DESC' THEN SS."ModifiedAt" END DESC
            OFFSET skip LIMIT take;
            RETURN NEXT snippet_list_ref;
        END IF;
        
        OPEN reaction_list_ref FOR
        SELECT "SnippetId", "ReactionType", "Reactions"
        FROM snippet."MV_SnippetReactions" SSR
        INNER JOIN unnest(snippet_list) SSL ON SSL = SSR."SnippetId";
        RETURN NEXT reaction_list_ref;
        
    END
$$;