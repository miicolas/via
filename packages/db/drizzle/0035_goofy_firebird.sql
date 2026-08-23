CREATE TABLE "city_demand_votes" (
	"city_slug" text NOT NULL,
	"voter_hash" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "city_demand_votes_city_slug_voter_hash_pk" PRIMARY KEY("city_slug","voter_hash")
);
--> statement-breakpoint
CREATE INDEX "city_demand_votes_created_idx" ON "city_demand_votes" USING btree ("created_at");