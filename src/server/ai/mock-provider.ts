import "server-only";

import type { AiProvider, AiRequest, AiResult } from "./types";

/**
 * Deterministic development provider.
 * Does not contact an external AI service or incur usage charges.
 */
export class MockAiProvider implements AiProvider {
  async generate(request: AiRequest): Promise<AiResult> {
    const context = request.context.trim();

    if (request.task === "discovery_summary") {
      return {
        task: request.task,
        output: {
          title: "Discovery summary (mock)",
          summary:
            "The mock provider received your discovery context. A live AI provider will later turn this into a personalised synthesis.",
          points: [
            "Your submitted context was accepted by the server.",
            "No external AI service was contacted.",
            "This response is a test fixture, not personalised analysis.",
          ],
          next_step:
            "Connect the discovery questionnaire to this endpoint and review the response shape.",
        },
        provider: "mock",
        mock: true,
      };
    }

    return {
      task: request.task,
      output: {
        title: "Opportunity ideas (mock)",
        summary:
          "The mock provider successfully processed the opportunity-ideas request. Replace this deterministic response with researched, evidence-backed generation when a live provider is enabled.",
        points: [
          "Validate the problem with real potential customers.",
          "Estimate startup costs and ongoing operating effort.",
          "Check competition and willingness to pay before selecting an idea.",
          context.length > 0
            ? "The request included user context."
            : "No user context was supplied.",
        ],
        next_step:
          "Use this response contract to build the opportunity review interface.",
      },
      provider: "mock",
      mock: true,
    };
  }
}
