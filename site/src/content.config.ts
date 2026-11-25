import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

/**
 * The `news` collection, articles at /news/<slug>.
 *
 * One .md file per article under src/content/news. Each is a short piece on
 * an Azure security event: what happened, who is affected, what to do. The
 * `sources` list is rendered at the foot of the article, so every claim in
 * the body should trace back to one of them.
 *
 * draft: true keeps an article out of the listing AND prevents its page
 * from being generated. Publishing is a one-line frontmatter flip.
 */
const news = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/news' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    published: z.coerce.date(),
    updated: z.coerce.date().optional(),
    tags: z.array(z.string()).default([]),
    sources: z.array(z.object({ label: z.string(), url: z.string().url() })).default([]),
    draft: z.boolean().default(false),
  }),
});

export const collections = { news };
