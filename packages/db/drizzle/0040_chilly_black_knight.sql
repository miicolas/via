ALTER TABLE "station_facts" DROP CONSTRAINT "station_facts_condition_check";--> statement-breakpoint
ALTER TABLE "station_facts" ADD CONSTRAINT "station_facts_condition_check" CHECK ((
        "station_facts"."kind" = 'accessibility'
        AND "station_facts"."condition" IN ('autonomous', 'staffAssistance', 'reservationRequired')
      ) OR (
        "station_facts"."kind" = 'toilets'
        AND "station_facts"."condition" = 'available'
      ) OR (
        "station_facts"."kind" = 'fountains'
        AND "station_facts"."condition" IN ('available', 'unavailable')
      ));