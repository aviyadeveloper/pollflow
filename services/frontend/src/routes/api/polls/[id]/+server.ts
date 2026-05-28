import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getPollById } from "$lib/server/db";
import { logger } from "$lib/server/logger";

export const GET: RequestHandler = async ({ params }) => {
  try {
    const pollId = parseInt(params.id);

    if (isNaN(pollId)) {
      return json({ error: "Invalid poll ID" }, { status: 400 });
    }

    const poll = await getPollById(pollId);

    if (!poll) {
      return json({ error: "Poll not found" }, { status: 404 });
    }

    return json({ poll });
  } catch (error) {
    logger.error(
      { event: "poll_fetch_failed", poll_id: params.id, error },
      "Error fetching poll",
    );
    return json({ error: "Failed to fetch poll" }, { status: 500 });
  }
};
