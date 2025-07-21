// server/api/image-search.get.ts (Nuxt 3 server route)
import type { H3Event } from 'h3';
import type { GoogleImageResult } from '~/types/supabase-tables';

// Define the type for the Google Custom Search API image result
interface GoogleImageItem {
  link: string;
  title: string;
  image: {
    contextLink: string;
    thumbnailLink: string;
  };
}

// Define the type for the API response
interface GoogleImageSearchResponse {
  items: GoogleImageItem[];
}

// Define the type for the returned image object
interface ImageSearchResult {
  url: string;
  title: string;
  thumbnail: string;
  sourcePage: string;
}

export default defineEventHandler(async (event: H3Event): Promise<ImageSearchResult[]> => {  
  const query = getQuery(event);
  const searchQuery = query.q as string;
  const start = parseInt(query.start as string) || 1;
  const apiKey = process.env.GOOGLE_SEARCH_API_KEY;
  const cx = process.env.GOOGLE_CSE_ID;

  const res = await $fetch<GoogleImageSearchResponse>('https://www.googleapis.com/customsearch/v1', {
    params: {
      key: apiKey,
      cx: cx,
      searchType: 'image',
      q: searchQuery,
      num: 10,
      start: start,
    },
  });  

  // Map the response to the desired format with types
  return res.items.map((item: GoogleImageItem): ImageSearchResult => ({
    url: item.link,
    title: item.title,
    thumbnail: item.image.thumbnailLink,
    sourcePage: item.image.contextLink,
  }));
});
