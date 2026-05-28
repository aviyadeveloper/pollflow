import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getAllPolls } from "$lib/server/db";
import { logger } from "$lib/server/logger";

export const GET: RequestHandler = async () => {
  try {
    const polls = await getAllPolls();
    return json({ polls });
  } catch (error) {
    logger.error({ event: "polls_fetch_failed", error }, "Error fetching all polls");
    return json({ error: "Failed to fetch polls" }, { status: 500 });
  }
};
