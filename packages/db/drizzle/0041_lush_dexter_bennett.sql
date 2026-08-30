CREATE TABLE "friend_invitations" (
	"id" text NOT NULL,
	"token_hash" text PRIMARY KEY NOT NULL,
	"idempotency_key" text NOT NULL,
	"inviter_user_id" text NOT NULL,
	"accepted_user_id" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"accepted_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	CONSTRAINT "friend_invitations_id_unique" UNIQUE("id"),
	CONSTRAINT "friend_invitations_idempotency_key_unique" UNIQUE("idempotency_key"),
	CONSTRAINT "friend_invitations_status_check" CHECK ("friend_invitations"."status" IN ('pending', 'accepted', 'revoked', 'expired'))
);
--> statement-breakpoint
CREATE TABLE "friendships" (
	"first_user_id" text NOT NULL,
	"second_user_id" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "friendships_first_user_id_second_user_id_pk" PRIMARY KEY("first_user_id","second_user_id"),
	CONSTRAINT "friendships_distinct_ordered_users_check" CHECK ("friendships"."first_user_id" < "friendships"."second_user_id")
);
--> statement-breakpoint
CREATE TABLE "meetup_activity_tokens" (
	"meetup_id" text NOT NULL,
	"participant_id" text NOT NULL,
	"installation_id" text NOT NULL,
	"activity_id" text NOT NULL,
	"token" text NOT NULL,
	"environment" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "meetup_activity_tokens_meetup_id_installation_id_activity_id_pk" PRIMARY KEY("meetup_id","installation_id","activity_id"),
	CONSTRAINT "meetup_activity_tokens_environment_check" CHECK ("meetup_activity_tokens"."environment" IN ('sandbox', 'production'))
);
--> statement-breakpoint
CREATE TABLE "meetup_device_keys" (
	"id" text PRIMARY KEY NOT NULL,
	"meetup_id" text NOT NULL,
	"participant_id" text NOT NULL,
	"user_id" text,
	"public_key" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"revoked_at" timestamp with time zone
);
--> statement-breakpoint
CREATE TABLE "meetup_invitations" (
	"id" text PRIMARY KEY NOT NULL,
	"meetup_id" text NOT NULL,
	"token_hash" text NOT NULL,
	"idempotency_key" text NOT NULL,
	"invited_user_id" text,
	"status" text DEFAULT 'pending' NOT NULL,
	"claimed_by_participant_id" text,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"responded_at" timestamp with time zone,
	"revoked_at" timestamp with time zone,
	CONSTRAINT "meetup_invitations_token_hash_unique" UNIQUE("token_hash"),
	CONSTRAINT "meetup_invitations_idempotency_key_unique" UNIQUE("idempotency_key"),
	CONSTRAINT "meetup_invitations_status_check" CHECK ("meetup_invitations"."status" IN ('pending', 'accepted', 'declined', 'revoked', 'expired'))
);
--> statement-breakpoint
CREATE TABLE "meetup_key_envelopes" (
	"meetup_id" text NOT NULL,
	"key_revision" integer NOT NULL,
	"recipient_key_id" text NOT NULL,
	"sender_participant_id" text,
	"ciphertext" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "meetup_key_envelopes_meetup_id_key_revision_recipient_key_id_pk" PRIMARY KEY("meetup_id","key_revision","recipient_key_id"),
	CONSTRAINT "meetup_key_envelopes_revision_check" CHECK ("meetup_key_envelopes"."key_revision" > 0)
);
--> statement-breakpoint
CREATE TABLE "meetup_participants" (
	"id" text PRIMARY KEY NOT NULL,
	"meetup_id" text NOT NULL,
	"user_id" text,
	"token_hash" text NOT NULL,
	"idempotency_key" text NOT NULL,
	"display_name" text NOT NULL,
	"role" text NOT NULL,
	"state" text NOT NULL,
	"share_level" text NOT NULL,
	"zone" text DEFAULT 'middle' NOT NULL,
	"encrypted_origin" jsonb NOT NULL,
	"planning_policy" jsonb NOT NULL,
	"journey" jsonb,
	"first_boarding_station" jsonb,
	"departure_at" timestamp with time zone,
	"arrival_at" timestamp with time zone,
	"public_key" text NOT NULL,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "meetup_participants_token_hash_unique" UNIQUE("token_hash"),
	CONSTRAINT "meetup_participants_idempotency_key_unique" UNIQUE("idempotency_key"),
	CONSTRAINT "meetup_participants_role_check" CHECK ("meetup_participants"."role" IN ('organizer', 'member')),
	CONSTRAINT "meetup_participants_state_check" CHECK ("meetup_participants"."state" IN ('configuring', 'ready', 'underway', 'joined', 'arrived', 'declined', 'left', 'removed')),
	CONSTRAINT "meetup_participants_share_level_check" CHECK ("meetup_participants"."share_level" IN ('positionAndProgress', 'progressOnly', 'off')),
	CONSTRAINT "meetup_participants_zone_check" CHECK ("meetup_participants"."zone" IN ('front', 'middle', 'rear'))
);
--> statement-breakpoint
CREATE TABLE "meetups" (
	"id" text PRIMARY KEY NOT NULL,
	"organizer_user_id" text,
	"destination_id" text NOT NULL,
	"destination_name" text NOT NULL,
	"destination_latitude" double precision NOT NULL,
	"destination_longitude" double precision NOT NULL,
	"target_arrival_at" timestamp with time zone NOT NULL,
	"phase" text DEFAULT 'planning' NOT NULL,
	"revision" integer DEFAULT 0 NOT NULL,
	"key_revision" integer DEFAULT 1 NOT NULL,
	"plan" jsonb,
	"next_refresh_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL,
	"purge_at" timestamp with time zone NOT NULL,
	CONSTRAINT "meetups_phase_check" CHECK ("meetups"."phase" IN ('draft', 'planning', 'ready', 'live', 'completed', 'cancelled', 'expired')),
	CONSTRAINT "meetups_revision_check" CHECK ("meetups"."revision" >= 0),
	CONSTRAINT "meetups_key_revision_check" CHECK ("meetups"."key_revision" > 0)
);
--> statement-breakpoint
ALTER TABLE "friend_invitations" ADD CONSTRAINT "friend_invitations_inviter_user_id_users_id_fk" FOREIGN KEY ("inviter_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friend_invitations" ADD CONSTRAINT "friend_invitations_accepted_user_id_users_id_fk" FOREIGN KEY ("accepted_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_first_user_id_users_id_fk" FOREIGN KEY ("first_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "friendships" ADD CONSTRAINT "friendships_second_user_id_users_id_fk" FOREIGN KEY ("second_user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_activity_tokens" ADD CONSTRAINT "meetup_activity_tokens_meetup_id_meetups_id_fk" FOREIGN KEY ("meetup_id") REFERENCES "public"."meetups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_activity_tokens" ADD CONSTRAINT "meetup_activity_tokens_participant_id_meetup_participants_id_fk" FOREIGN KEY ("participant_id") REFERENCES "public"."meetup_participants"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_device_keys" ADD CONSTRAINT "meetup_device_keys_meetup_id_meetups_id_fk" FOREIGN KEY ("meetup_id") REFERENCES "public"."meetups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_device_keys" ADD CONSTRAINT "meetup_device_keys_participant_id_meetup_participants_id_fk" FOREIGN KEY ("participant_id") REFERENCES "public"."meetup_participants"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_device_keys" ADD CONSTRAINT "meetup_device_keys_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_invitations" ADD CONSTRAINT "meetup_invitations_meetup_id_meetups_id_fk" FOREIGN KEY ("meetup_id") REFERENCES "public"."meetups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_invitations" ADD CONSTRAINT "meetup_invitations_invited_user_id_users_id_fk" FOREIGN KEY ("invited_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_invitations" ADD CONSTRAINT "meetup_invitations_claimed_by_participant_id_meetup_participants_id_fk" FOREIGN KEY ("claimed_by_participant_id") REFERENCES "public"."meetup_participants"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_key_envelopes" ADD CONSTRAINT "meetup_key_envelopes_meetup_id_meetups_id_fk" FOREIGN KEY ("meetup_id") REFERENCES "public"."meetups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_key_envelopes" ADD CONSTRAINT "meetup_key_envelopes_recipient_key_id_meetup_device_keys_id_fk" FOREIGN KEY ("recipient_key_id") REFERENCES "public"."meetup_device_keys"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_key_envelopes" ADD CONSTRAINT "meetup_key_envelopes_sender_participant_id_meetup_participants_id_fk" FOREIGN KEY ("sender_participant_id") REFERENCES "public"."meetup_participants"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_participants" ADD CONSTRAINT "meetup_participants_meetup_id_meetups_id_fk" FOREIGN KEY ("meetup_id") REFERENCES "public"."meetups"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetup_participants" ADD CONSTRAINT "meetup_participants_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meetups" ADD CONSTRAINT "meetups_organizer_user_id_users_id_fk" FOREIGN KEY ("organizer_user_id") REFERENCES "public"."users"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "friend_invitations_inviter_idx" ON "friend_invitations" USING btree ("inviter_user_id");--> statement-breakpoint
CREATE INDEX "friend_invitations_expires_idx" ON "friend_invitations" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "friendships_second_user_idx" ON "friendships" USING btree ("second_user_id");--> statement-breakpoint
CREATE INDEX "meetup_activity_tokens_participant_idx" ON "meetup_activity_tokens" USING btree ("participant_id");--> statement-breakpoint
CREATE INDEX "meetup_device_keys_meetup_idx" ON "meetup_device_keys" USING btree ("meetup_id");--> statement-breakpoint
CREATE INDEX "meetup_device_keys_participant_idx" ON "meetup_device_keys" USING btree ("participant_id");--> statement-breakpoint
CREATE INDEX "meetup_invitations_meetup_status_idx" ON "meetup_invitations" USING btree ("meetup_id","status");--> statement-breakpoint
CREATE INDEX "meetup_invitations_user_status_idx" ON "meetup_invitations" USING btree ("invited_user_id","status");--> statement-breakpoint
CREATE INDEX "meetup_invitations_expires_idx" ON "meetup_invitations" USING btree ("expires_at");--> statement-breakpoint
CREATE INDEX "meetup_participants_meetup_idx" ON "meetup_participants" USING btree ("meetup_id");--> statement-breakpoint
CREATE INDEX "meetup_participants_user_idx" ON "meetup_participants" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "meetups_target_arrival_idx" ON "meetups" USING btree ("target_arrival_at");--> statement-breakpoint
CREATE INDEX "meetups_refresh_idx" ON "meetups" USING btree ("next_refresh_at");--> statement-breakpoint
CREATE INDEX "meetups_purge_idx" ON "meetups" USING btree ("purge_at");--> statement-breakpoint
CREATE INDEX "meetups_organizer_idx" ON "meetups" USING btree ("organizer_user_id");