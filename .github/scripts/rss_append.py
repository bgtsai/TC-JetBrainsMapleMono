#!/usr/bin/env python3
"""在狀態 RSS 檔最前面加一則項目，只保留最近 20 則（格式比照 browser-tools/route-rain）。

環境變數：RSS_FILE、CHANNEL_TITLE、CHANNEL_DESC、CHANNEL_LINK、
          ITEM_TITLE、ITEM_DESC（每行一段，會轉成 <br>）、ITEM_GUID
用真正的 XML 解析器讀舊檔，不用逐行文字比對（多行內容容易漏）。
"""
import email.utils
import html
import os
import xml.etree.ElementTree as ET

rss_file = os.environ["RSS_FILE"]
title = os.environ["ITEM_TITLE"]
desc = "<br>\n".join(html.escape(l) for l in os.environ["ITEM_DESC"].strip("\n").split("\n"))
pub = email.utils.formatdate(usegmt=False).replace("-0000", "+0000")
guid = os.environ["ITEM_GUID"]

items = []
if os.path.exists(rss_file):
    try:
        ch = ET.parse(rss_file).getroot().find("channel")
        for it in (ch.findall("item") if ch is not None else []):
            items.append(tuple(it.findtext(k, default="") for k in ("title", "description", "pubDate", "guid")))
    except ET.ParseError:
        items = []  # 舊檔壞掉就當沒有歷史，不讓回報本身失敗
items = [(title, desc, pub, guid)] + [i for i in items if i[3] != guid]
items = items[:20]

out = ['<?xml version="1.0" encoding="UTF-8"?>', '<rss version="2.0"><channel>',
       f'<title>{html.escape(os.environ["CHANNEL_TITLE"])}</title>',
       f'<description>{html.escape(os.environ["CHANNEL_DESC"])}</description>',
       f'<link>{html.escape(os.environ["CHANNEL_LINK"])}</link>']
for t, d, p, g in items:
    out.append(f'<item><title>{html.escape(t, quote=False)}</title>'
               f'<description><![CDATA[{d}]]></description>'
               f'<pubDate>{p}</pubDate><guid isPermaLink="false">{html.escape(g)}</guid></item>')
out.append('</channel></rss>')
os.makedirs(os.path.dirname(os.path.abspath(rss_file)), exist_ok=True)
with open(rss_file, "w", encoding="utf-8") as f:
    f.write("\n".join(out) + "\n")
print(f"已寫入 {rss_file}：{title}")
