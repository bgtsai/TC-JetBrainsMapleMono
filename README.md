# TC-JetBrainsMapleMono

自動監控 [SpaceTimee/Fusion-JetBrainsMapleMono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono) 的更新，將其發布的每一種字重/組合自動轉換成簡轉繁字型並發布——字型內部編碼對應仍是簡體字，但顯示出來的是繁體字圖。

## 運作方式

透過 GitHub Actions 排程，每 30 分鐘檢查一次上游是否有新的 release 或新的 commit：

- 偵測到更新 → 下載該版本全部 16 種組合（Nerd Font / CN Narrow / 連字 / Hinting 四個開關的排列組合）→ 用 [TCFontCreator](https://github.com/bgtsai/TCFontCreator) 逐字重執行兩階段簡轉繁處理（一簡多繁+臺灣詞彙動態匹配，再補充字型本身簡繁異體）→ 全部組合齊全後發布
- 正式 release 觸發的版本發布在 [`latest`](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases/tag/latest) tag，commit 觸發（尚未出正式 release 的開發版）發布在 [`pre`](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases/tag/pre) tag
- 具備斷點續傳機制：處理中斷或失敗時，下次執行只會重跑尚未完成的組合，不會整批重來

## 下載使用

**[Releases 下載頁](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases)**

發布檔案按 `TC-JBMM-{NF/XX}-{NR/XX}-{NL/XX}-{HT/XX}.zip` 格式命名（`JBMM` 是 JetBrainsMapleMono 的縮寫）：

1. `XX`：佔位符，表示該字型沒有增加這項特性
2. `NF`：Nerd Font，為部分開發工具、命令列終端機、程式碼編輯器等提供圖示支援（會導致字型檔案體積略微增大）
3. `NR`：CN Narrow，縮小中日字型間距（會導致中英文/日英文不再 2:1 寬完美對齊）
4. `NL`：No Ligatures，停用連字
5. `HT`：Hinted，使字型在低解析度螢幕上（≤1080P）的渲染更加均勻（可能會導致字型在高解析度螢幕上的渲染略微模糊）

如果不清楚如何選擇，建議下載 `TC-JBMM-XX-XX-XX-XX.zip`。

每個組合的字型內部名稱（Family/PostScript name）都帶有組合標記（如 `TC_JBMM_NF-NR-NL-HT_Bold`），不同組合之間不會互相衝突，可以同時安裝多個組合並存使用。

## 想自己合成其他字型？

本專案的簡轉繁處理，是透過 [bgtsai/TCFontCreator](https://github.com/bgtsai/TCFontCreator) 這個工具完成的。如果你想把其他字型也轉換成簡轉繁版本（不限於 JetBrainsMapleMono），可以直接下載該工具自己動手：工具提供圖形介面，也支援命令列操作；如果轉換後發現有想保留、但被誤刪的字（例如特定日文/韓文用字），可以透過工具的 `datas/UsedChar_Custom.txt` 自訂保留清單自行補上，不需要改程式碼。

## 致謝與引用資源

本專案是純粹的下游自動化加工，實際的字型合成與簡繁轉換技術均來自以下專案：

- **[SpaceTimee/Fusion-JetBrainsMapleMono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono)** —— 本專案監控與加工的直接上游，將 JetBrains Mono 與 Maple Mono 合成為單一字型，並設計了完整的 GitHub Actions 自動化偵測/合成/發布流程，本專案的自動化架構設計直接參考自此專案
- **[JetBrains Mono](https://github.com/JetBrains/JetBrainsMono)** —— Fusion-JetBrainsMapleMono 合成所用的底層字型之一
- **[Maple Mono](https://github.com/subframe7536/maple-font)** —— Fusion-JetBrainsMapleMono 合成所用的底層字型之一
- **[GuiWonder/TCFontCreator](https://github.com/GuiWonder/TCFontCreator)**（本專案實際使用的是 [bgtsai/TCFontCreator](https://github.com/bgtsai/TCFontCreator) 修復版）—— 本專案用於簡轉繁處理的核心工具
- **[Ayaka／《正确实现简转繁字体》](https://ayaka.shn.hk/s2tfont/)** —— TCFontCreator「一簡多繁」處理方式所依據的核心方法論
- **[caryll/otfcc](https://github.com/caryll/otfcc)** —— 字型處理過程中實際執行讀寫的核心引擎

## 授權

本專案產出的字型是對 [Fusion-JetBrainsMapleMono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono) 的再次衍生（簡轉繁處理），授權為 **[SIL Open Font License 1.1](https://openfontlicense.org)**，與底層字型完全一致——OFL 明確規定衍生作品必須沿用同一份授權，不得改用其他授權方式。

完整授權文字見本 repo 的 [OFL.txt](OFL.txt)，著作權聲明依 OFL 慣例逐層疊加：

```
Copyright 2020 The JetBrains Mono Project Authors (https://github.com/JetBrains/JetBrainsMono)
Copyright 2022 The Maple Mono Project Authors (https://github.com/subframe7536/maple-font)
Copyright 2025 Space Time (https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono)
Copyright 2026 bgtsai (https://github.com/bgtsai/TC-JetBrainsMapleMono)
```

依 OFL 條款，字型（含衍生作品）不得單獨販售，但可以與其他軟體一起授權、嵌入、重新散布，前提是不使用任何被保留的字型名稱（Reserved Font Name）。
