import { getCollection } from 'astro:content';

/** Published articles, newest first. Drafts never appear anywhere. */
export async function publishedNews() {
  return (await getCollection('news'))
    .filter((a) => !a.data.draft)
    .sort((a, b) => b.data.published.valueOf() - a.data.published.valueOf());
}

export function newsDate(d: Date) {
  return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
}
