# REDAgent
REDAgent 視窗化修補程式

本儲存庫包含一個 Batch/PowerShell 混合腳本（patch-window-mode.bat），專門用於修改 REDAgent.exe，強制使其以「視窗模式」執行。

⚠️ 免責聲明與警告

請自行承擔使用風險。

修改執行檔可能會違反軟體的服務條款 (ToS) 或終端使用者授權合約 (EULA)。

若 REDAgent.exe 與線上服務或反作弊機制有關，使用此修補程式可能導致帳號遭到永久停權（Ban）。

您的防毒軟體可能會將此腳本標記為惡意程式，因為它會直接修改執行檔與記憶體代碼。基於本腳本的運作特性，這是正常的誤報。

🌟 功能特色

自動提權：若尚未以系統管理員身分執行，會自動透過 Windows UAC 請求管理員權限。

智慧偵測：自動尋找目前正在執行中的 REDAgent.exe 檔案路徑。

嚴格版本控制：使用 SHA256 雜湊值檢查，確保只會修改完全符合支援版本的檔案，防止意外損壞其他不支援的版本。

安全修改：在進行任何更改前，會自動建立備份檔（REDAgent.exe.bak）。

自動還原：如果修改過程失敗或最終的寫入驗證結果不符，腳本會自動從備份檔還原成原始檔案。

📋 系統需求

安裝有 PowerShell 的 Windows 作業系統。

執行腳本前，必須先啟動 REDAgent.exe。

系統管理員權限。

🚀 使用方法

啟動目標程式：確保 REDAgent.exe 目前正在背景執行中。

執行腳本：點擊兩下執行 patch-window-mode.bat。

允許權限：接受 Windows 使用者帳戶控制 (UAC) 提示，允許腳本以系統管理員身分執行。

等待完成：腳本會自動執行以下動作：

偵測執行中的進程與路徑。

驗證檔案雜湊值。

關閉 REDAgent.exe 進程。

建立備份並套用修補。

重新啟動程式：當主控台顯示「Patch complete」（修改完成）後，即可正常啟動 REDAgent.exe。它現在應該會以視窗模式執行了。

🛠️ 技術細節 (運作原理)

此腳本針對執行檔進行了特定的二進位修改（Hex 編輯）：

它會先檢查檔案是否符合預期的 SHA256 雜湊值（857143d5ceef5b1efba299ec07103bce570144a4d134ed5ffcb968b1a02054d5）。

將檔案位移 0x635e 處的位元組從 0x74（x86 JZ / JE 指令 - 若為零則跳轉）修改為 0xeb（x86 JMP 指令 - 無條件跳轉）。

這會繞過原本的條件檢查邏輯，強制程式進入特定的執行路線（即視窗化模式）。

❓ 常見問題與排除

「Unsupported REDAgent.exe version. No changes made.」
您目前的 REDAgent.exe 版本與本腳本支援的版本不同。為防止檔案損壞，腳本已自動中止執行，不會對您的檔案造成任何更改。

「Cannot read the running program path. Run this BAT as administrator.」
請確定您有允許 UAC 權限提示。某些較嚴格的防毒軟體可能會阻擋 PowerShell 讀取進程路徑，請嘗試暫時關閉防毒軟體再試一次。

「REDAgent.exe restarted automatically. Stop its service before retrying.」
有背景服務或啟動器正強制讓程式保持執行狀態。您必須在執行修補程式前，先關閉該自動重啟服務或遊戲啟動器。

📝 授權條款

本專案依「現況」提供，不附帶任何形式的擔保。請謹慎使用。
