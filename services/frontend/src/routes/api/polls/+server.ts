import { json } from "@sveltejs/kit";
import type { RequestHandler } from "./$types";
import { getAllPolls } from "$lib/server/db";

export const GET: RequestHandler = async () => {
  try {
    const polls = await getAllPolls();
    return json({ polls });
  } catch (error) {
    console.error("Error fetching all polls:", error);
    return json({ error: "Failed to fetch polls" }, { status: 500 });
  }
};
