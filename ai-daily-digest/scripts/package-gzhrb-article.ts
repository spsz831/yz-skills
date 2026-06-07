import { copyFile, mkdir, readFile, readdir, stat, writeFile } from 'node:fs/promises';
import { basename, dirname, isAbsolute, join, resolve } from 'node:path';
import process from 'node:process';
import { callOpenAICompatible, loadAiEnv } from './lib/ai-client';

interface Args {
  articlePath: string;
  gzhrbDir: string;
}

interface PublishPackage {
  titles: string[];
  intro_lines: string[];
  topic_tags: string[];
}

interface WorkitemRecord {
  article_id?: string;
  paths?: {
    publish_unit_dir?: string;
    illustration_dir?: string;
  };
}

function parseArgs(args: string[]): Args {
  let articlePath = '';
  let gzhrbDir = '';

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg === '--article' && args[i + 1]) {
      articlePath = args[++i]!;
    } else if (arg === '--gzhrb-dir' && args[i + 1]) {
      gzhrbDir = args[++i]!;
    }
  }

  return { articlePath, gzhrbDir };
}

async function listLatestArticleFromWorkspace(gzhrbDir: string): Promise<string | null> {
  const articlesRoot = join(gzhrbDir, 'articles');
  let entries: Awaited<ReturnType<typeof readdir>>;
  try {
    entries = await readdir(articlesRoot, { withFileTypes: true });
  } catch {
    return null;
  }

  const candidates = await Promise.all(
    entries
      .filter((entry) => entry.isDirectory())
      .map(async (entry) => {
        const articlePath = join(articlesRoot, entry.name, 'article.md');
        try {
          const articleStats = await stat(articlePath);
          return { articlePath, mtimeMs: articleStats.mtimeMs };
        } catch {
          return null;
        }
      }),
  );

  const found = candidates
    .filter((item): item is { articlePath: string; mtimeMs: number } => item !== null)
    .sort((a, b) => {
      if (b.mtimeMs !== a.mtimeMs) {
        return b.mtimeMs - a.mtimeMs;
      }
      return b.articlePath.localeCompare(a.articlePath, 'en');
    });

  return found[0]?.articlePath ?? null;
}

async function findLatestArticle(gzhrbDir: string): Promise<string> {
  const fromWorkspace = await listLatestArticleFromWorkspace(gzhrbDir);
  if (fromWorkspace) {
    return fromWorkspace;
  }

  const files = await readdir(gzhrbDir);
  const articles = files.filter((name) => /^gzhrb-\d{8}-\d{4}.*\.md$/i.test(name));
  if (articles.length === 0) {
    throw new Error(`No GZHRB article found in ${gzhrbDir}`);
  }

  const withStats = await Promise.all(
    articles.map(async (name) => {
      const fullPath = join(gzhrbDir, name);
      return { fullPath, stats: await stat(fullPath) };
    }),
  );

  withStats.sort((a, b) => {
    if (b.stats.mtimeMs !== a.stats.mtimeMs) {
      return b.stats.mtimeMs - a.stats.mtimeMs;
    }
    return b.fullPath.localeCompare(a.fullPath, 'en');
  });

  return withStats[0]!.fullPath;
}

function deriveArticleId(articlePath: string): string {
  const fileName = basename(articlePath).toLowerCase();
  if (fileName === 'article.md') {
    return basename(dirname(articlePath));
  }

  return basename(articlePath, '.md');
}

function normalizeLineEndings(text: string): string {
  return text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
}

function parseTopLevelSections(markdown: string): Map<string, string> {
  const normalized = normalizeLineEndings(markdown);
  const lines = normalized.split('\n');
  const sections = new Map<string, string>();

  let currentHeading = '';
  let currentBody: string[] = [];

  function flush() {
    if (!currentHeading) return;
    sections.set(currentHeading.trim(), currentBody.join('\n').trim());
  }

  for (const line of lines) {
    const headingMatch = line.match(/^#\s+(.+?)\s*$/);
    if (headingMatch) {
      flush();
      currentHeading = headingMatch[1]!;
      currentBody = [];
      continue;
    }
    currentBody.push(line);
  }

  flush();
  return sections;
}

function getArticleBody(markdown: string): string {
  const sections = parseTopLevelSections(markdown);
  const body = sections.get('正文');
  if (body && body.trim()) {
    return body.trim();
  }

  const ignored = new Set(['标题备选', '引导语备选', '话题标签']);
  const fallbackBodies: string[] = [];
  for (const [heading, content] of sections.entries()) {
    if (ignored.has(heading)) continue;
    if (content.trim()) fallbackBodies.push(content.trim());
  }

  if (fallbackBodies.length > 0) {
    return fallbackBodies.join('\n\n').trim();
  }

  return markdown.trim();
}

function extractJsonBlock(raw: string): string {
  const fenced = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced?.[1]) {
    return fenced[1].trim();
  }

  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start >= 0 && end > start) {
    return raw.slice(start, end + 1).trim();
  }

  return raw.trim();
}

function uniqueTrimmed(items: unknown[], maxCount: number): string[] {
  const seen = new Set<string>();
  const results: string[] = [];

  for (const item of items) {
    if (typeof item !== 'string') continue;
    const cleaned = item.replace(/\s+/g, ' ').trim();
    if (!cleaned || seen.has(cleaned)) continue;
    seen.add(cleaned);
    results.push(cleaned);
    if (results.length >= maxCount) break;
  }

  return results;
}

function parsePublishPackage(raw: string): PublishPackage {
  const parsed = JSON.parse(extractJsonBlock(raw)) as Partial<PublishPackage>;

  const titles = uniqueTrimmed(parsed.titles ?? [], 5).slice(0, 5);
  const introLines = uniqueTrimmed(parsed.intro_lines ?? [], 5).slice(0, 5);
  const topicTags = uniqueTrimmed(parsed.topic_tags ?? [], 10).slice(0, 10);

  if (titles.length < 3) {
    throw new Error('Publish package must contain at least 3 titles.');
  }
  if (introLines.length < 3) {
    throw new Error('Publish package must contain at least 3 intro lines.');
  }
  if (topicTags.length < 5) {
    throw new Error('Publish package must contain at least 5 topic tags.');
  }

  return {
    titles,
    intro_lines: introLines.map((line) => line.slice(0, 20).trim()),
    topic_tags: topicTags,
  };
}

function buildPackagingPrompt(articleBody: string): string {
  return `你现在要为一篇已经写好的微信公众号文章生成最终发布包装信息。

请只基于下面这篇文章正文，输出一个 JSON 对象，不要输出解释，不要输出 markdown，不要输出代码块外文本。

输出格式必须严格是：
{
  "titles": ["...","...","..."],
  "intro_lines": ["...","...","..."],
  "topic_tags": ["...","...","..."]
}

要求：
1. titles 提供 3 到 5 个。
2. 标题风格要像个人公众号，不要像技术文档标题，不要像论文题目。
3. 标题要更像近期热点单篇文章标题，而不是资料索引标题。
4. intro_lines 提供 3 到 5 个，每条不超过 20 个汉字。
5. intro_lines 要适合公众号发文时作为引导语，不要写成长句。
6. topic_tags 提供 5 到 10 个，适合公众号语境，保持短词组。
7. 不要带 # 符号，不要带编号，不要带 emoji。
8. 不能编造正文没有的信息。

文章正文如下：

${articleBody}`;
}

function normalizeArticleImagePaths(articleContent: string): string {
  let normalized = articleContent;
  normalized = normalized.replace(
    /\(illustrations\/[^/)]+\/([^)\s]+)\)/g,
    '(illustrations/$1)',
  );
  normalized = normalized.replace(
    /\(illustrations\\[^\\)]+\\([^)\s]+)\)/g,
    '(illustrations/$1)',
  );
  return normalized;
}

async function readWorkitem(workitemPath: string): Promise<WorkitemRecord | null> {
  try {
    const raw = await readFile(workitemPath, 'utf8');
    return JSON.parse(raw) as WorkitemRecord;
  } catch {
    return null;
  }
}

function resolvePathValue(gzhrbDir: string, rawValue: unknown, fallbackValue: string): string {
  if (typeof rawValue !== 'string' || !rawValue.trim()) {
    return fallbackValue;
  }

  if (isAbsolute(rawValue)) {
    return rawValue;
  }

  return resolve(gzhrbDir, rawValue);
}

async function listIllustrationFiles(sourceDir: string): Promise<string[]> {
  let entries: Awaited<ReturnType<typeof readdir>>;
  try {
    entries = await readdir(sourceDir, { withFileTypes: true });
  } catch {
    return [];
  }

  const imagePattern = /\.(png|jpe?g|webp|gif)$/i;
  return entries
    .filter((entry) => entry.isFile() && imagePattern.test(entry.name))
    .map((entry) => entry.name)
    .sort((a, b) => a.localeCompare(b, 'en'));
}

function buildReviewChecklist(articleId: string, newline: string): string {
  const lines = [
    '# 发布终审清单',
    '',
    `- 文章 ID：${articleId}`,
    '- [ ] 标题备选已人工挑选',
    '- [ ] 引导语备选已人工挑选',
    '- [ ] 话题标签已人工确认',
    '- [ ] 文章正文与配图顺序已复核',
    '- [ ] 图片链接在 publish-unit 内部可用',
    '- [ ] 事实、术语、来源已终审',
    '',
  ];
  return lines.join(newline);
}

function buildFinalPublishDocument(params: {
  articleId: string;
  articleContent: string;
  titles: string[];
  introLines: string[];
  topicTags: string[];
  illustrationFiles: string[];
  newline: string;
}): string {
  const {
    articleId,
    articleContent,
    titles,
    introLines,
    topicTags,
    illustrationFiles,
    newline,
  } = params;

  const sections: string[] = [
    '# 发布总览',
    '',
    `- 文章 ID：${articleId}`,
    '',
    '## 标题备选',
    '',
    ...titles.map((title, index) => `${index + 1}. ${title}`),
    '',
    '## 引导语备选',
    '',
    ...introLines.map((line, index) => `${index + 1}. ${line}`),
    '',
    '## 话题标签',
    '',
    topicTags.join(' · '),
    '',
    '## 正文',
    '',
    articleContent.trim(),
    '',
    '## 配图清单',
    '',
    ...illustrationFiles.map((file, index) => `${index + 1}. illustrations/${file}`),
    '',
  ];

  return `${sections.join(newline)}${newline}`;
}

async function main() {
  const projectDir = resolve(dirname(process.argv[1]!), '..');
  const args = parseArgs(process.argv.slice(2));
  const gzhrbDir = args.gzhrbDir || join(projectDir, 'reports', 'gzhrb');
  const articlePath = args.articlePath || await findLatestArticle(gzhrbDir);
  const articleId = deriveArticleId(articlePath);
  const workitemPath = join(gzhrbDir, 'workitems', `${articleId}.json`);
  const workitem = await readWorkitem(workitemPath);

  const defaultPublishUnitDir = join(gzhrbDir, 'publish-units', articleId);
  const publishUnitDir = resolvePathValue(
    gzhrbDir,
    workitem?.paths?.publish_unit_dir,
    defaultPublishUnitDir,
  );
  const defaultIllustrationDir = join(gzhrbDir, 'illustrations', articleId);
  const sourceIllustrationDir = resolvePathValue(
    gzhrbDir,
    workitem?.paths?.illustration_dir,
    defaultIllustrationDir,
  );

  const raw = await readFile(articlePath, 'utf8');
  const newline = raw.includes('\r\n') ? '\r\n' : '\n';
  const normalizedArticle = normalizeArticleImagePaths(raw);
  const articleBody = getArticleBody(normalizedArticle);
  if (!articleBody.trim()) {
    throw new Error(`Article body is empty: ${articlePath}`);
  }

  const { openaiApiKey, openaiApiBase, openaiModel, openaiWireApi } = loadAiEnv();
  const response = await callOpenAICompatible(buildPackagingPrompt(articleBody), {
    apiKey: openaiApiKey,
    apiBase: openaiApiBase,
    model: openaiModel || 'gpt-5.4',
    wireApi: openaiWireApi,
  });
  const pkg = parsePublishPackage(response);

  const publishIllustrationsDir = join(publishUnitDir, 'illustrations');
  await mkdir(publishIllustrationsDir, { recursive: true });

  const illustrationFiles = await listIllustrationFiles(sourceIllustrationDir);
  await Promise.all(
    illustrationFiles.map(async (fileName) => {
      await copyFile(join(sourceIllustrationDir, fileName), join(publishIllustrationsDir, fileName));
    }),
  );

  await writeFile(join(publishUnitDir, 'article.md'), normalizedArticle, 'utf8');
  await writeFile(join(publishUnitDir, 'titles.txt'), `${pkg.titles.join(newline)}${newline}`, 'utf8');
  await writeFile(
    join(publishUnitDir, 'intro-lines.txt'),
    `${pkg.intro_lines.join(newline)}${newline}`,
    'utf8',
  );
  await writeFile(
    join(publishUnitDir, 'topic-tags.txt'),
    `${pkg.topic_tags.join(newline)}${newline}`,
    'utf8',
  );
  await writeFile(
    join(publishUnitDir, 'package.json'),
    `${JSON.stringify(
      {
        article_id: articleId,
        source_article_path: articlePath,
        source_illustration_dir: sourceIllustrationDir,
        generated_at: new Date().toISOString(),
        titles: pkg.titles,
        intro_lines: pkg.intro_lines,
        topic_tags: pkg.topic_tags,
      },
      null,
      2,
    )}${newline}`,
    'utf8',
  );
  await writeFile(
    join(publishUnitDir, 'review-checklist.md'),
    buildReviewChecklist(articleId, newline),
    'utf8',
  );
  await writeFile(
    join(publishUnitDir, 'final-publish.md'),
    buildFinalPublishDocument({
      articleId,
      articleContent: normalizedArticle,
      titles: pkg.titles,
      introLines: pkg.intro_lines,
      topicTags: pkg.topic_tags,
      illustrationFiles,
      newline,
    }),
    'utf8',
  );

  console.log('[OK] GZHRB publish unit generated.');
  console.log(`Article ID: ${articleId}`);
  console.log(`Source article: ${articlePath}`);
  console.log(`Publish unit: ${publishUnitDir}`);
  console.log(`Illustrations copied: ${illustrationFiles.length}`);
}

await main().catch((error) => {
  console.error(String(error instanceof Error ? error.message : error));
  process.exit(1);
});
