-- ----------------------------------------------------------------------------------
--
-- View:    MV_SnippetCommentReactions
-- Schema:  snippet
-- Author:  Alen
--
-- Description: This view is responsible for perodical updates of Comments Reaction Count.
--              Since it uses `MATERIALIZED VIEW`, the value will be cached and a
--              job will periodically refresh this
--
-- Usecase:     This view would cache the count of reactions a snippet has!
--
-- Structure:   SnippetCommentId (UUID) - Id of the Comment
--              ReactionType (string) - The type of reaction
--              Reactions (long) - The count of reactions
--
-- ----------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS snippet."MV_SnippetCommentReactions"
AS
SELECT "SnippetCommentId", "SnippetId", "ReactionType", COUNT("ReactionType") AS "Reactions" 
FROM snippet."SnippetCommentReactions" SCR
INNER JOIN snippet."SnippetComments" SSC ON SSC."Id" = SCR."SnippetCommentId"
INNER JOIN snippet."Snippets" SSS ON SSS."Id" = SSC."SnippetId"
WHERE SSC."IsDeleted" = false AND SCR."IsDeleted" = false AND SSS."IsDeleted" = false
GROUP BY "SnippetCommentId", "SnippetId", "ReactionType";

-- Index to fetch data based on comments
CREATE INDEX "IX_MV_SnippetCommentReactions_SnippetCommentId" ON snippet."MV_SnippetCommentReactions" ("SnippetCommentId");

-- Index to fetch the popular snippets
CREATE INDEX "IX_MV_SnippetCommentReactions_SnippetId" ON snippet."MV_SnippetCommentReactions" ("SnippetId");

-- Unique index to concurrent refresh
CREATE UNIQUE INDEX "UNQ_MV_SnippetCommentReactions_SnippetCommentId_ReactionType" ON snippet."MV_SnippetCommentReactions" ("SnippetCommentId", "ReactionType");