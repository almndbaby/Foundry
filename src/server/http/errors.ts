import "server-only";
import { NextResponse } from "next/server";
import type { ApiErrorCode, ApiErrorResponse } from "@/types/api";

export function errorResponse(code: ApiErrorCode, message: string, status: number) {
  return NextResponse.json<ApiErrorResponse>({ error: { code, message } }, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}
