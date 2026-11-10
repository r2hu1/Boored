import { z } from "zod";

export const fileKindEnum = z.enum(["pdf", "timeline", "image"]);

export const fileSchema = z.object({
  id: z.string().uuid(),
  note_id: z.string().uuid(),
  kind: fileKindEnum,
  storage_key: z.string(),
  size_bytes: z.number().int(),
  checksum: z.string(),
});

export const presignUploadRequestSchema = z.object({
  kind: fileKindEnum,
  content_type: z.string(),
  size_bytes: z.number().int(),
});

export const presignUploadResponseSchema = z.object({
  url: z.string().url(),
  key: z.string(),
  headers: z.record(z.string(), z.string()),
});

export const confirmUploadSchema = z.object({
  key: z.string(),
  size_bytes: z.number().int(),
  checksum: z.string(),
});

export type FileKind = z.infer<typeof fileKindEnum>;
export type File = z.infer<typeof fileSchema>;
export type PresignUploadRequest = z.infer<typeof presignUploadRequestSchema>;
export type PresignUploadResponse = z.infer<typeof presignUploadResponseSchema>;
export type ConfirmUpload = z.infer<typeof confirmUploadSchema>;
