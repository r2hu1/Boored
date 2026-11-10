CREATE TYPE "public"."event_type" AS ENUM('ADD', 'ERASE', 'NONE');--> statement-breakpoint
CREATE TYPE "public"."file_kind" AS ENUM('pdf', 'timeline', 'image');--> statement-breakpoint
CREATE TYPE "public"."note_status" AS ENUM('recording', 'processing', 'ready', 'failed');--> statement-breakpoint
CREATE TYPE "public"."region_type" AS ENUM('text', 'math', 'table', 'diagram');--> statement-breakpoint
CREATE TABLE "files" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"note_id" uuid NOT NULL,
	"kind" "file_kind" NOT NULL,
	"storage_key" varchar(512) NOT NULL,
	"size_bytes" integer NOT NULL,
	"checksum" varchar(128) NOT NULL
);
--> statement-breakpoint
CREATE TABLE "keyframes" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"note_id" uuid NOT NULL,
	"index" integer NOT NULL,
	"timestamp_ms" integer NOT NULL,
	"event_type" "event_type" DEFAULT 'NONE' NOT NULL,
	"image_key" varchar(512) NOT NULL,
	"thumbnail_key" varchar(512),
	"diff_boxes" jsonb DEFAULT '[]'::jsonb
);
--> statement-breakpoint
CREATE TABLE "notes" (
	"id" uuid PRIMARY KEY NOT NULL,
	"user_id" uuid NOT NULL,
	"title" varchar(255) NOT NULL,
	"status" "note_status" DEFAULT 'recording' NOT NULL,
	"duration_ms" integer,
	"started_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"deleted_at" timestamp with time zone,
	"version" integer DEFAULT 1 NOT NULL,
	"search_vector" "tsvector" GENERATED ALWAYS AS (to_tsvector('english', coalesce(title, ''))) STORED
);
--> statement-breakpoint
CREATE TABLE "refresh_tokens" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" uuid NOT NULL,
	"token_hash" varchar(512) NOT NULL,
	"family_id" uuid NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "regions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"keyframe_id" uuid NOT NULL,
	"type" "region_type" NOT NULL,
	"bbox" jsonb NOT NULL,
	"text" text DEFAULT '' NOT NULL,
	"confidence" real DEFAULT 0 NOT NULL,
	"edited_by_user" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"google_sub" varchar(255) NOT NULL,
	"email" varchar(255) NOT NULL,
	"name" varchar(255) NOT NULL,
	"avatar_url" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_google_sub_unique" UNIQUE("google_sub")
);
--> statement-breakpoint
ALTER TABLE "files" ADD CONSTRAINT "files_note_id_notes_id_fk" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "keyframes" ADD CONSTRAINT "keyframes_note_id_notes_id_fk" FOREIGN KEY ("note_id") REFERENCES "public"."notes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "notes" ADD CONSTRAINT "notes_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "refresh_tokens" ADD CONSTRAINT "refresh_tokens_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "regions" ADD CONSTRAINT "regions_keyframe_id_keyframes_id_fk" FOREIGN KEY ("keyframe_id") REFERENCES "public"."keyframes"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "idx_files_note_id" ON "files" USING btree ("note_id");--> statement-breakpoint
CREATE INDEX "idx_keyframes_note_id" ON "keyframes" USING btree ("note_id");--> statement-breakpoint
CREATE UNIQUE INDEX "uq_keyframes_note_index" ON "keyframes" USING btree ("note_id","index");--> statement-breakpoint
CREATE INDEX "idx_notes_user_id" ON "notes" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "idx_notes_updated_at" ON "notes" USING btree ("updated_at");--> statement-breakpoint
CREATE INDEX "idx_notes_user_updated" ON "notes" USING btree ("user_id","updated_at");--> statement-breakpoint
CREATE INDEX "idx_notes_search" ON "notes" USING gin ("search_vector");--> statement-breakpoint
CREATE INDEX "idx_refresh_tokens_user_id" ON "refresh_tokens" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "idx_refresh_tokens_family_id" ON "refresh_tokens" USING btree ("family_id");--> statement-breakpoint
CREATE UNIQUE INDEX "idx_refresh_tokens_token_hash" ON "refresh_tokens" USING btree ("token_hash");--> statement-breakpoint
CREATE INDEX "idx_regions_keyframe_id" ON "regions" USING btree ("keyframe_id");