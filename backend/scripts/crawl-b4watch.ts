import axios from 'axios';
import cheerio from 'cheerio';
import fs from 'fs';
import path from 'path';

interface CrawlResult {
  title: string;
  thumbnailUrl: string;
  sourceUrl: string;
  releaseDate: string | null;
}

interface CrawlOptions {
  startUrl: string;
  maxPages: number;
  output: string;
  userAgent: string;
  delay: number; // Delay between requests in milliseconds
  retries: number; // Number of retries for failed requests
  timeout: number; // Request timeout in milliseconds
}

const DEFAULT_OPTIONS: CrawlOptions = {
  startUrl: 'https://b4watch.com/movies/',
  maxPages: 10,
  output: path.resolve(process.cwd(), 'b4watch-lgbtq.json'),
  userAgent:
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0 Safari/537.36',
  delay: 2000, // 2 seconds between requests
  retries: 3, // Retry failed requests 3 times
  timeout: 30000, // 30 second timeout
};

function parseArgs(): CrawlOptions {
  const args = process.argv.slice(2);
  const options: CrawlOptions = { ...DEFAULT_OPTIONS };

  for (const arg of args) {
    const [key, value] = arg.split('=');
    switch (key) {
      case '--start':
      case '--startUrl':
        if (value) options.startUrl = value;
        break;
      case '--maxPages':
        if (value) options.maxPages = Number(value);
        break;
      case '--output':
        if (value) options.output = path.resolve(process.cwd(), value);
        break;
      case '--userAgent':
        if (value) options.userAgent = value;
        break;
      case '--delay':
        if (value) options.delay = Number(value);
        break;
      case '--retries':
        if (value) options.retries = Number(value);
        break;
      case '--timeout':
        if (value) options.timeout = Number(value);
        break;
    }
  }

  return options;
}

const MONTH_MAP: Record<string, string> = {
  jan: '01',
  feb: '02',
  mar: '03',
  apr: '04',
  may: '05',
  jun: '06',
  jul: '07',
  aug: '08',
  sep: '09',
  sept: '09',
  oct: '10',
  nov: '11',
  dec: '12',
};

function parseReleaseDate(raw?: string): string | null {
  if (!raw) return null;
  const cleaned = raw
    .replace(/\b(1080p|720p|480p)\b/gi, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (!cleaned) return null;
  const straight = new Date(cleaned.replace(/\.(?=\s|\d)/g, ''));
  if (!Number.isNaN(straight.getTime())) {
    return straight.toISOString();
  }
  const mdy = cleaned.match(/([A-Za-z]+)\.?\s+(\d{1,2}),?\s*(\d{4})/);
  if (mdy) {
    const monthKey = mdy[1]?.toLowerCase().slice(0, 3) ?? '';
    const month = MONTH_MAP[monthKey];
    const dayValue = mdy[2];
    const year = mdy[3];
    if (month && dayValue && year) {
      const day = dayValue.padStart(2, '0');
      const iso = `${year}-${month}-${day}`;
      const parsedIso = new Date(iso);
      if (!Number.isNaN(parsedIso.getTime())) {
        return parsedIso.toISOString();
      }
    }
  }
  const dmy = cleaned.replace(/\b(\d{2})\.(\d{2})\.(\d{4})\b/, '$3-$2-$1');
  const parsedAlt = new Date(dmy);
  return Number.isNaN(parsedAlt.getTime()) ? null : parsedAlt.toISOString();
}

function normalizeUrl(baseUrl: string, maybeUrl?: string): string | null {
  if (!maybeUrl) return null;
  try {
    return new URL(maybeUrl, baseUrl).href;
  } catch {
    return null;
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchHtml(
  url: string,
  userAgent: string,
  timeout: number,
  retries: number = 3,
): Promise<string> {
  let lastError: any;
  
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await axios.get(url, {
        headers: {
          'User-Agent': userAgent,
          Accept: 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
        timeout,
        validateStatus: (status) => status < 500, // Don't throw on 4xx errors
      });
      
      if (response.status >= 400) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      return response.data;
    } catch (error: any) {
      lastError = error;
      const isLastAttempt = attempt === retries;
      
      if (!isLastAttempt) {
        const backoffDelay = Math.min(1000 * Math.pow(2, attempt - 1), 10000); // Exponential backoff, max 10s
        console.log(`   ⚠️  Attempt ${attempt} failed: ${error.message}`);
        console.log(`   🔄 Retrying in ${backoffDelay / 1000}s...`);
        await sleep(backoffDelay);
      }
    }
  }
  
  throw lastError;
}

function extractItems(url: string, html: string): CrawlResult[] {
  const $ = cheerio.load(html);
  const items: CrawlResult[] = [];

  // The "Recently Added" section is in div#archive-content
  // Featured Movies are in slider sections before it
  const archiveContent = $('#archive-content');
  
  if (!archiveContent.length) {
    console.log('⚠️  Could not find #archive-content section');
    // Fallback: process all articles but skip those in sliders
    $('article, .post, .hentry').each((_, element) => {
      const el = $(element);
      // Skip if inside a slider/carousel
      if (el.closest('.owl-carousel, .slider, [id*="slider"]').length > 0) {
        return; // skip this item
      }
      processArticle($, el, url, items);
    });
    return items;
  }

  // Only process articles within the #archive-content section
  let totalArticles = 0;
  let skippedArticles = 0;
  archiveContent.find('article, .post, .hentry').each((_, element) => {
    totalArticles++;
    const itemsBefore = items.length;
    processArticle($, $(element), url, items);
    if (items.length === itemsBefore) {
      skippedArticles++;
    }
  });

  // Always show total articles found for verification
  console.log(`   📊 Total articles in #archive-content: ${totalArticles}`);
  if (skippedArticles > 0) {
    console.log(`   ⚠️  Skipped ${skippedArticles} articles (missing title or thumbnail)`);
  }

  return items;
}

function processArticle(_$: any, el: any, url: string, items: CrawlResult[], debug = false) {
  const anchor =
    el.find('h2 a, h3 a, .entry-title a, .post-title a').first() ||
    el.find('a').first();

  const title = anchor.text().trim();
  const sourceUrl = normalizeUrl(url, anchor.attr('href')) ?? url;

  const imageEl = el.find('img').first();
  const thumb =
    imageEl.attr('data-src') ||
    imageEl.attr('data-lazy-src') ||
    imageEl.attr('src');
  const thumbnailUrl = normalizeUrl(url, thumb ?? undefined);

  const dataSpans = el.find('.data span');
  const primarySpan = dataSpans.eq(0).text().trim();
  const secondarySpan = dataSpans.eq(1).text().trim();
  const releaseText =
    secondarySpan ||
    primarySpan ||
    el.find('.release, .date, time').first().text().trim() ||
    el.find('.meta span, .details span').first().text().trim();
  const releaseDate = parseReleaseDate(releaseText);

  if (debug) {
    console.log('   🔍 Article:', { title: title || '(missing)', thumbnailUrl: thumbnailUrl || '(missing)' });
  }

  if (title && thumbnailUrl) {
    items.push({
      title,
      thumbnailUrl,
      sourceUrl,
      releaseDate,
    });
  } else if (debug) {
    console.log('   ❌ Skipped:', !title ? 'no title' : 'no thumbnail');
  }
}

function buildPageUrl(baseUrl: string, page: number): string {
  if (page <= 1) return baseUrl;
  const normalized = baseUrl.endsWith('/')
    ? baseUrl.slice(0, -1)
    : baseUrl;
  return `${normalized}/page/${page}/`;
}

async function crawl(options: CrawlOptions): Promise<CrawlResult[]> {
  const dedupMap = new Map<string, CrawlResult>();
  const checkpointInterval = 50; // Save progress every 50 pages
  const checkpointFile = options.output.replace(/\.json$/, '.checkpoint.json');
  
  for (let page = 1; page <= options.maxPages; page += 1) {
    const pageUrl = buildPageUrl(options.startUrl, page);
    console.log(`📄 Crawling page ${page}/${options.maxPages}: ${pageUrl}`);

    try {
      const html = await fetchHtml(pageUrl, options.userAgent, options.timeout, options.retries);
      const items = extractItems(pageUrl, html);
      let added = 0;

      items.forEach((item) => {
        if (!dedupMap.has(item.sourceUrl)) {
          dedupMap.set(item.sourceUrl, item);
          added += 1;
        }
      });

      console.log(
        `   ➜ Found ${items.length} entries (${added} new, ${items.length - added} duplicates skipped) | Total: ${dedupMap.size}`
      );

      if (items.length === 0) {
        console.log('   ⚠️  No items found on this page, stopping early.');
        break;
      }
      
      // Save checkpoint periodically
      if (page % checkpointInterval === 0) {
        const checkpointData = Array.from(dedupMap.values());
        fs.writeFileSync(checkpointFile, JSON.stringify(checkpointData, null, 2), 'utf8');
        console.log(`   💾 Checkpoint saved (${dedupMap.size} items) to ${checkpointFile}`);
      }
      
      // Add delay between requests (except after the last page)
      if (page < options.maxPages) {
        await sleep(options.delay);
      }
    } catch (error: any) {
      console.error(`   ⚠️  Failed to crawl ${pageUrl}:`, error.message || error);
      console.log(`   ⏭️  Skipping to next page...`);
      // Don't break, continue to next page
      await sleep(options.delay * 2); // Wait longer after an error
    }
  }

  return Array.from(dedupMap.values());
}

async function main() {
  const options = parseArgs();
  console.log('🚀 Starting b4watch crawler with options:', options);

  const results = await crawl(options);
  console.log(`✅ Completed. Total items collected: ${results.length}`);

  fs.writeFileSync(options.output, JSON.stringify(results, null, 2), 'utf8');
  console.log(`💾 Saved results to ${options.output}`);
}

main().catch((error) => {
  console.error('❌ Crawler failed:', error);
  process.exit(1);
});

