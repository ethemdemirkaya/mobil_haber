"""Read-only live audit of the Flutter source catalog.

Run in an isolated environment with requests, beautifulsoup4 and trafilatura:
  python tool/audit_news_sources.py --output docs/research/news-source-audit.json
HTML responses remain in the OS temporary directory; the report stores metrics,
URLs and short titles only. No credentials, proxy, login or challenge bypass.
"""
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import re
import statistics
import tempfile
import time
import urllib.parse
import urllib.robotparser
from pathlib import Path

import requests
from bs4 import BeautifulSoup
from lxml import etree
import trafilatura

ROOT = Path(__file__).resolve().parents[1]
UA = ('Mozilla/5.0 (Linux; Android 13; mobil_haber) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36')
SCRATCH = Path(tempfile.mkdtemp(prefix='pusula-news-audit-'))
NOW = dt.datetime.now(dt.timezone.utc)


def catalog():
    text = (ROOT / 'lib/data/models/news_source.dart').read_text(encoding='utf-8')
    blocks = re.split(r'NewsSource\(\s+id:', text)[1:]
    result = []
    for block in blocks:
        def field(name):
            return re.search(r"\b" + name + r":\s*'([^']+)'", block).group(1)
        categories = re.search(r'categoryFeeds:\s*\{(.*?)\}', block, re.S)
        result.append(dict(id=re.match(r"\s*'([^']+)'", block).group(1),
                           name=field('name'), primary=field('primaryFeed'),
                           categories=dict(re.findall(r"'([^']+)'\s*:\s*'([^']+)'",
                                                      categories.group(1))) if categories else {}))
    return result


def get(url, accept='*/*'):
    start = time.monotonic()
    info = dict(url=url)
    raw = b''
    try:
        with requests.Session() as session:
            session.max_redirects = 5
            with session.get(url, headers={'User-Agent': UA, 'Accept': accept,
                             'Accept-Language': 'tr-TR,tr;q=0.9,en;q=0.6'},
                             timeout=(6, 10), stream=True) as response:
                info.update(status=response.status_code, final_url=response.url,
                            content_type=response.headers.get('Content-Type', ''),
                            etag=bool(response.headers.get('ETag')),
                            last_modified=bool(response.headers.get('Last-Modified')))
                chunks = []
                count = 0
                for chunk in response.iter_content(65536):
                    chunks.append(chunk)
                    count += len(chunk)
                    if count > 3_000_000:
                        info['error'] = 'body_limit_3MB'
                        break
                raw = b''.join(chunks)
                info['bytes'] = len(raw)
    except requests.RequestException as error:
        info['error'] = type(error).__name__
    info['seconds'] = round(time.monotonic() - start, 2)
    return info, raw


def plain(value):
    return BeautifulSoup(value or '', 'html.parser').get_text(' ', strip=True)


def date(value):
    from email.utils import parsedate_to_datetime
    try:
        parsed = dt.datetime.fromisoformat(value.replace('Z', '+00:00'))
    except (ValueError, TypeError):
        try:
            parsed = parsedate_to_datetime(value)
        except (ValueError, TypeError, IndexError):
            return None
    return parsed.replace(tzinfo=dt.timezone.utc) if parsed.tzinfo is None else parsed


def parse_feed(raw, base):
    try:
        root = etree.fromstring(raw, parser=etree.XMLParser(recover=True, resolve_entities=False, no_network=True))
        root_name = etree.QName(root).localname
        if root_name.lower() not in ('rss', 'feed', 'rdf'):
            return [], 'not_feed:' + root_name
        nodes = root.xpath('//*[local-name()="item" or local-name()="entry"]')
        items = []
        for node in nodes:
            def texts(*names):
                for name in names:
                    matches = node.xpath('./*[local-name()=$name]', name=name)
                    if matches:
                        return ''.join(matches[0].itertext()).strip()
                return ''
            url = texts('link')
            if not url:
                links = node.xpath('./*[local-name()="link"]')
                url = next((link.get('href') for link in links
                            if link.get('href') and link.get('rel', 'alternate') == 'alternate'), '')
            if not url:
                url = texts('guid', 'id')
            published = date(texts('pubDate', 'published', 'updated', 'date'))
            items.append(dict(url=urllib.parse.urljoin(base, url), title=plain(texts('title'))[:160],
                              summary_chars=len(plain(texts('description', 'summary'))),
                              content_chars=len(plain(texts('encoded', 'content'))),
                              published=published.isoformat() if published else None))
        return items, root_name
    except Exception as error:
        return [], 'parse_error:' + type(error).__name__


def feed_probe(url):
    info, raw = get(url, 'application/rss+xml,application/atom+xml,application/xml,text/xml,*/*')
    if raw:
        capture = SCRATCH / (hashlib.sha256(url.encode()).hexdigest() + '.xml')
        capture.write_bytes(raw)
        info['scratch_feed'] = str(capture)
        try:
            etree.fromstring(raw, parser=etree.XMLParser(resolve_entities=False, no_network=True))
            info['strict_xml_valid'] = True
        except etree.XMLSyntaxError:
            info['strict_xml_valid'] = False
    items, kind = parse_feed(raw, info.get('final_url', url)) if info.get('status') == 200 else ([], '')
    dates = [date(item['published']) for item in items if item['published']]
    info.update(kind=kind, items=len(items),
                median_summary_chars=statistics.median(i['summary_chars'] for i in items) if items else 0,
                median_content_chars=statistics.median(i['content_chars'] for i in items) if items else 0,
                newest=max(dates).isoformat() if dates else None,
                age_hours=round((NOW-max(dates)).total_seconds()/3600, 1) if dates else None,
                unique_urls=len(set(i['url'] for i in items)))
    return info, items


def robots_for(url):
    origin = urllib.parse.urlsplit(url)
    robots_url = urllib.parse.urlunsplit((origin.scheme, origin.netloc, '/robots.txt', '', ''))
    info, raw = get(robots_url)
    parser = None
    if info.get('status') == 200:
        parser = urllib.robotparser.RobotFileParser()
        parser.parse(raw.decode('utf-8', errors='replace').splitlines())
    return info, parser


def json_articles(soup):
    found = []
    def walk(value):
        if isinstance(value, list):
            for child in value:
                walk(child)
        elif isinstance(value, dict):
            types = value.get('@type', [])
            types = [types] if isinstance(types, str) else types
            if any(t in ('Article', 'NewsArticle', 'ReportageNewsArticle', 'BlogPosting', 'LiveBlogPosting') for t in types):
                found.append(value)
            for child in value.values():
                if isinstance(child, (dict, list)):
                    walk(child)
    for tag in soup.select('script[type="application/ld+json"]'):
        try:
            walk(json.loads(tag.string or tag.get_text()))
        except (ValueError, TypeError):
            pass
    return found


def detail_probe(item, robots):
    url = item['url']
    info = dict(url=url, rss_summary_chars=item['summary_chars'],
                rss_content_chars=item['content_chars'])
    if not url.startswith(('https://', 'http://')):
        return dict(info, skipped='invalid_url')
    robot_info, parser = robots
    info['robots_status'] = robot_info.get('status', robot_info.get('error'))
    if robot_info.get('status') in (401, 403):
        return dict(info, skipped='robots_unavailable_access_denied')
    if parser and not parser.can_fetch('*', url):
        return dict(info, skipped='robots_disallow')
    fetched, raw = get(url, 'text/html,application/xhtml+xml')
    info.update(fetched)
    if info.get('status') != 200:
        return info
    key = hashlib.sha256(url.encode()).hexdigest()
    html_path = SCRATCH / (key + '.html')
    html_path.write_bytes(raw)
    info['scratch_html'] = str(html_path)
    soup = BeautifulSoup(raw, 'html.parser')
    articles = json_articles(soup)
    info['jsonld_article_nodes'] = len(articles)
    info['jsonld_body_chars'] = max((len(plain(str(a.get('articleBody', '')))) for a in articles), default=0)
    info['jsonld_paywall'] = any(a.get('isAccessibleForFree') in (False, 'False', 'false') for a in articles)
    info['article_elements'] = len(soup.select('article'))
    info['itemprop_body_elements'] = len(soup.select('[itemprop="articleBody"]'))
    info['has_og_image'] = bool(soup.select_one('meta[property="og:image"][content]'))
    info['has_jsonld_image'] = any(bool(article.get('image')) for article in articles)
    info['canonical'] = next((tag.get('href') for tag in soup.select('link[rel="canonical"]')), None)
    info['amphtml'] = next((tag.get('href') for tag in soup.select('link[rel="amphtml"]')), None)
    extracted = trafilatura.extract(raw, url=info.get('final_url', url), include_comments=False,
                                  include_tables=True, favor_precision=True, with_metadata=False)
    info['trafilatura_chars'] = len(extracted or '')
    info['trafilatura_paragraphs'] = len((extracted or '').splitlines()) if extracted else 0
    return info


def audit(source, categories, details):
    primary, items = feed_probe(source['primary'])
    result = dict(source=source, primary=primary, categories=[], details=[])
    if categories:
        for url in sorted(set(source['categories'].values()) - {source['primary']}):
            tested, _ = feed_probe(url)
            tested['category_ids'] = [key for key, value in source['categories'].items() if value == url]
            result['categories'].append(tested)
    if details and items:
        seen = set()
        for item in items:
            if item['url'] in seen:
                continue
            seen.add(item['url'])
            result['details'].append(detail_probe(item, robots_for(item['url'])))
            if len(seen) >= details:
                break
    print(f"{source['id']}: HTTP {primary.get('status', primary.get('error'))}, {len(items)} items, "
          f"{len(result['categories'])} category feeds, {len(result['details'])} detail probes", flush=True)
    return result


def main():
    cli = argparse.ArgumentParser()
    cli.add_argument('--output', required=True)
    cli.add_argument('--categories', action='store_true')
    cli.add_argument('--details', type=int, default=2)
    cli.add_argument('--workers', type=int, default=6)
    args = cli.parse_args()
    sources = catalog()
    print(f'{len(sources)} sources; scratch HTML: {SCRATCH}', flush=True)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        rows = list(pool.map(lambda source: audit(source, args.categories, args.details), sources))
    report = dict(checked_at=NOW.isoformat(), user_agent=UA, details_per_source=args.details,
                  categories_checked=args.categories, scratch_directory=str(SCRATCH),
                  trafilatura_version=trafilatura.__version__, results=rows)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    print(f'Wrote {output}', flush=True)


if __name__ == '__main__':
    main()
