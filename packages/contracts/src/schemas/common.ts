import { z } from "zod";

export const errorResponseSchema = z.object({
  error: z.object({
    code: z.string(),
    message: z.string(),
    details: z.any().optional(),
  }),
});

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

export const cursorSchema = z.object({
  cursor: z.string().optional(),
});

export const uuidSchema = z.string().uuid();

export type ErrorResponse = z.infer<typeof errorResponseSchema>;
export type Pagination = z.infer<typeof paginationSchema>;
export type CursorParams = z.infer<typeof cursorSchema>;
