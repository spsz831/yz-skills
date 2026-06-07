import process from 'node:process';

export const GEMINI_DEFAULT_MODEL = 'gemini-3.1-pro-preview';
export const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
export const OPENAI_DEFAULT_API_BASE = 'https://api.openai.com/v1';
export const OPENAI_DEFAULT_MODEL = 'gpt-4o-mini';

export type OpenAIWireApi = 'chat' | 'responses';

export interface OpenAIConfig {
  apiKey?: string;
  apiBase?: string;
  model?: string;
  wireApi?: string;
}

export interface AIClient {
  call(prompt: string): Promise<string>;
}

function inferWireApiFromBase(apiBase?: string): OpenAIWireApi | null {
  const normalizedBase = apiBase?.trim().toLowerCase() || '';
  if (!normalizedBase) return null;

  if (normalizedBase.includes('rawchat.cn/codex')) {
    return 'responses';
  }

  if (normalizedBase.includes('localhost:20128')) {
    return 'responses';
  }

  return null;
}

function normalizeOpenAIWireApi(wireApi?: string, apiBase?: string): OpenAIWireApi {
  const normalized = wireApi?.trim().toLowerCase();
  if (normalized === 'responses' || normalized === 'response') {
    return 'responses';
  }
  if (!normalized) {
    return inferWireApiFromBase(apiBase) ?? 'chat';
  }
  return 'chat';
}

function inferOpenAIModel(apiBase: string): string {
  const base = apiBase.toLowerCase();
  if (base.includes('deepseek')) return 'deepseek-chat';
  return OPENAI_DEFAULT_MODEL;
}

function extractTextFromChatContent(content: unknown): string {
  if (typeof content === 'string') {
    return content.trim();
  }

  if (Array.isArray(content)) {
    return content
      .map((item) => {
        if (typeof item === 'string') return item;
        if (item && typeof item === 'object' && 'text' in item && typeof item.text === 'string') {
          return item.text;
        }
        return '';
      })
      .filter(Boolean)
      .join('\n')
      .trim();
  }

  return '';
}

function extractTextFromResponseJson(data: unknown): string {
  if (!data || typeof data !== 'object') return '';

  const maybeData = data as {
    output_text?: string;
    output?: Array<{
      type?: string;
      content?: Array<{ type?: string; text?: string }>;
    }>;
    choices?: Array<{
      message?: {
        content?: string | Array<{ type?: string; text?: string }>;
      };
    }>;
  };

  if (typeof maybeData.output_text === 'string' && maybeData.output_text.trim()) {
    return maybeData.output_text.trim();
  }

  const messageTexts = maybeData.output
    ?.flatMap((item) => item.content ?? [])
    .filter((part) => part.type === 'output_text' && typeof part.text === 'string')
    .map((part) => part.text!.trim())
    .filter(Boolean);

  if (messageTexts && messageTexts.length > 0) {
    return messageTexts.join('\n').trim();
  }

  const choiceContent = extractTextFromChatContent(maybeData.choices?.[0]?.message?.content);
  if (choiceContent) {
    return choiceContent;
  }

  return '';
}

function extractTextFromResponsesSse(raw: string): string {
  const dataLines = [...raw.matchAll(/^data:\s*(\{.*\})$/gm)];
  const doneTexts: string[] = [];

  for (const match of dataLines) {
    try {
      const payload = JSON.parse(match[1] ?? '{}') as { type?: string; text?: string };
      if (payload.type === 'response.output_text.done' && typeof payload.text === 'string' && payload.text.trim()) {
        doneTexts.push(payload.text.trim());
      }
    } catch {
      // ignore malformed SSE frames
    }
  }

  if (doneTexts.length > 0) {
    return doneTexts.join('\n').trim();
  }

  const deltaTexts: string[] = [];
  for (const match of dataLines) {
    try {
      const payload = JSON.parse(match[1] ?? '{}') as { type?: string; delta?: string };
      if (payload.type === 'response.output_text.delta' && typeof payload.delta === 'string') {
        deltaTexts.push(payload.delta);
      }
    } catch {
      // ignore malformed SSE frames
    }
  }

  return deltaTexts.join('').trim();
}

export async function callGemini(prompt: string, apiKey: string, model: string): Promise<string> {
  const resolvedModel = (model.trim() || GEMINI_DEFAULT_MODEL).replace(/^models\//, '');
  const geminiUrl = `${GEMINI_API_BASE}/${resolvedModel}:generateContent`;
  const response = await fetch(`${geminiUrl}?key=${apiKey}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.3,
        topP: 0.8,
        topK: 40,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => 'Unknown error');
    throw new Error(`Gemini API error (${response.status}): ${errorText}`);
  }

  const data = await response.json() as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

export async function callOpenAICompatible(prompt: string, config: OpenAIConfig): Promise<string> {
  const apiKey = config.apiKey?.trim();
  const apiBase = (config.apiBase?.trim() || OPENAI_DEFAULT_API_BASE).replace(/\/+$/, '');
  const wireApi = normalizeOpenAIWireApi(config.wireApi, apiBase);
  let model = config.model?.trim() || '';

  if (!apiKey) {
    throw new Error('Missing OPENAI_API_KEY');
  }
  if (!model) {
    model = inferOpenAIModel(apiBase);
  }

  if (wireApi === 'responses') {
    const response = await fetch(`${apiBase}/responses`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        model,
        input: prompt,
        stream: true,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error');
      throw new Error(`OpenAI responses API error (${response.status}): ${errorText}`);
    }

    const contentType = response.headers.get('content-type')?.toLowerCase() ?? '';
    const rawText = await response.text();

    if (contentType.includes('text/event-stream')) {
      const sseText = extractTextFromResponsesSse(rawText);
      if (sseText) return sseText;
      throw new Error('Responses API returned empty SSE content');
    }

    const jsonText = extractTextFromResponseJson(JSON.parse(rawText));
    if (jsonText) return jsonText;
    throw new Error('Responses API returned empty content');
  }

  const response = await fetch(`${apiBase}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      top_p: 0.8,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text().catch(() => 'Unknown error');
    throw new Error(`OpenAI-compatible API error (${response.status}): ${errorText}`);
  }

  const data = await response.json() as {
    choices?: Array<{
      message?: {
        content?: string | Array<{ type?: string; text?: string }>;
      };
    }>;
  };

  const content = extractTextFromChatContent(data.choices?.[0]?.message?.content);
  if (!content) {
    throw new Error('Model returned empty content');
  }
  return content;
}

function isGeminiConnectionError(error: unknown): boolean {
  const message = (error instanceof Error ? error.message : String(error)).toLowerCase();
  return (
    message.includes('unable to connect') ||
    message.includes('fetch failed') ||
    message.includes('network') ||
    message.includes('timed out') ||
    message.includes('econn') ||
    message.includes('enotfound') ||
    message.includes('eai_again')
  );
}

export function createAIClient(config: {
  geminiApiKey?: string;
  geminiModel?: string;
  openaiApiKey?: string;
  openaiApiBase?: string;
  openaiModel?: string;
  openaiWireApi?: string;
}): AIClient {
  const state = {
    geminiApiKey: config.geminiApiKey?.trim() || '',
    geminiModel: config.geminiModel?.trim() || GEMINI_DEFAULT_MODEL,
    openaiApiKey: config.openaiApiKey?.trim() || '',
    openaiApiBase: (config.openaiApiBase?.trim() || OPENAI_DEFAULT_API_BASE).replace(/\/+$/, ''),
    openaiModel: config.openaiModel?.trim() || '',
    openaiWireApi: normalizeOpenAIWireApi(config.openaiWireApi, config.openaiApiBase),
    geminiEnabled: Boolean(config.geminiApiKey?.trim()),
    geminiConnectionFailures: 0,
    geminiFailureThreshold: 2,
    fallbackLogged: false,
  };

  if (!state.openaiModel) {
    state.openaiModel = inferOpenAIModel(state.openaiApiBase);
  }

  return {
    async call(prompt: string): Promise<string> {
      if (state.geminiEnabled && state.geminiApiKey) {
        try {
          const result = await callGemini(prompt, state.geminiApiKey, state.geminiModel);
          state.geminiConnectionFailures = 0;
          return result;
        } catch (error) {
          if (state.openaiApiKey) {
            const reason = error instanceof Error ? error.message : String(error);
            const isConnErr = isGeminiConnectionError(error);

            if (isConnErr) {
              state.geminiConnectionFailures += 1;
            } else {
              state.geminiConnectionFailures = 0;
            }

            const shouldDisableGemini = !isConnErr || state.geminiConnectionFailures >= state.geminiFailureThreshold;
            if (shouldDisableGemini) {
              if (!state.fallbackLogged) {
                console.warn(
                  `[digest] Gemini failed, switching to OpenAI-compatible fallback (${state.openaiApiBase}, model=${state.openaiModel}, wire=${state.openaiWireApi}). Reason: ${reason}`,
                );
                state.fallbackLogged = true;
              }
              state.geminiEnabled = false;
            } else {
              console.warn(
                `[digest] Gemini connection failed (${state.geminiConnectionFailures}/${state.geminiFailureThreshold}), using OpenAI fallback for this request. Reason: ${reason}`,
              );
            }

            return callOpenAICompatible(prompt, {
              apiKey: state.openaiApiKey,
              apiBase: state.openaiApiBase,
              model: state.openaiModel,
              wireApi: state.openaiWireApi,
            });
          }
          throw error;
        }
      }

      if (state.openaiApiKey) {
        return callOpenAICompatible(prompt, {
          apiKey: state.openaiApiKey,
          apiBase: state.openaiApiBase,
          model: state.openaiModel,
          wireApi: state.openaiWireApi,
        });
      }

      throw new Error('No AI API key configured. Set GEMINI_API_KEY and/or OPENAI_API_KEY.');
    },
  };
}

export function loadAiEnv() {
  return {
    geminiApiKey: process.env.GEMINI_API_KEY,
    geminiModel: process.env.GEMINI_MODEL,
    openaiApiKey: process.env.OPENAI_API_KEY,
    openaiApiBase: process.env.OPENAI_API_BASE,
    openaiModel: process.env.OPENAI_MODEL,
    openaiWireApi: process.env.OPENAI_WIRE_API,
  };
}
