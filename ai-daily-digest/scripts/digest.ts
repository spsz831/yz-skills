import { writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import process from 'node:process';
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
const WAYTOAGI_BLOG_URL = 'https://www.waytoagi.com/zh/blog';
const WAYTOAGI_SOURCE_NAME = 'waytoagi-blog';
const WAYTOAGI_SOURCE_URL = 'https://www.waytoagi.com/zh/blog';
const HUGGINGFACE_PAPERS_SOURCE_NAME = 'huggingface.co/papers';
const HUGGINGFACE_PAPERS_SOURCE_URL = 'https://huggingface.co/papers';
const DEFAULT_WATCH_KEYWORDS = ['Hermes', 'Hermes Agent'];

// 90 RSS feeds from Hacker News Popularity Contest 2025 (curated by Karpathy)
const RSS_FEEDS: Array<{ name: string; xmlUrl: string; htmlUrl: string }> = [
  { name: "simonwillison.net", xmlUrl: "https://simonwillison.net/atom/everything/", htmlUrl: "https://simonwillison.net" },
  { name: "jeffgeerling.com", xmlUrl: "https://www.jeffgeerling.com/blog.xml", htmlUrl: "https://jeffgeerling.com" },
  { name: "seangoedecke.com", xmlUrl: "https://www.seangoedecke.com/rss.xml", htmlUrl: "https://seangoedecke.com" },
  { name: "krebsonsecurity.com", xmlUrl: "https://krebsonsecurity.com/feed/", htmlUrl: "https://krebsonsecurity.com" },
  { name: "daringfireball.net", xmlUrl: "https://daringfireball.net/feeds/main", htmlUrl: "https://daringfireball.net" },
  { name: "ericmigi.com", xmlUrl: "https://ericmigi.com/rss.xml", htmlUrl: "https://ericmigi.com" },
  { name: "antirez.com", xmlUrl: "http://antirez.com/rss", htmlUrl: "http://antirez.com" },
  { name: "idiallo.com", xmlUrl: "https://idiallo.com/feed.rss", htmlUrl: "https://idiallo.com" },
  { name: "maurycyz.com", xmlUrl: "https://maurycyz.com/index.xml", htmlUrl: "https://maurycyz.com" },
  { name: "pluralistic.net", xmlUrl: "https://pluralistic.net/feed/", htmlUrl: "https://pluralistic.net" },
  { name: "shkspr.mobi", xmlUrl: "https://shkspr.mobi/blog/feed/", htmlUrl: "https://shkspr.mobi" },
  { name: "lcamtuf.substack.com", xmlUrl: "https://lcamtuf.substack.com/feed", htmlUrl: "https://lcamtuf.substack.com" },
  { name: "mitchellh.com", xmlUrl: "https://mitchellh.com/feed.xml", htmlUrl: "https://mitchellh.com" },
  { name: "dynomight.net", xmlUrl: "https://dynomight.net/feed.xml", htmlUrl: "https://dynomight.net" },
  { name: "utcc.utoronto.ca/~cks", xmlUrl: "https://utcc.utoronto.ca/~cks/space/blog/?atom", htmlUrl: "https://utcc.utoronto.ca/~cks" },
  { name: "xeiaso.net", xmlUrl: "https://xeiaso.net/blog.rss", htmlUrl: "https://xeiaso.net" },
  { name: "devblogs.microsoft.com/oldnewthing", xmlUrl: "https://devblogs.microsoft.com/oldnewthing/feed", htmlUrl: "https://devblogs.microsoft.com/oldnewthing" },
  { name: "righto.com", xmlUrl: "https://www.righto.com/feeds/posts/default", htmlUrl: "https://righto.com" },
  { name: "lucumr.pocoo.org", xmlUrl: "https://lucumr.pocoo.org/feed.atom", htmlUrl: "https://lucumr.pocoo.org" },
  { name: "skyfall.dev", xmlUrl: "https://skyfall.dev/rss.xml", htmlUrl: "https://skyfall.dev" },
  { name: "garymarcus.substack.com", xmlUrl: "https://garymarcus.substack.com/feed", htmlUrl: "https://garymarcus.substack.com" },
  { name: "rachelbythebay.com", xmlUrl: "https://rachelbythebay.com/w/atom.xml", htmlUrl: "https://rachelbythebay.com" },
  { name: "overreacted.io", xmlUrl: "https://overreacted.io/rss.xml", htmlUrl: "https://overreacted.io" },
  { name: "timsh.org", xmlUrl: "https://timsh.org/rss/", htmlUrl: "https://timsh.org" },
  { name: "johndcook.com", xmlUrl: "https://www.johndcook.com/blog/feed/", htmlUrl: "https://johndcook.com" },
  { name: "gilesthomas.com", xmlUrl: "https://gilesthomas.com/feed/rss.xml", htmlUrl: "https://gilesthomas.com" },
  { name: "matklad.github.io", xmlUrl: "https://matklad.github.io/feed.xml", htmlUrl: "https://matklad.github.io" },
  { name: "derekthompson.org", xmlUrl: "https://www.theatlantic.com/feed/author/derek-thompson/", htmlUrl: "https://derekthompson.org" },
  { name: "evanhahn.com", xmlUrl: "https://evanhahn.com/feed.xml", htmlUrl: "https://evanhahn.com" },
  { name: "terriblesoftware.org", xmlUrl: "https://terriblesoftware.org/feed/", htmlUrl: "https://terriblesoftware.org" },
  { name: "rakhim.exotext.com", xmlUrl: "https://rakhim.exotext.com/rss.xml", htmlUrl: "https://rakhim.exotext.com" },
  { name: "joanwestenberg.com", xmlUrl: "https://joanwestenberg.com/rss", htmlUrl: "https://joanwestenberg.com" },
  { name: "xania.org", xmlUrl: "https://xania.org/feed", htmlUrl: "https://xania.org" },
  { name: "micahflee.com", xmlUrl: "https://micahflee.com/feed/", htmlUrl: "https://micahflee.com" },
  { name: "nesbitt.io", xmlUrl: "https://nesbitt.io/feed.xml", htmlUrl: "https://nesbitt.io" },
  { name: "construction-physics.com", xmlUrl: "https://www.construction-physics.com/feed", htmlUrl: "https://construction-physics.com" },
  { name: "tedium.co", xmlUrl: "https://feed.tedium.co/", htmlUrl: "https://tedium.co" },
  { name: "susam.net", xmlUrl: "https://susam.net/feed.xml", htmlUrl: "https://susam.net" },
  { name: "entropicthoughts.com", xmlUrl: "https://entropicthoughts.com/feed.xml", htmlUrl: "https://entropicthoughts.com" },
  { name: "buttondown.com/hillelwayne", xmlUrl: "https://buttondown.com/hillelwayne/rss", htmlUrl: "https://buttondown.com/hillelwayne" },
  { name: "dwarkesh.com", xmlUrl: "https://www.dwarkeshpatel.com/feed", htmlUrl: "https://dwarkesh.com" },
  { name: "danielmiessler.com", xmlUrl: "https://danielmiessler.com/feed", htmlUrl: "https://danielmiessler.com" },
  { name: "grugq.github.io", xmlUrl: "https://grugq.github.io/feed.xml", htmlUrl: "https://grugq.github.io" },
  { name: "lucian36.substack.com", xmlUrl: "https://lucian36.substack.com/feed", htmlUrl: "https://lucian36.substack.com" },
  { name: "scotthelme.co.uk", xmlUrl: "https://scotthelme.co.uk/rss", htmlUrl: "https://scotthelme.co.uk" },
  { name: "aiforswes.com", xmlUrl: "https://www.aiforswes.com/feed", htmlUrl: "https://www.aiforswes.com" },
  { name: "aiguide.substack.com", xmlUrl: "https://aiguide.substack.com/feed", htmlUrl: "https://aiguide.substack.com" },
  { name: "aitidbits.ai", xmlUrl: "https://www.aitidbits.ai/feed", htmlUrl: "https://www.aitidbits.ai" },
  { name: "answer.ai", xmlUrl: "https://www.answer.ai/index.xml", htmlUrl: "https://www.answer.ai" },
  { name: "anyscale.com", xmlUrl: "https://www.anyscale.com/rss.xml", htmlUrl: "https://www.anyscale.com" },
  { name: "bensbites.com", xmlUrl: "https://www.bensbites.com/feed", htmlUrl: "https://www.bensbites.com" },
  { name: "blog.vllm.ai", xmlUrl: "https://vllm.ai/blog/atom.xml", htmlUrl: "https://vllm.ai/blog" },
  { name: "cameronrwolfe.substack.com", xmlUrl: "https://cameronrwolfe.substack.com/feed", htmlUrl: "https://cameronrwolfe.substack.com" },
  { name: "codingwithintelligence.substack.com", xmlUrl: "https://codingwithintelligence.com/feed", htmlUrl: "https://codingwithintelligence.com" },
  { name: "fchollet.substack.com", xmlUrl: "https://fchollet.substack.com/feed", htmlUrl: "https://fchollet.substack.com" },
  { name: "frontierai.substack.com", xmlUrl: "https://frontierai.substack.com/feed", htmlUrl: "https://frontierai.substack.com" },
  { name: "gonzoml.substack.com", xmlUrl: "https://gonzoml.substack.com/feed", htmlUrl: "https://gonzoml.substack.com" },
  { name: "huggingface.co", xmlUrl: "https://huggingface.co/blog/feed.xml", htmlUrl: "https://huggingface.co/blog" },
  { name: "iaee.substack.com", xmlUrl: "https://iaee.substack.com/feed", htmlUrl: "https://iaee.substack.com" },
  { name: "importai.substack.com", xmlUrl: "https://importai.substack.com/feed", htmlUrl: "https://importai.substack.com" },
  { name: "intersectingai.substack.com", xmlUrl: "https://intersectingai.substack.com/feed", htmlUrl: "https://intersectingai.substack.com" },
  { name: "intuitiveai.substack.com", xmlUrl: "https://intuitiveai.substack.com/feed", htmlUrl: "https://intuitiveai.substack.com" },
  { name: "kaitchup.substack.com", xmlUrl: "https://kaitchup.substack.com/feed", htmlUrl: "https://kaitchup.substack.com" },
  { name: "lastweekin.ai", xmlUrl: "https://lastweekin.ai/feed", htmlUrl: "https://lastweekin.ai" },
  { name: "latent.space", xmlUrl: "https://www.latent.space/feed", htmlUrl: "https://www.latent.space" },
  { name: "llmwatch.com", xmlUrl: "https://www.llmwatch.com/feed", htmlUrl: "https://www.llmwatch.com" },
  { name: "machinelearning.substack.com", xmlUrl: "https://machinelearning.substack.com/feed", htmlUrl: "https://machinelearning.substack.com" },
  { name: "magazine.sebastianraschka.com", xmlUrl: "https://magazine.sebastianraschka.com/feed", htmlUrl: "https://magazine.sebastianraschka.com" },
  { name: "newsletter.ruder.io", xmlUrl: "https://newsletter.ruder.io/feed", htmlUrl: "https://newsletter.ruder.io" },
  { name: "newsletter.victordibia.com", xmlUrl: "https://newsletter.victordibia.com/feed", htmlUrl: "https://newsletter.victordibia.com" },
  { name: "normaltech.ai", xmlUrl: "https://www.normaltech.ai/feed", htmlUrl: "https://www.normaltech.ai" },
  { name: "wise.readwise.io", xmlUrl: "https://wise.readwise.io/feed", htmlUrl: "https://wise.readwise.io" },
  { name: "semafor.com", xmlUrl: "https://www.semafor.com/rss.xml", htmlUrl: "https://www.semafor.com" },
  { name: "thegradient.pub", xmlUrl: "https://thegradient.pub/rss", htmlUrl: "https://thegradient.pub" },
  { name: "trelis.substack.com", xmlUrl: "https://trelis.substack.com/feed", htmlUrl: "https://trelis.substack.com" },
  { name: "verityharding.substack.com", xmlUrl: "https://verityharding.substack.com/feed", htmlUrl: "https://verityharding.substack.com" },
  { name: "InfoQ 中文", xmlUrl: "https://www.infoq.cn/feed", htmlUrl: "https://www.infoq.cn" },
  { name: "开源中国-资讯", xmlUrl: "https://www.oschina.net/news/rss", htmlUrl: "https://www.oschina.net/news" },
  { name: "爱范儿", xmlUrl: "https://www.ifanr.com/feed", htmlUrl: "https://www.ifanr.com" },
  { name: "量子位", xmlUrl: "https://www.qbitai.com/feed", htmlUrl: "https://www.qbitai.com" },
  { name: "36氪", xmlUrl: "https://36kr.com/feed", htmlUrl: "https://36kr.com" },
  { name: "IT之家", xmlUrl: "https://www.ithome.com/rss", htmlUrl: "https://www.ithome.com" },
  { name: "阮一峰网络日志", xmlUrl: "https://www.ruanyifeng.com/blog/atom.xml", htmlUrl: "https://www.ruanyifeng.com/blog" },
  { name: "少数派", xmlUrl: "https://sspai.com/feed", htmlUrl: "https://sspai.com" },
  { name: "V2EX-创意", xmlUrl: "https://www.v2ex.com/feed/tab/creative.xml", htmlUrl: "https://www.v2ex.com/?tab=creative" },
  { name: "V2EX-程序员", xmlUrl: "https://www.v2ex.com/feed/tab/qna.xml", htmlUrl: "https://www.v2ex.com/?tab=qna" },
  { name: "Solidot", xmlUrl: "https://www.solidot.org/index.rss", htmlUrl: "https://www.solidot.org" },
  { name: "AIGC开放社区", xmlUrl: "https://www.aigcopen.com/feed", htmlUrl: "https://www.aigcopen.com" },
  { name: "HyperAI", xmlUrl: "https://hyper.ai/cn/feed.xml", htmlUrl: "https://hyper.ai/cn/news" },
  { name: "雷峰网", xmlUrl: "https://www.leiphone.com/feed", htmlUrl: "https://www.leiphone.com" },
  { name: "腾讯研究院", xmlUrl: "https://www.tisi.org/feed", htmlUrl: "https://www.tisi.org" },
  { name: "科学空间", xmlUrl: "https://spaces.ac.cn/feed", htmlUrl: "https://spaces.ac.cn" },
  { name: "博客园首页精选", xmlUrl: "https://www.cnblogs.com/rss", htmlUrl: "https://www.cnblogs.com" },
  { name: "掘金RSS", xmlUrl: "https://juejin.cn/rss", htmlUrl: "https://juejin.cn" },
  { name: "开源中国问答", xmlUrl: "https://www.oschina.net/question/rss", htmlUrl: "https://www.oschina.net/question" },
  { name: "SegmentFault 问答", xmlUrl: "https://segmentfault.com/feeds/questions", htmlUrl: "https://segmentfault.com/questions" },
  { name: "CNode 社区", xmlUrl: "https://cnodejs.org/rss", htmlUrl: "https://cnodejs.org" },
  { name: "Appinn 小众软件", xmlUrl: "https://www.appinn.com/feed", htmlUrl: "https://www.appinn.com" },
  { name: "异次元软件世界", xmlUrl: "https://www.iplaysoft.com/feed", htmlUrl: "https://www.iplaysoft.com" },
  { name: "月光博客", xmlUrl: "https://www.williamlong.info/rss.xml", htmlUrl: "https://www.williamlong.info" },
  { name: "borretti.me", xmlUrl: "https://borretti.me/feed.xml", htmlUrl: "https://borretti.me" },
  { name: "wheresyoured.at", xmlUrl: "https://www.wheresyoured.at/rss/", htmlUrl: "https://wheresyoured.at" },
  { name: "jayd.ml", xmlUrl: "https://jayd.ml/feed.xml", htmlUrl: "https://jayd.ml" },
  { name: "minimaxir.com", xmlUrl: "https://minimaxir.com/index.xml", htmlUrl: "https://minimaxir.com" },
  { name: "geohot.github.io", xmlUrl: "https://geohot.github.io/blog/feed.xml", htmlUrl: "https://geohot.github.io" },
  { name: "paulgraham.com", xmlUrl: "http://www.aaronsw.com/2002/feeds/pgessays.rss", htmlUrl: "https://paulgraham.com" },
  { name: "filfre.net", xmlUrl: "https://www.filfre.net/feed/", htmlUrl: "https://filfre.net" },
  { name: "blog.jim-nielsen.com", xmlUrl: "https://blog.jim-nielsen.com/feed.xml", htmlUrl: "https://blog.jim-nielsen.com" },
  { name: "dfarq.homeip.net", xmlUrl: "https://dfarq.homeip.net/feed/", htmlUrl: "https://dfarq.homeip.net" },
  { name: "jyn.dev", xmlUrl: "https://jyn.dev/atom.xml", htmlUrl: "https://jyn.dev" },
  { name: "geoffreylitt.com", xmlUrl: "https://www.geoffreylitt.com/feed.xml", htmlUrl: "https://geoffreylitt.com" },
  { name: "downtowndougbrown.com", xmlUrl: "https://www.downtowndougbrown.com/feed/", htmlUrl: "https://downtowndougbrown.com" },
  { name: "brutecat.com", xmlUrl: "https://brutecat.com/rss.xml", htmlUrl: "https://brutecat.com" },
  { name: "eli.thegreenplace.net", xmlUrl: "https://eli.thegreenplace.net/feeds/all.atom.xml", htmlUrl: "https://eli.thegreenplace.net" },
  { name: "abortretry.fail", xmlUrl: "https://www.abortretry.fail/feed", htmlUrl: "https://abortretry.fail" },
  { name: "fabiensanglard.net", xmlUrl: "https://fabiensanglard.net/rss.xml", htmlUrl: "https://fabiensanglard.net" },
  { name: "oldvcr.blogspot.com", xmlUrl: "https://oldvcr.blogspot.com/feeds/posts/default", htmlUrl: "https://oldvcr.blogspot.com" },
  { name: "bogdanthegeek.github.io", xmlUrl: "https://bogdanthegeek.github.io/blog/index.xml", htmlUrl: "https://bogdanthegeek.github.io" },
  { name: "hugotunius.se", xmlUrl: "https://hugotunius.se/feed.xml", htmlUrl: "https://hugotunius.se" },
  { name: "gwern.net", xmlUrl: "https://gwern.substack.com/feed", htmlUrl: "https://gwern.net" },
  { name: "berthub.eu", xmlUrl: "https://berthub.eu/articles/index.xml", htmlUrl: "https://berthub.eu" },
  { name: "chadnauseam.com", xmlUrl: "https://chadnauseam.com/rss.xml", htmlUrl: "https://chadnauseam.com" },
  { name: "simone.org", xmlUrl: "https://simone.org/feed/", htmlUrl: "https://simone.org" },
  { name: "it-notes.dragas.net", xmlUrl: "https://it-notes.dragas.net/feed/", htmlUrl: "https://it-notes.dragas.net" },
  { name: "beej.us", xmlUrl: "https://beej.us/blog/rss.xml", htmlUrl: "https://beej.us" },
  { name: "hey.paris", xmlUrl: "https://hey.paris/index.xml", htmlUrl: "https://hey.paris" },
  { name: "danielwirtz.com", xmlUrl: "https://danielwirtz.com/rss.xml", htmlUrl: "https://danielwirtz.com" },
  { name: "matduggan.com", xmlUrl: "https://matduggan.com/rss/", htmlUrl: "https://matduggan.com" },
  { name: "refactoringenglish.com", xmlUrl: "https://refactoringenglish.com/index.xml", htmlUrl: "https://refactoringenglish.com" },
  { name: "worksonmymachine.substack.com", xmlUrl: "https://worksonmymachine.substack.com/feed", htmlUrl: "https://worksonmymachine.substack.com" },
  { name: "philiplaine.com", xmlUrl: "https://philiplaine.com/index.xml", htmlUrl: "https://philiplaine.com" },
  { name: "steveblank.com", xmlUrl: "https://steveblank.com/feed/", htmlUrl: "https://steveblank.com" },
  { name: "bernsteinbear.com", xmlUrl: "https://bernsteinbear.com/feed.xml", htmlUrl: "https://bernsteinbear.com" },
  { name: "danieldelaney.net", xmlUrl: "https://danieldelaney.net/feed", htmlUrl: "https://danieldelaney.net" },
  { name: "troyhunt.com", xmlUrl: "https://www.troyhunt.com/rss/", htmlUrl: "https://troyhunt.com" },
  { name: "herman.bearblog.dev", xmlUrl: "https://herman.bearblog.dev/feed/", htmlUrl: "https://herman.bearblog.dev" },
  { name: "tomrenner.com", xmlUrl: "https://tomrenner.com/index.xml", htmlUrl: "https://tomrenner.com" },
  { name: "blog.pixelmelt.dev", xmlUrl: "https://blog.pixelmelt.dev/rss/", htmlUrl: "https://blog.pixelmelt.dev" },
  { name: "martinalderson.com", xmlUrl: "https://martinalderson.com/feed.xml", htmlUrl: "https://martinalderson.com" },
  { name: "danielchasehooper.com", xmlUrl: "https://danielchasehooper.com/feed.xml", htmlUrl: "https://danielchasehooper.com" },
  { name: "chiark.greenend.org.uk/~sgtatham", xmlUrl: "https://www.chiark.greenend.org.uk/~sgtatham/quasiblog/feed.xml", htmlUrl: "https://chiark.greenend.org.uk/~sgtatham" },
  { name: "grantslatton.com", xmlUrl: "https://grantslatton.com/rss.xml", htmlUrl: "https://grantslatton.com" },
  { name: "experimental-history.com", xmlUrl: "https://www.experimental-history.com/feed", htmlUrl: "https://experimental-history.com" },
  { name: "anildash.com", xmlUrl: "https://anildash.com/feed.xml", htmlUrl: "https://anildash.com" },
  { name: "aresluna.org", xmlUrl: "https://aresluna.org/main.rss", htmlUrl: "https://aresluna.org" },
  { name: "michael.stapelberg.ch", xmlUrl: "https://michael.stapelberg.ch/feed.xml", htmlUrl: "https://michael.stapelberg.ch" },
  { name: "miguelgrinberg.com", xmlUrl: "https://blog.miguelgrinberg.com/feed", htmlUrl: "https://miguelgrinberg.com" },
  { name: "keygen.sh", xmlUrl: "https://keygen.sh/blog/feed.xml", htmlUrl: "https://keygen.sh" },
  { name: "mjg59.dreamwidth.org", xmlUrl: "https://mjg59.dreamwidth.org/data/rss", htmlUrl: "https://mjg59.dreamwidth.org" },
  { name: "computer.rip", xmlUrl: "https://computer.rip/rss.xml", htmlUrl: "https://computer.rip" },
  { name: "tedunangst.com", xmlUrl: "https://www.tedunangst.com/flak/rss", htmlUrl: "https://tedunangst.com" },
];

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

interface WatchMatch {
  keyword: string;
  article: Article;
  matchedIn: Array<'title' | 'description' | 'source'>;
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

async function fetchWaytoAgiLatest(limit: number): Promise<FeedFetchResult> {
  if (limit <= 0) {
    return {
      articles: [],
      health: {
        sourceName: WAYTOAGI_SOURCE_NAME,
        xmlUrl: WAYTOAGI_BLOG_URL,
        sourceUrl: WAYTOAGI_SOURCE_URL,
        status: 'empty',
        articleCount: 0,
      },
    };
  }

  try {
    const response = await fetch(WAYTOAGI_BLOG_URL, {
      headers: {
        'User-Agent': 'AI-Daily-Digest/1.0 (WaytoAGI Reader)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const html = await response.text();
    const cardPattern = /<a[^>]+href="(\/blog\/news-\d{8})"[^>]*>([\s\S]*?)<\/a>/gi;
    const seen = new Set<string>();
    const articles: Article[] = [];
    let match: RegExpExecArray | null;

    while ((match = cardPattern.exec(html)) !== null) {
      const href = match[1] ?? '';
      const cardHtml = match[2] ?? '';
      if (!href || seen.has(href)) continue;
      seen.add(href);

      const titleMatch = cardHtml.match(/<div[^>]*class="[^"]*text-lg font-bold[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
      const descMatch = cardHtml.match(/<div[^>]*class="[^"]*line-clamp-2[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
      const dateMatch = href.match(/news-(\d{4})(\d{2})(\d{2})/i);

      const title = stripHtml(titleMatch?.[1] ?? '').trim() || href.replace('/blog/', '');
      const description = stripHtml(descMatch?.[1] ?? '').trim().slice(0, 500);
      const link = `https://www.waytoagi.com/zh${href}`;

      let pubDate = new Date(0);
      if (dateMatch) {
        const yyyy = Number(dateMatch[1]);
        const mm = Number(dateMatch[2]) - 1;
        const dd = Number(dateMatch[3]);
        pubDate = new Date(Date.UTC(yyyy, mm, dd, 0, 0, 0));
      }

      articles.push({
        title,
        link,
        pubDate,
        description,
        sourceName: WAYTOAGI_SOURCE_NAME,
        sourceUrl: WAYTOAGI_SOURCE_URL,
      });
    }

    const limited = articles.slice(0, limit);
    return {
      articles: limited,
      health: {
        sourceName: WAYTOAGI_SOURCE_NAME,
        xmlUrl: WAYTOAGI_BLOG_URL,
        sourceUrl: WAYTOAGI_SOURCE_URL,
        status: limited.length > 0 ? 'ok' : 'empty',
        articleCount: limited.length,
      },
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return {
      articles: [],
      health: {
        sourceName: WAYTOAGI_SOURCE_NAME,
        xmlUrl: WAYTOAGI_BLOG_URL,
        sourceUrl: WAYTOAGI_SOURCE_URL,
        status: 'error',
        articleCount: 0,
        errorCode: classifyFeedError(msg),
        errorMessage: msg,
      },
    };
  }
}

// ============================================================================
// AI Providers (Gemini + OpenAI-compatible fallback)
// ============================================================================

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

### 2. 质量 (quality) - 文章本身的深度和写作质量
- 10: 深度分析，原创洞见，引用丰富
- 7-9: 有深度，观点独到
- 4-6: 信息准确，表达清晰
- 1-3: 浅尝辄止或纯转述

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
  
  for (let i = 0; i < batches.length; i += MAX_CONCURRENT_GEMINI) {
    const batchGroup = batches.slice(i, i + MAX_CONCURRENT_GEMINI);
    const promises = batchGroup.map(async (batch) => {
      try {
        const prompt = buildScoringPrompt(batch);
        const responseText = await aiClient.call(prompt);
        const parsed = parseJsonResponse<GeminiScoringResult>(responseText);
        
        if (parsed.results && Array.isArray(parsed.results)) {
          for (const result of parsed.results) {
            const clamp = (v: number) => Math.min(10, Math.max(1, Math.round(v)));
            const cat = (validCategories.has(result.category) ? result.category : 'other') as CategoryId;
            allScores.set(result.index, {
              relevance: clamp(result.relevance),
              quality: clamp(result.quality),
              timeliness: clamp(result.timeliness),
              category: cat,
              keywords: Array.isArray(result.keywords) ? result.keywords.slice(0, 4) : [],
            });
          }
        }
      } catch (error) {
        console.warn(`[digest] Scoring batch failed: ${error instanceof Error ? error.message : String(error)}`);
        for (const item of batch) {
          allScores.set(item.index, { relevance: 5, quality: 5, timeliness: 5, category: 'other', keywords: [] });
        }
      }
    });
    
    await Promise.all(promises);
    console.log(`[digest] Scoring progress: ${Math.min(i + MAX_CONCURRENT_GEMINI, batches.length)}/${batches.length} batches`);
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

  return `你是一个技术内容摘要专家。请为以下文章完成三件事：

1. **中文标题** (titleZh): 将英文标题翻译成自然的中文。如果原标题已经是中文则保持不变。
2. **摘要** (summary): 4-6 句话的结构化摘要，让读者不点进原文也能了解核心内容。包含：
   - 文章讨论的核心问题或主题（1 句）
   - 关键论点、技术方案或发现（2-3 句）
   - 结论或作者的核心观点（1 句）
3. **推荐理由** (reason): 1 句话说明"为什么值得读"，区别于摘要（摘要说"是什么"，推荐理由说"为什么"）。

${langInstruction}

摘要要求：
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
  lang: 'zh' | 'en'
): Promise<Map<number, { titleZh: string; summary: string; reason: string }>> {
  const summaries = new Map<number, { titleZh: string; summary: string; reason: string }>();
  
  const indexed = articles.map(a => ({
    index: a.index,
    title: a.title,
    description: a.description,
    sourceName: a.sourceName,
    link: a.link,
  }));
  
  const batches: typeof indexed[] = [];
  for (let i = 0; i < indexed.length; i += GEMINI_BATCH_SIZE) {
    batches.push(indexed.slice(i, i + GEMINI_BATCH_SIZE));
  }
  
  console.log(`[digest] Generating summaries for ${articles.length} articles in ${batches.length} batches`);
  
  for (let i = 0; i < batches.length; i += MAX_CONCURRENT_GEMINI) {
    const batchGroup = batches.slice(i, i + MAX_CONCURRENT_GEMINI);
    const promises = batchGroup.map(async (batch) => {
      try {
        const prompt = buildSummaryPrompt(batch, lang);
        const responseText = await aiClient.call(prompt);
        const parsed = parseJsonResponse<GeminiSummaryResult>(responseText);
        
        if (parsed.results && Array.isArray(parsed.results)) {
          for (const result of parsed.results) {
            summaries.set(result.index, {
              titleZh: result.titleZh || '',
              summary: result.summary || '',
              reason: result.reason || '',
            });
          }
        }
      } catch (error) {
        console.warn(`[digest] Summary batch failed: ${error instanceof Error ? error.message : String(error)}`);
        for (const item of batch) {
          summaries.set(item.index, { titleZh: item.title, summary: item.title, reason: '' });
        }
      }
    });
    
    await Promise.all(promises);
    console.log(`[digest] Summary progress: ${Math.min(i + MAX_CONCURRENT_GEMINI, batches.length)}/${batches.length} batches`);
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

  const prompt = `根据以下今日精选技术文章列表，写一段 3-5 句话的"今日看点"总结。
要求：
- 提炼出今天技术圈的 2-3 个主要趋势或话题
- 不要逐篇列举，要做宏观归纳
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

function humanizeTime(pubDate: Date): string {
  const diffMs = Date.now() - pubDate.getTime();
  const diffMins = Math.floor(diffMs / 60_000);
  const diffHours = Math.floor(diffMs / 3_600_000);
  const diffDays = Math.floor(diffMs / 86_400_000);

  if (diffMins < 60) return `${diffMins} 分钟前`;
  if (diffHours < 24) return `${diffHours} 小时前`;
  if (diffDays < 7) return `${diffDays} 天前`;
  return pubDate.toISOString().slice(0, 10);
}

async function fetchHuggingFacePapersLatest(): Promise<FeedFetchResult> {
  try {
    const response = await fetch(HUGGINGFACE_PAPERS_SOURCE_URL, {
      headers: {
        'User-Agent': 'AI-Daily-Digest/1.0 (Hugging Face Papers Reader)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const html = await response.text();
    const dateMatch = html.match(/&quot;dateString&quot;:&quot;(\d{4}-\d{2}-\d{2})&quot;/i);
    const pageDate = dateMatch ? new Date(`${dateMatch[1]}T00:00:00.000Z`) : new Date();

    const articlePattern = /<h3[^>]*>\s*<a href="(\/papers\/[^"]+)"[^>]*>([\s\S]*?)<\/a>\s*<\/h3>/gi;
    const seen = new Set<string>();
    const articles: Article[] = [];
    let match: RegExpExecArray | null;

    while ((match = articlePattern.exec(html)) !== null) {
      const href = match[1] ?? '';
      const rawTitle = match[2] ?? '';
      if (!href || seen.has(href)) continue;
      seen.add(href);

      const title = stripHtml(rawTitle).trim();
      if (!title) continue;

      articles.push({
        title,
        link: `https://huggingface.co${href}`,
        pubDate: pageDate,
        description: '',
        sourceName: HUGGINGFACE_PAPERS_SOURCE_NAME,
        sourceUrl: HUGGINGFACE_PAPERS_SOURCE_URL,
      });
    }

    return {
      articles,
      health: {
        sourceName: HUGGINGFACE_PAPERS_SOURCE_NAME,
        xmlUrl: HUGGINGFACE_PAPERS_SOURCE_URL,
        sourceUrl: HUGGINGFACE_PAPERS_SOURCE_URL,
        status: articles.length > 0 ? 'ok' : 'empty',
        articleCount: articles.length,
      },
    };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    return {
      articles: [],
      health: {
        sourceName: HUGGINGFACE_PAPERS_SOURCE_NAME,
        xmlUrl: HUGGINGFACE_PAPERS_SOURCE_URL,
        sourceUrl: HUGGINGFACE_PAPERS_SOURCE_URL,
        status: 'error',
        articleCount: 0,
        errorCode: classifyFeedError(msg),
        errorMessage: msg,
      },
    };
  }
}

function getWatchKeywords(): string[] {
  const raw = process.env.DIGEST_WATCH_KEYWORDS?.trim();
  if (!raw) {
    return DEFAULT_WATCH_KEYWORDS;
  }

  const parsed = raw
    .split(/[,\n|;]/)
    .map((item) => item.trim())
    .filter(Boolean);

  return parsed.length > 0 ? parsed : DEFAULT_WATCH_KEYWORDS;
}

function findWatchMatches(articles: Article[], keywords: string[]): WatchMatch[] {
  const matches: WatchMatch[] = [];
  const seen = new Set<string>();

  for (const article of articles) {
    const title = article.title.toLowerCase();
    const description = article.description.toLowerCase();
    const source = article.sourceName.toLowerCase();

    for (const keyword of keywords) {
      const needle = keyword.toLowerCase();
      const matchedIn: Array<'title' | 'description' | 'source'> = [];

      if (title.includes(needle)) matchedIn.push('title');
      if (description.includes(needle)) matchedIn.push('description');
      if (source.includes(needle)) matchedIn.push('source');

      if (matchedIn.length === 0) continue;

      const dedupeKey = `${keyword}::${article.link}`;
      if (seen.has(dedupeKey)) continue;
      seen.add(dedupeKey);

      matches.push({ keyword, article, matchedIn });
    }
  }

  matches.sort((a, b) => b.article.pubDate.getTime() - a.article.pubDate.getTime());
  return matches;
}

function generateWatchSection(
  watchKeywords: string[],
  watchMatches: WatchMatch[],
  selectedLinks: Set<string>,
): string {
  let report = `## 🎯 重点关注关键词\n\n`;
  report += `当前重点关注：${watchKeywords.map((kw) => `\`${kw}\``).join('、')}\n\n`;

  if (watchMatches.length === 0) {
    report += `最近时间范围内未命中这些关键词\n\n`;
    return report;
  }

  report += `本次命中 ${watchMatches.length} 条：\n\n`;

  for (const match of watchMatches.slice(0, 8)) {
    const inTop = selectedLinks.has(match.article.link) ? '已进入 Top 15' : '未进入 Top 15';
    const matchedInText = match.matchedIn.join('/');
    report += `- [${match.article.title}](${match.article.link})\n`;
    report += `  来源：${match.article.sourceName} · ${humanizeTime(match.article.pubDate)} · 命中：${match.keyword}（${matchedInText}） · ${inTop}\n`;
  }

  report += `\n`;
  return report;
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
  hours: number;
  lang: string;
}, watch: {
  keywords: string[];
  matches: WatchMatch[];
}): string {
  const now = new Date();
  const dateStr = now.toISOString().split('T')[0];
  const karpathyFeeds = Math.min(92, stats.totalFeeds);
  const supplementalFeeds = Math.max(stats.totalFeeds - 92, 0);
  
  let report = `# 📰 AI 博客每日精选 — ${dateStr}\n\n`;
  report += `> 本期从 ${stats.totalFeeds} 个信息源中完成聚合筛选（Karpathy 推荐 ${karpathyFeeds} 个 + spsz0831 补充 ${supplementalFeeds} 个），AI 精选 Top ${articles.length}\n\n`;

  // ── Today's Highlights ──
  if (highlights) {
    report += `## 📝 今日看点\n\n`;
    report += `${highlights}\n\n`;
    report += `---\n\n`;
  }

  report += generateWatchSection(
    watch.keywords,
    watch.matches,
    new Set(articles.map((article) => article.link)),
  );
  report += `---\n\n`;

  // ── Top 3 Deep Showcase ──
  if (articles.length >= 3) {
    report += `## 🏆 今日必读\n\n`;
    for (let i = 0; i < Math.min(3, articles.length); i++) {
      const a = articles[i];
      const medal = ['🥇', '🥈', '🥉'][i];
      const catMeta = CATEGORY_META[a.category];
      
      report += `${medal} **${a.titleZh || a.title}**\n\n`;
      report += `[${a.title}](${a.link}) — ${a.sourceName} · ${humanizeTime(a.pubDate)} · ${catMeta.emoji} ${catMeta.label}\n\n`;
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
      report += `[${a.title}](${a.link}) — **${a.sourceName}** · ${humanizeTime(a.pubDate)} · ⭐ ${scoreTotal}/30\n\n`;
      report += `> ${a.summary}\n\n`;
      if (a.keywords.length > 0) {
        report += `🏷️ ${a.keywords.join(', ')}\n\n`;
      }
      report += `---\n\n`;
    }
  }

  // ── Footer ──
  report += `*生成于 ${dateStr} ${now.toISOString().split('T')[1]?.slice(0, 5) || ''} | 扫描 ${stats.successFeeds} 源 → 获取 ${stats.totalArticles} 篇 → 精选 ${articles.length} 篇*\n`;
  report += `*源说明：其中 92 个基于 [Hacker News Popularity Contest 2025](https://refactoringenglish.com/tools/hn-popularity/) / [Andrej Karpathy](https://x.com/karpathy) 推荐，其他为 spsz0831 按需补充*\n`;
  report += `*由「AI杨侦探」制作，欢迎关注获取更多 AI 实用技巧 💡*\n`;

  return report;
}

// ============================================================================
// CLI
// ============================================================================

function printUsage(): never {
  console.log(`AI杨侦探工作流 - AI-powered content workflow from curated feeds

Usage:
  bun scripts/digest.ts [options]

Options:
  --hours <n>     Time range in hours (default: 48)
  --top-n <n>     Number of top articles to include (default: 15)
  --lang <lang>   Summary language: zh or en (default: zh)
  --waytoagi-limit <n> Optional: include latest N posts from waytoagi blog (default: 0, disabled)
  --output <path> Output file path (default: ./reports/output/ai-daily-digest-YYYYMMDD.md)
  --health-log <path> Optional health log JSON path (default: ./reports/health/run-YYYYMMDD-HHmm.json)
  --help          Show this help

Environment:
  GEMINI_API_KEY   Optional but recommended. Get one at https://aistudio.google.com/apikey
  GEMINI_MODEL     Optional Gemini model (default: gemini-3.1-pro-preview)
  OPENAI_API_KEY   Optional OpenAI-compatible key, including local 9router
  OPENAI_API_BASE  Optional OpenAI-compatible base URL (default: https://api.openai.com/v1)
  OPENAI_MODEL     Optional OpenAI-compatible model (default: deepseek-chat for DeepSeek base, else gpt-4o-mini)
  OPENAI_WIRE_API  Optional protocol override: chat | responses

Examples:
  bun scripts/digest.ts --hours 24 --top-n 10 --lang zh
  bun scripts/digest.ts --hours 72 --top-n 20 --lang en --output ./reports/output/my-digest.md
`);
  process.exit(0);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  if (args.includes('--help') || args.includes('-h')) printUsage();
  
  let hours = 48;
  let topN = 15;
  let lang: 'zh' | 'en' = 'zh';
  let waytoAgiLimit = 0;
  let outputPath = '';
  let healthLogPath = '';
  
  for (let i = 0; i < args.length; i++) {
    const arg = args[i]!;
    if (arg === '--hours' && args[i + 1]) {
      hours = parseInt(args[++i]!, 10);
    } else if (arg === '--top-n' && args[i + 1]) {
      topN = parseInt(args[++i]!, 10);
    } else if (arg === '--lang' && args[i + 1]) {
      lang = args[++i] as 'zh' | 'en';
    } else if (arg === '--waytoagi-limit' && args[i + 1]) {
      waytoAgiLimit = parseInt(args[++i]!, 10);
    } else if (arg === '--output' && args[i + 1]) {
      outputPath = args[++i]!;
    } else if (arg === '--health-log' && args[i + 1]) {
      healthLogPath = args[++i]!;
    }
  }
  
  const {
    geminiApiKey,
    geminiModel,
    openaiApiKey,
    openaiApiBase,
    openaiModel,
    openaiWireApi,
  } = loadAiEnv();

  if (!geminiApiKey && !openaiApiKey) {
    console.error('[digest] Error: Missing API key. Set GEMINI_API_KEY and/or OPENAI_API_KEY.');
    console.error('[digest] Gemini key: https://aistudio.google.com/apikey');
    process.exit(1);
  }

  const aiClient = createAIClient({
    geminiApiKey,
    geminiModel,
    openaiApiKey,
    openaiApiBase,
    openaiModel,
    openaiWireApi,
  });
  
    if (!outputPath) {
      const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
      outputPath = `./reports/output/ai-daily-digest-${dateStr}.md`;
    }
  
  console.log(`[digest] === AI杨侦探工作流 ===`);
  console.log(`[digest] Time range: ${hours} hours`);
  console.log(`[digest] Top N: ${topN}`);
  console.log(`[digest] Language: ${lang}`);
  if (waytoAgiLimit > 0) {
    console.log(`[digest] WaytoAGI latest limit: ${waytoAgiLimit}`);
  }
  console.log(`[digest] Output: ${outputPath}`);
  console.log(`[digest] AI provider: ${geminiApiKey ? 'Gemini (primary)' : 'OpenAI-compatible (primary)'}`);
  if (geminiApiKey) {
    const resolvedGeminiModel = geminiModel?.trim() || GEMINI_DEFAULT_MODEL;
    console.log(`[digest] Gemini model: ${resolvedGeminiModel}`);
  }
  if (openaiApiKey) {
    const resolvedBase = (openaiApiBase?.trim() || OPENAI_DEFAULT_API_BASE).replace(/\/+$/, '');
    const resolvedModel = openaiModel?.trim() || 'auto';
    const resolvedWire = inferDisplayWireApi(resolvedBase, openaiWireApi);
    console.log(`[digest] Fallback: ${resolvedBase} (model=${resolvedModel}, wire=${resolvedWire})`);
  }
  const watchKeywords = getWatchKeywords();
  console.log(`[digest] Watch keywords: ${watchKeywords.join(', ')}`);
  console.log('');
  
  console.log(`[digest] Step 1/5: Fetching ${RSS_FEEDS.length} RSS feeds...`);
  const fetchResult = await fetchAllFeeds(RSS_FEEDS);
  let allArticles = fetchResult.articles;

  console.log(`[digest] Step 1.2/5: Fetching Hugging Face Papers latest page...`);
  const huggingFacePapersResult = await fetchHuggingFacePapersLatest();
  fetchResult.healthEntries.push(huggingFacePapersResult.health);
  if (huggingFacePapersResult.health.status === 'error') {
    console.warn(`[digest] ✗ ${HUGGINGFACE_PAPERS_SOURCE_NAME}: ${huggingFacePapersResult.health.errorMessage || 'unknown error'}`);
  } else {
    console.log(`[digest] Hugging Face Papers added ${huggingFacePapersResult.articles.length} posts`);
  }
  allArticles = allArticles.concat(huggingFacePapersResult.articles);

  if (waytoAgiLimit > 0) {
    console.log(`[digest] Step 1.5/5: Fetching WaytoAGI latest ${waytoAgiLimit} posts...`);
    const waytoAgiResult = await fetchWaytoAgiLatest(waytoAgiLimit);
    fetchResult.healthEntries.push(waytoAgiResult.health);
    if (waytoAgiResult.health.status === 'error') {
      console.warn(`[digest] ✗ ${WAYTOAGI_SOURCE_NAME}: ${waytoAgiResult.health.errorMessage || 'unknown error'}`);
    } else {
      console.log(`[digest] WaytoAGI added ${waytoAgiResult.articles.length} posts`);
    }
    allArticles = allArticles.concat(waytoAgiResult.articles);
  }
  
  if (allArticles.length === 0) {
    console.error('[digest] Error: No articles fetched from any feed. Check network connection.');
    process.exit(1);
  }
  
  console.log(`[digest] Step 2/5: Filtering by time range (${hours} hours)...`);
  const cutoffTime = new Date(Date.now() - hours * 60 * 60 * 1000);
  const recentArticles = allArticles.filter(a => a.pubDate.getTime() > cutoffTime.getTime());
  
  console.log(`[digest] Found ${recentArticles.length} articles within last ${hours} hours`);

  const watchMatches = findWatchMatches(recentArticles, watchKeywords);
  if (watchMatches.length > 0) {
    console.log(`[digest] Watch hits: ${watchMatches.length}`);
    for (const match of watchMatches.slice(0, 5)) {
      console.log(`  - [${match.keyword}] ${match.article.title}`);
    }
  } else {
    console.log(`[digest] Watch hits: 0`);
  }
  
  if (recentArticles.length === 0) {
    console.error(`[digest] Error: No articles found within the last ${hours} hours.`);
    console.error(`[digest] Try increasing --hours (e.g., --hours 168 for one week)`);
    process.exit(1);
  }
  
  console.log(`[digest] Step 3/5: AI scoring ${recentArticles.length} articles...`);
  const scores = await scoreArticlesWithAI(recentArticles, aiClient);
  
  const scoredArticles = recentArticles.map((article, index) => {
    const score = scores.get(index) || { relevance: 5, quality: 5, timeliness: 5, category: 'other' as CategoryId, keywords: [] };
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
  const summaries = await summarizeArticles(indexedTopArticles, aiClient, lang);
  
  const finalArticles: ScoredArticle[] = topArticles.map((a, i) => {
    const sm = summaries.get(i) || { titleZh: a.title, summary: a.description.slice(0, 200), reason: '' };
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
  
  console.log(`[digest] Step 5/5: Generating today's highlights...`);
  const highlights = await generateHighlights(finalArticles, aiClient, lang);
  
  const successfulSources = new Set(allArticles.map(a => a.sourceName));
  
  const report = generateDigestReport(finalArticles, highlights, {
    totalFeeds: RSS_FEEDS.length + 1 + (waytoAgiLimit > 0 ? 1 : 0),
    successFeeds: successfulSources.size,
    totalArticles: allArticles.length,
    filteredArticles: recentArticles.length,
    hours,
    lang,
  }, {
    keywords: watchKeywords,
    matches: watchMatches,
  });
  
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, report);

  if (!healthLogPath) {
    const ts = new Date().toISOString().slice(0, 16).replace(/[:T]/g, '-');
      healthLogPath = `./reports/health/run-${ts}.json`;
  }

  const healthSummary = {
    totalFeeds: RSS_FEEDS.length + 1 + (waytoAgiLimit > 0 ? 1 : 0),
    okFeeds: fetchResult.healthEntries.filter(e => e.status === 'ok').length,
    emptyFeeds: fetchResult.healthEntries.filter(e => e.status === 'empty').length,
    errorFeeds: fetchResult.healthEntries.filter(e => e.status === 'error').length,
  };

  const healthLog = {
    generatedAt: new Date().toISOString(),
    hours,
    topN,
    lang,
    outputPath,
    stats: healthSummary,
    watchKeywords,
    watchMatches: watchMatches.map((match) => ({
      keyword: match.keyword,
      title: match.article.title,
      link: match.article.link,
      sourceName: match.article.sourceName,
      pubDate: match.article.pubDate.toISOString(),
      matchedIn: match.matchedIn,
      inTopN: finalArticles.some((article) => article.link === match.article.link),
    })),
    entries: fetchResult.healthEntries,
  };

  await mkdir(dirname(healthLogPath), { recursive: true });
  await writeFile(healthLogPath, JSON.stringify(healthLog, null, 2));
  
  console.log('');
  console.log(`[digest] ✅ Done!`);
  console.log(`[digest] 📁 Report: ${outputPath}`);
  console.log(`[digest] 🧪 Health log: ${healthLogPath}`);
  console.log(`[digest] 📊 Stats: ${successfulSources.size} sources → ${allArticles.length} articles → ${recentArticles.length} recent → ${finalArticles.length} selected`);
  
  if (finalArticles.length > 0) {
    console.log('');
    console.log(`[digest] 🏆 Top 3 Preview:`);
    for (let i = 0; i < Math.min(3, finalArticles.length); i++) {
      const a = finalArticles[i];
      console.log(`  ${i + 1}. ${a.titleZh || a.title}`);
      console.log(`     ${a.summary.slice(0, 80)}...`);
    }
  }

  if (watchMatches.length > 0) {
    console.log('');
    console.log(`[digest] 🎯 Watch keyword alert:`);
    for (const match of watchMatches.slice(0, 5)) {
      const inTopN = finalArticles.some((article) => article.link === match.article.link) ? 'IN_TOP_N' : 'NOT_IN_TOP_N';
      console.log(`  - ${match.keyword} | ${inTopN} | ${match.article.title}`);
    }
  }
}

await main().catch((err) => {
  console.error(`[digest] Fatal error: ${err instanceof Error ? err.message : String(err)}`);
  process.exit(1);
});
