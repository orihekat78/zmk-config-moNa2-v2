# zmk-config-moNa2

<img src="keymap-drawer/mona2_01.svg">

## Keymap Editorからファームウェアを書き換える（Windows）

初回だけ、[GitHub CLI](https://cli.github.com/) を入れて `gh auth login` を実行する。Keymap EditorにはGitHubでログインし、`orihekat78/zmk-config-moNa2-v2` の `main` を開く。このフォークのGitHub Actionsも有効にしておく。

以後のキーマップ変更では、中央側の右側を書き換える。次の順序で行う。

1. [tools/KeymapWorkflow.cmd](tools/KeymapWorkflow.cmd) をダブルクリックする。既定ブラウザでKeymap Editorが開き、PowerShellの監視画面も表示される。監視画面を開いたままにする。
2. [Keymap Editor](https://nickcoutsos.github.io/keymap-editor/) で `config/mona2.keymap` を編集し、GitHubへ保存する。すでにログイン済みのアプリ内エディタ画面を使ってもよい。
3. 補助ツールがその保存に対応するGitHub Actionsのビルドを待ち、右側のUF2を `Downloads\moNa2-builds` に取得する。
4. 「RESETを素早く2回押してください」と表示されたら、**右側だけ**をUSBで接続してRESETを2回押す。XIAO nRF52840のUF2ドライブを検出したら、右側であることを確認して `RIGHT` と入力する。右側UF2をコピーする。

ビルドとダウンロードだけで止める場合は `-BuildOnly` を付ける。すでに完了したビルドを使う場合は `-RunId <GitHub Actionsのrun ID>` を付ける。この場合はエディタを開かず、指定したビルドを使う。

左側を書き換える場合は、成功したビルドのIDを指定して `tools\KeymapWorkflow.cmd -RunId <GitHub Actionsのrun ID> -Side Left` を実行する。**左側だけ**をUSB接続してRESETを素早く2回押し、確認画面で `LEFT` と入力する。左側用の `mona2_l ... .uf2` がコピーされる。新たにKeymap Editorで保存する場合は、実行前に `-Side Left` を指定すれば、その保存のビルドを待てる。

UF2ドライブの識別情報では左右を区別できない。指定した側の本体だけを接続する。通常のキーマップ変更には右側の更新で足りる。基板設定や左右の構成を変更した場合は、必要な側をそれぞれ書き込む。ブートローダーへ入れるRESET操作は本体で行う。

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
