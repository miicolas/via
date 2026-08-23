CREATE TABLE "account_saved_destinations" (
	"user_id" text NOT NULL,
	"id" text NOT NULL,
	"destination_id" text NOT NULL,
	"kind" text NOT NULL,
	"name" text NOT NULL,
	"context" text,
	"latitude" double precision NOT NULL,
	"longitude" double precision NOT NULL,
	"label" text NOT NULL,
	"system_image" text NOT NULL,
	"position" integer NOT NULL,
	"saved_at" timestamp with time zone NOT NULL,
	"updated_at" timestamp with time zone NOT NULL,
	CONSTRAINT "account_saved_destinations_user_id_id_pk" PRIMARY KEY("user_id","id"),
	CONSTRAINT "account_saved_destinations_position_check" CHECK ("account_saved_destinations"."position" >= 0)
);
--> statement-breakpoint
ALTER TABLE "account_places" ADD COLUMN "system_image" text;--> statement-breakpoint
UPDATE "account_places"
SET "system_image" = CASE
	WHEN "role" = 'home' THEN 'house.fill'
	ELSE 'briefcase.fill'
END;--> statement-breakpoint
ALTER TABLE "account_places" ALTER COLUMN "system_image" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "account_saved_destinations" ADD CONSTRAINT "account_saved_destinations_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "account_saved_destinations_user_destination_idx" ON "account_saved_destinations" USING btree ("user_id","destination_id");--> statement-breakpoint
CREATE INDEX "account_saved_destinations_user_position_idx" ON "account_saved_destinations" USING btree ("user_id","position");
