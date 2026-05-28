import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getPollById } from "$lib/server/db";

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
    console.error(`Error fetching poll ${params.id}:`, error);
    return json({ error: "Failed to fetch poll" }, { status: 500 });
  }
};
