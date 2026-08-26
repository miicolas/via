CREATE TABLE "journey_shares" (
	"token_hash" text PRIMARY KEY NOT NULL,
	"idempotency_key" text NOT NULL,
	"owner_user_id" text,
	"snapshot" jsonb NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	CONSTRAINT "journey_shares_idempotency_key_unique" UNIQUE("idempotency_key")
);
--> statement-breakpoint
ALTER TABLE "journey_shares" ADD CONSTRAINT "journey_shares_owner_user_id_users_id_fk" FOREIGN KEY ("owner_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "journey_shares_expires_idx" ON "journey_shares" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "journey_shares_owner_idx" ON "journey_shares" USING btree ("owner_user_id");