export type AiTask = "discovery_summary" | "opportunity_ideas";

export type AiRequest = {
  task: AiTask;
  context: string;
};

export type AiResult = {
  task: AiTask;
  output: {
    title: string;
    summary: string;
    points: string[];
    next_step: string;
  };
  provider: "mock";
  mock: true;
};

export interface AiProvider {
  generate(request: AiRequest): Promise<AiResult>;
}
