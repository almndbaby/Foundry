import { errorResponse } from "@/server/http/errors";

export const runtime = "nodejs";

export async function POST() {
  return errorResponse("FEATURE_NOT_ENABLED", "AI capabilities are not enabled in this foundation release.", 503);
}
