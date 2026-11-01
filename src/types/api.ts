export type ApiErrorCode = "FEATURE_NOT_ENABLED" | "INTERNAL_ERROR";
export type ApiErrorResponse = { error: { code: ApiErrorCode; message: string } };
