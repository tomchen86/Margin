# Margin（原型）

> 這是先行驗證用的原型，只放在 `prototype` 分支，不會合併進 main。
> 正式的程式會照 `docs/proposals/` 的提案，一個 issue 一個 PR 重新做進 repo。

極簡、原生感的 iOS Markdown＋HTML 閱讀器（iOS 26+，SwiftUI）。
沒有 Swift 套件依賴；第三方只有打包在 `Margin/Web/` 的 JavaScript 函式庫，授權見 `THIRD_PARTY_NOTICES.md`。

設計參考 MarkEdit：內容交給 WebKit 顯示，其他都用系統原生元件。
檔案瀏覽、最近項目、iCloud 交給系統的 `DocumentGroup`，App 本身不做檔案管理。

## 檔案

| 檔案 | 用途 |
|---|---|
| `Margin/MarginApp.swift` | 進入點，`DocumentGroup(viewing:)` |
| `Margin/DocumentView.swift` | 閱讀畫面、選單（尋找／原始碼／分享）、資料夾授權按鈕 |
| `Margin/ReaderModel.swift` | `WebPage` 設定、連結政策（網址交給 Safari） |
| `Margin/LocalFiles.swift` | `margin://` scheme：`margin://file/` 讀使用者的檔案，`margin://app/` 讀 App 自帶的腳本、樣式、字型；Markdown 頁面的 CSP |
| `Margin/Web/render.js` | 在頁面裡用 markdown-it 把 Markdown 轉成 HTML，加上數學（`$…$`、`$$…$$`）、待辦清單、標題錨點 |
| `Margin/Web/` 其他檔案 | 打包的第三方檔案：markdown-it 15.0.3、markdown-it-footnote 4.0.0、KaTeX 0.19.1（含 woff2 字型）、highlight.js 11.12.0（MIT／BSD-3） |
| `Margin/MarkdownRenderer.swift` | 舊的 Foundation 解析器，已不再使用（只剩 `HTML.escape`） |
| `Margin/FolderAccess.swift` | 記住使用者授權的資料夾（security-scoped bookmark） |
| `Margin/TextDecoding.swift` | UTF-8 以外的編碼偵測（Big5、GB18030、Shift-JIS） |
| `Margin/Reader.css` | 仿 iOS 系統字型、顏色、深色模式的閱讀樣式 |
| `Margin/SandboxSimulation.swift` | 只在模擬器生效，用來模擬真機的沙盒限制 |
| `Samples/Notes/` | 測試用範例檔 |

## 周邊圖片怎麼讀

從「檔案」App 打開一份文件時，iOS 只給 App 讀那一個檔案的權限。
旁邊的 `images/a.png`、`../assets/b.png` 都讀不到。

1. 頁面要的檔案都經過 `margin://`，由 App 自己讀取，WebView 的程序不需要權限。
2. 讀不到時，底部會出現「允許讀取「資料夾」來顯示圖片」按鈕，檔案選擇器會直接開在那個資料夾。
3. 授權結果會存成 bookmark，之後同一個資料夾裡的所有文件都能直接顯示圖片，重開 App 也一樣。

## 執行

用 Xcode 26 打開 `Margin.xcodeproj`，選一台模擬器後按 Run。

### 裝到 iPhone

1. iPhone 要是 iOS 26 以上，並在「設定 → 隱私權與安全性 → 開發者模式」打開（第一次會要求重新開機）。
2. Xcode → Settings → Accounts 加入你的 Apple 帳號。
3. 點專案的 Margin target → Signing & Capabilities：Team 選你的帳號，Bundle Identifier 改成你自己的，例如 `com.你的名字.Margin`（`dev.local.Margin` 可能已被別人用掉）。
4. 用線接上 iPhone（或同一個 Wi-Fi 下配對過），在上方裝置選單選它，按 Run。
5. 第一次開啟會被擋：到「設定 → 一般 → VPN 與裝置管理」信任你的開發者帳號。

用免費 Apple 帳號簽的 App，7 天後就打不開，要重新 Run 一次；加入付費的 Apple Developer Program 則是一年。

測試檔在 `Samples/Notes/`，可以用 AirDrop 或 iCloud Drive 傳到 iPhone 的「檔案」App，整個 `Notes` 資料夾一起放，才測得到旁邊資料夾的圖片。

模擬器不會強制執行沙盒限制，旁邊的檔案一定讀得到。
想在模擬器測授權流程，啟動時加上參數 `-SimulateSandbox`（Edit Scheme → Run → Arguments）。
