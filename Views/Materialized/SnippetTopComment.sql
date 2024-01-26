-- ----------------------------------------------------------------------------------
--
-- View:    MV_SnippetTopComment
-- Schema:  snippet
-- Author:  Alen
--
-- Description: This view is responsible for perodical updates the top comments of a snippet
--              Since it uses `MATERIALIZED VIEW`, the value will be cached and a
--              job will periodically refresh this
--
-- Usecase:     This view would cache the top comments of a snippet
--
-- Structure:   Id (UUID) - Id of the Snippet Comment
--              Text (string) - The comment which was posted
--              SnippetId (UUID) - The Id of the snippet
--              UserId (UUID) - The Id of the of the user who posted the snippet
--              TotalReactions (long) - The count of the total reaction of that snippet
--
-- ----------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS snippet."MV_SnippetTopComment"
AS
    SELECT SSC."Id",
    SSC."Text",
    SSC."Mentions", 
    SSC."SnippetId", 
    SSC."UserId", 
    COUNT(SSR."Id") OVER (PARTITION BY SSC."SnippetId") AS "TotalReactions" 
    FROM snippet."SnippetComments" SSC
    INNER JOIN snippet."SnippetCommentReactions" SSR ON SSR."SnippetCommentId" = SSC."Id"
    INNER JOIN snippet."Snippets" SSS ON SSC."SnippetId" = SSS."Id"
    WHERE SSS."IsDeleted" = false AND SSC."IsDeleted" = false AND SSR."IsDeleted" = false
    ORDER BY "TotalReactions" DESC, SSC."CreatedAt" DESC
    LIMIT 20;
    
-- The index would be used to fetch data faster based on Snippet
CREATE INDEX "IX_MV_SnippetTopComment_SnippetId" ON snippet."MV_SnippetTopComment" ("SnippetId");    

CREATE UNIQUE INDEX "UNQ_MV_SnippetTopComments" ON snippet."MV_SnippetTopComment" ("Id", "SnippetId", "UserId");