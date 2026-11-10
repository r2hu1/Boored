import { z } from "zod";

export const searchRequestSchema = z.object({
  q: z.string().min(1).max(500),
});

export const searchResultSchema = z.object({
  note_id: z.string().uuid(),
  keyframe_id: z.string().uuid().nullable(),
  text: z.string(),
  highlight: z.string(),
  rank: z.number(),
});

export const searchResponseSchema = z.object({
  results: z.array(searchResultSchema),
});

export type SearchRequest = z.infer<typeof searchRequestSchema>;
export type SearchResult = z.infer<typeof searchResultSchema>;
export type SearchResponse = z.infer<typeof searchResponseSchema>;
