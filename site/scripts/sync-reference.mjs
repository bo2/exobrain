// Renders the seed's concept domains into the site as its Reference section.
// Runs before every dev and build; the output directory is gitignored, so the
// pages are always the current text of knowledge/, never a stale copy.
import { mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, posix } from 'node:path';
import { fileURLToPath } from 'node:url';

const site = join(dirname(fileURLToPath(import.meta.url)), '..');
const repo = join(site, '..');
const out = join(site, 'src/content/docs/reference');
const REPO_URL = 'https://github.com/bo2/exobrain';

// Site section → the knowledge domain it renders.
const SECTIONS = {
  exobrain: 'knowledge/exobrain',
  'harness-engineering': 'knowledge/harness-engineering',
};

// The shim ledger stays on GitHub only: its example marker line would read as
// live transitional code to validate-exobrain.sh, which scans the whole tree.
const SKIP = new Set(['knowledge/exobrain/compat.md']);

// Every rendered source file and the site URL it lands at.
const pages = new Map();
for (const [section, dir] of Object.entries(SECTIONS)) {
  for (const file of readdirSync(join(repo, dir)).filter((f) => f.endsWith('.md'))) {
    if (SKIP.has(`${dir}/${file}`)) continue;
    const slug = file === 'README.md' ? '' : `${file.slice(0, -3)}/`;
    pages.set(`${dir}/${file}`, `/reference/${section}/${slug}`);
  }
}

// A relative link resolves against its source file: to the rendered page when
// there is one, otherwise to the file or directory on GitHub.
function rewriteLink(href, source) {
  if (/^([a-z][a-z0-9+.-]*:|#|\/)/i.test(href)) return href;
  const [path, anchor] = href.split('#');
  const hash = anchor ? `#${anchor}` : '';
  const target = posix.normalize(posix.join(posix.dirname(source), path));
  if (pages.has(target)) return pages.get(target) + hash;
  const isFile = /\.[a-z0-9]+$/i.test(path);
  return `${REPO_URL}/${isFile ? 'blob' : 'tree'}/main/${target.replace(/\/$/, '')}${hash}`;
}

// Rewrite links and escape stray <placeholders> in prose, leaving code alone.
function transformProse(text, source) {
  return text
    .split(/(```[\s\S]*?```|`[^`\n]*`)/)
    .map((part, i) =>
      i % 2
        ? part
        : part
            .replace(/\]\(([^)\s]+)\)/g, (_, href) => `](${rewriteLink(href, source)})`)
            .replace(/<([A-Za-z][^>\s]*)>/g, '&lt;$1&gt;'),
    )
    .join('');
}

const yaml = (s) => JSON.stringify(s);

rmSync(out, { recursive: true, force: true });
for (const [source, url] of pages) {
  let body = readFileSync(join(repo, source), 'utf8');
  let summary = '';
  const fm = body.match(/^---\n([\s\S]*?)\n---\n/);
  if (fm) {
    summary = (fm[1].match(/^summary:\s*(.+)$/m) || [])[1] || '';
    body = body.slice(fm[0].length);
  }
  const h1 = body.match(/^# (.+)$/m);
  const title = h1 ? h1[1].trim() : source;
  if (h1) body = body.replace(h1[0], '');
  const isIndex = source.endsWith('/README.md');

  const frontmatter = [
    '---',
    `title: ${yaml(title)}`,
    summary && `description: ${yaml(summary)}`,
    `editUrl: ${yaml(`${REPO_URL}/edit/main/${source}`)}`,
    isIndex && 'sidebar:\n  label: Overview\n  order: 0',
    '---',
  ].filter(Boolean);

  const provenance = `*Rendered from [\`${source}\`](${REPO_URL}/blob/main/${source}) — the text an agent reads.*`;
  const [section, name] = url.replace(/^\/reference\//, '').split('/');
  const dest = join(out, section, `${name || 'index'}.md`);
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, `${frontmatter.join('\n')}\n\n${provenance}\n\n${transformProse(body.trim(), source)}\n`);
}
console.log(`sync-reference: rendered ${pages.size} pages`);
