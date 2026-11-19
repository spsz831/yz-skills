import { existsSync, readFileSync } from 'node:fs';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawn } from 'node:child_process';
import process from 'node:process';

export const GEMINI_DEFAULT_MODEL = 'gemini-3.1-pro-preview';
export const GEMINI_API_BASE = 'https://generativelanguage.googleapis.com/v1beta/models';
export const OPENAI_DEFAULT_API_BASE = 'https://api.openai.com/v1';
export const OPENAI_DEFAULT_MODEL = 'gpt-4o-mini';
const AI_REQUEST_TIMEOUT_MS = 30_000;
const CODEX_CLI_TIMEOUT_MS = 120_000;

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

type RepoEnvMap = Record<string, string>;

let cachedRepoEnv: RepoEnvMap | null = null;

function parseRepoEnvFile(): RepoEnvMap {
  const envPath = join(process.cwd(), '.env');
  if (!existsSync(envPath)) {
    return {};
  }

  const result: RepoEnvMap = {};
  const content = readFileSync(envPath, 'utf8');

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith('#')) continue;

    const eqIndex = line.indexOf('=');
    if (eqIndex <= 0) continue;

    const key = line.slice(0, eqIndex).trim();
    let value = line.slice(eqIndex + 1).trim();

    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith('\'') && value.endsWith('\''))
    ) {
      value = value.slice(1, -1);
    }

    result[key] = value;
  }

  return result;
}

function getRepoEnvValue(key: string): string | undefined {
  if (cachedRepoEnv === null) {
    cachedRepoEnv = parseRepoEnvFile();
  }

  if (Object.prototype.hasOwnProperty.call(cachedRepoEnv, key)) {
    return cachedRepoEnv[key];
  }

  return undefined;
}

function pickFirstNonEmpty(...values: Array<string | undefined>): string | undefined {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value;
    }
  }

  return undefined;
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

async function fetchWithTimeout(input: string, init: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), AI_REQUEST_TIMEOUT_MS);
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`AI request timed out after ${AI_REQUEST_TIMEOUT_MS / 1000}s`);
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

async function callCodexCli(prompt: string, model?: string, reasoningEffort = 'low'): Promise<string> {
  const tempDir = await mkdtemp(join(tmpdir(), 'ai-daily-digest-codex-'));
  const outputPath = join(tempDir, 'last-message.txt');
  const command = process.platform === 'win32' ? 'node' : 'codex';
  const codexEntry = process.platform === 'win32'
    ? join(process.env.APPDATA ?? '', 'npm', 'node_modules', '@openai', 'codex', 'bin', 'codex.js')
    : '';
  const args = [
    ...(codexEntry ? [codexEntry] : []),
    'exec',
    '-c', `model_reasoning_effort=${JSON.stringify(reasoningEffort)}`,
    '--ephemeral',
    '--sandbox', 'read-only',
    '--skip-git-repo-check',
    '--color', 'never',
    ...(model?.trim() ? ['--model', model.trim()] : []),
    '--output-last-message', outputPath,
    '-',
  ];

  try {
    await new Promise<void>((resolve, reject) => {
      const child = spawn(command, args, {
        cwd: process.cwd(),
        windowsHide: true,
        stdio: ['pipe', 'ignore', 'pipe'],
      });
      let stderr = '';
      let settled = false;
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        child.kill();
        reject(new Error(`process timed out after ${CODEX_CLI_TIMEOUT_MS / 1000}s`));
      }, CODEX_CLI_TIMEOUT_MS);

      child.stderr?.on('data', (chunk) => {
        stderr += String(chunk);
        if (stderr.length > 10 * 1024 * 1024) stderr = stderr.slice(-10 * 1024 * 1024);
      });
      child.once('error', (error) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        reject(error);
      });
      // Descendant processes can inherit stderr on Windows and keep the pipe
      // open after Codex exits. Waiting for "close" would then report a timeout
      // despite a successful result; "exit" tracks the launched process itself.
      child.once('exit', (code, signal) => {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        child.stderr?.destroy();
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`exit code ${code ?? 'unknown'}${signal ? ` (${signal})` : ''}: ${stderr.trim()}`));
        }
      });
      child.stdin.write(prompt);
      child.stdin.end();
    });
    const content = (await readFile(outputPath, 'utf8')).trim();
    if (!content) throw new Error('Codex CLI returned empty content');
    return content;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Codex CLI request failed: ${message}`);
  } finally {
    await rm(tempDir, { recursive: true, force: true }).catch(() => undefined);
  }
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
  const response = await fetchWithTimeout(`${geminiUrl}?key=${apiKey}`, {
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
    const response = await fetchWithTimeout(`${apiBase}/responses`, {
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

  const response = await fetchWithTimeout(`${apiBase}/chat/completions`, {
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
  provider?: string;
  codexCliModel?: string;
  codexCliReasoningEffort?: string;
  geminiApiKey?: string;
  geminiModel?: string;
  openaiApiKey?: string;
  openaiApiBase?: string;
  openaiModel?: string;
  openaiWireApi?: string;
}): AIClient {
  const state = {
    provider: config.provider?.trim().toLowerCase() || '',
    codexCliModel: config.codexCliModel?.trim() || '',
    codexCliReasoningEffort: config.codexCliReasoningEffort?.trim() || 'low',
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
      if (state.provider === 'codex-cli') {
        return callCodexCli(prompt, state.codexCliModel, state.codexCliReasoningEffort);
      }
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
  const repoAiProvider = getRepoEnvValue('AI_PROVIDER');
  const repoCodexCliModel = getRepoEnvValue('CODEX_CLI_MODEL');
  const repoCodexCliReasoningEffort = getRepoEnvValue('CODEX_CLI_REASONING_EFFORT');
  const repoGeminiApiKey = getRepoEnvValue('GEMINI_API_KEY');
  const repoGeminiModel = getRepoEnvValue('GEMINI_MODEL');
  const repoOpenaiApiKey = getRepoEnvValue('OPENAI_API_KEY');
  const repoOpenaiApiBase = getRepoEnvValue('OPENAI_API_BASE');
  const repoOpenaiModel = getRepoEnvValue('OPENAI_MODEL');
  const repoOpenaiWireApi = getRepoEnvValue('OPENAI_WIRE_API');
  const repoAnthropicApiKey = getRepoEnvValue('ANTHROPIC_AUTH_TOKEN');
  const repoAnthropicApiBase = getRepoEnvValue('ANTHROPIC_BASE_URL');
  const repoAnthropicModel = getRepoEnvValue('ANTHROPIC_MODEL');

  return {
    provider: pickFirstNonEmpty(repoAiProvider, process.env.AI_PROVIDER),
    codexCliModel: pickFirstNonEmpty(repoCodexCliModel, process.env.CODEX_CLI_MODEL),
    codexCliReasoningEffort: pickFirstNonEmpty(repoCodexCliReasoningEffort, process.env.CODEX_CLI_REASONING_EFFORT),
    geminiApiKey: pickFirstNonEmpty(repoGeminiApiKey, process.env.GEMINI_API_KEY),
    geminiModel: pickFirstNonEmpty(repoGeminiModel, process.env.GEMINI_MODEL),
    openaiApiKey: pickFirstNonEmpty(
      repoOpenaiApiKey,
      process.env.OPENAI_API_KEY,
      repoAnthropicApiKey,
      process.env.ANTHROPIC_AUTH_TOKEN,
    ),
    openaiApiBase: pickFirstNonEmpty(
      repoOpenaiApiBase,
      process.env.OPENAI_API_BASE,
      repoAnthropicApiBase,
      process.env.ANTHROPIC_BASE_URL,
    ),
    openaiModel: pickFirstNonEmpty(
      // A script-level -Model override is safe: it changes no credentials or endpoint.
      process.env.OPENAI_MODEL,
      repoOpenaiModel,
      process.env.ANTHROPIC_MODEL,
      repoAnthropicModel,
    ),
    openaiWireApi: pickFirstNonEmpty(process.env.OPENAI_WIRE_API, repoOpenaiWireApi),
  };
}
