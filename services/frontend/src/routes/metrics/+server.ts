import { register } from "$lib/server/metrics";
import type { RequestHandler } from "./$types";

export const GET: RequestHandler = async () => {
  const metrics = await register.metrics();

  return new Response(metrics, {
    headers: {
      "Content-Type": register.contentType,
    },
  });
};
