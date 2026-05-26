import type { PageLoad } from "./$types";
import type { Poll } from "$lib/types";

export const load: PageLoad = async ({ fetch }) => {
  try {
    const response = await fetch("/api/polls");
    const data = (await response.json()) as { polls: Poll[] };

    return {
      polls: data.polls,
    };
  } catch (error) {
    console.error("Error loading polls:", error);
    return {
      polls: [],
    };
  }
};
