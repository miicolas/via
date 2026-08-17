CREATE TABLE "account_places" (
	"user_id" text NOT NULL,
	"id" text NOT NULL,
	"role" text NOT NULL,
	"kind" text NOT NULL,
	"name" text NOT NULL,
	"context" text,
	"latitude" double precision NOT NULL,
	"longitude" double precision NOT NULL,
	"saved_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	CONSTRAINT "account_places_user_id_id_pk" PRIMARY KEY("user_id","id")
);
--> statement-breakpoint
ALTER TABLE "account_favorite_stations" ADD COLUMN "latitude" double precision;--> statement-breakpoint
ALTER TABLE "account_favorite_stations" ADD COLUMN "longitude" double precision;--> statement-breakpoint
ALTER TABLE "account_places" ADD CONSTRAINT "account_places_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "account_places_user_role_idx" ON "account_places" USING btree ("user_id","role");