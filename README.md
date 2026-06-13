# いっくいっく 1Quick

五・七・五を埋めるだけの俳句作成アプリ。音数カウント・季語パレット・型テンプレート・お題ガチャ・句帳、そして
「投稿すると雰囲気の近い2句が出て、好きな方を選ぶとレーティング（Elo）が更新される」句くらべ機能つき。

ファイルは [`index.html`](index.html) 1枚だけ。ダブルクリックで開けばすぐ動きます。

## 2つのモード

| モード | 条件 | データの置き場所 |
|---|---|---|
| ローカル | 既定（設定なし） | この端末の `localStorage` だけ |
| みんなで共有 | Supabase の設定を入れる | クラウド（全員で共有） |

設定が空のうちは、サンプル12句を相手に**この端末だけ**で句くらべできます。

## 「みんなで共有」モードにする手順

1. [supabase.com](https://supabase.com) で無料アカウント＆新規プロジェクトを作成。
2. 左メニュー **SQL Editor** を開き、[`supabase.sql`](supabase.sql) の中身を貼り付けて **Run**。
   （テーブル `haiku`・投票関数 `vote()`・権限設定・サンプル12句が入ります）
3. **Project Settings → API** から次の2つをコピー：
   - **Project URL**（例 `https://xxxx.supabase.co`）
   - **anon public** key（公開してよい鍵です）
4. [`index.html`](index.html) 内の設定欄に貼り付ける：
   ```html
   <script>
     window.SUPA_URL = 'https://xxxx.supabase.co';
     window.SUPA_KEY = 'eyJhbGciOi...';
   </script>
   ```
5. 保存して開き直せば共有モード。🏆ランキングの「ローカルモードです」注記が消えれば成功です。

## 安全性メモ

- `anon` key はクライアントに置く前提の公開鍵です。データは **RLS（行レベルセキュリティ）** で守ります。
- 新規投稿は**トリガで必ず rating=1500 に固定**。レート変更は投票関数 `vote()` 経由のみ（UPDATE/DELETE は直接不可）。
- 投票の Elo 計算は**サーバー側で行・id順ロック**して行うので、同時に投票が来ても壊れません。

## 既知の限界 / 次の一手

- 類似度は軽量なキーワード辞書ベクトルです。精度を上げるなら埋め込み（embedding）＋ `pgvector` に差し替え。
- 連投・荒らし対策（レート制限）は未実装。本格運用時は Edge Function や reCAPTCHA を検討。
