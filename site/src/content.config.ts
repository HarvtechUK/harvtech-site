import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

/**
 * The `docs` collection — the internal-style wiki at /docs/*.
 *
 * Each .md file under src/content/docs/<category>/<slug>.md gets routed to
 * /docs/<category>/<slug> by src/pages/docs/[...slug].astro. The category
 * is also derived from the folder name as a safety belt, but the
 * frontmatter `category` is the source of truth.
 *
 * status: drafts, deprecated, and superseded docs are still indexable by
 *   URL but the /docs landing page filters them out so the index stays
 *   clean. "superseded" is the standard ADR vocabulary for "this decision
 *   has been re-made elsewhere" — semantically distinct from "deprecated"
 *   (rotting / will be removed) even though both hide from the index.
 */
const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    category: z.enum(['architecture', 'decisions', 'how-to', 'tools']),
    order: z.number().default(100),
    updated: z.coerce.date(),
    status: z.enum(['living', 'draft', 'deprecated', 'superseded']).default('living'),
  }),
});

export const collections = { docs };
