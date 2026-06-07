import { mkdir, readFile, stat, writeFile } from 'node:fs/promises';
import { basename, dirname, join, resolve } from 'node:path';
import process from 'node:process';

const MAX_CANDIDATE_SUMMARY_CHARS = 220;

interface Args {
  digestPath: string;
  limit: number;
  json: boolean;
  outputJsonPath: string;
  outputMarkdownPath: string;
}

interface DigestCandidate {
  rank: number;
  title: string;
  url: string;
  source: string;
  age: string;
  category: string;
  summary: string;
  whyRead: string;
  tags: string[];
}

interface ScoredDigestCandidate extends DigestCandidate {
  editorialScore: number;
  editorialReasons: string[];
}

function cleanInlineText(text: string): string {
  return text
    .replace(/\r/g, '')
    .replace(/\n+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function shortenText(text: string, maxChars: number): string {
  if (text.length <= maxChars) return text;
  return `${text.slice(0, maxChars).trim()}...`;
}

function parseArgs(args: string[]): Args {
  let digestPath = '';
  let limit = 5;
  let json = false;
  let outputJsonPath = '';
  let outputMarkdownPath = '';

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg === '--digest' && args[i + 1]) {
      digestPath = args[++i]!;
    } else if (arg === '--limit' && args[i + 1]) {
      limit = Math.max(1, Math.min(5, Number(args[++i]!) || 5));
    } else if (arg === '--json') {
      json = true;
    } else if (arg === '--output-json' && args[i + 1]) {
      outputJsonPath = args[++i]!;
    } else if (arg === '--output-md' && args[i + 1]) {
      outputMarkdownPath = args[++i]!;
    }
  }

  if (!digestPath) {
    throw new Error('Missing required --digest <path>.');
  }

  return { digestPath, limit, json, outputJsonPath, outputMarkdownPath };
}

function extractDigestCandidates(content: string): DigestCandidate[] {
  const matches = [...content.matchAll(
    /^###\s+(\d+)\.\s+(.+?)\n\n\[(.+?)\]\((https?:\/\/.+?)\)\s+—\s+\*\*(.+?)\*\*\s+·\s+(.+?)\s+·\s+⭐\s+\d+\/30\s*\n\n>\s+([\s\S]*?)\n\n🏷️\s+([^\n]+)\n/gm,
  )];

  return matches.map((match) => {
    const [, rank, title, , url, source, meta, summary, tagsRaw] = match;
    const metaParts = meta.split('·').map((part) => cleanInlineText(part));
    const age = metaParts[0] || '';
    const category = metaParts[1] || '';
    const whyReadMatch = content
      .slice(match.index ?? 0, (match.index ?? 0) + match[0].length + 300)
      .match(/💡\s+\*\*为什么值得读\*\*:\s*([^\n]+)/);

    return {
      rank: Number(rank),
      title: cleanInlineText(title),
      url: cleanInlineText(url),
      source: cleanInlineText(source),
      age,
      category,
      summary: shortenText(cleanInlineText(summary), MAX_CANDIDATE_SUMMARY_CHARS),
      whyRead: shortenText(cleanInlineText(whyReadMatch?.[1] || ''), 120),
      tags: tagsRaw.split(',').map((tag) => cleanInlineText(tag)).filter(Boolean),
    };
  });
}

function containsAny(text: string, keywords: string[]): boolean {
  const lower = text.toLowerCase();
  return keywords.some((keyword) => lower.includes(keyword.toLowerCase()));
}

function ageToHours(age: string): number | null {
  const normalized = cleanInlineText(age);
  const minuteMatch = normalized.match(/(-?\d+)\s*分钟/);
  if (minuteMatch) return Math.abs(Number(minuteMatch[1])) / 60;

  const hourMatch = normalized.match(/(\d+)\s*小时/);
  if (hourMatch) return Number(hourMatch[1]);

  const dayMatch = normalized.match(/(\d+)\s*天/);
  if (dayMatch) return Number(dayMatch[1]) * 24;

  return null;
}

function scoreDigestCandidate(candidate: DigestCandidate): ScoredDigestCandidate {
  const titleText = candidate.title;
  const combinedText = [
    candidate.title,
    candidate.summary,
    candidate.whyRead,
    candidate.source,
    candidate.category,
    candidate.tags.join(' '),
  ].join(' ');

  let score = 0;
  const reasons: string[] = [];

  const hours = ageToHours(candidate.age);
  if (hours !== null) {
    if (hours <= 24) {
      score += 4;
      reasons.push('24小时内的新鲜热点');
    } else if (hours <= 48) {
      score += 2;
      reasons.push('48小时内仍具时效性');
    }
  }

  if (candidate.rank <= 3) {
    score += 2;
    reasons.push('原始精选排名靠前');
  } else if (candidate.rank <= 6) {
    score += 1;
  }

  const titleEventKeywords = [
    '推出', '发布', '开源', '上线', '宣布', '倒闭', '裁掉', '裁员', '融资', '重组', '解散', '峰会', 'server',
  ];
  if (containsAny(titleText, titleEventKeywords)) {
    score += 5;
    reasons.push('标题本身就是明确事件型新闻');
  }

  const highPriorityKeywords = [
    '推出', '发布', '开源', '上线', '宣布', '倒闭', '裁', '裁员', '融资', '峰会',
    'agent', 'claude code', 'mcp', 'anthropic', 'openai', 'google', '谷歌', 'github',
    'colab', 'red hat', 'cloudflare', '巨头', '明星ai公司', '企业级', '多代理', '多智能体',
  ];
  if (containsAny(combinedText, highPriorityKeywords)) {
    score += 4;
    reasons.push('事件型新闻或大厂/行业动作明显');
  }

  const spreadKeywords = [
    '改变', '重构', '倒闭', '最大进步', '关键转折', '行业', '企业级落地', '重组', '解散', '爆发',
    '颠覆', '转向', '洗牌', '新阶段', '云端运行代码',
  ];
  if (containsAny(combinedText, spreadKeywords)) {
    score += 3;
    reasons.push('具备传播张力或明显转折');
  }

  const accountFitKeywords = [
    'ai agent', 'agent', 'claude code', 'mcp', '企业', 'workflow', '工程', '基础设施',
    '编程', '开发', '模型', '大模型', '智能体',
  ];
  if (containsAny(combinedText, accountFitKeywords)) {
    score += 3;
    reasons.push('与账号的AI工程/工具/大模型方向匹配');
  }

  const lowPriorityKeywords = [
    '全解析', '机制', '源码', '导论', '指南', '通关手册', 'tutorial', '权重加载',
    '软硬协同', '传输层', 'sqlite', 'release', '缓存优化方法',
  ];
  if (containsAny(combinedText, lowPriorityKeywords)) {
    score -= 4;
    reasons.push('更偏资料型或硬核技术型，传播性相对弱');
  }

  if (candidate.source.includes('InfoQ') || candidate.source.includes('36氪') || candidate.source.includes('少数派')) {
    score += 1;
  }

  const commentaryKeywords = [
    '为什么', '观察', '浅谈', '导论', '最大进步', '改变了一切', 'biggest advance',
  ];
  if (containsAny(titleText, commentaryKeywords)) {
    score -= 3;
    reasons.push('更像评论/解读型标题，不是直接事件型新闻');
  }

  if (candidate.category.includes('观点') || candidate.source.toLowerCase().includes('substack')) {
    score -= 2;
    reasons.push('更偏观点源，时事新闻属性略弱');
  }

  return {
    ...candidate,
    editorialScore: score,
    editorialReasons: reasons,
  };
}

function shortlistCandidatesForWechat(candidates: DigestCandidate[], limit: number): ScoredDigestCandidate[] {
  return candidates
    .map(scoreDigestCandidate)
    .sort((a, b) => {
      if (b.editorialScore !== a.editorialScore) {
        return b.editorialScore - a.editorialScore;
      }
      return a.rank - b.rank;
    })
    .slice(0, limit);
}

function buildShortlistMarkdown(digestPath: string, candidates: ScoredDigestCandidate[]): string {
  const digestName = basename(digestPath);
  const lines: string[] = [
    '# 公众号候选题清单',
    '',
    `- 来源日报：${digestName}`,
    `- 候选数量：${candidates.length}`,
    '',
  ];

  candidates.forEach((item, index) => {
    lines.push(`## 候选 ${index + 1}`);
    lines.push('');
    lines.push(`- 原始排名：${item.rank}`);
    lines.push(`- 标题：${item.title}`);
    lines.push(`- 公众号选题分：${item.editorialScore}`);
    lines.push(`- 来源：${item.source} | ${item.age} | ${item.category}`);
    lines.push(`- 链接：${item.url}`);
    lines.push(`- 摘要：${item.summary}`);
    if (item.whyRead) {
      lines.push(`- 值得关注：${item.whyRead}`);
    }
    if (item.editorialReasons.length) {
      lines.push(`- 入选原因：${item.editorialReasons.join('；')}`);
    }
    if (item.tags.length) {
      lines.push(`- 标签：${item.tags.join(' / ')}`);
    }
    lines.push('');
  });

  return lines.join('\n');
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const digestPath = resolve(args.digestPath);
  const digestRaw = await readFile(digestPath, 'utf8');
  const candidates = extractDigestCandidates(digestRaw);
  if (candidates.length === 0) {
    throw new Error(`No digest candidates found in ${digestPath}`);
  }

  const shortlist = shortlistCandidatesForWechat(candidates, args.limit);
  const payload = {
    digestPath,
    generatedAt: new Date().toISOString(),
    count: shortlist.length,
    candidates: shortlist,
  };

  if (args.outputJsonPath) {
    const outputJsonPath = resolve(args.outputJsonPath);
    await mkdir(dirname(outputJsonPath), { recursive: true });
    await writeFile(outputJsonPath, JSON.stringify(payload, null, 2), 'utf8');
  }

  if (args.outputMarkdownPath) {
    const outputMarkdownPath = resolve(args.outputMarkdownPath);
    await mkdir(dirname(outputMarkdownPath), { recursive: true });
    await writeFile(outputMarkdownPath, buildShortlistMarkdown(digestPath, shortlist), 'utf8');
  }

  if (args.json) {
    process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
    return;
  }

  process.stdout.write(`${buildShortlistMarkdown(digestPath, shortlist)}\n`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
