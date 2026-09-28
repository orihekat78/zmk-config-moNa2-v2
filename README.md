# zmk-config-moNa2

<img src="keymap-drawer/mona2_01.svg">

## Keymap Editorから右側を書き換える（Windows）

初回だけ、[GitHub CLI](https://cli.github.com/) を入れて `gh auth login` を実行する。Keymap EditorにはGitHubでログインし、`orihekat78/zmk-config-moNa2-v2` の `main` を開く。このフォークのGitHub Actionsも有効にしておく。

以後のキーマップ変更は次の順序で行う。

1. [tools/KeymapWorkflow.cmd](tools/KeymapWorkflow.cmd) をダブルクリックする。PowerShellの監視画面を開いたままにする。
2. [Keymap Editor](https://nickcoutsos.github.io/keymap-editor/) で `config/mona2.keymap` を編集し、GitHubへ保存する。すでに開いているエディタ画面を使える。
3. 補助ツールがその保存に対応するGitHub Actionsのビルドを待ち、右側のUF2を `Downloads\moNa2-builds` に取得する。
4. 「RESETを素早く2回押してください」と表示されたら、右側をUSBで接続してRESETを2回押す。XIAO nRF52840のUF2ドライブを検出すると、自動で右側UF2をコピーする。

エディタを通常のブラウザで開く場合は、`tools\KeymapWorkflow.cmd -OpenEditor` を実行する。ビルドとダウンロードだけで止める場合は `-BuildOnly` を付ける。すでに完了したビルドを使う場合は `-RunId <GitHub Actionsのrun ID>` を付ける。

この補助ツールはキーマップ変更用で、右側のファームウェアだけを書き込む。基板設定や左右の構成を変更した場合は、必要なUF2を別途確認して書き込む。ブートローダーへ入れるRESET操作は本体で行う。

# COROPITを使用するへ

COROPITを使用する方は以下のようにコードを編集してください。

mona2_r.overlay

修正前
```
  trackball_central: trackball_central@0 {
        status = "okay";
        compatible = "pixart,pmw3610";  //トラボセンサ用のドライバとバインド
        reg = <0>;
        spi-max-frequency = <2000000>;
        irq-gpios = <&gpio0 2 (GPIO_ACTIVE_LOW | GPIO_PULL_UP)>; //P0.02を指定(MOTION)
        cpi = <600>;
        //swap-xy;
        //invert-x; //COROPIT版ではコメントアウトを外す
        //invert-y; //COROPIT版ではコメントアウトを外す
        evt-type = <INPUT_EV_REL>;
        x-input-code = <INPUT_REL_X>;
        y-input-code = <INPUT_REL_Y>;
    };
};

```
**修正後**
```
  trackball_central: trackball_central@0 {
        status = "okay";
        compatible = "pixart,pmw3610";  //トラボセンサ用のドライバとバインド
        reg = <0>;
        spi-max-frequency = <2000000>;
        irq-gpios = <&gpio0 2 (GPIO_ACTIVE_LOW | GPIO_PULL_UP)>; //P0.02を指定(MOTION)
        cpi = <600>;
        //swap-xy;
        invert-x; //COROPIT版ではコメントアウトを外す
        invert-y; //COROPIT版ではコメントアウトを外す
        evt-type = <INPUT_EV_REL>;
        x-input-code = <INPUT_REL_X>;
        y-input-code = <INPUT_REL_Y>;
    };
};

```
