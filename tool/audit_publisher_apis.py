"""Read-only publisher API research; persists metrics, never article bodies.

Requires requirements-news-audit.txt and the previous news-source-audit.json.
Uses public HTML and declared GET endpoints, without login, API keys or bypass.
This is an investigation tool, not a production adapter or a coverage test.
"""
import datetime as dt
import json
from pathlib import Path
from urllib.parse import urljoin

from bs4 import BeautifulSoup
from audit_news_sources import ROOT, get, plain


def json_get(url):
    info, raw = get(url, 'application/json')
    try:
        value = json.loads(raw)
    except (ValueError, UnicodeError):
        value = None
    return info, value


def descendants(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from descendants(child)
    elif isinstance(value, list):
        for child in value:
            yield from descendants(child)


def wp_probe(base):
    result = {'kind': 'wordpress_public_api', 'base': base, 'pages': []}
    ids = []
    for page in (1, 2):
        info, posts = json_get(base + '?per_page=2&page=' + str(page))
        items = posts if isinstance(posts, list) else []
        info['items'] = [dict(id=p.get('id'), link=p.get('link'),
                              body_chars=len(plain(p.get('content', {}).get('rendered', ''))),
                              has_date_gmt=bool(p.get('date_gmt')),
                              has_modified_gmt=bool(p.get('modified_gmt')),
                              featured_media=p.get('featured_media'), author=p.get('author'),
                              categories=p.get('categories')) for p in items]
        result['pages'].append(info)
        ids.extend(p.get('id') for p in items)
        if not items:
            break
    result['distinct_ids'] = len(set(ids))
    if ids:
        info, post = json_get(base + '/' + str(ids[0]) + '?_embed=wp:featuredmedia,author')
        if isinstance(post, dict):
            info.update(body_chars=len(plain(post.get('content', {}).get('rendered', ''))),
                        embedded_relations=list(post.get('_embedded', {})))
        result['detail'] = info
    return result


def ht_probe(url):
    result = {'kind': 'publisher_category_api', 'pages': []}
    for _ in range(2):
        info, value = json_get(url)
        nodes = list(descendants(value))
        posts = {n['newsId']: n for n in nodes if 'newsId' in n and 'title' in n}
        next_urls = [n['next'] for n in nodes if isinstance(n.get('next'), str)]
        info.update(distinct_news=len(posts),
                    with_spot=sum(bool(n.get('spot')) for n in posts.values()),
                    with_image=sum(bool(n.get('image')) for n in posts.values()),
                    news_keys=sorted(set(k for n in posts.values() for k in n)),
                    next=next_urls[0] if next_urls else None)
        result['pages'].append(info)
        if not next_urls or not next_urls[0].startswith('https://htapi.haberturk.com/'):
            break
        url = next_urls[0]
    result['detail_api_verified'] = False
    return result


def embedded_probe(source, url):
    info, raw = get(url, 'text/html')
    soup = BeautifulSoup(raw, 'html.parser')
    info.update(kind='embedded_structured_data', source=source)
    if source == 'donanimhaber':
        state = json.loads(soup.select_one('#ng-state').get_text())
        transfer = next(v for v in state.values() if isinstance(v, dict)
                        and 'News/GetNewsDetailPage' in str(v.get('u')))
        news = transfer['b']['Data']['NewsDetailData']['NewsDetail']
        info.update(embedded_api_url=transfer['u'], embedded_status=transfer['s'],
                    direct_api_request_verified=False,
                    body_chars=len(plain(news.get('RawContent', ''))),
                    content_list_chars=len(news.get('ContentList', '')),
                    image_count=len(news.get('ContentImages', [])),
                    fields=list(news))
    elif source == 'bbcturkce':
        state = json.loads(soup.select_one('#__NEXT_DATA__').get_text())
        page = state['props']['pageProps']['pageData']
        texts = [n['text'] for n in descendants(page['content']) if isinstance(n.get('text'), str)]
        info.update(page_data_fields=list(page), text_nodes=len(texts),
                    text_node_chars=sum(len(t) for t in texts),
                    note='Text-node total may include headings/captions and is not a completeness metric.')
    elif source == 'euronews':
        text = soup.select_one('#euronews-initial-server-data').get_text()
        state = json.loads(text[text.index('({') + 1:text.rfind('})') + 1])
        article = state['entities']['article']
        info.update(article_fields=list(article),
                    long_text_fields={k: len(plain(v)) for k, v in article.items()
                                      if isinstance(v, str) and len(v) > 400})
    return info


def main():
    original = json.loads((ROOT / 'docs/research/news-source-audit.json').read_text(encoding='utf-8'))
    inventory = []
    samples = {}
    for row in original['results']:
        details = row.get('details', [])
        if not details:
            continue
        detail = details[0]
        path = Path(detail.get('scratch_html', ''))
        if not path.is_file():
            continue
        soup = BeautifulSoup(path.read_bytes(), 'html.parser')
        source = row['source']['id']
        samples[source] = detail['url']
        inventory.append(dict(source=source, url=detail['url'],
                              json_alternates=[x.get('href') for x in soup.select('link[href]')
                                               if x.get('type') == 'application/json'],
                              wp_roots=[x.get('href') for x in soup.select('link[href]')
                                        if 'https://api.w.org/' in x.get('rel', [])],
                              embedded_ids=[x['id'] for x in soup.select('script[id]')
                                            if x['id'] in ['__NEXT_DATA__', 'ng-state',
                                                           'euronews-initial-server-data']]))
    report = dict(checked_at=dt.datetime.now(dt.timezone.utc).isoformat(),
                  method='Public unauthenticated GET; HTML/script inspection, not browser network capture.',
                  discovery_inventory=inventory, live_results=[])
    for base in ['https://www.diken.com.tr/wp-json/wp/v2/posts',
                 'https://medyascope.tv/wp-json/wp/v2/posts',
                 'https://shiftdelete.net/wp-json/wp/v2/posts']:
        report['live_results'].append(wp_probe(base))
    report['live_results'].append(ht_probe('https://htapi.haberturk.com/api/v1/haber/kategori/ht/gundem'))
    for source in ['donanimhaber', 'bbcturkce', 'euronews']:
        try:
            report['live_results'].append(embedded_probe(source, samples[source]))
        except (ValueError, KeyError, AttributeError, StopIteration) as error:
            report['live_results'].append(dict(source=source, error=type(error).__name__))
    info, raw = get('https://apiv2.sozcu.com.tr/')
    soup = BeautifulSoup(raw, 'html.parser')
    info['declared_docs'] = []
    for link in soup.select('a[href]'):
        url = urljoin(info['url'], link['href'])
        if url.startswith('https://apiv2.sozcu.com.tr/swagger-'):
            metadata, _ = get(url)
            info['declared_docs'].append(metadata)
    report['live_results'].append(info)
    output = ROOT / 'docs/research/publisher-api-audit.json'
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({'report': str(output), 'discovered_pages': len(inventory),
                      'live_result_groups': len(report['live_results'])}))


if __name__ == '__main__':
    main()
