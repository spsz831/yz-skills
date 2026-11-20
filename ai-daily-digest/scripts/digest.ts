import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import process from 'node:process';
import { RSS_FEEDS } from './source-catalog';
import {
  GEMINI_DEFAULT_MODEL,
  OPENAI_DEFAULT_API_BASE,
  createAIClient,
  loadAiEnv,
} from './lib/ai-client';

// ============================================================================
// Constants
// ============================================================================

const FEED_FETCH_TIMEOUT_MS = 15_000;
const FEED_CONCURRENCY = 10;
const GEMINI_BATCH_SIZE = 10;
const MAX_CONCURRENT_GEMINI = 2;
const SCORING_RETRY_DELAY_MS = 1_500;
const SUMMARY_RETRY_DELAY_MS = 1_500;
const MIN_SUMMARY_LENGTH = 40;



// ============================================================================
// Types
// ============================================================================

type CategoryId = 'ai-ml' | 'security' | 'engineering' | 'tools' | 'opinion' | 'other';

const CATEGORY_META: Record<CategoryId, { emoji: string; label: string }> = {
  'ai-ml':       { emoji: '🤖', label: 'AI / ML' },
  'security':    { emoji: '🔒', label: '安全' },
  'engineering': { emoji: '⚙️', label: '工程' },
  'tools':       { emoji: '🛠', label: '工具 / 开源' },
  'opinion':     { emoji: '💡', label: '观点 / 杂谈' },
  'other':       { emoji: '📝', label: '其他' },
};

interface Article {
  title: string;
  link: string;
  pubDate: Date;
  description: string;
  sourceName: string;
  sourceUrl: string;
}

interface ScoredArticle extends Article {
  score: number;
  scoreBreakdown: {
    relevance: number;
    quality: number;
    timeliness: number;
  };
  category: CategoryId;
  keywords: string[];
  titleZh: string;
  summary: string;
  reason: string;
}

interface GeminiScoringResult {
  results: Array<{
    index: number;
    relevance: number;
    quality: number;
    timeliness: number;
    category: string;
    keywords: string[];
  }>;
}

interface GeminiSummaryResult {
  results: Array<{
    index: number;
    titleZh: string;
    summary: string;
    reason: string;
  }>;
}

interface AIClient {
  call(prompt: string): Promise<string>;
}

type FeedHealthStatus = 'ok' | 'empty' | 'error';
type FeedErrorCode = 'timeout' | 'http_403' | 'http_429' | 'http_other' | 'network' | 'other';

interface FeedHealthEntry {
  sourceName: string;
  xmlUrl: string;
  sourceUrl: string;
  status: FeedHealthStatus;
  articleCount: number;
  errorCode?: FeedErrorCode;
  errorMessage?: string;
}

interface FeedFetchResult {
  articles: Article[];
  health: FeedHealthEntry;
}

// ============================================================================
// RSS/Atom Parsing (using Bun's built-in HTMLRewriter or manual XML parsing)
// ============================================================================

function stripHtml(html: string): string {
  return html
    .replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ')
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(parseInt(code)))
    .trim();
}

function extractCDATA(text: string): string {
  const cdataMatch = text.match(/<!\[CDATA\[([\s\S]*?)\]\]>/);
  return cdataMatch ? cdataMatch[1] : text;
}

function getTagContent(xml: string, tagName: string): string {
  // Handle namespaced and non-namespaced tags
  const patterns = [
    new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'i'),
    new RegExp(`<${tagName}[^>]*/>`, 'i'), // self-closing
  ];

  for (const pattern of patterns) {
    const match = xml.match(pattern);
    if (match?.[1]) {
      return extractCDATA(match[1]).trim();
    }
  }
  return '';
}

function getAttrValue(xml: string, tagName: string, attrName: string): string {
  const pattern = new RegExp(`<${tagName}[^>]*\\s${attrName}=["']([^"']*)["'][^>]*/?>`, 'i');
  const match = xml.match(pattern);
  return match?.[1] || '';
}

function parseDate(dateStr: string): Date | null {
  if (!dateStr) return null;

  const d = new Date(dateStr);
  if (!isNaN(d.getTime())) return d;

  // Try common RSS date formats
  // RFC 822: "Mon, 01 Jan 2024 00:00:00 GMT"
  const rfc822 = dateStr.match(/(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/);
  if (rfc822) {
    const parsed = new Date(dateStr);
    if (!isNaN(parsed.getTime())) return parsed;
  }

  return null;
}

function parseRSSItems(xml: string): Array<{ title: string; link: string; pubDate: string; description: string }> {
  const items: Array<{ title: string; link: string; pubDate: string; description: string }> = [];

  // Detect format: Atom vs RSS
  const isAtom = xml.includes('<feed') && xml.includes('xmlns="http://www.w3.org/2005/Atom"') || xml.includes('<feed ');

  if (isAtom) {
    // Atom format: <entry>
    const entryPattern = /<entry[\s>]([\s\S]*?)<\/entry>/gi;
    let entryMatch;
    while ((entryMatch = entryPattern.exec(xml)) !== null) {
      const entryXml = entryMatch[1];
      const title = stripHtml(getTagContent(entryXml, 'title'));

      // Atom link: <link href="..." rel="alternate"/>
      let link = getAttrValue(entryXml, 'link[^>]*rel="alternate"', 'href');
      if (!link) {
        link = getAttrValue(entryXml, 'link', 'href');
      }

      const pubDate = getTagContent(entryXml, 'published')
        || getTagContent(entryXml, 'updated');

      const description = stripHtml(
        getTagContent(entryXml, 'summary')
        || getTagContent(entryXml, 'content')
      );

      if (title || link) {
        items.push({ title, link, pubDate, description: description.slice(0, 500) });
      }
    }
  } else {
    // RSS format: <item>
    const itemPattern = /<item[\s>]([\s\S]*?)<\/item>/gi;
    let itemMatch;
    while ((itemMatch = itemPattern.exec(xml)) !== null) {
      const itemXml = itemMatch[1];
      const title = stripHtml(getTagContent(itemXml, 'title'));
      const link = getTagContent(itemXml, 'link') || getTagContent(itemXml, 'guid');
      const pubDate = getTagContent(itemXml, 'pubDate')
        || getTagContent(itemXml, 'dc:date')
        || getTagContent(itemXml, 'date');
      const description = stripHtml(
        getTagContent(itemXml, 'description')
        || getTagContent(itemXml, 'content:encoded')
      );

      if (title || link) {
        items.push({ title, link, pubDate, description: description.slice(0, 500) });
      }
    }
  }

  return items;
}

// ============================================================================
// Feed Fetching
// ============================================================================

function classifyFeedError(message: string): FeedErrorCode {
  const m = message.toLowerCase();
  if (m.includes('timeout') || m.includes('abort')) return 'timeout';
  if (m.includes('http 403')) return 'http_403';
  if (m.includes('http 429')) return 'http_429';
  if (m.includes('http ')) return 'http_other';
  if (m.includes('unable to connect') || m.includes('fetch failed') || m.includes('econn') || m.includes('enotfound') || m.includes('eai_again')) return 'network';
  return 'other';
}

async function fetchFeed(feed: { name: string; xmlUrl: string; htmlUrl: string }): Promise<FeedFetchResult> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FEED_FETCH_TIMEOUT_MS);

    const response = await fetch(feed.xmlUrl, {
      signal: controller.signal,
      headers: {
        'User-Agent': 'AI-Daily-Digest/1.0 (RSS Reader)',
        'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
      },
    });

    clearTimeout(timeout);

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const xml = await response.text();
    const items = parseRSSItems(xml);

    const articles = items.map(item => ({
      title: item.title,
      link: item.link,
      pubDate: parseDate(item.pubDate) || new Date(0),
      description: item.description,
      sourceName: feed.name,
      sourceUrl: feed.htmlUrl,
    }));

    return {
      articles,
      health: {
        sourceName: feed.name,
        xmlUrl: feed.xmlUrl,
        sourceUrl: feed.htmlUrl,
        status: articles.length > 0 ? 'ok' : 'empty',
        articleCount: articles.length,
      },
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    const errorCode = classifyFeedError(msg);
    // Only log non-abort errors to reduce noise
    if (!msg.includes('abort')) {
      console.warn(`[digest] ✗ ${feed.name}: ${msg}`);
    } else {
      console.warn(`[digest] ✗ ${feed.name}: timeout`);
    }
    return {
      articles: [],
      health: {
        sourceName: feed.name,
        xmlUrl: feed.xmlUrl,
        sourceUrl: feed.htmlUrl,
        status: 'error',
        articleCount: 0,
        errorCode,
        errorMessage: msg,
      },
    };
  }
}

async function fetchAllFeeds(feeds: typeof RSS_FEEDS): Promise<{ articles: Article[]; healthEntries: FeedHealthEntry[] }> {
  const allArticles: Article[] = [];
  const healthEntries: FeedHealthEntry[] = [];
  let successCount = 0;
  let failCount = 0;

  for (let i = 0; i < feeds.length; i += FEED_CONCURRENCY) {
    const batch = feeds.slice(i, i + FEED_CONCURRENCY);
    const results = await Promise.allSettled(batch.map(fetchFeed));

    for (const result of results) {
      if (result.status === 'fulfilled') {
        allArticles.push(...result.value.articles);
        healthEntries.push(result.value.health);
        if (result.value.articles.length > 0) {
          successCount++;
        } else {
          failCount++;
        }
      } else {
        // Extremely rare path: Promise rejection outside fetchFeed catch.
        failCount++;
      }
    }

    const progress = Math.min(i + FEED_CONCURRENCY, feeds.length);
    console.log(`[digest] Progress: ${progress}/${feeds.length} feeds processed (${successCount} ok, ${failCount} failed)`);
  }

  console.log(`[digest] Fetched ${allArticles.length} articles from ${successCount} feeds (${failCount} failed)`);
  return { articles: allArticles, healthEntries };
}

function normalizeArticleUrl(link: string): string {
  try {
    const url = new URL(link);
    url.hash = '';
    url.pathname = url.pathname.replace(/\/+$/, '') || '/';
    for (const key of [...url.searchParams.keys()]) {
      if (/^(utm_.+|fbclid|gclid|mc_cid|mc_eid|ref)$/i.test(key)) {
        url.searchParams.delete(key);
      }
    }
    url.searchParams.sort();
    return url.toString();
  } catch {
    return link.trim().replace(/#.*$/, '');
  }
}

function normalizeArticleTitle(title: string): string {
  return title.normalize('NFKC').toLocaleLowerCase().replace(/[^\p{L}\p{N}]+/gu, '');
}

function deduplicateArticles(articles: Article[]): Article[] {
  const parent = articles.map((_, index) => index);
  const find = (index: number): number => {
    if (parent[index] !== index) parent[index] = find(parent[index]!);
    return parent[index]!;
  };
  const union = (a: number, b: number): void => {
    const rootA = find(a);
    const rootB = find(b);
    if (rootA !== rootB) parent[rootB] = rootA;
  };
  const articleIndexByUrl = new Map<string, number>();
  const articleIndexByTitleAndDay = new Map<string, number>();

  for (const [index, article] of articles.entries()) {
    const normalizedUrl = normalizeArticleUrl(article.link);
    const normalizedTitle = normalizeArticleTitle(article.title);
    const day = Number.isNaN(article.pubDate.getTime()) ? '' : article.pubDate.toISOString().slice(0, 10);
    const titleAndDay = normalizedTitle ? `${normalizedTitle}:${day}` : '';
    const urlMatch = normalizedUrl ? articleIndexByUrl.get(normalizedUrl) : undefined;
    const titleMatch = titleAndDay ? articleIndexByTitleAndDay.get(titleAndDay) : undefined;
    if (urlMatch !== undefined) union(index, urlMatch);
    if (titleMatch !== undefined) union(index, titleMatch);
    if (normalizedUrl) articleIndexByUrl.set(normalizedUrl, index);
    if (titleAndDay) articleIndexByTitleAndDay.set(titleAndDay, index);
  }

  const unique = new Map<number, Article>();
  for (const [index, article] of articles.entries()) {
    const root = find(index);
    const existing = unique.get(root);
    if (!existing || article.description.length > existing.description.length) {
      unique.set(root, article);
    }
  }
  return [...unique.values()];
}

function findBalancedJsonSlice(text: string): string | null {
  const startIndexes: number[] = [];
  const objectStart = text.indexOf('{');
  if (objectStart >= 0) {
    startIndexes.push(objectStart);
  }
  const arrayStart = text.indexOf('[');
  if (arrayStart >= 0) {
    startIndexes.push(arrayStart);
  }

  startIndexes.sort((a, b) => a - b);

  for (const start of startIndexes) {
    const opener = text[start]!;
    const closer = opener === '{' ? '}' : ']';
    let depth = 0;
    let inString = false;
    let escaped = false;

    for (let i = start; i < text.length; i++) {
      const char = text[i]!;

      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (char === '\\') {
          escaped = true;
        } else if (char === '"') {
          inString = false;
        }
        continue;
      }

      if (char === '"') {
        inString = true;
        continue;
      }

      if (char === opener) {
        depth += 1;
      } else if (char === closer) {
        depth -= 1;
        if (depth === 0) {
          return text.slice(start, i + 1);
        }
      }
    }
  }

  return null;
}

function extractJsonCandidate(text: string): string {
  const trimmed = text.trim().replace(/^\uFEFF/, '');
  const fencedMatches = [...trimmed.matchAll(/```(?:json)?\s*([\s\S]*?)```/gi)];

  for (const match of fencedMatches) {
    const candidate = match[1]?.trim();
    if (candidate) {
      return candidate;
    }
  }

  const balanced = findBalancedJsonSlice(trimmed);
  if (balanced) {
    return balanced.trim();
  }

  return trimmed;
}

function parseJsonResponse<T>(text: string): T {
  const jsonText = extractJsonCandidate(text);
  try {
    return JSON.parse(jsonText) as T;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`Failed to parse JSON from model output. ${message}`);
  }
}

function inferDisplayWireApi(apiBase?: string, wireApi?: string): 'chat' | 'responses' {
  const normalizedWire = wireApi?.trim().toLowerCase();
  if (normalizedWire === 'responses' || normalizedWire === 'response') {
    return 'responses';
  }

  const normalizedBase = apiBase?.trim().toLowerCase() || '';
  if (normalizedBase.includes('rawchat.cn/codex') || normalizedBase.includes('localhost:20128')) {
    return 'responses';
  }

  return 'chat';
}

// ============================================================================
// AI Scoring
// ============================================================================

function buildScoringPrompt(articles: Array<{ index: number; title: string; description: string; sourceName: string }>): string {
  const articlesList = articles.map(a =>
    `Index ${a.index}: [${a.sourceName}] ${a.title}\n${a.description.slice(0, 300)}`
  ).join('\n\n---\n\n');

  return `你是一个技术内容策展人，正在为一份面向技术爱好者的每日精选摘要筛选文章。

请对以下文章进行三个维度的评分（1-10 整数，10 分最高），并为每篇文章分配一个分类标签和提取 2-4 个关键词。

## 评分维度

### 1. 相关性 (relevance) - 对技术/编程/AI/互联网从业者的价值
- 10: 所有技术人都应该知道的重大事件/突破
- 7-9: 对大部分技术从业者有价值
- 4-6: 对特定技术领域有价值
- 1-3: 与技术行业关联不大

### 2. 信息丰富度 (quality) - 当前 RSS 标题和简介提供的信息量
- 10: 标题与简介提供充分背景、具体细节和清晰结论
- 7-9: 有具体内容，但部分背景或结论不完整
- 4-6: 只有少量可用信息
- 1-3: 几乎只有标题、宣传语或模糊描述
- 只能评估本次提供的 RSS 信息，不得假装读过原文或推断全文质量

### 3. 时效性 (timeliness) - 当前是否值得阅读
- 10: 正在发生的重大事件/刚发布的重要工具
- 7-9: 近期热点相关
- 4-6: 常青内容，不过时
- 1-3: 过时或无时效价值

## 分类标签（必须从以下选一个）
- ai-ml: AI、机器学习、LLM、深度学习相关
- security: 安全、隐私、漏洞、加密相关
- engineering: 软件工程、架构、编程语言、系统设计
- tools: 开发工具、开源项目、新发布的库/框架
- opinion: 行业观点、个人思考、职业发展、文化评论
- other: 以上都不太适合的

## 关键词提取
提取 2-4 个最能代表文章主题的关键词（用英文，简短，如 "Rust", "LLM", "database", "performance"）

## 待评分文章

${articlesList}

请严格按 JSON 格式返回，不要包含 markdown 代码块或其他文字：
{
  "results": [
    {
      "index": 0,
      "relevance": 8,
      "quality": 7,
      "timeliness": 9,
      "category": "engineering",
      "keywords": ["Rust", "compiler", "performance"]
    }
  ]
}`;
}

async function scoreArticlesWithAI(
  articles: Article[],
  aiClient: AIClient
): Promise<Map<number, { relevance: number; quality: number; timeliness: number; category: CategoryId; keywords: string[] }>> {
  const allScores = new Map<number, { relevance: number; quality: number; timeliness: number; category: CategoryId; keywords: string[] }>();
  const failedBatches: string[] = [];

  const indexed = articles.map((article, index) => ({
    index,
    title: article.title,
    description: article.description,
    sourceName: article.sourceName,
  }));

  const batches: typeof indexed[] = [];
  for (let i = 0; i < indexed.length; i += GEMINI_BATCH_SIZE) {
    batches.push(indexed.slice(i, i + GEMINI_BATCH_SIZE));
  }

  console.log(`[digest] AI scoring: ${articles.length} articles in ${batches.length} batches`);

  const validCategories = new Set<string>(['ai-ml', 'security', 'engineering', 'tools', 'opinion', 'other']);

  const scoreBatch = async (batch: typeof indexed): Promise<void> => {
    const prompt = buildScoringPrompt(batch);

    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        const responseText = await aiClient.call(prompt);
        const parsed = parseJsonResponse<GeminiScoringResult>(responseText);

        if (!parsed.results || !Array.isArray(parsed.results)) {
          throw new Error('scoring response did not contain a results array');
        }

        const expectedIndexes = new Set(batch.map((item) => item.index));
        const returnedIndexes = new Set<number>();
        for (const result of parsed.results) {
          if (!Number.isInteger(result.index) || !expectedIndexes.has(result.index)) {
            throw new Error(`scoring response returned unexpected index: ${result.index}`);
          }
          if (returnedIndexes.has(result.index)) {
            throw new Error(`scoring response returned duplicate index: ${result.index}`);
          }

          const scores = [result.relevance, result.quality, result.timeliness];
          if (scores.some((score) => !Number.isFinite(score) || score < 1 || score > 10)) {
            throw new Error(`scoring response returned an invalid score for index ${result.index}`);
          }

          returnedIndexes.add(result.index);
          const cat = (validCategories.has(result.category) ? result.category : 'other') as CategoryId;
          allScores.set(result.index, {
            relevance: Math.round(result.relevance),
            quality: Math.round(result.quality),
            timeliness: Math.round(result.timeliness),
            category: cat,
            keywords: Array.isArray(result.keywords) ? result.keywords.slice(0, 4) : [],
          });
        }

        const missingIndexes = [...expectedIndexes].filter((index) => !returnedIndexes.has(index));
        if (missingIndexes.length > 0) {
          throw new Error(`scoring response omitted indexes: ${missingIndexes.join(', ')}`);
        }
        return;
      } catch (error) {
        if (attempt === 1) {
          console.warn(`[digest] Scoring batch failed on attempt 1, retrying once: ${error instanceof Error ? error.message : String(error)}`);
          await new Promise((resolve) => setTimeout(resolve, SCORING_RETRY_DELAY_MS));
          continue;
        }

        const message = error instanceof Error ? error.message : String(error);
        failedBatches.push(`indexes ${batch.map((item) => item.index).join(',')}: ${message}`);
        console.warn(`[digest] Scoring batch failed after retry: ${message}`);
      }
    }
  };

  for (let i = 0; i < batches.length; i += MAX_CONCURRENT_GEMINI) {
    const batchGroup = batches.slice(i, i + MAX_CONCURRENT_GEMINI);
    const promises = batchGroup.map((batch) => scoreBatch(batch));

    await Promise.all(promises);
    console.log(`[digest] Scoring progress: ${Math.min(i + MAX_CONCURRENT_GEMINI, batches.length)}/${batches.length} batches`);
  }

  if (failedBatches.length > 0) {
    throw new Error(
      `AI scoring failed for ${failedBatches.length} batch(es). ` +
      'No digest was written with default scores. Check the configured text model and API route. ' +
      failedBatches.join(' | ')
    );
  }

  return allScores;
}

// ============================================================================
// AI Summarization
// ============================================================================

function buildSummaryPrompt(
  articles: Array<{ index: number; title: string; description: string; sourceName: string; link: string }>,
  lang: 'zh' | 'en'
): string {
  const articlesList = articles.map(a =>
    `Index ${a.index}: [${a.sourceName}] ${a.title}\nURL: ${a.link}\n${a.description.slice(0, 800)}`
  ).join('\n\n---\n\n');

  const langInstruction = lang === 'zh'
    ? '请用中文撰写摘要和推荐理由。如果原文是英文，请翻译为中文。标题翻译也用中文。'
    : 'Write summaries, reasons, and title translations in English.';

  return `你是一个技术内容导读编辑。输入仅包括 RSS 标题、RSS 简介和原文链接；你没有读取原文全文。只能依据给出的 RSS 信息撰写，不得根据链接、常识或标题猜测未提供的技术细节、数据和结论。

请为以下条目完成三件事：

1. **中文标题** (titleZh): 将英文标题翻译成自然的中文。如果原标题已经是中文则保持不变。
2. **导读** (summary): 根据实际提供的信息写 2-4 句话。简介足够时概括主题和明确出现的要点；简介不足或为空时，明确说明目前只有标题或简短 RSS 信息，建议点开原文，不要补造内容。
3. **推荐理由** (reason): 1 句话说明"为什么值得读"，区别于摘要（摘要说"是什么"，推荐理由说"为什么"）。

${langInstruction}

导读要求：
- 直接说重点，不要用"本文讨论了..."、"这篇文章介绍了..."这种开头
- 包含具体的技术名词、数据、方案名称或观点
- 保留关键数字和指标（如性能提升百分比、用户数、版本号等）
- 如果文章涉及对比或选型，要点出比较对象和结论
- 目标：读者花 30 秒读完摘要，就能决定是否值得花 10 分钟读原文

## 待摘要文章

${articlesList}

请严格按 JSON 格式返回：
{
  "results": [
    {
      "index": 0,
      "titleZh": "中文翻译的标题",
      "summary": "摘要内容...",
      "reason": "推荐理由..."
    }
  ]
}`;
}

async function summarizeArticles(
  articles: Array<Article & { index: number }>,
  aiClient: AIClient,
  lang: 'zh' | 'en',
  batchSize = GEMINI_BATCH_SIZE
): Promise<Map<number, { titleZh: string; summary: string; reason: string }>> {
  const summaries = new Map<number, { titleZh: string; summary: string; reason: string }>();
  const failedBatches: string[] = [];

  const indexed = articles.map(a => ({
    index: a.index,
    title: a.title,
    description: a.description,
    sourceName: a.sourceName,
    link: a.link,
  }));

  const batches: typeof indexed[] = [];
  for (let i = 0; i < indexed.length; i += batchSize) {
    batches.push(indexed.slice(i, i + batchSize));
  }

  console.log(`[digest] Generating summaries for ${articles.length} articles in ${batches.length} batches`);

  for (let i = 0; i < batches.length; i += MAX_CONCURRENT_GEMINI) {
    const batchGroup = batches.slice(i, i + MAX_CONCURRENT_GEMINI);
    const promises = batchGroup.map(async (batch) => {
      const prompt = buildSummaryPrompt(batch, lang);

      for (let attempt = 1; attempt <= 2; attempt += 1) {
        try {
          const responseText = await aiClient.call(prompt);
          const parsed = parseJsonResponse<GeminiSummaryResult>(responseText);

          if (!parsed.results || !Array.isArray(parsed.results)) {
            throw new Error('summary response did not contain a results array');
          }

          const expectedIndexes = new Set(batch.map((item) => item.index));
          const batchResults = new Map<number, GeminiSummaryResult['results'][number]>();
          for (const result of parsed.results) {
            if (!Number.isInteger(result.index) || !expectedIndexes.has(result.index)) {
              throw new Error(`summary response returned unexpected index: ${result.index}`);
            }
            if (batchResults.has(result.index)) {
              throw new Error(`summary response returned duplicate index: ${result.index}`);
            }
            batchResults.set(result.index, result);
          }

          const missingIndexes = [...expectedIndexes].filter((index) => !batchResults.has(index));
          if (missingIndexes.length > 0) {
            throw new Error(`summary response omitted indexes: ${missingIndexes.join(', ')}`);
          }

          for (const item of batch) {
            const result = batchResults.get(item.index);
            const summary = result?.summary?.trim() || '';
            if (!result || summary.length < MIN_SUMMARY_LENGTH || summary === item.title.trim()) {
              throw new Error(`invalid summary for article index ${item.index}`);
            }
          }

          for (const item of batch) {
            const result = batchResults.get(item.index)!;
            summaries.set(item.index, {
              titleZh: result.titleZh?.trim() || item.title,
              summary: result.summary.trim(),
              reason: result.reason?.trim() || '',
            });
          }
          return;
        } catch (error) {
          const message = error instanceof Error ? error.message : String(error);
          if (attempt === 1) {
            console.warn(`[digest] Summary batch failed on attempt 1, retrying once: ${message}`);
            await new Promise((resolve) => setTimeout(resolve, SUMMARY_RETRY_DELAY_MS));
            continue;
          }

          failedBatches.push(`indexes ${batch.map((item) => item.index).join(',')}: ${message}`);
          console.warn(`[digest] Summary batch failed after retry: ${message}`);
        }
      }
    });

    await Promise.all(promises);
    console.log(`[digest] Summary progress: ${Math.min(i + MAX_CONCURRENT_GEMINI, batches.length)}/${batches.length} batches`);
  }

  if (failedBatches.length > 0) {
    throw new Error(
      `AI summary generation failed for ${failedBatches.length} batch(es). ` +
      'No digest was written with title-only fallbacks. Check the configured text model and API route. ' +
      failedBatches.join(' | ')
    );
  }

  return summaries;
}

// ============================================================================
// AI Highlights (Today's Trends)
// ============================================================================

async function generateHighlights(
  articles: ScoredArticle[],
  aiClient: AIClient,
  lang: 'zh' | 'en'
): Promise<string> {
  const articleList = articles.slice(0, 10).map((a, i) =>
    `${i + 1}. [${a.category}] ${a.titleZh || a.title} — ${a.summary.slice(0, 100)}`
  ).join('\n');

  const langNote = lang === 'zh' ? '用中文回答。' : 'Write in English.';

  const prompt = `根据以下本期精选技术文章列表，写一段 3-5 句话的"本期看点"总结。
要求：
- 提炼出今天技术圈的 2-3 个主要趋势或话题
- 不要逐篇列举，要做宏观归纳
- 只能依据 RSS 导读归纳；不要将少量条目夸大成行业共识，也不要推断因果关系
- 风格简洁有力，像新闻导语
${langNote}

文章列表：
${articleList}

直接返回纯文本总结，不要 JSON，不要 markdown 格式。`;

  try {
    const text = await aiClient.call(prompt);
    return text.trim();
  } catch (error) {
    console.warn(`[digest] Highlights generation failed: ${error instanceof Error ? error.message : String(error)}`);
    return '';
  }
}

// ============================================================================
// Visualization Helpers
// ============================================================================

function humanizeTime(pubDate: Date, timeZone: string): string {
  const diffMs = Date.now() - pubDate.getTime();
  const diffMins = Math.floor(diffMs / 60_000);
  const diffHours = Math.floor(diffMs / 3_600_000);
  const diffDays = Math.floor(diffMs / 86_400_000);

  if (diffMins < 60) return `${diffMins} 分钟前`;
  if (diffHours < 24) return `${diffHours} 小时前`;
  if (diffDays < 7) return `${diffDays} 天前`;
  return getDateTimeInTimeZone(pubDate, timeZone).date;
}

function getDateTimeInTimeZone(date: Date, timeZone: string): { date: string; time: string } {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map((part) => [part.type, part.value]));
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    time: `${values.hour}:${values.minute}`,
  };
}

function validateTimeZone(timeZone: string): void {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone }).format();
  } catch {
    throw new Error(`Invalid IANA time zone: ${timeZone}`);
  }
}

function generateKeywordBarChart(articles: ScoredArticle[]): string {
  const kwCount = new Map<string, number>();
  for (const a of articles) {
    for (const kw of a.keywords) {
      const normalized = kw.toLowerCase();
      kwCount.set(normalized, (kwCount.get(normalized) || 0) + 1);
    }
  }

  const sorted = Array.from(kwCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 12);

  if (sorted.length === 0) return '';

  const labels = sorted.map(([k]) => `"${k}"`).join(', ');
  const values = sorted.map(([, v]) => v).join(', ');
  const maxVal = sorted[0][1];

  let chart = '```mermaid\n';
  chart += `xychart-beta horizontal\n`;
  chart += `    title "高频关键词"\n`;
  chart += `    x-axis [${labels}]\n`;
  chart += `    y-axis "出现次数" 0 --> ${maxVal + 2}\n`;
  chart += `    bar [${values}]\n`;
  chart += '```\n';

  return chart;
}

function generateCategoryPieChart(articles: ScoredArticle[]): string {
  const catCount = new Map<CategoryId, number>();
  for (const a of articles) {
    catCount.set(a.category, (catCount.get(a.category) || 0) + 1);
  }

  if (catCount.size === 0) return '';

  const sorted = Array.from(catCount.entries()).sort((a, b) => b[1] - a[1]);

  let chart = '```mermaid\n';
  chart += `pie showData\n`;
  chart += `    title "文章分类分布"\n`;
  for (const [cat, count] of sorted) {
    const meta = CATEGORY_META[cat];
    chart += `    "${meta.emoji} ${meta.label}" : ${count}\n`;
  }
  chart += '```\n';

  return chart;
}

function generateAsciiBarChart(articles: ScoredArticle[]): string {
  const kwCount = new Map<string, number>();
  for (const a of articles) {
    for (const kw of a.keywords) {
      const normalized = kw.toLowerCase();
      kwCount.set(normalized, (kwCount.get(normalized) || 0) + 1);
    }
  }

  const sorted = Array.from(kwCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10);

  if (sorted.length === 0) return '';

  const maxVal = sorted[0][1];
  const maxBarWidth = 20;
  const maxLabelLen = Math.max(...sorted.map(([k]) => k.length));

  let chart = '```\n';
  for (const [label, value] of sorted) {
    const barLen = Math.max(1, Math.round((value / maxVal) * maxBarWidth));
    const bar = '█'.repeat(barLen) + '░'.repeat(maxBarWidth - barLen);
    chart += `${label.padEnd(maxLabelLen)} │ ${bar} ${value}\n`;
  }
  chart += '```\n';

  return chart;
}

function generateTagCloud(articles: ScoredArticle[]): string {
  const kwCount = new Map<string, number>();
  for (const a of articles) {
    for (const kw of a.keywords) {
      const normalized = kw.toLowerCase();
      kwCount.set(normalized, (kwCount.get(normalized) || 0) + 1);
    }
  }

  const sorted = Array.from(kwCount.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 20);

  if (sorted.length === 0) return '';

  return sorted
    .map(([word, count], i) => i < 3 ? `**${word}**(${count})` : `${word}(${count})`)
    .join(' · ');
}

// ============================================================================
// Report Generation
// ============================================================================

function generateDigestReport(articles: ScoredArticle[], highlights: string, stats: {
  totalFeeds: number;
  successFeeds: number;
  totalArticles: number;
  filteredArticles: number;
  duplicateArticlesRemoved: number;
  hours: number;
  lang: string;
  timeZone: string;
}): string {
  const now = new Date();
  const generatedAt = getDateTimeInTimeZone(now, stats.timeZone);
  const dateStr = generatedAt.date;
  const karpathyFeeds = Math.min(92, RSS_FEEDS.length);
  const supplementalFeeds = Math.max(RSS_FEEDS.length - 92, 0);

  let report = `# 📰 AI 每日精选 — ${dateStr}\n\n`;
  report += `> 本期默认聚合 ${RSS_FEEDS.length} 个 RSS 源（其中 ${karpathyFeeds} 个参考 HN Popularity Contest / Karpathy 推荐，${supplementalFeeds} 个为补充源），AI 精选 Top ${articles.length}\n\n`;
  report += `> 阅读说明：以下是基于 RSS 标题和简介生成的导读，不代表已核验原文全文；关键数据和结论请打开原文确认。\n\n`;
  report += `> 时间窗口内抓取 ${stats.filteredArticles} 篇，合并重复 ${stats.duplicateArticlesRemoved} 篇后参与排序；报告时间按 ${stats.timeZone} 时区显示。\n\n`;

  // ── Today's Highlights ──
  if (highlights) {
    report += `## 📝 本期看点\n\n`;
    report += `${highlights}\n\n`;
    report += `---\n\n`;
  }

  // ── Top 3 Deep Showcase ──
  if (articles.length >= 3) {
    report += `## 🏆 今日必读\n\n`;
    for (let i = 0; i < Math.min(3, articles.length); i++) {
      const a = articles[i];
      const medal = ['🥇', '🥈', '🥉'][i];
      const catMeta = CATEGORY_META[a.category];

      report += `${medal} **${a.titleZh || a.title}**\n\n`;
      report += `[${a.title}](${a.link}) — ${a.sourceName} · ${humanizeTime(a.pubDate, stats.timeZone)} · ${catMeta.emoji} ${catMeta.label}\n\n`;
      report += `> ${a.summary}\n\n`;
      if (a.reason) {
        report += `💡 **为什么值得读**: ${a.reason}\n\n`;
      }
      if (a.keywords.length > 0) {
        report += `🏷️ ${a.keywords.join(', ')}\n\n`;
      }
    }
    report += `---\n\n`;
  }

  // ── Visual Statistics ──
  report += `## 📊 数据概览\n\n`;

  report += `| 扫描源 | 抓取文章 | 时间范围 | 精选 |\n`;
  report += `|:---:|:---:|:---:|:---:|\n`;
  report += `| ${stats.successFeeds}/${stats.totalFeeds} | ${stats.totalArticles} 篇 → ${stats.filteredArticles} 篇 | ${stats.hours}h | **${articles.length} 篇** |\n\n`;

  const pieChart = generateCategoryPieChart(articles);
  if (pieChart) {
    report += `### 分类分布\n\n${pieChart}\n`;
  }

  const barChart = generateKeywordBarChart(articles);
  if (barChart) {
    report += `### 高频关键词\n\n${barChart}\n`;
  }

  const asciiChart = generateAsciiBarChart(articles);
  if (asciiChart) {
    report += `<details>\n<summary>📈 纯文本关键词图（终端友好）</summary>\n\n${asciiChart}\n</details>\n\n`;
  }

  const tagCloud = generateTagCloud(articles);
  if (tagCloud) {
    report += `### 🏷️ 话题标签\n\n${tagCloud}\n\n`;
  }

  report += `---\n\n`;

  // ── Category-Grouped Articles ──
  const categoryGroups = new Map<CategoryId, ScoredArticle[]>();
  for (const a of articles) {
    const list = categoryGroups.get(a.category) || [];
    list.push(a);
    categoryGroups.set(a.category, list);
  }

  const sortedCategories = Array.from(categoryGroups.entries())
    .sort((a, b) => b[1].length - a[1].length);

  let globalIndex = 0;
  for (const [catId, catArticles] of sortedCategories) {
    const catMeta = CATEGORY_META[catId];
    report += `## ${catMeta.emoji} ${catMeta.label}\n\n`;

    for (const a of catArticles) {
      globalIndex++;
      const scoreTotal = a.scoreBreakdown.relevance + a.scoreBreakdown.quality + a.scoreBreakdown.timeliness;

      report += `### ${globalIndex}. ${a.titleZh || a.title}\n\n`;
      report += `[${a.title}](${a.link}) — **${a.sourceName}** · ${humanizeTime(a.pubDate, stats.timeZone)} · ⭐ ${scoreTotal}/30\n\n`;
      report += `> ${a.summary}\n\n`;
      if (a.keywords.length > 0) {
        report += `🏷️ ${a.keywords.join(', ')}\n\n`;
      }
      report += `---\n\n`;
    }
  }

  // ── Footer ──
  report += `*生成于 ${dateStr} ${generatedAt.time} (${stats.timeZone}) | 扫描 ${stats.successFeeds} 源 → 获取 ${stats.totalArticles} 篇 → 精选 ${articles.length} 篇*\n`;
  report += `*RSS 源说明：92 个参考 [Hacker News Popularity Contest 2025](https://refactoringenglish.com/tools/hn-popularity/) / [Andrej Karpathy](https://x.com/karpathy) 推荐，另有 ${supplementalFeeds} 个补充源*\n`;
  report += `*由 AI Daily Digest 生成*\n`;

  return report;
}

// ============================================================================
// CLI
// ============================================================================

function printUsage(): never {
  console.log(`AI Daily Digest - AI-powered digest from curated feeds

Usage:
  bun scripts/digest.ts [options]

Options:
  --hours <n>     Time range in hours (default: 48)
  --top-n <n>     Number of top articles to include (default: 15)
  --lang <lang>   Summary language: zh or en (default: zh)
  --timezone <id> IANA time zone for report dates (default: system time zone)
  --output <path> Output file path (default: ./reports/output/ai-daily-digest-YYYYMMDD.md)
  --health-log <path> Optional health log JSON path (default: ./reports/health/run-YYYYMMDD-HHmm.json)
  --help          Show this help

Environment:
  GEMINI_API_KEY   Optional but recommended. Get one at https://aistudio.google.com/apikey
  GEMINI_MODEL     Optional Gemini model (default: gemini-3.1-pro-preview)
  OPENAI_API_KEY   Optional OpenAI-compatible API key
  OPENAI_API_BASE  Optional OpenAI-compatible base URL (default: https://api.openai.com/v1)
  OPENAI_MODEL     Optional OpenAI-compatible model (default: deepseek-chat for DeepSeek base, else gpt-4o-mini)
  OPENAI_WIRE_API  Optional protocol override: chat | responses
  ANTHROPIC_AUTH_TOKEN Optional Anthropic-compatible token, mapped to the same OpenAI-compatible transport
  ANTHROPIC_BASE_URL   Optional Anthropic-compatible base URL, used when OPENAI_API_BASE is absent
  ANTHROPIC_MODEL      Optional Anthropic-compatible model, used when OPENAI_MODEL is absent

Examples:
  bun scripts/digest.ts --hours 24 --top-n 10 --lang zh
  bun scripts/digest.ts --hours 72 --top-n 20 --lang en --output ./reports/output/my-digest.md
`);
  process.exit(0);
}

async function runAiPreflight(aiClient: AIClient): Promise<void> {
  const timeoutMs = 30_000;
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    await Promise.race([
      aiClient.call('日报连接探针：只回复“连接成功”。'),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error(`preflight timed out after ${timeoutMs / 1000}s`)), timeoutMs);
      }),
    ]);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(`AI preflight failed: ${message}`);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) printUsage();

  let hours = 48;
  let topN = 15;
  let lang: 'zh' | 'en' = 'zh';
  let timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  let outputPath = '';
  let healthLogPath = '';

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg === '--hours' && args[i + 1]) {
      hours = Number(args[++i]);
    } else if (arg === '--top-n' && args[i + 1]) {
      topN = Number(args[++i]);
    } else if (arg === '--lang' && args[i + 1]) {
      lang = args[++i] as 'zh' | 'en';
    } else if (arg === '--timezone' && args[i + 1]) {
      timeZone = args[++i]!;
    } else if (arg === '--output' && args[i + 1]) {
      outputPath = args[++i]!;
    } else if (arg === '--health-log' && args[i + 1]) {
      healthLogPath = args[++i]!;
    } else {
      throw new Error(`Unknown option or missing value: ${arg}`);
    }
  }

  if (!Number.isInteger(hours) || hours <= 0) {
    throw new Error('--hours must be a positive integer');
  }
  if (!Number.isInteger(topN) || topN <= 0) {
    throw new Error('--top-n must be a positive integer');
  }
  if (lang !== 'zh' && lang !== 'en') {
    throw new Error('--lang must be zh or en');
  }
  validateTimeZone(timeZone);

  const {
    provider,
    codexCliModel,
    codexCliReasoningEffort,
    geminiApiKey,
    geminiModel,
    openaiApiKey,
    openaiApiBase,
    openaiModel,
    openaiWireApi,
  } = loadAiEnv();

  const useCodexCli = provider?.trim().toLowerCase() === 'codex-cli';
  if (!useCodexCli && !geminiApiKey && !openaiApiKey) {
    console.error('[digest] Error: Missing API key. Set GEMINI_API_KEY and/or OPENAI_API_KEY and/or ANTHROPIC_AUTH_TOKEN.');
    console.error('[digest] Gemini key: https://aistudio.google.com/apikey');
    process.exit(1);
  }

  const aiClient = createAIClient({
    provider,
    codexCliModel,
    codexCliReasoningEffort,
    geminiApiKey,
    geminiModel,
    openaiApiKey,
    openaiApiBase,
    openaiModel,
    openaiWireApi,
  });

  console.log('[digest] Preflight: testing the configured text model...');
  await runAiPreflight(aiClient);
  console.log('[digest] Preflight: text model is responding.');

  if (!outputPath) {
    const dateStr = getDateTimeInTimeZone(new Date(), timeZone).date.replace(/-/g, '');
    outputPath = `./reports/output/ai-daily-digest-${dateStr}.md`;
  }

  console.log(`[digest] === AI Daily Digest ===`);
  console.log(`[digest] Time range: ${hours} hours`);
  console.log(`[digest] Time zone: ${timeZone}`);
  console.log(`[digest] Top N: ${topN}`);
  console.log(`[digest] Language: ${lang}`);
  console.log(`[digest] Output: ${outputPath}`);
  console.log(`[digest] AI provider: ${useCodexCli ? 'Codex CLI' : (geminiApiKey ? 'Gemini (primary)' : 'OpenAI-compatible (primary)')}`);
  if (useCodexCli) {
    console.log(`[digest] Codex CLI model: ${codexCliModel?.trim() || 'Codex CLI default'}`);
    console.log(`[digest] Codex CLI reasoning effort: ${codexCliReasoningEffort?.trim() || 'low'}`);
  }
  if (geminiApiKey) {
    const resolvedGeminiModel = geminiModel?.trim() || GEMINI_DEFAULT_MODEL;
    console.log(`[digest] Gemini model: ${resolvedGeminiModel}`);
  }
  if (openaiApiKey && !useCodexCli) {
    const resolvedBase = (openaiApiBase?.trim() || OPENAI_DEFAULT_API_BASE).replace(/\/+$/, '');
    const resolvedModel = openaiModel?.trim() || 'auto';
    const resolvedWire = inferDisplayWireApi(resolvedBase, openaiWireApi);
    console.log(`[digest] Fallback: ${resolvedBase} (model=${resolvedModel}, wire=${resolvedWire})`);
  }
  console.log('');

  console.log(`[digest] Step 1/5: Fetching ${RSS_FEEDS.length} RSS feeds...`);
  const fetchResult = await fetchAllFeeds(RSS_FEEDS);
  let allArticles = fetchResult.articles;

  if (allArticles.length === 0) {
    console.error('[digest] Error: No articles fetched from any feed. Check network connection.');
    process.exit(1);
  }

  console.log(`[digest] Step 2/5: Filtering by time range (${hours} hours)...`);
  const cutoffTime = new Date(Date.now() - hours * 60 * 60 * 1000);
  const recentSourceArticles = allArticles.filter(a => a.pubDate.getTime() > cutoffTime.getTime());
  const recentArticles = deduplicateArticles(recentSourceArticles);
  const duplicateArticlesRemoved = recentSourceArticles.length - recentArticles.length;

  console.log(`[digest] Found ${recentSourceArticles.length} articles in the time window; removed ${duplicateArticlesRemoved} duplicates; ${recentArticles.length} remain`);

  if (recentArticles.length === 0) {
    console.error(`[digest] Error: No articles found within the last ${hours} hours.`);
    console.error(`[digest] Try increasing --hours (e.g., --hours 168 for one week)`);
    process.exit(1);
  }

  console.log(`[digest] Step 3/5: AI scoring ${recentArticles.length} articles...`);
  const scores = await scoreArticlesWithAI(recentArticles, aiClient);

  const scoredArticles = recentArticles.map((article, index) => {
    const score = scores.get(index);
    if (!score) {
      throw new Error(`Missing AI score for article index ${index}; refusing to rank an unscored story`);
    }
    return {
      ...article,
      totalScore: score.relevance + score.quality + score.timeliness,
      breakdown: score,
    };
  });

  scoredArticles.sort((a, b) => b.totalScore - a.totalScore);
  const topArticles = scoredArticles.slice(0, topN);

  console.log(`[digest] Top ${topN} articles selected (score range: ${topArticles[topArticles.length - 1]?.totalScore || 0} - ${topArticles[0]?.totalScore || 0})`);

  console.log(`[digest] Step 4/5: Generating AI summaries...`);
  const indexedTopArticles = topArticles.map((a, i) => ({ ...a, index: i }));
  const summaries = await summarizeArticles(indexedTopArticles, aiClient, lang, useCodexCli ? 5 : GEMINI_BATCH_SIZE);

  const finalArticles: ScoredArticle[] = topArticles.map((a, i) => {
    const sm = summaries.get(i);
    if (!sm) {
      throw new Error(`Missing AI summary for selected article index ${i}: ${a.title}`);
    }
    return {
      title: a.title,
      link: a.link,
      pubDate: a.pubDate,
      description: a.description,
      sourceName: a.sourceName,
      sourceUrl: a.sourceUrl,
      score: a.totalScore,
      scoreBreakdown: {
        relevance: a.breakdown.relevance,
        quality: a.breakdown.quality,
        timeliness: a.breakdown.timeliness,
      },
      category: a.breakdown.category,
      keywords: a.breakdown.keywords,
      titleZh: sm.titleZh,
      summary: sm.summary,
      reason: sm.reason,
    };
  });

  console.log(`[digest] Step 5/5: Generating digest highlights...`);
  const highlights = await generateHighlights(finalArticles, aiClient, lang);

  const successfulFeedCount = fetchResult.healthEntries.filter((entry) => entry.status === 'ok').length;

  const report = generateDigestReport(finalArticles, highlights, {
    totalFeeds: RSS_FEEDS.length,
    successFeeds: successfulFeedCount,
    totalArticles: allArticles.length,
    filteredArticles: recentSourceArticles.length,
    duplicateArticlesRemoved,
    hours,
    lang,
    timeZone,
  });

  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, report);

  if (!healthLogPath) {
    const generatedAt = getDateTimeInTimeZone(new Date(), timeZone);
    const ts = `${generatedAt.date.replace(/-/g, '')}-${generatedAt.time.replace(':', '')}`;
    healthLogPath = `./reports/health/run-${ts}.json`;
  }

  const healthSummary = {
    totalFeeds: RSS_FEEDS.length,
    okFeeds: fetchResult.healthEntries.filter(e => e.status === 'ok').length,
    emptyFeeds: fetchResult.healthEntries.filter(e => e.status === 'empty').length,
    errorFeeds: fetchResult.healthEntries.filter(e => e.status === 'error').length,
  };

  const healthLog = {
    generatedAt: new Date().toISOString(),
    timeZone,
    hours,
    topN,
    lang,
    outputPath,
    stats: healthSummary,
    entries: fetchResult.healthEntries,
  };

  await mkdir(dirname(healthLogPath), { recursive: true });
  await writeFile(healthLogPath, JSON.stringify(healthLog, null, 2));

  console.log('');
  console.log(`[digest] ✅ Done!`);
  console.log(`[digest] 📁 Report: ${outputPath}`);
  console.log(`[digest] 🧪 Health log: ${healthLogPath}`);
  console.log(`[digest] 📊 Stats: ${successfulFeedCount}/${fetchResult.healthEntries.length} feeds ok → ${allArticles.length} articles → ${recentSourceArticles.length} recent → ${duplicateArticlesRemoved} duplicates removed → ${finalArticles.length} selected`);

  if (finalArticles.length > 0) {
    console.log('');
    console.log(`[digest] 🏆 Top 3 Preview:`);
    for (let i = 0; i < Math.min(3, finalArticles.length); i++) {
      const a = finalArticles[i];
      console.log(`  ${i + 1}. ${a.titleZh || a.title}`);
      console.log(`     ${a.summary.slice(0, 80)}...`);
    }
  }


}

await main().catch((err) => {
  console.error(`[digest] Fatal error: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
