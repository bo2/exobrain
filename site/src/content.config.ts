import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
import { docsLoader } from '@astrojs/starlight/loaders';
import { docsSchema } from '@astrojs/starlight/schema';

export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
  // The seed's feed is the project's changelog; the site renders it at build time.
  feed: defineCollection({
    loader: glob({ pattern: '0*.md', base: '../seed/feed' }),
    schema: z.object({
      title: z.string(),
      date: z.coerce.date(),
      touches_invariant: z.boolean().default(false),
    }),
  }),
};
