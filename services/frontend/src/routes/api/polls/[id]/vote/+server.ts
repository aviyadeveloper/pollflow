import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { publishVote } from "$lib/server/redis";
import { logger } from "$lib/server/logger";

export const POST: RequestHandler = async ({
  params,
  request,
  getClientAddress,
}) => {
  const pollId = parseInt(params.id);

  try {
    if (isNaN(pollId)) {
      return json({ error: "Invalid poll ID" }, { status: 400 });
    }

    const body = await request.json();
    const { option } = body;

    // Validate required fields
    if (!option) {
      return json({ error: "Missing required field: option" }, { status: 400 });
    }

    // Validate option is 'a' or 'b'
    if (option !== "a" && option !== "b") {
      return json(
        { error: "Invalid option. Must be 'a' or 'b'" },
        { status: 400 },
      );
    }

    // Get user's IP address
    const userIp = getClientAddress();

    // Publish vote to Redis queue for processing by poll-broker
    await publishVote({
      pollId,
      option,
      userIp,
    });

    return json({ success: true, message: "Vote submitted for processing" });
  } catch (error) {
    logger.error(
      { event: "vote_submit_failed", poll_id: pollId, error },
      "Error submitting vote",
    );
    return json({ error: "Failed to submit vote" }, { status: 500 });
  }
};
