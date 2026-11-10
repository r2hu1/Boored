import { z } from "zod";

export const noteStatusEnum = z.enum(["recording", "processing", "ready", "failed"]);

export const noteSchema = z.object({
  id: z.string().uuid(),
  user_id: z.string().uuid(),
  title: z.string(),
  status: noteStatusEnum,
  duration_ms: z.number().int().nullable(),
  started_at: z.string().datetime().nullable(),
  created_at: z.string().datetime(),
  updated_at: z.string().datetime(),
  deleted_at: z.string().datetime().nullable(),
  version: z.number().int(),
});

export const createNoteSchema = z.object({
  id: z.string().uuid(),
  title: z.string().min(1).max(255),
});

export const updateNoteSchema = z.object({
  title: z.string().min(1).max(255).optional(),
  version: z.number().int(),
});

export const noteListResponseSchema = z.object({
  notes: z.array(noteSchema),
  cursor: z.string().nullable(),
});

export type NoteStatus = z.infer<typeof noteStatusEnum>;
export type Note = z.infer<typeof noteSchema>;
export type CreateNote = z.infer<typeof createNoteSchema>;
export type UpdateNote = z.infer<typeof updateNoteSchema>;
export type NoteListResponse = z.infer<typeof noteListResponseSchema>;
