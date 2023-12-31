-- ----------------------------------------------------------------------------------
--
-- View:    MV_SnippetReactions
-- Schema:  snippet
-- Author:  Alen
--
-- Description: This view is responsible for perodical updates of Reaction Count.
--              Since it uses `MATERIALIZED VIEW`, the value will be cached and a
--              job will periodically refresh this
--
-- Usecase:     This view would cache the count of reactions a snippet has!
--
-- Structure:   SnippetId (UUID) - Id of the Snippet
--              ReactionType (string) - The type of reaction
--              Reactions (long) - The count of reactions
--
-- ----------------------------------------------------------------------------------
CREATE MATERIALIZED VIEW IF NOT EXISTS snippet."MV_SnippetReactions"
AS
SELECT "SnippetId", "ReactionType", COUNT("ReactionType") AS "Reactions" FROM snippet."SnippetReactions"
WHERE "IsDeleted" = false
GROUP BY "SnippetId", "ReactionType";

-- The index would be used to fetch data faster
CREATE INDEX "IX_MV_SnippetReactions" ON snippet."MV_SnippetReactions" ("SnippetId");