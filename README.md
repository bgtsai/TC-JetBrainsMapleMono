# TC-JetBrainsMapleMono

自動監控 [SpaceTimee/Fusion-JetBrainsMapleMono](https://github.com/SpaceTimee/Fusion-JetBrainsMapleMono) 的更新，將其發布的每一種字重/組合自動轉換成簡轉繁字型並發布——字型內部編碼對應仍是簡體字，但顯示出來的是繁體字圖。

## 運作方式

透過 GitHub Actions 排程，每天台灣時間晚上 21:00 檢查一次上游是否有新的 release 或新的 commit：

- 偵測到更新 → 下載該版本全部 16 種組合（Nerd Font / CN Narrow / 連字 / Hinting 四個開關的排列組合）→ 用 [TCFontCreator](https://github.com/bgtsai/TCFontCreator) 逐字重執行兩階段簡轉繁處理（一簡多繁+臺灣詞彙動態匹配，再補充字型本身簡繁異體）→ 全部組合齊全後發布
- 正式 release 觸發的版本發布在 [`latest`](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases/tag/latest) tag，commit 觸發（尚未出正式 release 的開發版）發布在 [`pre`](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases/tag/pre) tag
- 每次轉換都會自動抓 [TCFontCreator 作者維護的保留字清單](https://github.com/bgtsai/TCFontCreator/blob/main/main/datas/UsedChar_Author.txt)最新版，清單上的字一定會保留；抓不到清單時這次轉換會直接失敗，不會用舊清單產出字型
- 具備斷點續傳機制：處理中斷或失敗時，下次執行只會重跑尚未完成的組合，不會整批重來
- 除了中文常用字、日文假名/常用漢字/人名用漢字、韓文常用音節，字型的一簡多繁處理也涵蓋拉丁文擴充、希臘文、西里爾文與一般符號類（標點、箭頭、數學符號、製表符等），這些字元轉換後不會被誤刪
- 轉換過程不會把彎引號（`''`、`""`）替換成中文直角引號（`「」`、`『』`）——查證確認這種替換並非源自 [OpenCC](https://github.com/BYVoid/OpenCC) 官方詞庫，是上游工具額外加入的客製規則，已在 [TCFontCreator](https://github.com/bgtsai/TCFontCreator) 移除，引號符號本身維持原樣

## 執行狀態 RSS

每次排程執行都會在下面這個 RSS 新增一則（保留最近 20 則）：

https://raw.githubusercontent.com/bgtsai/TC-JetBrainsMapleMono/main/convert_status.xml

🟢 上游無更新 · 🔵 已轉換發布 · 🔴 轉換失敗（下次執行會接續處理缺少的組合）。

## 下載使用

**[Releases 下載頁](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases)**

發布檔案按 `TC-JBMM-{4位代碼}.zip` 格式命名（`JBMM` 是 JetBrainsMapleMono 的縮寫）。4 位代碼依序對應 4 個特性開關，**1 = 啟用、0 = 停用**：

| 位數 | 特性 | 說明 |
|---|---|---|
| 第1位 | NF（Nerd Font） | 為部分開發工具、命令列終端機、程式碼編輯器等提供圖示支援（會導致字型檔案體積略微增大） |
| 第2位 | NR（CN Narrow） | 縮小中日字型間距（會導致中英文/日英文不再 2:1 寬完美對齊） |
| 第3位 | NL（No Ligatures） | 1 表示停用連字；0 表示保留連字 |
| 第4位 | HT（Hinted） | 使字型在低解析度螢幕上（≤1080P）的渲染更加均勻（可能會導致字型在高解析度螢幕上的渲染略微模糊） |

**完整對照表**（16 種組合）：

| 代碼 | 對應組合 | 代碼 | 對應組合 |
|---|---|---|---|
| `1111` | NF-NR-NL-HT | `0111` | XX-NR-NL-HT |
| `1110` | NF-NR-NL-XX | `0110` | XX-NR-NL-XX |
| `1101` | NF-NR-XX-HT | `0101` | XX-NR-XX-HT |
| `1100` | NF-NR-XX-XX | `0100` | XX-NR-XX-XX |
| `1011` | NF-XX-NL-HT | `0011` | XX-XX-NL-HT |
| `1010` | NF-XX-NL-XX | `0010` | XX-XX-NL-XX |
| `1001` | NF-XX-XX-HT | `0001` | XX-XX-XX-HT |
| `1000` | NF-XX-XX-XX | `0000` | XX-XX-XX-XX |

如果不清楚如何選擇，建議下載 `TC-JBMM-0000.zip`（全部特性關閉的基礎版本）。

每個組合的字型內部名稱（Family/PostScript name）與壓縮包內的 `.ttf` 檔名，都帶有相同的 4 位代碼標記（如 `TC_JBMM_1111_Bold.ttf`），三者（zip 檔名／字型檔名／字型內部名稱）保證一致，不同組合之間也不會互相衝突，可以同時安裝多個組合並存使用。

## Windows 一鍵安裝／更新字型

字型會隨上游改版或保留字調整而推出新版。手動更新要先移除舊字型、下載、解壓、再一個個安裝，很繁瑣。如果你常常需要更新，可以用這個工具一鍵完成：

**[下載 TC-JBMM-Updater.zip](https://github.com/bgtsai/TC-JetBrainsMapleMono/releases/download/updater/TC-JBMM-Updater.zip)**（Windows 10／11）

### 它會做什麼

按一下，工具會依序：

1. 讀取設定檔，確認你要裝哪些代碼、哪些字重
2. 查詢 GitHub 上的最新版本；跟上次安裝的版本與設定都一樣時，直接顯示「已是最新」，不重複下載
3. 下載需要的 zip（每個檔案都有逾時與自動重試，並核對檔案大小）並解壓
4. 移除這些代碼在 Windows 裡的舊字型（系統與個人兩個字型資料夾都會清）
5. 安裝新字型給這台電腦的所有使用者，並通知系統字型已更新

### 使用步驟

1. 下載上面的 zip，解壓到任意資料夾（例如 `D:\Tools\TC-JBMM-Updater`），三個檔案要放在一起：
   - `更新TC_JBMM字型.bat`：雙擊執行的入口
   - `Update-TCJBMM.ps1`：工具本體
   - `TC-JBMM-Updater.ini`：設定檔
2. 用記事本打開 `TC-JBMM-Updater.ini`，改成你要的代碼與字重（說明見下一節）
3. 雙擊 `更新TC_JBMM字型.bat`，Windows 跳出「使用者帳戶控制」時按「是」（安裝給所有使用者需要系統管理員權限）
4. 等待完成。之後想更新時，再雙擊一次就好

### 設定檔說明

```ini
[General]
; 要抓哪一版：latest＝正式版（建議）；pre＝開發版（更新頻繁）
Tag = latest

[Fonts]
; 格式：代碼 = 字重清單（用逗號分隔），* 代表全部 16 個字重
1011 = *
1111 = Regular, Bold, Italic, BoldItalic
```

- **`[General]` 區段的 `Tag`**：`latest` 是正式版，跟著上游正式 release 更新，建議一般使用。`pre` 是開發版，上游每次 commit 都會更新，比較頻繁。
- **`[Fonts]` 區段**：每行一組，`代碼 = 字重`。
  - 代碼就是上面「下載使用」一節的 4 位數代碼（例如 `1011`）。
  - 字重可以寫 `*`（全部 16 個），也可以列出要的字重，用逗號分隔，大小寫不拘。
  - 可用的字重：`Thin`、`ThinItalic`、`ExtraLight`、`ExtraLightItalic`、`Light`、`LightItalic`、`Regular`、`Italic`、`Medium`、`MediumItalic`、`SemiBold`、`SemiBoldItalic`、`Bold`、`BoldItalic`、`ExtraBold`、`ExtraBoldItalic`
- 分號 `;` 或井號 `#` 開頭的行是註解。

### 常見設定範例

| 想要的效果 | 寫法 |
|---|---|
| 整組全部安裝 | `1011 = *` |
| 只裝常用的 4 個字重（一般、粗體、斜體、粗斜體） | `1111 = Regular, Bold, Italic, BoldItalic` |
| 只裝單一字重 | `0000 = Regular` |
| 同時裝好幾組 | 每組各寫一行，例如 `1011 = *` 和 `0000 = Regular` |
| 暫時不要裝某一組 | 在那一行前面加 `;` 註解掉 |

設定改了之後，下次執行就會照新的設定重裝，不必等字型出新版。如果某一組裡拿掉了幾個字重，那幾個字重會被移除。

設定檔裡**沒有列出**的代碼，工具不會去動它。例如你以前手動裝過 `0000`，設定檔沒寫 `0000`，它就會保持原樣。

設定檔寫錯時（例如代碼不是 4 位、字重拼錯），工具會列出是第幾行、哪裡錯，並停下來，不會裝到一半。

### 進階用法

在 `更新TC_JBMM字型.bat` 後面加參數（例如建一個捷徑，在「目標」欄位後面加）：

| 參數 | 作用 |
|---|---|
| `-Force` | 版本沒變也強制重新安裝 |
| `-Tag pre` | 這次改抓開發版（優先於設定檔裡的 `Tag`） |
| `-Config 路徑` | 改用另一份設定檔 |

### 常見問題

- **為什麼要按「是」？** 安裝字型給所有使用者，必須寫入 `C:\Windows\Fonts`，Windows 規定這需要系統管理員權限。這個確認視窗是 Windows 的安全機制，沒有辦法跳過。
- **顯示「有舊字型正在被程式使用」？** 有程式（例如開著的編輯器）正在使用舊字型，檔案被鎖住刪不掉。新字型已經裝好了，舊檔案會在重新開機後自動刪除。
- **裝好了，編輯器卻還是舊字型？** 已經開著的程式要重新啟動，才會讀到新字型。
- **有裝 Adobe Acrobat？** 工具在安裝期間會暫停 Acrobat 的常駐程式（acrotray），裝完再恢復，避免它收到字型變更通知時叫起 Distiller，跳出「無法建立暫存資料夾」的錯誤。
- **電腦上的狀態記錄在哪裡？** `C:\ProgramData\TC_JBMM_Updater\`，刪掉的話，下次執行就會重新安裝。

## 想自己合成其他字型？

本專案的簡轉繁處理，是透過 [bgtsai/TCFontCreator](https://github.com/bgtsai/TCFontCreator) 這個工具完成的。如果你想把其他字型也轉換成簡轉繁版本（不限於 JetBrainsMapleMono），可以直接下載該工具自己動手：工具提供圖形介面，也支援命令列操作；如果轉換後發現有想保留、但被誤刪的字（例如特定日文/韓文用字或符號），可以透過工具的 `datas/UsedChar_Custom.txt` 自訂保留清單自行補上，不需要改程式碼。工具另有作者維護的保留字清單，勾選「線上更新保留字清單」（預設勾選）就會在每次轉換前自動更新，詳見該工具 README 的「線上更新保留字清單」一節。

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
